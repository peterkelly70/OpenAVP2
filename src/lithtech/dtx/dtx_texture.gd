# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DtxTexture
extends RefCounted

## Reader for LithTech DTX textures.
##
## The format is documented in docs/formats/dtx.md, derived independently from a
## retail installation. Godot supports the S3TC formats natively, so the
## compressed majority of AvP2's textures are handed to the GPU untouched and
## only the uncompressed variants need converting.

## Size of the header preceding pixel data.
const HEADER_SIZE := 164

## Version this reader understands. AvP2 uses -5 throughout.
const SUPPORTED_VERSION := -5

## Offset of the 128-byte command string.
const COMMAND_STRING_OFFSET := 0x24
const COMMAND_STRING_SIZE := 128

## Values of the format identifier in the header's extra bytes.
enum Format {
	PALETTE_8 = 0,
	BIT_8 = 1,
	BIT_16 = 2,
	BIT_32 = 3,
	DXT1 = 4,
	DXT3 = 5,
	DXT5 = 6,
}

## Texture width in pixels.
var width := 0
## Texture height in pixels.
var height := 0
## Number of mipmap levels stored, including the base level.
var mipmaps := 0
## Engine flags from the header.
var flags := 0
## Game-defined flags from the header.
var user_flags := 0
## Pixel format identifier.
var format := Format.BIT_32
## The texture's command string, which carries surface directives such as
## ViewModes, Detailtex and AlphaRef. Empty for most textures.
var command_string := ""

var _error := ""


## Parses a DTX file. Returns whether it succeeded.
func parse(data: PackedByteArray) -> bool:
	_error = ""

	if data.size() < HEADER_SIZE:
		_error = "shorter than a DTX header"
		return false

	var version := data.decode_s32(4)
	if version != SUPPORTED_VERSION:
		_error = "unsupported version %d" % version
		return false

	width = data.decode_u16(8)
	height = data.decode_u16(10)
	mipmaps = data.decode_u16(12)
	flags = data.decode_s32(16)
	user_flags = data.decode_s32(20)

	# The format identifier lives in the third of the header's twelve extra
	# bytes, which begin at 0x18.
	format = data.decode_u8(0x1A) as Format

	if width == 0 or height == 0:
		_error = "zero dimensions"
		return false
	if mipmaps == 0:
		_error = "no mipmap levels"
		return false

	command_string = _read_command_string(data)
	return true


## The reason parsing failed, or an empty string.
func error() -> String:
	return _error


## Whether the pixel data is an S3TC format Godot can upload directly.
func is_compressed() -> bool:
	return format in [Format.DXT1, Format.DXT3, Format.DXT5]


## Bytes occupied by one mip level of the given size.
func level_size(level_width: int, level_height: int) -> int:
	match format:
		Format.DXT1:
			return maxi(level_width, 1) * maxi(level_height, 1) / 2
		Format.DXT3, Format.DXT5:
			return maxi(level_width, 1) * maxi(level_height, 1)
		Format.BIT_16:
			return maxi(level_width, 1) * maxi(level_height, 1) * 2
		_:
			return maxi(level_width, 1) * maxi(level_height, 1) * 4


## Total bytes the mip chain should occupy.
func expected_data_size() -> int:
	var total := 0
	for level in mipmaps:
		total += level_size(width >> level, height >> level)
	return total


## Builds a Godot image from a parsed file.
##
## Returns null when the data does not match the header, which is a stronger
## check than trusting the header alone.
##
## Only the base level is used. DTX stores a partial mip chain, typically four
## levels for a 256 by 256 texture, while Godot requires a complete chain down
## to one pixel. Uploading the partial chain is rejected by the engine, so the
## base level is taken and mip generation is left to Godot, which can also
## regenerate them at the filtering quality the renderer wants.
func to_image(data: PackedByteArray) -> Image:
	var pixels := data.slice(HEADER_SIZE)
	var expected := expected_data_size()

	# Some textures carry trailing data beyond the mip chain, so only a shortfall
	# is an error.
	if pixels.size() < expected:
		_error = "pixel data is %d bytes, expected at least %d" % [pixels.size(), expected]
		return null

	var godot_format := _godot_format()
	if godot_format < 0:
		_error = "unsupported pixel format %d" % format
		return null

	var base := pixels.slice(0, level_size(width, height))
	if format == Format.BIT_32 or format == Format.PALETTE_8:
		base = _bgra_to_rgba(base)

	return Image.create_from_data(width, height, false, godot_format, base)


## The bytes of one stored mip level, or an empty array when absent.
func mip_data(data: PackedByteArray, level: int) -> PackedByteArray:
	if level < 0 or level >= mipmaps:
		return PackedByteArray()

	var offset := HEADER_SIZE
	for i in level:
		offset += level_size(width >> i, height >> i)
	var size := level_size(width >> level, height >> level)
	if offset + size > data.size():
		return PackedByteArray()
	return data.slice(offset, offset + size)


func _godot_format() -> int:
	match format:
		Format.DXT1:
			return Image.FORMAT_DXT1
		Format.DXT3:
			return Image.FORMAT_DXT3
		Format.DXT5:
			return Image.FORMAT_DXT5
		Format.BIT_32, Format.PALETTE_8:
			# Files that declare no format identifier store 32-bit pixels; the
			# field predates them and defaults to zero.
			return Image.FORMAT_RGBA8
		_:
			return -1


## LithTech stores uncompressed pixels as BGRA; Godot expects RGBA.
static func _bgra_to_rgba(pixels: PackedByteArray) -> PackedByteArray:
	var out := pixels.duplicate()
	for i in range(0, out.size() - 3, 4):
		var b := out[i]
		out[i] = out[i + 2]
		out[i + 2] = b
	return out


func _read_command_string(data: PackedByteArray) -> String:
	var end := COMMAND_STRING_OFFSET
	var limit := COMMAND_STRING_OFFSET + COMMAND_STRING_SIZE
	while end < limit and end < data.size() and data[end] != 0:
		end += 1
	if end == COMMAND_STRING_OFFSET:
		return ""
	return data.slice(COMMAND_STRING_OFFSET, end).get_string_from_ascii().strip_edges()
