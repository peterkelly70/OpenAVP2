# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Covers loading and scaling of interface artwork. Uses synthetic images, so no
## game artwork is required or redistributed.

const TMP := "user://ui_test"

var _vfs: Vfs
var _images: InterfaceImages


func before_each() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(TMP)
	_vfs = Vfs.new()
	_images = InterfaceImages.new(_vfs)


func after_each() -> void:
	_clean()


func _clean() -> void:
	var absolute := ProjectSettings.globalize_path(TMP)
	if DirAccess.dir_exists_absolute(absolute):
		OS.move_to_trash(absolute)


## Mounts a directory containing one PCX image.
func _mount_pcx(path: String, width: int, height: int) -> void:
	var data := PackedByteArray()
	data.resize(PcxImage.HEADER_SIZE)
	data.encode_u8(0, PcxImage.ZSOFT)
	data.encode_u8(1, 5)
	data.encode_u8(2, 1)
	data.encode_u8(3, 8)
	data.encode_u16(8, width - 1)
	data.encode_u16(10, height - 1)
	data.encode_u8(65, 1)
	data.encode_u16(66, width)

	var body := PackedByteArray()
	body.resize(width * height)
	data.append_array(body)

	data.append(PcxImage.PALETTE_MARKER)
	var palette := PackedByteArray()
	palette.resize(PcxImage.PALETTE_SIZE)
	palette[0] = 200
	data.append_array(palette)

	var full := TMP.path_join(path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()

	_vfs.mount_directory(TMP, MountPriority.Level.BASE_GAME)


func test_loads_a_pcx_image() -> void:
	_mount_pcx("interface/logo.pcx", 8, 4)

	var texture := _images.texture("interface/logo.pcx")

	assert_not_null(texture)
	assert_eq(texture.get_width(), 8)
	assert_eq(texture.get_height(), 4)


func test_upscales_by_the_configured_factor() -> void:
	# The original artwork is 640 by 480 era and looks soft at modern
	# resolutions, so it is enlarged on load.
	_mount_pcx("interface/logo.pcx", 8, 4)
	_images.scale = 3

	var texture := _images.texture("interface/logo.pcx")

	assert_eq(texture.get_width(), 24)
	assert_eq(texture.get_height(), 12)


func test_caches_by_path() -> void:
	# Menus reuse the same artwork across screens, so decoding once matters.
	_mount_pcx("interface/logo.pcx", 8, 4)

	assert_same(_images.texture("interface/logo.pcx"),
		_images.texture("interface/logo.pcx"))


func test_records_images_it_cannot_load() -> void:
	assert_null(_images.texture("interface/absent.pcx"))
	assert_true(_images.missing().has("interface/absent.pcx"))


func test_refuses_an_unknown_format() -> void:
	assert_null(_images.texture("interface/thing.jpg"))
	assert_true(_images.missing().has("interface/thing.jpg"))


func test_an_empty_path_loads_nothing_and_is_not_reported_missing() -> void:
	assert_null(_images.texture(""))
	assert_eq(_images.missing().size(), 0)
