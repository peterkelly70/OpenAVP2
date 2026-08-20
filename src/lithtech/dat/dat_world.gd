# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DatWorld
extends RefCounted

## Reader for LithTech Talon v70 world files.
##
## The format is documented in docs/formats/dat.md, derived independently from a
## retail installation. This reads the header and the object records; geometry
## is a separate and much larger task.

## Versions this reader understands.
##
## Held as a set rather than a single constant so that adding a version is a
## data change plus whatever branching that version needs. Every AvP2 world is
## 70, the Talon revision. Other LithTech generations use different world
## versions and should be added here once their files can be tested rather than
## assumed.
const SUPPORTED_VERSIONS: Array[int] = [70]

## The version AvP2 uses, for tests and for building files.
const SUPPORTED_VERSION := 70

## Offset of the world info string's length.
##
## The header is a version, two offsets and eight unused slots, so the world
## info section begins here.
const INFO_LENGTH_OFFSET := 0x2C

## Offset of the world info string itself.
const INFO_STRING_OFFSET := 0x30

## Longest world info string accepted, as a guard against a bad read.
const MAX_INFO_LENGTH := 4096

## Property type identifiers.
enum PropertyType {
	STRING = 0,
	VECTOR = 1,
	COLOR = 2,
	REAL = 3,
	FLAGS = 4,
	BOOL = 5,
	LONG_INT = 6,
	ROTATION = 7,
}

## Guards the world tree walk against a malformed subdivision bitstream.
const MAX_TREE_DEPTH := 16

## Upper bounds on the counts a world model may declare.
##
## Geometry is reached by reading forwards rather than through an offset, so a
## misread yields enormous counts rather than an obvious failure. Bounding them
## turns that into a clean rejection instead of an allocation that never
## returns.
const MAX_MODELS := 65535
const MAX_POINTS := 4194304
const MAX_POLYGONS := 4194304
const MAX_SURFACES := 1048576

## World version, always 70 for AvP2.
var version := 0

## Offset of the object records within the file.
var object_data_position := 0

## Offset of the blind object data.
var blind_data_position := 0

## The world info string, carrying directives such as AmbientLight and
## TerrainSubDivSize. Empty for about a third of AvP2's worlds.
var info_string := ""

## Every object record, in file order.
var objects: Array[DatObject] = []

## Lightmap grid size from the world info section.
var lightmap_grid_size := 0.0

## World bounds.
var bounds_min := Vector3.ZERO
var bounds_max := Vector3.ZERO

## Number of nodes in the world tree.
var world_tree_nodes := 0

## Every world model, in file order. The first is the level hull.
var world_models: Array[DatWorldModel] = []

var _error := ""


## Parses a world file. Returns whether it succeeded.
func parse(data: PackedByteArray) -> bool:
	_error = ""
	objects = []

	if data.size() < INFO_STRING_OFFSET:
		_error = "shorter than a DAT header"
		return false

	version = data.decode_u32(0)
	if not SUPPORTED_VERSIONS.has(version):
		_error = "unsupported version %d, this reader handles %s" % [version, SUPPORTED_VERSIONS]
		return false

	object_data_position = data.decode_u32(4)
	blind_data_position = data.decode_u32(8)

	if not _read_info_string(data):
		return false

	if object_data_position <= 0 or object_data_position >= data.size():
		_error = "object data offset %d is outside the file" % object_data_position
		return false

	if not _read_objects(data):
		return false

	# Geometry is not addressed by an offset; it follows the world info section
	# sequentially. A failure here is reported but does not discard the objects,
	# which are useful on their own.
	_read_geometry(data)
	return true


## Reads the world info, tree and models, which run sequentially from just after
## the world info string.
func _read_geometry(data: PackedByteArray) -> bool:
	var reader := DatReader.new(data, INFO_STRING_OFFSET + info_string.length())

	lightmap_grid_size = reader.f32()
	bounds_min = reader.vector()
	bounds_max = reader.vector()

	# The world tree repeats the bounds, padded, then declares its node count.
	reader.vector()
	reader.vector()
	world_tree_nodes = reader.s32()
	reader.s32()

	_skip_world_tree(reader)

	var model_count := reader.s32()
	if model_count < 0 or model_count > MAX_MODELS:
		_error = "implausible world model count %d" % model_count
		return false

	for i in model_count:
		var model := _read_world_model(reader, data)
		if model == null:
			return false
		if model.has_geometry():
			world_models.append(model)

	return true


## Walks the tree's subdivision bitstream, which encodes one bit per node: set
## means the node divides into four children. Only its length matters here,
## since the tree itself is not needed to build geometry.
func _skip_world_tree(reader: DatReader) -> void:
	var state := {"byte": 0, "bit": 8}
	_walk_tree_node(reader, state, 0)


