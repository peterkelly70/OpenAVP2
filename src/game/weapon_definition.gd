# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name WeaponDefinition
extends RefCounted

## A weapon assembled from the game's own attribute data.
##
## AvP2 splits a weapon across three linked sections. The weapon names its
## barrels, a barrel holds the firing behaviour and names its ammo, and the ammo
## holds the damage. Nothing useful can be read from the weapon section alone,
## so the chain has to be followed.

const WEAPONS_PATH := "attributes/weapons.txt"

## Weapon name as written in the file, for example "Pulse_Rifle".
var name := ""
## Display model paths, kept for when weapons are drawn.
var view_model := ""
var hand_model := ""
## Crosshair image path.
var crosshair := ""

## Effective range in metres.
var range_metres := 0.0
## Rays fired per shot. Shotguns fire several.
var vectors_per_round := 1
## Rounds in a full clip.
var shots_per_clip := 0
## Damage per ray.
var damage := 0.0
## Spread in degrees, minimum and maximum.
var min_spread := 0.0
var max_spread := 0.0
## Whether the weapon is a melee weapon.
var melee := false
## Sound played when the weapon is selected.
var select_sound := ""
## Sound played when firing.
var fire_sound := ""

## Seconds between shots.
##
## Not present in the attribute data: in the original the rate comes from the
## length of the weapon's fire animation, which lives in the model. Until
## animations are loaded this is a stated assumption rather than a measured
## value, and it is the one number here that is not the game's own.
var fire_interval := 0.1

var _error := ""


## The reason loading failed, or an empty string.
func error() -> String:
	return _error


## Loads a weapon by name from an installation through the VFS.
func load_from(vfs: Vfs, weapon_name: String) -> bool:
	if vfs == null:
		_error = "no filesystem"
		return false

	var data := vfs.read(WEAPONS_PATH)
	if data.is_empty():
		_error = "%s not found" % WEAPONS_PATH
		return false

	var file := AttributeFile.new()
	if not file.parse(data.get_string_from_utf8()):
		_error = "%s could not be parsed" % WEAPONS_PATH
		return false

	return load_from_file(file, weapon_name)


## Loads a weapon from an already-parsed attribute file.
func load_from_file(file: AttributeFile, weapon_name: String) -> bool:
	var weapon := file.section(weapon_name)
	if weapon == null:
		_error = "no weapon named '%s'" % weapon_name
		return false

	name = weapon_name
	view_model = weapon.text("PVModel")
	hand_model = weapon.text("HHModel")
	crosshair = weapon.text("CrosshairImage")
	select_sound = weapon.text("SelectSnd")
	melee = weapon.flag("Melee")

	# The weapon's first barrel carries its primary fire.
	var barrel := file.section(weapon.text("Barrel0"))
	if barrel == null:
		_error = "weapon '%s' names no readable barrel" % weapon_name
		return false

	range_metres = barrel.number("Range") * WorldBuilder.WORLD_SCALE
	vectors_per_round = maxi(barrel.integer("VectorsPerRound", 1), 1)
	shots_per_clip = barrel.integer("ShotsPerClip")
	fire_sound = barrel.text("AltFireSnd")

	# Perturb is the spread cone, given separately per axis. The larger of the
	# two is used, since a single cone cannot express an elliptical spread.
	min_spread = maxf(barrel.number("MinXPerturb"), barrel.number("MinYPerturb"))
	max_spread = maxf(barrel.number("MaxXPerturb"), barrel.number("MaxYPerturb"))

	var ammo := file.section(barrel.text("AmmoName"))
	if ammo != null:
		damage = ammo.number("InstDamage")

	return true


## Every weapon name in the file, in file order.
static func names_in(file: AttributeFile) -> PackedStringArray:
	var out := PackedStringArray()
	for section_name in file.section_names():
		var section := file.section(section_name)
		if section != null and section.text("Type").to_lower() == "weapon":
			out.append(section_name)
	return out


func _to_string() -> String:
	return "%s: %.0f damage x%d, %.0fm range, %d rounds, spread %.0f-%.0f" % [
		name, damage, vectors_per_round, range_metres, shots_per_clip,
		min_spread, max_spread]
