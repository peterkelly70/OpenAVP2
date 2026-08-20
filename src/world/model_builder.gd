# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name ModelBuilder
extends RefCounted

## Builds Godot meshes from LithTech models.
##
## Sits above the format layer, like WorldBuilder: everything below is
## Godot-free and this is where neutral model data becomes nodes. Skins are
## resolved through the VFS so patched and modded content overrides base
## content as it does everywhere else.

## Metres per LithTech unit, matching world geometry so models and levels agree.
const MODEL_SCALE := WorldBuilder.WORLD_SCALE

var _vfs: Vfs
var _missing := {}


func _init(vfs: Vfs = null) -> void:
	_vfs = vfs


## Skins that could not be resolved.
func missing_skins() -> Array:
	return _missing.keys()


## Builds a mesh instance from a model.
##
## [param skins] are texture paths indexed by a piece's material, as the game's
## attribute data supplies them; a model does not name its own skins.
func build(model: AbcModel, skins: PackedStringArray = PackedStringArray(),
		level: int = 0) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var built := 0

	for piece in model.pieces:
		if piece.levels.is_empty():
			continue
		var lod: AbcModel.Level = piece.levels[mini(level, piece.levels.size() - 1)]
		if lod.positions.is_empty():
			continue

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _scaled(lod.positions)
		arrays[Mesh.ARRAY_NORMAL] = _converted_normals(lod.normals)
		arrays[Mesh.ARRAY_TEX_UV] = lod.uvs
		arrays[Mesh.ARRAY_INDEX] = lod.indices

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(built, _material(skins, piece.material))
		built += 1

	if built == 0:
		return null

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Builds a skeleton from a model's bones.
func build_skeleton(model: AbcModel) -> Skeleton3D:
	if model.nodes.is_empty():
		return null

	var skeleton := Skeleton3D.new()
	for bone in model.nodes:
		skeleton.add_bone(bone.name)

	for i in model.nodes.size():
		var bone: AbcModel.Bone = model.nodes[i]
		if bone.parent >= 0 and bone.parent < i:
			skeleton.set_bone_parent(i, bone.parent)
		var transform := bone.transform
		transform.origin *= MODEL_SCALE
		skeleton.set_bone_rest(i, transform)

	return skeleton


## Attachment points, as transforms in model space.
##
## Weapons, effects and equipment hang off these, so they must survive loading
## even before anything is attached to them.
func sockets_of(model: AbcModel) -> Dictionary:
	var out := {}
	for socket in model.sockets:
		var transform := socket.transform
		transform.origin *= MODEL_SCALE
		out[socket.name] = transform
	return out


func _scaled(positions: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(positions.size())
	for i in positions.size():
		out[i] = WorldBuilder._convert(positions[i])
	return out


## Normals are mirrored on the same axis as positions, but not scaled.
func _converted_normals(normals: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(normals.size())
	for i in normals.size():
		var n := normals[i]
		out[i] = Vector3(-n.x, n.y, n.z)
	return out


func _material(skins: PackedStringArray, index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	if index < 0 or index >= skins.size():
		material.albedo_color = Color(0.62, 0.63, 0.66)
		return material

	var texture := _skin(skins[index])
	if texture != null:
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	else:
		material.albedo_color = Color(0.62, 0.63, 0.66)
	return material


func _skin(path: String) -> ImageTexture:
	if path.is_empty() or _vfs == null:
		return null

	var data := _vfs.read(path)
	if data.is_empty():
		_missing[path] = true
		return null

	var dtx := DtxTexture.new()
	if not dtx.parse(data):
		_missing[path] = true
		return null

	var image := dtx.to_image(data)
	if image == null:
		_missing[path] = true
		return null

	return ImageTexture.create_from_image(image)
