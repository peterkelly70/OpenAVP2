# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node

## Demonstrates AvP2's adaptive score without DirectMusic.
##
## Loads a theme's control file, plays its rendered segments through
## [MusicPlayer], and drives the intensity the way the game would: calm, then
## combat, then calm again. The bridge segments between them are chosen by the
## control file, not by this script.
##
##   godot demo/adaptive_music.tscn -- <theme-dir> <segment-dir>
##
## where theme-dir holds the extracted control file and segment-dir holds the
## rendered WAVs, both produced by scripts/render-music.sh.

## Seconds spent at each step before changing intensity.
const STEP := 18.0

var _music: MusicPlayer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: adaptive_music.tscn -- <theme-dir> <segment-dir>")
		get_tree().quit(2)
		return

	var theme_dir: String = args[0]
	var segment_dir: String = args[1]

	var control_file := _find_control(theme_dir)
	if control_file.is_empty():
		printerr("[MUSIC] no control file in %s" % theme_dir)
		get_tree().quit(1)
		return

	var control := MusicControl.new()
	if not control.parse(FileAccess.get_file_as_string(control_file)):
		printerr("[MUSIC] %s: %s" % [control_file, control.error()])
		get_tree().quit(1)
		return

	print("[MUSIC] %s: %d intensities, %d transitions" % [
		control_file.get_file(), control.intensities.size(), control.transitions.size()])

	_music = MusicPlayer.new(control, segment_dir)
	_music.segment_started.connect(func(n: String) -> void: print("   segment  %s" % n))
	_music.intensity_changed.connect(func(l: int) -> void: print("  intensity %d" % l))
	add_child(_music)

	await _run(control)
	get_tree().quit(0)


## Drives the intensity through a calm/combat/calm arc, which is what the game
## would do in response to enemies appearing and being dealt with.
func _run(control: MusicControl) -> void:
	print("\n-- ambient --")
	_music.start()
	_music.set_intensity(_pick(control, [2]))
	await get_tree().create_timer(STEP).timeout

	print("\n-- contact: raising intensity --")
	_music.set_intensity(_pick(control, [5]))
	await get_tree().create_timer(STEP * 1.5).timeout

	print("\n-- clear: returning to ambient --")
	_music.set_intensity(_pick(control, [2]))
	await get_tree().create_timer(STEP).timeout

	print("\n-- done --")


## Uses the first candidate the theme actually defines, since themes number
## their intensities differently.
func _pick(control: MusicControl, candidates: Array) -> int:
	for level in candidates:
		if control.intensity(level) != null:
			return level
	return control.initial_intensity


func _find_control(dir: String) -> String:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with("control.txt"):
			return dir.path_join(f)
	return ""
