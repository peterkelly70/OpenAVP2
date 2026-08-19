# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DtxBuilder
extends RefCounted

## Builds synthetic DTX files for tests, written to the layout documented in
## docs/formats/dtx.md and independently of the reader.

var width := 4
var height := 4
var mipmaps := 1
var format := DtxTexture.Format.BIT_32
var version := DtxTexture.SUPPORTED_VERSION
var flags := 0
var user_flags := 0
var command_string := ""
var trailing_bytes := 0
var truncate_pixels := 0


func with_size(w: int, h: int) -> DtxBuilder:
	width = w
	height = h
	return self


func with_format(f: DtxTexture.Format) -> DtxBuilder:
	format = f
	return self


func with_mipmaps(n: int) -> DtxBuilder:
	mipmaps = n
	return self


func with_command_string(s: String) -> DtxBuilder:
	command_string = s
	return self


func with_version(v: int) -> DtxBuilder:
	version = v
	return self


## Appends bytes past the mip chain, as some shipped textures do.
func with_trailing(n: int) -> DtxBuilder:
	trailing_bytes = n
	return self


## Removes bytes from the end, to produce a truncated file.
func with_truncated_pixels(n: int) -> DtxBuilder:
	truncate_pixels = n
	return self


func build() -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(_s32(0))                # resource type
	out.append_array(_s32(version))
	out.append_array(_u16(width))
	out.append_array(_u16(height))
	out.append_array(_u16(mipmaps))
	out.append_array(_u16(0))                # sections
	out.append_array(_s32(flags))
	out.append_array(_s32(user_flags))

	var extra := PackedByteArray()
	extra.resize(12)
	extra[2] = format                        # format identifier
	out.append_array(extra)

	var command := PackedByteArray()
	command.resize(DtxTexture.COMMAND_STRING_SIZE)
	var text := command_string.to_ascii_buffer()
	for i in mini(text.size(), DtxTexture.COMMAND_STRING_SIZE - 1):
		command[i] = text[i]
	out.append_array(command)

	var pixels := PackedByteArray()
	pixels.resize(_expected_pixels() + trailing_bytes - truncate_pixels)
	# A recognisable pattern, so a byte-order bug is visible rather than silent.
	for i in pixels.size():
		pixels[i] = i % 251
	out.append_array(pixels)
	return out


func _expected_pixels() -> int:
	var total := 0
	for level in mipmaps:
		var w := maxi(width >> level, 1)
		var h := maxi(height >> level, 1)
		match format:
			DtxTexture.Format.DXT1:
				total += w * h / 2
			DtxTexture.Format.DXT3, DtxTexture.Format.DXT5:
				total += w * h
			DtxTexture.Format.BIT_16:
				total += w * h * 2
			_:
				total += w * h * 4
	return total


func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(2); b.encode_u16(0, v); return b


func _s32(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_s32(0, v); return b
