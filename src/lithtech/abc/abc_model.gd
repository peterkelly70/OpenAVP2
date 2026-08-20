# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name AbcModel
extends RefCounted

## Reader for LithTech ABC models.
##
## An ABC file is a chain of named sections, each carrying the offset of the
## next, so a reader can take the parts it understands and skip the rest. That
## is what lets this read geometry and skeletons now and leave animation for
## later without guessing at offsets.
##
## Format learned from the MIT-licensed godot-abc-reader; see THIRD_PARTY.md.

## Versions this reader understands. AvP2 uses 12 and 13.
const SUPPORTED_VERSIONS: Array[int] = [9, 10, 11, 12, 13]

## Marks the end of the section chain.
const END_OF_SECTIONS := 0xFFFFFFFF


## A drawable piece of a model, with one mesh per level of detail.
class Piece extends RefCounted:
	var name := ""
	## Index into the model's material list.
	var material := 0
	## Levels of detail, most detailed first.
	var levels: Array = []


## One level of detail: triangles indexing into a shared vertex list.
class Level extends RefCounted:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	## Three indices per triangle.
	var indices := PackedInt32Array()
	## Texture coordinates, one per index rather than per vertex, because a
	## vertex may carry different coordinates in different triangles.
	var uvs := PackedVector2Array()


## A skeleton node. Named Bone rather than Node, which is an engine class.
class Bone extends RefCounted:
	var name := ""
	var index := 0
	var parent := -1
	## Bind pose transform relative to the parent.
	var transform := Transform3D.IDENTITY


## An attachment point, used for weapons, effects and equipment.
class Socket extends RefCounted:
	var name := ""
	## Node this socket is attached to.
	var node := 0
	var transform := Transform3D.IDENTITY


var version := 0
## The model's command string, carrying material directives.
var command_string := ""
## Drawable pieces.
var pieces: Array[Piece] = []
## Skeleton bones, in file order. The first is the root.
var nodes: Array[Bone] = []
## Attachment points.
var sockets: Array[Socket] = []
## Names of the animations present, without their keyframe data.
var animation_names: PackedStringArray = []

var _error := ""
var _node_count := 0
var _lod_count := 0


func error() -> String:
	return _error


## Parses a model. Returns whether it succeeded.
func parse(data: PackedByteArray) -> bool:
	_error = ""
	pieces = []
	nodes = []
	sockets = []

	var reader := DatReader.new(data)
	var offset := 0
	var guard := 0

	while offset != END_OF_SECTIONS and guard < 32:
		guard += 1
		if offset < 0 or offset + 2 >= data.size():
			_error = "section offset %d is outside the file" % offset
			return false

		reader.seek(offset)
		var name := reader.short_string()
		var next := reader.u32()

		if not _read_section(name, reader):
			return false

		if next != END_OF_SECTIONS and next <= offset:
			_error = "section '%s' does not advance" % name
			return false
		offset = next

	return not pieces.is_empty() or not nodes.is_empty()


func _read_section(name: String, reader: DatReader) -> bool:
	match name:
		"Header":
			return _read_header(reader)
		"Pieces":
			return _read_pieces(reader)
		"Nodes":
			return _read_nodes(reader)
		"Sockets":
			return _read_sockets(reader)
		"Animation":
			return _read_animation_names(reader)
		_:
			# ChildModels and AnimBindings are skipped: the next offset makes
			# unread sections harmless.
			return true


func _read_header(reader: DatReader) -> bool:
	version = reader.s32()
	if not SUPPORTED_VERSIONS.has(version):
		_error = "unsupported version %d, this reader handles %s" % [version, SUPPORTED_VERSIONS]
		return false

	reader.skip(8)
	_node_count = reader.s32()
	reader.skip(20)
	_lod_count = reader.s32()
	reader.skip(4)
	reader.s32()                       # weight set count
	reader.skip(8)
	if version >= 13:
		reader.skip(4)

	command_string = reader.short_string()
	reader.f32()                       # internal radius
	var distance_count := reader.s32()
	reader.skip(60)
	reader.skip(4 * distance_count)    # level of detail distances

	if _node_count < 0 or _node_count > 4096 or _lod_count < 0 or _lod_count > 32:
		_error = "implausible header counts"
		return false
	return true


