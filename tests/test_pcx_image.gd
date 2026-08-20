# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Built from synthetic PCX data rather than game artwork.


## Builds a palettised PCX with a run-length encoded body.
func _palettised(width: int, height: int, indices: PackedByteArray,
		palette: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(PcxImage.HEADER_SIZE)
	out.encode_u8(0, PcxImage.ZSOFT)
	out.encode_u8(1, 5)                    # version
	out.encode_u8(2, 1)                    # run-length encoded
	out.encode_u8(3, 8)                    # bits per pixel
	out.encode_u16(4, 0); out.encode_u16(6, 0)
	out.encode_u16(8, width - 1); out.encode_u16(10, height - 1)
	out.encode_u8(65, 1)                   # planes
	out.encode_u16(66, width)              # bytes per line

	# Literals only: a value below 0xC0 encodes as itself.
	out.append_array(indices)

	out.append(PcxImage.PALETTE_MARKER)
	var full := palette.duplicate()
	full.resize(PcxImage.PALETTE_SIZE)
	out.append_array(full)
	return out


func test_reads_the_header() -> void:
	var pcx := PcxImage.new()
	var data := _palettised(2, 2, PackedByteArray([0, 1, 1, 0]), PackedByteArray())

	assert_true(pcx.parse(data), pcx.error())
	assert_eq(pcx.width, 2)
	assert_eq(pcx.height, 2)
	assert_eq(pcx.bits_per_pixel, 8)
	assert_eq(pcx.planes, 1)


func test_decodes_palettised_pixels() -> void:
	var palette := PackedByteArray([10, 20, 30, 200, 100, 50])
	var data := _palettised(2, 1, PackedByteArray([0, 1]), palette)

	var pcx := PcxImage.new()
	assert_true(pcx.parse(data))
	var image := pcx.to_image(data)

	assert_not_null(image, pcx.error())
	assert_eq(image.get_pixel(0, 0).r8, 10)
	assert_eq(image.get_pixel(0, 0).g8, 20)
	assert_eq(image.get_pixel(0, 0).b8, 30)
	assert_eq(image.get_pixel(1, 0).r8, 200)


func test_expands_runs() -> void:
	# A byte with its top two bits set is a repeat count, not a pixel.
	var body := PackedByteArray([0xC0 | 4, 3])          # four pixels of index 3
	var data := _palettised(4, 1, body, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 90, 91, 92]))

	var pcx := PcxImage.new()
	assert_true(pcx.parse(data))
	var image := pcx.to_image(data)

	assert_not_null(image, pcx.error())
	for x in 4:
		assert_eq(image.get_pixel(x, 0).r8, 90)


func test_the_palette_is_not_decoded_as_pixels() -> void:
	# The palette sits at the end of the file and would otherwise be consumed as
	# image data, which silently corrupts the last rows.
	var palette := PackedByteArray([1, 2, 3, 4, 5, 6])
	var data := _palettised(2, 1, PackedByteArray([1, 0]), palette)

	var pcx := PcxImage.new()
	assert_true(pcx.parse(data))
	assert_not_null(pcx.to_image(data), pcx.error())


func test_rejects_data_that_is_not_pcx() -> void:
	var pcx := PcxImage.new()
	var data := PackedByteArray()
	data.resize(PcxImage.HEADER_SIZE)

	assert_false(pcx.parse(data))
	assert_string_contains(pcx.error(), "not a PCX")


func test_rejects_a_file_shorter_than_the_header() -> void:
	var pcx := PcxImage.new()
	var short := PackedByteArray()
	short.resize(16)

	assert_false(pcx.parse(short))
	assert_string_contains(pcx.error(), "header")


func test_reports_truncated_pixel_data() -> void:
	var data := _palettised(64, 64, PackedByteArray([1, 2, 3]), PackedByteArray())

	var pcx := PcxImage.new()
	assert_true(pcx.parse(data))

	assert_null(pcx.to_image(data))
	assert_string_contains(pcx.error(), "ends early")


func test_reports_an_unsupported_plane_layout() -> void:
	# One image in the installation is 1-bit across four planes.
	var data := _palettised(2, 1, PackedByteArray([0, 0]), PackedByteArray())
	data.encode_u8(3, 1)
	data.encode_u8(65, 4)

	var pcx := PcxImage.new()
	assert_true(pcx.parse(data))
	assert_null(pcx.to_image(data))
	assert_string_contains(pcx.error(), "unsupported")
