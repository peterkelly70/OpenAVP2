# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Movement is data, not a guess. These cover the conversion from the game's
## units into metres and the fallback when an installation cannot be read.


func test_speeds_convert_from_lithtech_units() -> void:
	# The shipped BaseHuman values are 125 and 300 units per second, which at
	# eighty units to the metre are a 1.56 m/s walk and a 3.75 m/s run.
	var file := AttributeFile.new()
	file.parse("[BaseHuman]\nWalkSpeed = 125\nRunSpeed = 300\nNormJumpSpeed = 550\n")

	assert_almost_eq(MovementAttributes._speed(file, ["BaseHuman"], "WalkSpeed"), 1.5625, 0.001)
	assert_almost_eq(MovementAttributes._speed(file, ["BaseHuman"], "RunSpeed"), 3.75, 0.001)
	assert_almost_eq(MovementAttributes._speed(file, ["BaseHuman"], "NormJumpSpeed"), 6.875, 0.001)


func test_a_missing_key_yields_zero_rather_than_a_wrong_speed() -> void:
	var file := AttributeFile.new()
	file.parse("[BaseHuman]\nWalkSpeed = 125\n")

	assert_eq(MovementAttributes._speed(file, ["BaseHuman"], "Absent"), 0.0)


func test_defaults_are_used_when_no_installation_is_available() -> void:
	var attributes := MovementAttributes.new()

	assert_false(attributes.load_from(null))
	assert_false(attributes.loaded())


func test_run_is_faster_than_walk_in_the_defaults() -> void:
	# The controller's built-in values stand in for the data and must keep the
	# same ordering, or movement changes character when data is unavailable.
	var player := PlayerController.new()

	assert_gt(player.run_speed, player.walk_speed)
	assert_gt(player.walk_speed, player.crouch_speed)
	player.free()
