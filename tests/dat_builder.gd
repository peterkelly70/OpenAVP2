# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DatBuilder
extends RefCounted

## Builds synthetic DAT worlds for tests, written to the layout documented in
## docs/formats/dat.md and independently of the reader.

var version := DatWorld.SUPPORTED_VERSION
var info_string := ""
var _objects: Array = []


func with_version(v: int) -> DatBuilder:
	version = v
	return self


func with_info_string(s: String) -> DatBuilder:
	info_string = s
	return self


## Adds an object. Properties are given as {name: [type, value]}.
func with_object(cls: String, properties: Dictionary = {}) -> DatBuilder:
	_objects.append({"class": cls, "properties": properties})
	return self


func build() -> PackedByteArray:
	var objects := _encode_objects()

	var header := PackedByteArray()
	header.append_array(_u32(version))
	header.append_array(_u32(0))          # object data position, filled below
	header.append_array(_u32(0))          # blind data position
	while header.size() < DatWorld.INFO_LENGTH_OFFSET:
		header.append(0)
	header.append_array(_u32(info_string.length()))
	header.append_array(info_string.to_ascii_buffer())

	header.encode_u32(4, header.size())
	header.append_array(objects)
	return header


func _encode_objects() -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(_u32(_objects.size()))

	for entry in _objects:
		var record := PackedByteArray()
		var cls: String = entry["class"]
		record.append_array(_u16(cls.length()))
		record.append_array(cls.to_ascii_buffer())
		record.append_array(_u32(entry["properties"].size()))

		for name in entry["properties"]:
			var spec: Array = entry["properties"][name]
			var value := _encode_value(spec[0], spec[1])
			record.append_array(_u16(name.length()))
			record.append_array(name.to_ascii_buffer())
			record.append(spec[0])
			record.append_array(_u32(0))       # flags
			record.append_array(_u16(value.size()))
			record.append_array(value)

		out.append_array(_u16(record.size()))
		out.append_array(record)

	return out


func _encode_value(type: int, value: Variant) -> PackedByteArray:
	var out := PackedByteArray()
	match type:
		DatWorld.PropertyType.STRING:
			var text: String = value
			out.append_array(_u16(text.length()))
			out.append_array(text.to_ascii_buffer())
		DatWorld.PropertyType.VECTOR, DatWorld.PropertyType.COLOR:
			var v: Vector3 = value
			out.append_array(_f32(v.x)); out.append_array(_f32(v.y)); out.append_array(_f32(v.z))
		DatWorld.PropertyType.REAL:
			out.append_array(_f32(value))
		DatWorld.PropertyType.BOOL:
			out.append(1 if value else 0)
		DatWorld.PropertyType.FLAGS:
			out.append_array(_u32(value))
		DatWorld.PropertyType.ROTATION:
			var q: Quaternion = value
			out.append_array(_f32(q.x)); out.append_array(_f32(q.y))
			out.append_array(_f32(q.z)); out.append_array(_f32(q.w))
	return out


func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(2); b.encode_u16(0, v); return b


func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_u32(0, v); return b


func _f32(v: float) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_float(0, v); return b
