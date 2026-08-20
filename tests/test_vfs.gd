# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Exercised against synthetic archives and directories, never game data.

const TMP := "user://vfs_test"

var _vfs: Vfs


func before_each() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(TMP)
	_vfs = Vfs.new()


func after_each() -> void:
	_clean()


func _clean() -> void:
	var absolute := ProjectSettings.globalize_path(TMP)
	if DirAccess.dir_exists_absolute(absolute):
		OS.move_to_trash(absolute)


## Writes an archive containing the given {path: text} and mounts it.
func _mount_archive(name: String, files: Dictionary, priority: MountPriority.Level) -> void:
	var builder := RezBuilder.new()
	for path in files:
		builder.with_text_file(path, files[path])
	var full := TMP.path_join(name)
	builder.write(full)
	assert_true(_vfs.mount_archive(full, priority), "mounting %s" % name)


## Writes a directory of loose files and mounts it.
func _mount_directory(name: String, files: Dictionary, priority: MountPriority.Level) -> void:
	var base := TMP.path_join(name)
	for path in files:
		var full := base.path_join(path)
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		var file := FileAccess.open(full, FileAccess.WRITE)
		file.store_string(files[path])
		file.close()
	assert_true(_vfs.mount_directory(base, priority), "mounting %s" % name)


func test_reads_from_a_single_mount() -> void:
	_mount_archive("base.rez", {"worlds/m1.dat": "base"}, MountPriority.Level.BASE_GAME)

	assert_true(_vfs.has("worlds/m1.dat"))
	assert_eq(_vfs.read("worlds/m1.dat").get_string_from_utf8(), "base")


func test_a_higher_priority_mount_wins() -> void:
	# This is the case that matters for AvP2: patch archives override base
	# content, and reading the base version would be silently wrong.
	_mount_archive("base.rez", {"worlds/m1.dat": "base"}, MountPriority.Level.BASE_GAME)
	_mount_archive("patch.rez", {"worlds/m1.dat": "patched"}, MountPriority.Level.OFFICIAL_PATCH)

	assert_eq(_vfs.read("worlds/m1.dat").get_string_from_utf8(), "patched")


func test_mount_order_is_irrelevant_to_priority() -> void:
	# Mounting the patch first must not make it lose.
	_mount_archive("patch.rez", {"a.txt": "patched"}, MountPriority.Level.OFFICIAL_PATCH)
	_mount_archive("base.rez", {"a.txt": "base"}, MountPriority.Level.BASE_GAME)

	assert_eq(_vfs.read("a.txt").get_string_from_utf8(), "patched")


func test_later_mounts_win_within_one_priority_level() -> void:
	# Mods share a level, so their declared load order decides between them.
	_mount_archive("mod_a.rez", {"a.txt": "first"}, MountPriority.Level.MOD)
	_mount_archive("mod_b.rez", {"a.txt": "second"}, MountPriority.Level.MOD)

	assert_eq(_vfs.read("a.txt").get_string_from_utf8(), "second")


func test_loose_files_override_everything() -> void:
	_mount_archive("base.rez", {"a.txt": "base"}, MountPriority.Level.BASE_GAME)
	_mount_archive("mod.rez", {"a.txt": "mod"}, MountPriority.Level.MOD)
	_mount_directory("loose", {"a.txt": "loose"}, MountPriority.Level.USER_OVERRIDE)

	assert_eq(_vfs.read("a.txt").get_string_from_utf8(), "loose")


func test_resolution_is_case_and_separator_insensitive() -> void:
	_mount_archive("base.rez", {"Worlds/M1.dat": "base"}, MountPriority.Level.BASE_GAME)

	assert_true(_vfs.has("WORLDS\\M1.DAT"))
	assert_eq(_vfs.read("worlds/m1.dat").get_string_from_utf8(), "base")


func test_unresolved_paths_read_as_empty() -> void:
	_mount_archive("base.rez", {"a.txt": "base"}, MountPriority.Level.BASE_GAME)

	assert_false(_vfs.has("missing.txt"))
	assert_eq(_vfs.read("missing.txt").size(), 0)


func test_describe_names_the_winning_mount_and_what_it_shadows() -> void:
	# Without this, an unexpected override is diagnosed by guesswork.
	_mount_archive("base.rez", {"a.txt": "base"}, MountPriority.Level.BASE_GAME)
	_mount_archive("patch.rez", {"a.txt": "patched"}, MountPriority.Level.OFFICIAL_PATCH)

	var entry := _vfs.describe("a.txt")

	assert_eq(entry.source, "patch.rez")
	assert_eq(entry.priority, MountPriority.Level.OFFICIAL_PATCH)
	assert_true(entry.is_override())
	assert_eq(entry.shadowed_by, PackedStringArray(["base.rez"]))


func test_describe_reports_no_shadowing_for_a_unique_resource() -> void:
	_mount_archive("base.rez", {"a.txt": "base"}, MountPriority.Level.BASE_GAME)

	assert_false(_vfs.describe("a.txt").is_override())


func test_describe_returns_nothing_for_an_unresolved_path() -> void:
	_mount_archive("base.rez", {"a.txt": "x"}, MountPriority.Level.BASE_GAME)

	assert_null(_vfs.describe("missing.txt"))


func test_lists_paths_after_override_resolution() -> void:
	_mount_archive("base.rez", {"a.txt": "1", "b.txt": "2"}, MountPriority.Level.BASE_GAME)
	_mount_archive("patch.rez", {"b.txt": "3", "c.txt": "4"}, MountPriority.Level.OFFICIAL_PATCH)

	assert_eq(_vfs.paths(), PackedStringArray(["a.txt", "b.txt", "c.txt"]))


func test_lists_paths_under_a_prefix() -> void:
	_mount_archive("base.rez", {"worlds/a.dat": "1", "sounds/b.wav": "2"},
		MountPriority.Level.BASE_GAME)

	assert_eq(_vfs.paths("worlds"), PackedStringArray(["worlds/a.dat"]))


func test_reports_which_paths_are_overridden() -> void:
	_mount_archive("base.rez", {"a.txt": "1", "b.txt": "2"}, MountPriority.Level.BASE_GAME)
	_mount_archive("patch.rez", {"b.txt": "3"}, MountPriority.Level.OFFICIAL_PATCH)

	assert_eq(_vfs.overridden_paths(), PackedStringArray(["b.txt"]))


func test_refuses_to_mount_a_file_that_is_not_an_archive() -> void:
	var path := TMP.path_join("bogus.rez")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not an archive")
	file.close()

	assert_false(_vfs.mount_archive(path, MountPriority.Level.BASE_GAME))
	assert_eq(_vfs.mount_count(), 0)


func test_refuses_to_mount_a_missing_directory() -> void:
	assert_false(_vfs.mount_directory(TMP.path_join("nope"), MountPriority.Level.MOD))
