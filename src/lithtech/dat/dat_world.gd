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
	BOOL = 5,
	FLAGS = 6,
	ROTATION = 7,
}

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

	return _read_objects(data)


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
