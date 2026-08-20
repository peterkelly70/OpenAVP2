# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name InterfaceImages
extends RefCounted

## Loads interface artwork from an installation.
##
## Handles both formats the interface uses, PCX and DTX, so callers can ask for
## a path without caring which. Images are cached by path, since the menus reuse
## the same artwork across screens.
##
## Optional upscaling is applied on load. The original art is 640 by 480 era
## and looks soft on a modern display, so it can be enlarged, but this happens
## in memory from the user's own installation: no artwork is written into the
## project or redistributed.

## How to enlarge artwork.
enum Upscale {
	## Original pixels, sharp and blocky.
	NONE,
	## Smooth interpolation, softer.
	BILINEAR,
	## Sharper than bilinear at the same size.
	LANCZOS,
}

var _vfs: Vfs
var _cache := {}
var _missing := {}

## Multiplier applied to loaded artwork.
var scale := 1
## Interpolation used when scaling.
var upscale := Upscale.LANCZOS


func _init(vfs: Vfs) -> void:
	_vfs = vfs


## Paths that could not be loaded, for diagnostics.
func missing() -> Array:
	return _missing.keys()


## Loads an interface image, or null when it cannot be read.
func texture(path: String) -> ImageTexture:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]

	var image := _load(path)
	var result: ImageTexture = null
	if image != null:
		if scale > 1:
			image.resize(image.get_width() * scale, image.get_height() * scale,
				_interpolation())
		result = ImageTexture.create_from_image(image)

	_cache[path] = result
	return result


func _interpolation() -> Image.Interpolation:
	match upscale:
		Upscale.NONE:
			return Image.INTERPOLATE_NEAREST
		Upscale.BILINEAR:
			return Image.INTERPOLATE_BILINEAR
		_:
			return Image.INTERPOLATE_LANCZOS


func _load(path: String) -> Image:
	var data := _vfs.read(path)
	if data.is_empty():
		_missing[path] = true
		return null

	match path.get_extension().to_lower():
		"pcx":
			var pcx := PcxImage.new()
			if not pcx.parse(data):
				_missing[path] = true
				return null
			var image := pcx.to_image(data)
			if image == null:
				_missing[path] = true
			return image
		"dtx":
			var dtx := DtxTexture.new()
			if not dtx.parse(data):
				_missing[path] = true
				return null
			var image := dtx.to_image(data)
			if image == null:
				_missing[path] = true
				return null
			# Compressed textures must be expanded before they can be scaled.
			if dtx.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			return image
		_:
			_missing[path] = true
			return null
