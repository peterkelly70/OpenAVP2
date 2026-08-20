# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Written to the shape of the shipped weapons.txt, where a weapon names its
## barrels, a barrel holds firing behaviour and names its ammo, and the ammo
## holds the damage.

const SAMPLE := """
[Pulse_Rifle]
Type            = "Weapon"
PVModel         = "Models\\\\Weapons\\\\Marine\\\\mpulserifle_pv.abc"
CrosshairImage  = "Interface\\\\StatusBar\\\\Marine\\\\Xhair_normal.pcx"
Barrel0         = "Pulse_Rifle_Bullet_Barrel"
Melee           = 0

[Pulse_Rifle_Bullet_Barrel]
Type            = "Barrel"
Range           = 3500
MinXPerturb     = 2
MaxXPerturb     = 6
MinYPerturb     = 2
MaxYPerturb     = 6
VectorsPerRound = 1
ShotsPerClip    = 99
AmmoName        = "Pulse_Rifle_Bullets_Ammo"

[Pulse_Rifle_Bullets_Ammo]
Type            = "Ammo"
InstDamage      = 25

[Knife]
Type            = "Weapon"
Barrel0         = "Knife_Barrel"
Melee           = 1

[Knife_Barrel]
Type            = "Barrel"
Range           = 100
VectorsPerRound = 1
AmmoName        = "Knife_Ammo"

[Knife_Ammo]
Type            = "Ammo"
InstDamage      = 60

[Broken]
Type            = "Weapon"
"""


func _file() -> AttributeFile:
	var file := AttributeFile.new()
	assert_true(file.parse(SAMPLE))
	return file


func _loaded(name: String) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	assert_true(weapon.load_from_file(_file(), name), weapon.error())
	return weapon


func test_follows_the_weapon_barrel_ammo_chain() -> void:
	# Damage is on the ammo, not the weapon, so a reader that stops at the
	# weapon section finds nothing useful.
	var weapon := _loaded("Pulse_Rifle")

	assert_eq(weapon.damage, 25.0)
	assert_eq(weapon.shots_per_clip, 99)


func test_converts_range_into_metres() -> void:
	# 3500 units at eighty units to the metre.
	assert_almost_eq(_loaded("Pulse_Rifle").range_metres, 43.75, 0.01)


func test_reads_spread_from_the_larger_axis() -> void:
	var weapon := _loaded("Pulse_Rifle")

	assert_eq(weapon.min_spread, 2.0)
	assert_eq(weapon.max_spread, 6.0)


func test_reads_model_and_crosshair_paths() -> void:
	var weapon := _loaded("Pulse_Rifle")

	assert_string_contains(weapon.view_model, "mpulserifle_pv.abc")
	assert_string_contains(weapon.crosshair, "Xhair_normal.pcx")


func test_identifies_melee_weapons() -> void:
	assert_false(_loaded("Pulse_Rifle").melee)
	assert_true(_loaded("Knife").melee)


func test_defaults_to_one_ray_per_shot() -> void:
	assert_eq(_loaded("Knife").vectors_per_round, 1)


func test_lists_weapons_but_not_barrels_or_ammo() -> void:
	var names := WeaponDefinition.names_in(_file())

	assert_true(names.has("Pulse_Rifle"))
	assert_true(names.has("Knife"))
	assert_false(names.has("Pulse_Rifle_Bullet_Barrel"))
	assert_false(names.has("Pulse_Rifle_Bullets_Ammo"))


func test_rejects_an_unknown_weapon() -> void:
	var weapon := WeaponDefinition.new()

	assert_false(weapon.load_from_file(_file(), "Nothing"))
	assert_string_contains(weapon.error(), "Nothing")


func test_rejects_a_weapon_with_no_readable_barrel() -> void:
	# Without a barrel there is no firing behaviour at all, so this is a failure
	# rather than a weapon with default values.
	var weapon := WeaponDefinition.new()

	assert_false(weapon.load_from_file(_file(), "Broken"))
	assert_string_contains(weapon.error(), "barrel")
