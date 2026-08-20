# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name PcxImage
extends RefCounted

## Reader for ZSoft PCX images.
##
## PCX is a published format from well before LithTech and is not specific to
## any game; AvP2 uses it for interface artwork. Godot has no PCX importer, so
## the 376 interface images in an installation are unreadable without this.
##
## Three variants appear in AvP2: 8-bit palettised, 24-bit as three planes, and
## a single 4-plane image. All use run-length encoding.

## Fixed header size.
const HEADER_SIZE := 128

## Bytes of palette data appended to a palettised image, after a marker byte.
const PALETTE_SIZE := 768

## Marker introducing the appended palette.
const PALETTE_MARKER := 0x0C

## The only manufacturer value the format defines.
const ZSOFT := 0x0A

var width := 0
var height := 0
## Bits per pixel in each plane.
var bits_per_pixel := 0
## Number of colour planes.
var planes := 0
## Bytes per scanline in one plane, which may exceed the width.
var bytes_per_line := 0

var _error := ""


## The reason parsing failed, or an empty string.
func error() -> String:
	return _error


## Reads a PCX header. Returns whether the data looks like a PCX image.
func parse(data: PackedByteArray) -> bool:
	_error = ""

	if data.size() < HEADER_SIZE:
		_error = "shorter than a PCX header"
		return false

	if data.decode_u8(0) != ZSOFT:
		_error = "not a PCX image"
		return false

	# Run-length encoding is the only encoding the format defines.
	if data.decode_u8(2) != 1:
		_error = "unsupported encoding %d" % data.decode_u8(2)
		return false

	bits_per_pixel = data.decode_u8(3)
	var min_x := data.decode_u16(4)
	var min_y := data.decode_u16(6)
	var max_x := data.decode_u16(8)
	var max_y := data.decode_u16(10)
	planes = data.decode_u8(65)
	bytes_per_line = data.decode_u16(66)

	width = max_x - min_x + 1
	height = max_y - min_y + 1

	if width <= 0 or height <= 0:
		_error = "implausible dimensions %dx%d" % [width, height]
		return false
	if bytes_per_line <= 0:
		_error = "no scanline length"
		return false

	return true


## Decodes the image. Returns null when the data cannot be decoded.
func to_image(data: PackedByteArray) -> Image:
	var scanlines := _decode_scanlines(data)
	if scanlines.is_empty():
		return null

	if bits_per_pixel == 8 and planes == 1:
		return _from_palette(data, scanlines)
	if bits_per_pixel == 8 and planes == 3:
		return _from_planes(scanlines)

	_error = "unsupported %d bits per pixel across %d planes" % [bits_per_pixel, planes]
	return null


## Expands the run-length encoded body into raw scanline bytes.
##
## A byte with its top two bits set is a run count in its low six bits, followed
## by the value to repeat. Anything else is a literal.
func _decode_scanlines(data: PackedByteArray) -> PackedByteArray:
	var expected := bytes_per_line * planes * height
	var out := PackedByteArray()
	out.resize(expected)

	var read := HEADER_SIZE
	var written := 0
	var limit := data.size()

	# A palettised image ends with a marker and 768 bytes of palette, which must
	# not be decoded as pixel data.
	if bits_per_pixel == 8 and planes == 1 and limit >= PALETTE_SIZE + 1:
		limit -= PALETTE_SIZE + 1

	while written < expected and read < limit:
		var byte := data.decode_u8(read)
		read += 1

		if (byte & 0xC0) == 0xC0:
			var count := byte & 0x3F
			if read >= limit:
				break
			var value := data.decode_u8(read)
			read += 1
			for i in count:
				if written >= expected:
					break
				out[written] = value
				written += 1
		else:
			out[written] = byte
			written += 1

	if written < expected:
		_error = "pixel data ends early: %d of %d bytes" % [written, expected]
		return PackedByteArray()

	return out


## Builds an image from palettised scanlines and the appended palette.
func _from_palette(data: PackedByteArray, scanlines: PackedByteArray) -> Image:
	var palette_start := data.size() - PALETTE_SIZE
	if palette_start < HEADER_SIZE or data.decode_u8(palette_start - 1) != PALETTE_MARKER:
		_error = "palettised image has no palette"
		return null

	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)

	for y in height:
		var row := y * bytes_per_line
		for x in width:
			var index := scanlines[row + x] * 3
			var target := (y * width + x) * 4
			pixels[target] = data[palette_start + index]
			pixels[target + 1] = data[palette_start + index + 1]
			pixels[target + 2] = data[palette_start + index + 2]
			pixels[target + 3] = 255

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)


## Builds an image from three separate colour planes.
##
## Each scanline holds a full row of red, then green, then blue, rather than
## interleaved pixels.
func _from_planes(scanlines: PackedByteArray) -> Image:
	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)

	for y in height:
		var row := y * bytes_per_line * planes
		for x in width:
			var target := (y * width + x) * 4
			pixels[target] = scanlines[row + x]
			pixels[target + 1] = scanlines[row + bytes_per_line + x]
			pixels[target + 2] = scanlines[row + bytes_per_line * 2 + x]
			pixels[target + 3] = 255

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