func _walk_tree_node(reader: DatReader, state: Dictionary, depth: int) -> void:
	if depth > MAX_TREE_DEPTH or reader.failed():
		return

	if int(state["bit"]) == 8:
		state["byte"] = reader.u8()
		state["bit"] = 0

	var subdivides: bool = (int(state["byte"]) & (1 << int(state["bit"]))) != 0
	state["bit"] = int(state["bit"]) + 1

	if subdivides:
		for i in 4:
			_walk_tree_node(reader, state, depth + 1)


func _read_world_model(reader: DatReader, data: PackedByteArray) -> DatWorldModel:
	var start := reader.offset()
	var next_model := reader.s32()
	# A fixed padding block precedes each model's geometry.
	reader.skip(32)

	var model := DatWorldModel.new()
	reader.s32()                       # info flags
	reader.s32()
	model.name = reader.short_string()

	var point_count := reader.s32()
	var plane_count := reader.s32()
	var surface_count := reader.s32()
	var portal_count := reader.s32()
	var polygon_count := reader.s32()
	var leaf_count := reader.s32()

	if point_count < 0 or point_count > MAX_POINTS \
			or polygon_count < 0 or polygon_count > MAX_POLYGONS \
			or surface_count < 0 or surface_count > MAX_SURFACES \
			or plane_count < 0 or plane_count > MAX_POLYGONS \
			or leaf_count < 0 or leaf_count > MAX_POLYGONS:
		_error = "world model declares implausible counts"
		return null

	reader.s32()                       # total vertex references
	reader.s32()                       # visibility list size
	var leaf_list_count := reader.s32()
	var node_count := reader.s32()
	reader.s32()
	reader.s32()

	model.bounds_min = reader.vector()
	model.bounds_max = reader.vector()
	model.translation = reader.vector()

	var texture_bytes := reader.s32()
	var texture_count := reader.s32()
	if texture_bytes < 0 or texture_count < 0 or texture_count > 4096 \
			or not reader.has(texture_bytes):
		_error = "world model '%s' declares an implausible texture block" % model.name
		return null
	var texture_end := reader.offset() + texture_bytes
	for i in texture_count:
		model.textures.append(reader.c_string())
	reader.seek(texture_end)

	# One entry per polygon, giving how many vertices that polygon has.
	var vertex_counts := PackedInt32Array()
	for i in polygon_count:
		var count := reader.u8()
		var extra := reader.u8()
		vertex_counts.append(count + extra)

	if not _skip_leaves(reader, leaf_count):
		return null

	reader.skip(16 * plane_count)      # planes: normal and distance

	for i in surface_count:
		model.surfaces.append(_read_surface(reader))

	for i in point_count:
		model.points.append(reader.vector())

	for i in polygon_count:
		var polygon := _read_polygon(reader, vertex_counts[i] if i < vertex_counts.size() else 0)
		if polygon != null:
			model.polygons.append(polygon)

	if reader.failed():
		_error = "world model '%s' ran past the end of the file" % model.name
		return null

	# Each model declares where the next begins, which is what makes the
	# remaining per-model sections safe to skip without decoding them.
	# Each model declares where the next begins. It must move forwards, or the
	# model loop cannot terminate.
	if next_model > 0 and next_model < data.size():
		if next_model <= start:
			_error = "world model '%s' does not advance the cursor" % model.name
			return null
		reader.seek(next_model)

	return model


func _skip_leaves(reader: DatReader, leaf_count: int) -> bool:
	for i in leaf_count:
		var list_count := reader.u16()
		if list_count == 0xFFFF:
			reader.u16()
		else:
			for j in list_count:
				reader.s16()
				var size := reader.u16()
				reader.skip(size)
		var polygon_count := reader.s32()
		reader.skip(polygon_count * 4)
		reader.s32()
		if reader.failed():
			_error = "leaf list is malformed"
			return false
	return true


func _read_surface(reader: DatReader) -> DatWorldModel.Surface:
	var origin := reader.vector()
	var u_axis := reader.vector()
	var v_axis := reader.vector()

	var texture := reader.u16()
	var flags := reader.s32()
	reader.skip(4)

	# An effect name and parameter follow only when the flag is set.
	if reader.u8() > 0:
		reader.short_string()
		reader.short_string()

	reader.u16()                       # texture flags
	return DatWorldModel.Surface.new(texture, flags, origin, u_axis, v_axis)


