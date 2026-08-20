# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## The project's own artwork. Generated art is drawn at the size asked for,
## which is what makes the interface resolution independent rather than an
## upscale of something authored for a smaller screen.


func test_background_is_drawn_at_the_requested_size() -> void:
	var texture := GeneratedArt.background(Vector2i(160, 90))

	assert_eq(texture.get_width(), 160)
	assert_eq(texture.get_height(), 90)


func test_background_is_drawn_at_any_size() -> void:
	var large := GeneratedArt.background(Vector2i(400, 300))

	assert_eq(large.get_width(), 400)
	assert_eq(large.get_height(), 300)


func test_title_plate_is_drawn_at_the_requested_size() -> void:
	var texture := GeneratedArt.title_plate(Vector2i(240, 100))

	assert_eq(texture.get_width(), 240)
	assert_eq(texture.get_height(), 100)


func test_title_plate_cuts_its_corners() -> void:
	# Cut corners rather than rounded ones are the era's idiom, and the cut is
	# what distinguishes the plate from a plain box.
	var image := GeneratedArt.title_plate(Vector2i(120, 120)).get_image()

	assert_eq(image.get_pixel(0, 0).a, 0.0, "top-left is cut away")
	assert_gt(image.get_pixel(60, 60).a, 0.0, "the middle is solid")


func test_crosshair_is_transparent_at_its_centre() -> void:
	# The gap is the point: a filled centre would obscure what is being aimed at.
	var image := GeneratedArt.crosshair(64).get_image()

	assert_eq(image.get_pixel(32, 32).a, 0.0)


func test_menu_background_returns_a_texture_at_any_size() -> void:
	# Falls back to the procedural background when no painted art is present, so
	# a build without artwork still renders.
	assert_not_null(GeneratedArt.menu_background(Vector2i(320, 180)))
