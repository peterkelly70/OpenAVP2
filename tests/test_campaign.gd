# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## The campaign order comes from the game's mission data rather than from
## sorting filenames, which would put M10 before M2 and lose the real names.

const SAMPLE := """
[Mission0]
Name                 = "Marine Start"
NextLevel            = "Worlds\\\\SinglePlayer\\\\m_open"
ScreenFadeTime       = 5.000000

[Mission1]
Name                 = "Predator Start"
NextLevel            = "Worlds\\\\SinglePlayer\\\\p_open"
ScreenFadeTime       = 2.000000

[Mission2]
Name                 = "Hunt"
NextLevel            = "Worlds\\\\SinglePlayer\\\\p1s1"
ScreenFadeTime       = 2.000000

[NotAMission]
Name                 = "No level"
"""


func _campaign() -> Campaign:
	# Loads through a VFS backed by a directory holding just the mission file.
	var dir := "user://campaign_test"
	DirAccess.make_dir_recursive_absolute(dir.path_join("attributes"))
	var file := FileAccess.open(dir.path_join(Campaign.MISSIONS_PATH), FileAccess.WRITE)
	file.store_string(SAMPLE)
	file.close()

	var vfs := Vfs.new()
	vfs.mount_directory(dir, MountPriority.Level.BASE_GAME)

	var campaign := Campaign.new()
	assert_true(campaign.load_from(vfs))
	return campaign


func after_each() -> void:
	var path := ProjectSettings.globalize_path("user://campaign_test")
	if DirAccess.dir_exists_absolute(path):
		OS.move_to_trash(path)


func test_reads_missions_in_file_order() -> void:
	var missions := _campaign().missions()

	assert_eq(missions.size(), 3)
	assert_eq(missions[0].name, "Marine Start")
	assert_eq(missions[1].name, "Predator Start")


func test_skips_sections_without_a_level() -> void:
	for mission in _campaign().missions():
		assert_ne(mission.name, "No level")


func test_converts_a_level_into_a_world_path() -> void:
	# The file uses Windows separators and no extension.
	assert_eq(_campaign().missions()[0].world_path(), "worlds/singleplayer/m_open.dat")


func test_reads_the_fade_time() -> void:
	assert_almost_eq(_campaign().missions()[0].fade_time, 5.0, 0.01)


func test_groups_missions_by_species() -> void:
	var campaign := _campaign()

	assert_eq(campaign.missions_for("marine").size(), 1)
	assert_eq(campaign.missions_for("predator").size(), 2)
	assert_eq(campaign.missions_for("alien").size(), 0)


func test_unknown_species_have_no_missions() -> void:
	assert_eq(_campaign().missions_for("nothing").size(), 0)


func test_maps_species_to_archives_and_models() -> void:
	assert_eq(Campaign.archive_for("predator"), "PREDATOR.REZ")
	assert_string_contains(Campaign.model_for("predator"), "sp_predator.abc")
	assert_string_contains(Campaign.model_for("alien"), "sp_drone.abc")
	assert_eq(Campaign.archive_for("nothing"), "")


func test_reports_failure_without_a_filesystem() -> void:
	assert_false(Campaign.new().load_from(null))