func _read_polygon(reader: DatReader, vertex_count: int) -> DatWorldModel.Polygon:
	reader.vector()                    # centre
	reader.s16()                       # lightmap width
	reader.s16()                       # lightmap height

	var extra := reader.s16()
	if extra > 0:
		reader.skip(extra * 4)

	var surface := reader.s32()
	var plane := reader.s32()

	reader.vector()                    # texture mapping axes
	reader.vector()
	reader.vector()

	var indices := PackedInt32Array()
	for i in vertex_count:
		indices.append(reader.s16())
		reader.skip(3)

	if reader.failed():
		return null
	return DatWorldModel.Polygon.new(indices, surface, plane)


## The reason parsing failed, or an empty string.
func error() -> String:
	return _error


## Every object of a given class.
func objects_of_class(cls: String) -> Array[DatObject]:
	var out: Array[DatObject] = []
	for object in objects:
		if object.class_name_ == cls:
			out.append(object)
	return out


## A count of objects by class name, for diagnostics and for deciding which
## classes to implement first.
func class_histogram() -> Dictionary:
	var counts := {}
	for object in objects:
		counts[object.class_name_] = counts.get(object.class_name_, 0) + 1
	return counts


func _read_info_string(data: PackedByteArray) -> bool:
	var length := data.decode_u32(INFO_LENGTH_OFFSET)
	if length == 0:
		info_string = ""
		return true
	if length > MAX_INFO_LENGTH or INFO_STRING_OFFSET + length > data.size():
		_error = "world info string length %d is implausible" % length
		return false

	info_string = data.slice(INFO_STRING_OFFSET, INFO_STRING_OFFSET + length) \
		.get_string_from_ascii()
	return true


func _read_objects(data: PackedByteArray) -> bool:
	var offset := object_data_position
	var count := data.decode_u32(offset)
	offset += 4

	for i in count:
		if offset + 4 > data.size():
			_error = "object %d begins past the end of the file" % i
			return false

		# The declared record length lets a misread be caught immediately rather
		# than corrupting every object that follows.
		var record_length := data.decode_u16(offset)
		var record_start := offset + 2
		offset += 2

		var class_name_length := data.decode_u16(offset)
		offset += 2
		if offset + class_name_length > data.size():
			_error = "object %d has a class name running past the end of the file" % i
			return false

		var cls := data.slice(offset, offset + class_name_length).get_string_from_ascii()
		offset += class_name_length

		var property_count := data.decode_u32(offset)
		offset += 4

		var properties := {}
		for p in property_count:
			offset = _read_property(data, offset, properties)
			if offset < 0:
				_error = "object %d '%s' has a malformed property" % [i, cls]
				return false

		if offset - record_start != record_length:
			_error = "object %d '%s' consumed %d bytes, record declares %d" % [
				i, cls, offset - record_start, record_length]
			return false

		objects.append(DatObject.new(cls, properties))

	return true


## Reads one property into [param properties], returning the new offset, or -1.
func _read_property(data: PackedByteArray, offset: int, properties: Dictionary) -> int:
	if offset + 2 > data.size():
		return -1

	var name_length := data.decode_u16(offset)
	offset += 2
	if offset + name_length + 7 > data.size():
		return -1

	var name := data.slice(offset, offset + name_length).get_string_from_ascii()
	offset += name_length

	var type := data.decode_u8(offset)
	offset += 1
	# Flags are read past rather than stored; nothing consumes them yet.
	offset += 4

	var length := data.decode_u16(offset)
	offset += 2
	if offset + length > data.size():
		return -1

	properties[name] = _decode_value(data, offset, type, length)
	return offset + length


func _decode_value(data: PackedByteArray, offset: int, type: int, length: int) -> Variant:
	match type:
		PropertyType.STRING:
			# A string value is itself length prefixed.
			if length < 2:
				return ""
			var text_length := data.decode_u16(offset)
			if text_length == 0 or offset + 2 + text_length > data.size():
				return ""
			return data.slice(offset + 2, offset + 2 + text_length).get_string_from_ascii()
		PropertyType.VECTOR, PropertyType.COLOR:
			if length < 12:
				return Vector3.ZERO
			return Vector3(data.decode_float(offset), data.decode_float(offset + 4),
				data.decode_float(offset + 8))
		PropertyType.REAL:
			return data.decode_float(offset) if length >= 4 else 0.0
		PropertyType.BOOL:
			return data.decode_u8(offset) != 0 if length >= 1 else false
		PropertyType.FLAGS:
			return data.decode_u32(offset) if length >= 4 else 0
		PropertyType.ROTATION:
			if length < 16:
				return Quaternion.IDENTITY
			return Quaternion(data.decode_float(offset), data.decode_float(offset + 4),
				data.decode_float(offset + 8), data.decode_float(offset + 12))
		_:
			return data.slice(offset, offset + length)
