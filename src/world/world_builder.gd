# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name WorldBuilder
extends RefCounted

## Builds Godot geometry from a parsed LithTech world.
##
## This is the boundary between the format layer and the engine: everything
## below it is Godot-free, and this is where neutral world data becomes nodes.
## Textures are resolved through the VFS so that patched and modded content
## overrides base content exactly as it does everywhere else.

## The model holding the level's collision hull.
const COLLISION_MODEL := "PhysicsBSP"

## Textures that mark a surface as not drawn.
##
## Invisible.dtx is near-fully transparent magenta and is used for clip and
## blocker brushes: the game shapes movement with it without showing it. Drawing
## it opaque fills the level with magenta walls. Sky textures mark portals onto
## the skybox rather than surfaces, and are likewise not drawn directly.
const NON_VISUAL_TEXTURES: Array[String] = [
	"invisible.dtx", "sky.dtx",
]

## Models whose geometry is structural rather than visible.
##
## PhysicsBSP is the collision hull and VisBSP is the visibility structure;
## drawing them would bury the level in overlapping surfaces.
const NON_VISUAL_MODELS: Array[String] = ["PhysicsBSP", "VisBSP"]

## Metres per LithTech unit.
##
## Calibrated against objects of known real-world size rather than guessed: a
## door in the first Marine mission is 160 units tall and the player start sits
## at 128 units, which at this scale give a 2.0 metre door and a 1.6 metre eye
## height. Eighty units to the metre.
const WORLD_SCALE := 0.0125

var _vfs: Vfs
var _materials := {}
var _textures := {}
var _missing_textures := {}


func _init(vfs: Vfs = null) -> void:
	_vfs = vfs


## Texture paths that could not be resolved, for diagnostics.
func missing_textures() -> Array:
	return _missing_textures.keys()


