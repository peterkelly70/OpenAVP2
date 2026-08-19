# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Tests the sequencing logic without audio. Segments are never loaded, so the
## state machine is exercised on its own, and segment_started records what the
## player would have played.

const CONTROL := """
INITIALINTENSITY 1
INTENSITY	1	0	1	Silence.sgt
INTENSITY	2	0	3	Ambient1.sgt
INTENSITY	3	0	2	Ambient2.sgt
INTENSITY	5	0	6	March1.sgt
INTENSITY	6	0	5	March2.sgt
TRANSITION	2	5	MEASURE	MANUAL	TransToMarch1.sgt
TRANSITION	5	2	MEASURE	MANUAL	TransFromMarch1.sgt
TRANSITION	2	1	MEASURE	MANUAL
"""

const SEGMENT_DIR := "user://test_segments"

var _player: MusicPlayer
var _played: Array[String]
var _levels: Array[int]


## Writes a minimal valid WAV so that segment loading succeeds and the state
## machine follows its real path rather than the missing-segment fallback.
func _write_segment(name: String) -> void:
	var pcm := PackedByteArray()
	pcm.resize(64)
	var header := PackedByteArray()
	header.append_array("RIFF".to_ascii_buffer())
	header.append_array(_u32(36 + pcm.size()))
	header.append_array("WAVEfmt ".to_ascii_buffer())
	header.append_array(_u32(16))
	header.append_array(_u16(1))     # PCM
	header.append_array(_u16(1))     # mono
	header.append_array(_u32(22050))
	header.append_array(_u32(44100))
	header.append_array(_u16(2))
	header.append_array(_u16(16))
	header.append_array("data".to_ascii_buffer())
	header.append_array(_u32(pcm.size()))
	header.append_array(pcm)

	var file := FileAccess.open(SEGMENT_DIR.path_join(name), FileAccess.WRITE)
	file.store_buffer(header)
	file.close()


func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_u32(0, v); return b


func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(2); b.encode_u16(0, v); return b


func before_each() -> void:
	var control := MusicControl.new()
	assert_true(control.parse(CONTROL), control.error())

	DirAccess.make_dir_recursive_absolute(SEGMENT_DIR)
	for name in ["silence.wav", "ambient1.wav", "ambient2.wav", "march1.wav",
			"march2.wav", "transtomarch1.wav", "transfrommarch1.wav"]:
		_write_segment(name)

	_played = []
	_levels = []
	_player = MusicPlayer.new(control, SEGMENT_DIR)
	_player.segment_started.connect(func(n: String) -> void: _played.append(n))
	_player.intensity_changed.connect(func(l: int) -> void: _levels.append(l))
	add_child_autofree(_player)


func test_starts_at_the_initial_intensity() -> void:
	_player.start()

	assert_eq(_player.intensity(), 1)
	assert_eq(_levels, [1] as Array[int])


func test_entering_a_level_without_a_declared_transition_is_immediate() -> void:
	_player.start()
	_player.set_intensity(2)

	assert_eq(_player.intensity(), 2)
	assert_false(_player.in_transition())


func test_a_declared_bridge_segment_plays_before_the_new_level() -> void:
	# This is the behaviour that keeps the score musically continuous: entering
	# combat routes through TransToMarch1 rather than cutting.
	_player.start()
	_player.set_intensity(2)
	_played.clear()

	_player.set_intensity(5)

	assert_true(_player.in_transition())
	assert_eq(_player.intensity(), 2, "still on the old level until the bridge finishes")
	assert_eq(_played, ["TransToMarch1.sgt"] as Array[String])


func test_leaving_combat_uses_the_matching_bridge() -> void:
	_player.start()
	_player.set_intensity(2)
	_player.set_intensity(5)
	_player._on_segment_finished()      # bridge completes
	_played.clear()

	_player.set_intensity(2)

	assert_eq(_played, ["TransFromMarch1.sgt"] as Array[String])


func test_a_transition_without_a_segment_switches_directly() -> void:
	_player.start()
	_player.set_intensity(2)
	_played.clear()

	_player.set_intensity(1)

	assert_false(_player.in_transition())
	assert_eq(_player.intensity(), 1)


func test_a_finished_level_advances_to_its_declared_next_level() -> void:
	# Ambient levels cycle 2 -> 3 -> 2, which is how the loop is expressed.
	_player.start()
	_player.set_intensity(2)

	_player._on_segment_finished()

	assert_eq(_player.intensity(), 3)


func test_a_level_pointing_at_itself_repeats_rather_than_advancing() -> void:
	_player.start()
	_played.clear()

	_player._on_segment_finished()

	assert_eq(_player.intensity(), 1)
	assert_eq(_played, ["Silence.sgt"] as Array[String])


func test_setting_the_current_intensity_does_nothing() -> void:
	_player.start()
	_player.set_intensity(2)
	_levels.clear()

	_player.set_intensity(2)

	assert_eq(_levels.size(), 0)


func test_an_undefined_intensity_is_refused() -> void:
	_player.start()

	_player.set_intensity(99)

	assert_eq(_player.intensity(), 1)
