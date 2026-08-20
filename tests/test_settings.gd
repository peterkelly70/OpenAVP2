# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Settings live under an OpenAvP2-owned path; the installation is never
## written to.


func after_each() -> void:
	var path := ProjectSettings.globalize_path(Settings.PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_defaults_to_the_projects_own_artwork() -> void:
	# The generated artwork is the only art that can be distributed, so it is
	# what a fresh installation uses.
	var settings := Settings.new()

	assert_eq(settings.art_source, Settings.ArtSource.GENERATED)
	assert_false(settings.uses_original_art())


func test_round_trips_through_a_file() -> void:
	var saved := Settings.new()
	saved.installation = "/games/avp2"
	saved.art_source = Settings.ArtSource.ORIGINAL
	saved.art_upscale = 3
	assert_true(saved.save_settings())

	var loaded := Settings.new()
	assert_true(loaded.load_settings())

	assert_eq(loaded.installation, "/games/avp2")
	assert_true(loaded.uses_original_art())
	assert_eq(loaded.art_upscale, 3)


func test_reports_when_no_settings_exist() -> void:
	assert_false(Settings.new().load_settings())


func test_settings_are_not_written_into_the_installation() -> void:
	# Writing to the game's directory is forbidden, so the path must be one
	# OpenAvP2 owns.
	assert_true(Settings.PATH.begins_with("user://"))
	assert_true(Settings.new().extract_directory.begins_with("user://"))
