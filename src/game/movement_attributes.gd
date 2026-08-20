# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MovementAttributes
extends RefCounted

## Movement values read from the game's own attribute data.
##
## The design document says movement should be tuned against reference
## behaviour rather than left at engine defaults. It does not have to be tuned
## by observation: the values are in `attributes/characterbutes.txt`, in
## LithTech units per second, and are converted here to metres.
##
## Reading them rather than guessing also means a mod that changes movement
## changes it here too, since the file resolves through the VFS like any other
## resource.

## Where the character attributes live.
const ATTRIBUTES_PATH := "attributes/characterbutes.txt"

## Sections consulted in order, so a specific character falls back to its base.
const HUMAN_SECTIONS: Array = ["BaseHuman"]

## Speeds in metres per second.
var walk_speed := 0.0
var run_speed := 0.0
var crouch_speed := 0.0
var ladder_speed := 0.0
var liquid_speed := 0.0
var jump_speed := 0.0

## Eye height as a fraction of the character's full height.
var camera_height_percent := 0.82

## Whether this character can walk on walls and ceilings, which the Alien does
## and the Marine does not.
var can_wall_walk := false

var _loaded := false


## Whether values were read from the installation rather than left at defaults.
func loaded() -> bool:
	return _loaded


## Loads a character's movement from an installation through the VFS.
##
## [param sections] are consulted in order, most specific first.
func load_from(vfs: Vfs, sections: Array = HUMAN_SECTIONS) -> bool:
	if vfs == null:
		return false

	var data := vfs.read(ATTRIBUTES_PATH)
	if data.is_empty():
		push_warning("[MOVE] %s not found; using defaults" % ATTRIBUTES_PATH)
		return false

	var file := AttributeFile.new()
	if not file.parse(data.get_string_from_utf8()):
		push_warning("[MOVE] %s could not be parsed; using defaults" % ATTRIBUTES_PATH)
		return false

	walk_speed = _speed(file, sections, "WalkSpeed")
	run_speed = _speed(file, sections, "RunSpeed")
	crouch_speed = _speed(file, sections, "CrouchSpeed")
	ladder_speed = _speed(file, sections, "LadderSpeed")
	liquid_speed = _speed(file, sections, "LiquidSpeed")
	jump_speed = _speed(file, sections, "NormJumpSpeed")

	var percent = file.resolve(sections, "CameraHeightPercent")
	if percent != null:
		camera_height_percent = float(percent)

	var wall_walk = file.resolve(sections, "CanWallWalk")
	if wall_walk != null:
		can_wall_walk = float(wall_walk) != 0.0

	_loaded = walk_speed > 0.0 or run_speed > 0.0
	return _loaded


## Converts a speed in LithTech units per second into metres per second.
static func _speed(file: AttributeFile, sections: Array, key: String) -> float:
	var raw = file.resolve(sections, key)
	if raw == null or not str(raw).is_valid_float():
		return 0.0
	return float(raw) * WorldBuilder.WORLD_SCALE


func _to_string() -> String:
	return "walk %.2f, run %.2f, crouch %.2f, jump %.2f m/s, eye %.0f%%" % [
		walk_speed, run_speed, crouch_speed, jump_speed, camera_height_percent * 100.0]
