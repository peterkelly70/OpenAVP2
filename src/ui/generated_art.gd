# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name GeneratedArt
extends RefCounted

## OpenAvP2's own interface artwork, generated rather than shipped as images.
##
## Two reasons for generating it. It is resolution independent: a menu drawn at
## 4K asks for 4K artwork and gets it, rather than an upscale of something
## authored for 640 by 480. And it is unambiguously the project's own work, so
## it can be distributed, which the game's artwork cannot.
##
## The palette and forms take after the era the game belongs to, industrial
## greens and warning reds on dark metal, without reproducing anything from it.

## Interface palette.
const BACKGROUND := Color(0.035, 0.042, 0.045)
const PANEL := Color(0.075, 0.088, 0.092)
const PANEL_LIGHT := Color(0.11, 0.13, 0.135)
const ACCENT := Color(0.35, 0.85, 0.42)
const ACCENT_DIM := Color(0.16, 0.34, 0.2)
const WARNING := Color(0.85, 0.18, 0.14)
const TEXT := Color(0.82, 0.87, 0.85)
const TEXT_DIM := Color(0.45, 0.5, 0.49)


## Painted menu artwork shipped with the project.
const BACKGROUND_ART := "res://assets/art/openavp2-menu-background.png"


## The menu background.
##
## Uses the project's own painted artwork when present, falling back to the
## procedural background below so that a build without the art still renders.
static func menu_background(size: Vector2i) -> Texture2D:
	if ResourceLoader.exists(BACKGROUND_ART):
		var texture := load(BACKGROUND_ART)
		if texture is Texture2D:
			return texture
	return background(size)


## A procedurally drawn background: a dark vertical gradient, a faint grid, a
## vignette and scanlines.
##
## Drawn at the requested size, so it is sharp at any resolution. Used when no
## painted artwork is available, and as the basis for panels.
static func background(size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	var centre := Vector2(size) * 0.5
	var max_distance := centre.length()

	for y in size.y:
		var vertical := float(y) / float(maxi(size.y - 1, 1))
		for x in size.x:
			# A slight lift towards the top, as if lit from above.
			var shade := lerpf(1.15, 0.72, vertical)
			var colour := BACKGROUND * shade

			# A faint engineering grid, brighter on major lines.
			var grid := size.y / 24
			if grid > 0 and (x % grid == 0 or y % grid == 0):
				colour = colour.lerp(PANEL_LIGHT, 0.35)
			var major := grid * 4
			if major > 0 and (x % major == 0 or y % major == 0):
				colour = colour.lerp(ACCENT_DIM, 0.22)

			# Vignette towards the corners.
			var distance := Vector2(x, y).distance_to(centre) / max_distance
			colour = colour.darkened(clampf(distance - 0.35, 0.0, 1.0) * 0.7)

			# Scanlines, subtle enough not to shimmer.
			if y % 3 == 0:
				colour = colour.darkened(0.10)

			colour.a = 1.0
			image.set_pixel(x, y, colour)

	return ImageTexture.create_from_image(image)


## A title plate: an angled dark panel with an accent rule, sized to order.
##
## The corners are cut rather than rounded, which is the era's idiom and reads
## as machined rather than soft.
static func title_plate(size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var cut := mini(size.x, size.y) / 6
	var border := maxi(size.y / 40, 2)

	for y in size.y:
		for x in size.x:
			# Cut the top-left and bottom-right corners.
			if x + y < cut or (size.x - x) + (size.y - y) < cut:
				continue

			var edge := x < border or y < border \
				or x >= size.x - border or y >= size.y - border
			var colour := PANEL_LIGHT if edge else PANEL
			colour.a = 0.94 if edge else 0.82
			image.set_pixel(x, y, colour)

	# An accent rule along the lower edge, inset from the cut corners.
	var rule := maxi(size.y / 28, 2)
	for y in range(size.y - rule * 2, size.y - rule):
		for x in range(cut, size.x - cut):
			if y >= 0 and y < size.y:
				image.set_pixel(x, y, ACCENT)

	return ImageTexture.create_from_image(image)


## A crosshair, drawn as four ticks around a gap.
static func crosshair(size: int = 64) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var centre := size / 2
	var gap := size / 8
	var length := size / 4
	var thickness := maxi(size / 32, 1)

	for offset in range(gap, gap + length):
		for t in thickness:
			image.set_pixel(centre + offset, centre + t, ACCENT)
			image.set_pixel(centre - offset, centre + t, ACCENT)
			image.set_pixel(centre + t, centre + offset, ACCENT)
			image.set_pixel(centre + t, centre - offset, ACCENT)

	return ImageTexture.create_from_image(image)
