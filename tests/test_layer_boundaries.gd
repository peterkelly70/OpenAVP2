# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Guards the boundary between the engine layer and the game.
##
## AvP2 is one of several titles built on LithTech, so the container, texture
## and world readers are engine code rather than AvP2 code. Keeping them
## game-neutral costs nothing now; discovering later that AvP2 assumptions have
## spread through the format layer is expensive to undo.
##
## These tests exist because that boundary is otherwise maintained by memory,
## and memory is not a mechanism.

## Directories that must contain no knowledge of any particular game.
const ENGINE_DIRECTORIES: Array[String] = [
	"res://src/lithtech",
	"res://src/vfs",
	"res://src/platform",
]

## Terms that indicate game-specific knowledge. Matching is case-insensitive and
## ignores comments, since documentation may legitimately mention the game the
## reader was developed against.
const GAME_TERMS: Array[String] = [
	"avp2", "primal", "marine", "predator", "xenomorph",
	"pulse rifle", "m1s1", "lithserver",
]

## Godot types the format layer must not depend on, so that parsing stays
## testable without an engine and reusable outside it. Image is permitted in the
## texture reader alone, which exists to produce one.
const GODOT_TYPES: Array[String] = [
	"SceneTree", "AudioStreamPlayer", "Viewport", "Camera3D", "MeshInstance3D",
]


func _engine_scripts() -> Array[String]:
	var found: Array[String] = []
	for directory in ENGINE_DIRECTORIES:
		_collect(directory, found)
	return found


func _collect(directory: String, into: Array[String]) -> void:
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			into.append(directory.path_join(name))
	for sub in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(sub), into)


## Strips comments and the SPDX header, leaving only code.
func _code_of(path: String) -> String:
	var out := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var comment := line.find("#")
		out += (line if comment < 0 else line.substr(0, comment)) + "\n"
	return out


func test_the_engine_layer_contains_scripts_to_check() -> void:
	# Guards the guard: a path typo would otherwise make every test below pass
	# by checking nothing.
	assert_gt(_engine_scripts().size(), 4)


func test_the_engine_layer_names_no_particular_game() -> void:
	var offences: Array[String] = []

	for path in _engine_scripts():
		var code := _code_of(path).to_lower()
		for term in GAME_TERMS:
			if code.contains(term):
				offences.append("%s contains '%s'" % [path, term])

	assert_eq(offences, [] as Array[String],
		"Game-specific knowledge belongs above src/lithtech, in installation " +
		"discovery, the entity registry or the gameplay layer.")


func test_the_format_layer_does_not_depend_on_the_scene_tree() -> void:
	# Format readers must stay usable from a command line tool and testable
	# without booting a game, which is what the design document asks for.
	var offences: Array[String] = []

	for path in _engine_scripts():
		var code := _code_of(path)
		for type_name in GODOT_TYPES:
			if code.contains(type_name):
				offences.append("%s depends on %s" % [path, type_name])

	assert_eq(offences, [] as Array[String])


func test_readers_declare_supported_versions_as_a_set() -> void:
	# A single hardcoded version is what makes a reader hard to extend to another
	# LithTech generation, so each reader must express versions as a set it can
	# grow rather than a constant to be edited.
	for path in ["res://src/lithtech/rez/rez_archive.gd",
			"res://src/lithtech/dtx/dtx_texture.gd",
			"res://src/lithtech/dat/dat_world.gd"]:
		var code := _code_of(path)
		assert_true(code.contains("SUPPORTED_VERSIONS"),
			"%s should declare SUPPORTED_VERSIONS" % path)


func test_an_unsupported_version_reports_what_is_supported() -> void:
	# Pointing a reader at a different LithTech generation should explain the
	# mismatch rather than fail flatly.
	var world := DatWorld.new()
	world.parse(DatBuilder.new().with_version(85).build())
	assert_string_contains(world.error(), "this reader handles")

	var texture := DtxTexture.new()
	texture.parse(DtxBuilder.new().with_version(-3).build())
	assert_string_contains(texture.error(), "this reader handles")
