# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Exercised against synthetic textures built by DtxBuilder, never game data.


func _parsed(builder: DtxBuilder) -> DtxTexture:
	var dtx := DtxTexture.new()
	assert_true(dtx.parse(builder.build()), dtx.error())
	return dtx


func test_reads_the_header() -> void:
	var dtx := _parsed(DtxBuilder.new().with_size(256, 128).with_mipmaps(4))

	assert_eq(dtx.width, 256)
	assert_eq(dtx.height, 128)
	assert_eq(dtx.mipmaps, 4)


func test_reads_the_format_identifier() -> void:
	assert_eq(_parsed(DtxBuilder.new().with_format(DtxTexture.Format.DXT1)).format,
		DtxTexture.Format.DXT1)
	assert_eq(_parsed(DtxBuilder.new().with_format(DtxTexture.Format.DXT5)).format,
		DtxTexture.Format.DXT5)


func test_reads_the_command_string() -> void:
	# Command strings carry surface directives the renderer needs, such as the
	# alpha test threshold, so they must survive parsing intact.
	var dtx := _parsed(DtxBuilder.new().with_command_string("ColorKey 0 0 0;AlphaRef 128;"))

	assert_eq(dtx.command_string, "ColorKey 0 0 0;AlphaRef 128;")


func test_command_string_is_empty_when_absent() -> void:
	assert_eq(_parsed(DtxBuilder.new()).command_string, "")


func test_identifies_compressed_formats() -> void:
	for f in [DtxTexture.Format.DXT1, DtxTexture.Format.DXT3, DtxTexture.Format.DXT5]:
		assert_true(_parsed(DtxBuilder.new().with_format(f)).is_compressed())
	assert_false(_parsed(DtxBuilder.new().with_format(DtxTexture.Format.BIT_32)).is_compressed())


func test_computes_dxt1_sizes_at_half_a_byte_per_pixel() -> void:
	var dtx := _parsed(DtxBuilder.new().with_size(256, 256).with_format(DtxTexture.Format.DXT1).with_mipmaps(4))

	# 32768 + 8192 + 2048 + 512
	assert_eq(dtx.expected_data_size(), 43520)


func test_computes_dxt5_sizes_at_one_byte_per_pixel() -> void:
	var dtx := _parsed(DtxBuilder.new().with_size(256, 256).with_format(DtxTexture.Format.DXT5).with_mipmaps(4))

	# 65536 + 16384 + 4096 + 1024
	assert_eq(dtx.expected_data_size(), 87040)


func test_builds_an_image_from_compressed_data() -> void:
	var builder := DtxBuilder.new().with_size(64, 64).with_format(DtxTexture.Format.DXT1).with_mipmaps(3)
	var dtx := _parsed(builder)

	var image := dtx.to_image(builder.build())

	assert_not_null(image, dtx.error())
	assert_eq(image.get_width(), 64)
	assert_eq(image.get_format(), Image.FORMAT_DXT1)


func test_builds_an_image_from_uncompressed_data() -> void:
	var builder := DtxBuilder.new().with_size(8, 8).with_format(DtxTexture.Format.BIT_32)
	var dtx := _parsed(builder)

	var image := dtx.to_image(builder.build())

	assert_not_null(image, dtx.error())
	assert_eq(image.get_format(), Image.FORMAT_RGBA8)


func test_swaps_byte_order_for_uncompressed_pixels() -> void:
	# LithTech stores BGRA and Godot expects RGBA. Getting this wrong produces a
	# picture that looks plausible but has red and blue exchanged.
	var builder := DtxBuilder.new().with_size(1, 1).with_format(DtxTexture.Format.BIT_32)
	var data := builder.build()
	data[DtxTexture.HEADER_SIZE + 0] = 10     # blue
	data[DtxTexture.HEADER_SIZE + 1] = 20     # green
	data[DtxTexture.HEADER_SIZE + 2] = 30     # red
	data[DtxTexture.HEADER_SIZE + 3] = 40     # alpha

	var dtx := DtxTexture.new()
	assert_true(dtx.parse(data))
	var colour := dtx.to_image(data).get_pixel(0, 0)

	assert_eq(colour.r8, 30)
	assert_eq(colour.g8, 20)
	assert_eq(colour.b8, 10)
	assert_eq(colour.a8, 40)


func test_extracts_individual_mip_levels() -> void:
	var builder := DtxBuilder.new().with_size(64, 64).with_format(DtxTexture.Format.DXT1).with_mipmaps(3)
	var data := builder.build()
	var dtx := _parsed(builder)

	assert_eq(dtx.mip_data(data, 0).size(), 64 * 64 / 2)
	assert_eq(dtx.mip_data(data, 1).size(), 32 * 32 / 2)
	assert_eq(dtx.mip_data(data, 2).size(), 16 * 16 / 2)
	assert_eq(dtx.mip_data(data, 3).size(), 0, "level beyond those stored")


func test_tolerates_trailing_data_beyond_the_mip_chain() -> void:
	var builder := DtxBuilder.new().with_size(32, 32).with_mipmaps(2).with_trailing(64)
	var dtx := _parsed(builder)

	assert_not_null(dtx.to_image(builder.build()), dtx.error())


func test_rejects_truncated_pixel_data() -> void:
	var builder := DtxBuilder.new().with_size(32, 32).with_truncated_pixels(100)
	var dtx := _parsed(builder)

	assert_null(dtx.to_image(builder.build()))
	assert_string_contains(dtx.error(), "expected at least")


func test_rejects_an_unsupported_version() -> void:
	var dtx := DtxTexture.new()

	assert_false(dtx.parse(DtxBuilder.new().with_version(-2).build()))
	assert_string_contains(dtx.error(), "version")


func test_rejects_a_file_shorter_than_the_header() -> void:
	var dtx := DtxTexture.new()
	var short := PackedByteArray()
	short.resize(64)

	assert_false(dtx.parse(short))
	assert_string_contains(dtx.error(), "header")


func test_reports_which_versions_it_supports() -> void:
	var dtx := DtxTexture.new()

	assert_false(dtx.parse(DtxBuilder.new().with_version(-2).build()))
	assert_string_contains(dtx.error(), "-2")
	assert_string_contains(dtx.error(), "-5")
