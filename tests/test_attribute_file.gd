# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Written to the shape of the shipped files, including their base-and-override
## structure and their comment style.

const SAMPLE := """
// Character attributes

[BaseHuman]
CameraHeightPercent     = 0.82
WalkSpeed               = 125
RunSpeed                = 300
JumpDirection           = <0.0, 1.0, 0.0>
CanWallWalk             = 0
Name                    = "Base Human"

[Marine_Exosuit_AI]
WalkSpeed               = 50      // slower in the suit
RunSpeed				= 400

[BaseAlien]
CanWallWalk             = 1
"""


func _parsed() -> AttributeFile:
	var file := AttributeFile.new()
	assert_true(file.parse(SAMPLE))
	return file


func test_reads_sections() -> void:
	var file := _parsed()

	assert_true(file.has_section("BaseHuman"))
	assert_true(file.has_section("basehuman"), "lookup is case-insensitive")
	assert_false(file.has_section("Nothing"))


func test_reads_numbers() -> void:
	var human := _parsed().section("BaseHuman")

	assert_almost_eq(human.number("CameraHeightPercent"), 0.82, 0.001)
	assert_eq(human.integer("WalkSpeed"), 125)


func test_reads_flags_and_strings() -> void:
	var file := _parsed()

	assert_false(file.section("BaseHuman").flag("CanWallWalk"))
	assert_true(file.section("BaseAlien").flag("CanWallWalk"))
	assert_eq(file.section("BaseHuman").text("Name"), "Base Human", "quotes are removed")


func test_reads_vectors() -> void:
	assert_eq(_parsed().section("BaseHuman").vector("JumpDirection"), Vector3(0, 1, 0))


func test_strips_trailing_comments() -> void:
	# Values are commented in place in the shipped files, so a comment left
	# attached would make the number unparseable.
	assert_eq(_parsed().section("Marine_Exosuit_AI").integer("WalkSpeed"), 50)


func test_tolerates_tabs_around_the_separator() -> void:
	assert_eq(_parsed().section("Marine_Exosuit_AI").integer("RunSpeed"), 400)


func test_resolve_falls_back_through_sections() -> void:
	# The files define a base section and override only what differs, so a
	# lookup must fall back rather than read one section in isolation.
	var file := _parsed()

	assert_eq(float(file.resolve(["Marine_Exosuit_AI", "BaseHuman"], "WalkSpeed")), 50.0)
	assert_almost_eq(float(file.resolve(["Marine_Exosuit_AI", "BaseHuman"],
		"CameraHeightPercent")), 0.82, 0.001, "inherited from the base section")


func test_resolve_returns_nothing_when_no_section_defines_the_key() -> void:
	assert_null(_parsed().resolve(["BaseHuman"], "Absent"))


func test_missing_values_return_the_fallback() -> void:
	var human := _parsed().section("BaseHuman")

	assert_eq(human.number("Absent", 7.0), 7.0)
	assert_eq(human.text("Absent", "none"), "none")
	assert_eq(human.vector("Absent", Vector3.UP), Vector3.UP)


func test_rejects_text_with_no_sections() -> void:
	assert_false(AttributeFile.new().parse("// only a comment\n\n"))