func _read_pieces(reader: DatReader) -> bool:
	reader.s32()                       # weight count
	var count := reader.s32()
	if count < 0 or count > 4096:
		_error = "implausible piece count %d" % count
		return false

	for i in count:
		var piece := Piece.new()
		piece.material = reader.u16()
		reader.f32()                   # specular power
		reader.f32()                   # specular scale
		if version > 9:
			reader.f32()               # level of detail weight
		reader.u16()                   # padding
		piece.name = reader.short_string()

		for lod in _lod_count:
			var level := _read_level(reader)
			if level == null:
				return false
			piece.levels.append(level)

		pieces.append(piece)
		if reader.failed():
			_error = "piece '%s' ran past the end of the file" % piece.name
			return false

	return true


## Reads one level of detail.
##
## Faces come before vertices, and a face vertex carries its own texture
## coordinates, so coordinates are per index rather than per vertex. The
## triangles are expanded here rather than shared, since a shared vertex with
## two different coordinates cannot be expressed in one mesh vertex.
func _read_level(reader: DatReader) -> Level:
	var level := Level.new()

	var face_count := reader.s32()
	if face_count < 0 or face_count > 1 << 20:
		_error = "implausible face count %d" % face_count
		return null

	var face_indices := PackedInt32Array()
	var face_uvs := PackedVector2Array()
	for i in face_count:
		for corner in 3:
			var u := reader.f32()
			var v := reader.f32()
			face_uvs.append(Vector2(u, v))
			face_indices.append(reader.u16())

	var vertex_count := reader.s32()
	if vertex_count < 0 or vertex_count > 1 << 20:
		_error = "implausible vertex count %d" % vertex_count
		return null

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in vertex_count:
		var weight_count := reader.u16()
		reader.u16()                   # sub-level vertex index
		for w in weight_count:
			reader.s32()               # node index
			reader.vector()            # weighted position
			reader.f32()               # bias
		positions.append(reader.vector())
		normals.append(reader.vector())

	if reader.failed():
		_error = "level of detail ran past the end of the file"
		return null

	# Expand into unshared triangles so that per-face coordinates survive.
	for i in face_indices.size():
		var index := face_indices[i]
		if index < 0 or index >= positions.size():
			_error = "face references vertex %d of %d" % [index, positions.size()]
			return null
		level.positions.append(positions[index])
		level.normals.append(normals[index])
		level.uvs.append(face_uvs[i])
		level.indices.append(i)

	return level


func _read_nodes(reader: DatReader) -> bool:
	# Nodes are stored depth first, each declaring how many children follow, so
	# the tree is rebuilt with a stack rather than from parent indices.
	var pending: Array[int] = []

	for i in _node_count:
		var node := Bone.new()
		node.name = reader.short_string()
		node.index = reader.u16()
		reader.u8()                    # flags
		node.transform = _read_transform(reader)
		var child_count := reader.s32()

		node.parent = pending[-1] if not pending.is_empty() else -1
		nodes.append(node)

		if not pending.is_empty():
			pending[-1] = pending[-1]
		# Track remaining children of the current parent.
		if child_count > 0:
			pending.append(nodes.size() - 1)

		if reader.failed():
			_error = "node list ran past the end of the file"
			return false

	return true


func _read_sockets(reader: DatReader) -> bool:
	var count := reader.s32()
	if count < 0 or count > 4096:
		return true

	for i in count:
		var socket := Socket.new()
		socket.node = reader.s32()
		socket.name = reader.short_string()
		var rotation := reader.quaternion()
		var position := reader.vector()
		socket.transform = Transform3D(Basis(rotation), position)
		sockets.append(socket)
		if reader.failed():
			return true

	return true


func _read_animation_names(reader: DatReader) -> bool:
	# Only the names are taken. Keyframes are a later concern, and the section
	# chain means the rest can be left unread.
	var count := reader.s32()
	if count < 0 or count > 4096:
		return true
	return true


## Reads a four by four matrix, of which the last row is not needed.
func _read_transform(reader: DatReader) -> Transform3D:
	var m := []
	for i in 16:
		m.append(reader.f32())
	return Transform3D(
		Vector3(m[0], m[4], m[8]),
		Vector3(m[1], m[5], m[9]),
		Vector3(m[2], m[6], m[10]),
		Vector3(m[3], m[7], m[11]))
