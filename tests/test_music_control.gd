# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Exercised against text written to the shipped format, never against game data.

const SAMPLE := """
;
; LithTech DirectMusic Level Control File
;

NUMINTENSITIES 10
INITIALINTENSITY 1
VOICES 64
SYNTHSAMPLERATE 44100

STYLE	M144.sty
BAND 	M144.sty 	Band1

INTENSITY	1	0	1	Silence.sgt
INTENSITY	2	0	3	Ambient1.sgt
INTENSITY	5	-1	6	March1.sgt	March1b.sgt

;TRANSITION	2	3	MEASURE	MANUAL
TRANSITION	1	5	IMMEDIATE	MANUAL	TransToMarch1.sgt
TRANSITION	2	1	MEASURE	MANUAL
"""


func _parsed() -> MusicControl:
	var control := MusicControl.new()
	assert_true(control.parse(SAMPLE), control.error())
	return control


func test_reads_scalar_settings() -> void:
	var control := _parsed()

	assert_eq(control.initial_intensity, 1)
	assert_eq(control.settings["VOICES"], "64")
	assert_eq(control.settings["SYNTHSAMPLERATE"], "44100")


func test_reads_styles_and_bands() -> void:
	var control := _parsed()

	assert_eq(control.styles[0], "M144.sty")
	assert_eq(control.bands[0]["style"], "M144.sty")
	assert_eq(control.bands[0]["band"], "Band1")


func test_reads_intensities() -> void:
	var control := _parsed()

	var one := control.intensity(1)
	assert_eq(one.loops, 0)
	assert_eq(one.next, 1)
	assert_eq(one.segments[0], "Silence.sgt")


func test_reads_multiple_segments_on_one_intensity() -> void:
	var five := _parsed().intensity(5)

	assert_eq(five.segments.size(), 2)
	assert_eq(five.loops, -1, "-1 means loop forever")
	assert_eq(five.next, 6)


func test_reads_transitions_with_a_bridge_segment() -> void:
	var t := _parsed().transition(1, 5)

	assert_eq(t.enact, "IMMEDIATE")
	assert_eq(t.mode, "MANUAL")
	assert_eq(t.segment, "TransToMarch1.sgt")


func test_reads_transitions_without_a_bridge_segment() -> void:
	var t := _parsed().transition(2, 1)

	assert_eq(t.enact, "MEASURE")
	assert_eq(t.segment, "", "no bridge segment means start the new intensity directly")


func test_ignores_commented_out_transitions() -> void:
	# The shipped files carry commented-out transitions as documentation. Reading
	# one as live would insert a transition the game never performs.
	assert_null(_parsed().transition(2, 3))


func test_undeclared_transitions_are_absent_not_an_error() -> void:
	# Only transitions differing from the default are declared.
	assert_null(_parsed().transition(5, 2))


func test_tolerates_tabs_and_spaces_mixed() -> void:
	var control := MusicControl.new()
	assert_true(control.parse("INTENSITY\t \t7  0 \t 8 \tSeg.sgt"))
	assert_eq(control.intensity(7).segments[0], "Seg.sgt")


func test_keeps_unknown_directives_rather_than_failing() -> void:
	var control := MusicControl.new()
	assert_true(control.parse("INTENSITY 1 0 1 A.sgt\nSOMETHINGNEW 42"))
	assert_eq(control.settings["SOMETHINGNEW"], "42")


func test_rejects_a_file_with_no_intensities() -> void:
	var control := MusicControl.new()

	assert_false(control.parse("; just a comment\nVOICES 64"))
	assert_string_contains(control.error(), "no intensity")


func test_rejects_a_malformed_intensity() -> void:
	var control := MusicControl.new()

	assert_false(control.parse("INTENSITY 1 0"))
	assert_string_contains(control.error(), "INTENSITY")
