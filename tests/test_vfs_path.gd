# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Path canonicalisation is the defence against the cross-platform case and
## separator bugs called out as a standing risk in the design document.


func test_lowercases_and_normalizes_separators() -> void:
	assert_eq(VfsPath.canonicalize("Worlds\\SinglePlayer\\Marine\\m1s1.dat"),
		"worlds/singleplayer/marine/m1s1.dat")
	assert_eq(VfsPath.canonicalize("Textures/Characters/Marine.dtx"),
		"textures/characters/marine.dtx")
	assert_eq(VfsPath.canonicalize("MODELS\\CHARACTERS\\ALIEN.ABC"),
		"models/characters/alien.abc")


func test_strips_empty_and_current_directory_segments() -> void:
	for input in ["/worlds/m1s1.dat", "\\worlds\\m1s1.dat", "worlds//m1s1.dat",
			"worlds\\/m1s1.dat", "./worlds/m1s1.dat", "worlds/./m1s1.dat"]:
		assert_eq(VfsPath.canonicalize(input), "worlds/m1s1.dat", "input: %s" % input)


func test_resolves_parent_segments() -> void:
	assert_eq(VfsPath.canonicalize("worlds/multiplayer/../m1s1.dat"), "worlds/m1s1.dat")


func test_rejects_paths_escaping_the_root() -> void:
	assert_eq(VfsPath.canonicalize("../../etc/passwd"), "")


func test_returns_empty_for_paths_without_segments() -> void:
	assert_eq(VfsPath.canonicalize("/"), "")


func test_matches_paths_differing_only_by_case_and_separator() -> void:
	assert_true(VfsPath.are_equivalent("Worlds\\Marine\\M1S1.DAT", "worlds/marine/m1s1.dat"))


func test_extension_is_lowercased_without_dot() -> void:
	assert_eq(VfsPath.extension("worlds/m1s1.dat"), "dat")
	assert_eq(VfsPath.extension("Textures\\Wall01.DTX"), "dtx")
	assert_eq(VfsPath.extension("readme"), "")
	assert_eq(VfsPath.extension("worlds/m1s1."), "")
	assert_eq(VfsPath.extension("some.dir/readme"), "")