## Builds a node holding one mesh per world model.
##
## [param include_collision] adds the collision hull as geometry instead of
## discarding it, which is useful for inspecting it directly.
func build(world: DatWorld, include_collision: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "World"

	for model in world.world_models:
		if not include_collision and model.name in NON_VISUAL_MODELS:
			continue
		var instance := _build_model(model)
		if instance != null:
			root.add_child(instance)

	return root


## Builds a static body carrying the level's collision.
##
## Collision is generated from the same models that are drawn, plus PhysicsBSP.
## PhysicsBSP alone is not enough: it is the outer world hull, while the
## surfaces actually stood on belong to the terrain and world models. Building
## from only the hull drops the player through the visible floor onto whatever
## the hull encloses far below.
##
## VisBSP is excluded because it is a visibility structure rather than a
## surface, and colliding against it would wall the level off invisibly.
func build_collision(world: DatWorld) -> StaticBody3D:
	var faces := PackedVector3Array()
	for model in world.world_models:
		if model.name == "VisBSP":
			continue
		_append_faces(model, faces)

	if faces.is_empty():
		push_warning("[WORLD] the level has no collision geometry")
		return null

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collider := CollisionShape3D.new()
	collider.shape = shape

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(collider)
	return body


## Appends a model's triangles to a face array.
func _append_faces(model: DatWorldModel, faces: PackedVector3Array) -> void:
	for polygon in model.polygons:
		var indices: PackedInt32Array = polygon.indices
		if indices.size() < 3:
			continue

		var valid := true
		for index in indices:
			if index < 0 or index >= model.points.size():
				valid = false
				break
		if not valid:
			continue

		var first := _convert(model.points[indices[0]])
		for i in range(1, indices.size() - 1):
			faces.append(first)
			faces.append(_convert(model.points[indices[i]]))
			faces.append(_convert(model.points[indices[i + 1]]))


## The number of collision triangles, for diagnostics.
func collision_triangle_count(world: DatWorld) -> int:
	var total := 0
	for model in world.world_models:
		if model.name == "VisBSP":
			continue
		for polygon in model.polygons:
			total += maxi(polygon.indices.size() - 2, 0)
	return total


func _build_model(model: DatWorldModel) -> MeshInstance3D:
	if not model.has_geometry():
		return null

	var mesh := ArrayMesh.new()
	var grouped := model.polygons_by_texture()
	var built := 0

	for texture_index in grouped:
		if _is_non_visual(model, texture_index):
			continue
		var texture := _texture_for(model, texture_index)
		var size := Vector2(texture.get_width(), texture.get_height()) if texture != null \
			else Vector2(256, 256)
		var arrays := _surface_arrays(model, grouped[texture_index], size)
		if arrays.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(built, _material_for(model, texture_index))
		built += 1

	if built == 0:
		return null

	# The node stays at the origin: world model points are already in world
	# space, so positioning by the model's pivot would displace it by its own
	# centre.
	var instance := MeshInstance3D.new()
	instance.name = model.name if not model.name.is_empty() else "WorldModel"
	instance.mesh = mesh
	return instance


## Triangulates a group of polygons into mesh arrays.
##
## World polygons are convex, so a triangle fan from the first vertex is
## sufficient and avoids a general triangulation pass.
func _surface_arrays(model: DatWorldModel, polygons: Array, texture_size: Vector2) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	for polygon in polygons:
		var indices: PackedInt32Array = polygon.indices
		if indices.size() < 3:
			continue

		var valid := true
		for index in indices:
			if index < 0 or index >= model.points.size():
				valid = false
				break
		if not valid:
			continue

		var surface: DatWorldModel.Surface = null
		if polygon.surface >= 0 and polygon.surface < model.surfaces.size():
			surface = model.surfaces[polygon.surface]

		var first_point := model.points[indices[0]]
		var first := _convert(first_point)
		var first_uv := _texture_coordinate(surface, first_point, texture_size)

		for i in range(1, indices.size() - 1):
			var second_point := model.points[indices[i]]
			var third_point := model.points[indices[i + 1]]
			var second := _convert(second_point)
			var third := _convert(third_point)

			var normal := (third - first).cross(second - first).normalized()
			if not normal.is_finite():
				normal = Vector3.UP

			vertices.append(first); normals.append(normal); uvs.append(first_uv)
			vertices.append(second); normals.append(normal)
			uvs.append(_texture_coordinate(surface, second_point, texture_size))
			vertices.append(third); normals.append(normal)
			uvs.append(_texture_coordinate(surface, third_point, texture_size))

	if vertices.is_empty():
		return []

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays


## Projects a vertex onto its surface's texture axes.
##
## LithTech stores mapping as an origin and two axis vectors in world space
## rather than per-vertex coordinates, so the texture coordinate is the vertex's
## offset from that origin projected onto each axis and divided by the texture's
## size. Using the wrong size leaves the mapping correct but scaled wrongly,
## which is why the real texture dimensions are read rather than assumed.
static func _texture_coordinate(surface: DatWorldModel.Surface, point: Vector3,
		texture_size: Vector2) -> Vector2:
	if surface == null or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO

	var offset := point - surface.uv_origin
	return Vector2(offset.dot(surface.uv_u) / texture_size.x,
		offset.dot(surface.uv_v) / texture_size.y)


func _material_for(model: DatWorldModel, texture_index: int) -> StandardMaterial3D:
	var path := _texture_path(model, texture_index)
	if _materials.has(path):
		return _materials[path]

	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_repeat = true

	var texture := _texture_for(model, texture_index)
	if texture != null:
		material.albedo_texture = texture
		# Many world textures carry an alpha channel used for grates, foliage
		# and decals. Rendered opaque they become solid rectangles.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	else:
		material.albedo_color = Color(0.6, 0.6, 0.62)

	_materials[path] = material
	return material


## Whether a texture marks surfaces that should not be drawn.
func _is_non_visual(model: DatWorldModel, texture_index: int) -> bool:
	var path := _texture_path(model, texture_index).to_lower().replace("\\", "/")
	if path.is_empty():
		return false
	var leaf := path.get_file()
	return NON_VISUAL_TEXTURES.has(leaf)


func _texture_path(model: DatWorldModel, texture_index: int) -> String:
	if texture_index >= 0 and texture_index < model.textures.size():
		return model.textures[texture_index]
	return ""


## Loads a texture, caching by path so a texture shared by many models is
## decoded once.
func _texture_for(model: DatWorldModel, texture_index: int) -> ImageTexture:
	var path := _texture_path(model, texture_index)
	if _textures.has(path):
		return _textures[path]
	var texture := _load_texture(path)
	_textures[path] = texture
	return texture


func _load_texture(path: String) -> ImageTexture:
	if path.is_empty() or _vfs == null or not path.to_lower().ends_with(".dtx"):
		return null

	var data := _vfs.read(path)
	if data.is_empty():
		_missing_textures[path] = true
		return null

	var dtx := DtxTexture.new()
	if not dtx.parse(data):
		_missing_textures[path] = true
		return null

	var image := dtx.to_image(data)
	if image == null:
		_missing_textures[path] = true
		return null

	return ImageTexture.create_from_image(image)


## Converts a LithTech coordinate into Godot's space.
##
## LithTech is left-handed with Y up; Godot is right-handed with Y up, so one
## horizontal axis is mirrored. Without this the world renders inside out and
## every surface faces the wrong way.
static func _convert(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z) * WORLD_SCALE
