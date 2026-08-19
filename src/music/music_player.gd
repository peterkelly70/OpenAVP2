# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MusicPlayer
extends Node

## Plays a theme's rendered segments, following its control file.
##
## OpenAvP2 does not run DirectMusic. Segments are rendered to audio once during
## extraction, and this node reproduces the adaptive behaviour by sequencing
## them: it holds an intensity level, plays that level's segments, and when the
## level changes it plays the bridge segment the control file names before
## entering the new level.
##
## The audio is therefore ordinary streams, while the adaptivity lives here.

## Emitted when the played intensity changes, after any bridge segment.
signal intensity_changed(level: int)

## Emitted when a segment starts. Chiefly useful for tests and diagnostics.
signal segment_started(name: String)

## Directory holding rendered segments, named as in the control file but
## lowercased and with a .wav extension.
var segment_directory := ""

var _control: MusicControl
var _player: AudioStreamPlayer
var _intensity := 0
var _pending := -1
var _in_transition := false


func _init(control: MusicControl = null, directory: String = "") -> void:
	_control = control
	segment_directory = directory


func _ready() -> void:
	if _player == null:
		_player = AudioStreamPlayer.new()
		add_child(_player)
		_player.finished.connect(_on_segment_finished)


## The level currently playing.
func intensity() -> int:
	return _intensity


## Whether a bridge segment is currently playing.
func in_transition() -> bool:
	return _in_transition


## Starts playback at the control file's initial intensity.
func start() -> void:
	if _control == null:
		push_error("[MUSIC] no control file loaded")
		return
	set_intensity(_control.initial_intensity)


## Requests a new intensity level.
##
## If the control file declares a MANUAL transition with a bridge segment, that
## segment plays first and the new level begins when it finishes. Otherwise the
## new level starts immediately.
func set_intensity(level: int) -> void:
	if _control == null or level == _intensity:
		return

	if _control.intensity(level) == null:
		push_warning("[MUSIC] intensity %d is not defined" % level)
		return

	var bridge := _control.transition(_intensity, level)
	if bridge != null and bridge.segment != "" and _intensity != 0:
		_pending = level
		_in_transition = true
		_play(bridge.segment)
		return

	_enter(level)


func _enter(level: int) -> void:
	_intensity = level
	_in_transition = false
	_pending = -1
	intensity_changed.emit(level)

	var entry := _control.intensity(level)
	if entry == null or entry.segments.is_empty():
		return
	_play(entry.segments[0])


func _play(segment: String) -> void:
	# Emitted on the decision to play, not on successful loading, so that the
	# sequencing can be observed and tested independently of which segments have
	# actually been rendered.
	segment_started.emit(segment)

	var stream := _load(segment)
	if stream == null:
		push_warning("[MUSIC] segment not available: %s" % segment)
		# A missing segment must not strand the state machine mid-transition.
		if _in_transition and _pending >= 0:
			_enter(_pending)
		return

	if _player != null:
		_player.stream = stream
		_player.play()


func _on_segment_finished() -> void:
	if _in_transition and _pending >= 0:
		_enter(_pending)
		return

	# A level names the level to advance to when its segment finishes, which is
	# how the ambient and combat loops cycle. Zero stops.
	var entry := _control.intensity(_intensity)
	if entry == null:
		return
	if entry.next == 0:
		return
	if entry.next == _intensity:
		_play(entry.segments[0]) if not entry.segments.is_empty() else null
		return

	_enter(entry.next)


func _load(segment: String) -> AudioStream:
	if segment_directory.is_empty():
		return null
	var path := segment_directory.path_join(segment.get_basename().to_lower() + ".wav")
	if not FileAccess.file_exists(path):
		return null
	return AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
