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

## Models whose geometry is structural rather than visible.
##
## PhysicsBSP is the collision hull and VisBSP is the visibility structure;
## drawing them would bury the level in overlapping surfaces.
const NON_VISUAL_MODELS: Array[String] = ["PhysicsBSP", "VisBSP"]

## LithTech worlds are authored at a much larger scale than Godot's metre.
const WORLD_SCALE := 0.01

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


func _build_model(model: DatWorldModel) -> MeshInstance3D:
	if not model.has_geometry():
		return null

	var mesh := ArrayMesh.new()
	var grouped := model.polygons_by_texture()
	var built := 0

	for texture_index in grouped:
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

	var instance := MeshInstance3D.new()
	instance.name = model.name if not model.name.is_empty() else "WorldModel"
	instance.mesh = mesh
	instance.position = _convert(model.translation)
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
	else:
		material.albedo_color = Color(0.6, 0.6, 0.62)

	_materials[path] = material
	return material


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
