# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DatReader
extends RefCounted

## Sequential reader for the primitive types used by LithTech world files.
##
## The format is little-endian throughout and mixes fixed-width numbers with
## length-prefixed strings, so a cursor that tracks its own position keeps the
## structure readers legible and makes an overrun detectable in one place.

var _data: PackedByteArray
var _offset := 0
var _failed := false


func _init(data: PackedByteArray, offset: int = 0) -> void:
	_data = data
	_offset = offset


## Current position.
func offset() -> int:
	return _offset


## Moves to an absolute position.
func seek(position: int) -> void:
	_offset = position


## Advances by a number of bytes.
func skip(count: int) -> void:
	_offset += count


## Whether a read has run past the end of the data.
func failed() -> bool:
	return _failed


## Whether the given number of bytes remain.
func has(count: int) -> bool:
	return _offset + count <= _data.size()


func u8() -> int:
	if not _check(1): return 0
	var value := _data.decode_u8(_offset)
	_offset += 1
	return value


func u16() -> int:
	if not _check(2): return 0
	var value := _data.decode_u16(_offset)
	_offset += 2
	return value


func s16() -> int:
	if not _check(2): return 0
	var value := _data.decode_s16(_offset)
	_offset += 2
	return value


func u32() -> int:
	if not _check(4): return 0
	var value := _data.decode_u32(_offset)
	_offset += 4
	return value


func s32() -> int:
	if not _check(4): return 0
	var value := _data.decode_s32(_offset)
	_offset += 4
	return value


func f32() -> float:
	if not _check(4): return 0.0
	var value := _data.decode_float(_offset)
	_offset += 4
	return value


## A three-component vector.
func vector() -> Vector3:
	return Vector3(f32(), f32(), f32())


## A four-component rotation.
func quaternion() -> Quaternion:
	return Quaternion(f32(), f32(), f32(), f32())


## A string with a u16 length prefix.
func short_string() -> String:
	var length := u16()
	return _string_of(length)


## A string with a u32 length prefix.
func long_string() -> String:
	var length := u32()
	return _string_of(length)


## A fixed number of bytes as a string.
func fixed_string(length: int) -> String:
	return _string_of(length)


## A NUL-terminated string.
func c_string() -> String:
	var start := _offset
	while _offset < _data.size() and _data[_offset] != 0:
		_offset += 1
	var text := _data.slice(start, _offset).get_string_from_ascii()
	_offset += 1
	return text


func _string_of(length: int) -> String:
	if length <= 0 or not _check(length):
		return ""
	var text := _data.slice(_offset, _offset + length).get_string_from_ascii()
	_offset += length
	return text


func _check(count: int) -> bool:
	if _offset + count > _data.size():
		_failed = true
		return false
	return true
