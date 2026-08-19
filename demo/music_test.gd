# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node

## Plays AvP2 music straight out of a REZ archive.
##
## The first end-to-end proof that original game content reaches Godot's audio
## output: open the archive, resolve a logical path, read the bytes, wrap them
## as an AudioStream and play. Nothing is written to disk and no game data is
## distributed with OpenAvP2.
##
## Run it with scripts/play-music.sh, or open this scene in the editor after
## setting [member archive_path].

## A REZ archive from your own AvP2 installation.
@export_file("*.rez") var archive_path: String = ""

## Logical path inside the archive. Empty plays the longest track found under
## Music/WaveTracks, which is where the streamed score lives.
@export var resource_path: String = ""

## Seconds to play before quitting. Zero plays the whole track.
@export var play_seconds: float = 0.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		archive_path = args[0]
	if args.size() > 1:
		resource_path = args[1]

	if archive_path.is_empty():
		push_warning("No archive given. Pass one, or set archive_path in the scene.")
		return

	var archive := RezArchive.new()
	if not archive.load(archive_path):
		printerr("[REZ] %s: %s" % [archive_path, archive.error()])
		get_tree().quit(1)
		return

	print("[REZ] %s: %d entries" % [archive_path.get_file(), archive.entries().size()])

	var entry := _choose(archive)
	if entry == null:
		printerr("[REZ] no playable track found in %s" % archive_path.get_file())
		get_tree().quit(1)
		return

	var data := archive.read_entry(entry)
	var stream := _to_stream(data)
	if stream == null:
		# 45% of the game's audio is MP3 inside a RIFF container and 25% is IMA
		# ADPCM; neither loads as plain PCM. See docs/formats/audio.md.
		printerr("[AUDIO] %s is not plain PCM and needs conversion first" % entry.path)
		get_tree().quit(1)
		return

	print("[AUDIO] %s" % entry.path)
	print("[AUDIO] %.1f MB, %.1f seconds, %d Hz, %s" % [
		entry.size / 1048576.0, stream.get_length(), stream.mix_rate,
		"stereo" if stream.stereo else "mono"])
	print("[AUDIO] playing...")

	_player.stream = stream
	_player.play()

	if play_seconds > 0.0:
		await get_tree().create_timer(play_seconds).timeout
	else:
		await _player.finished

	print("[AUDIO] done")
	get_tree().quit(0)


## Picks the requested track, or the longest streamed music track available.
func _choose(archive: RezArchive) -> RezEntry:
	if not resource_path.is_empty():
		return archive.find(resource_path)

	var best: RezEntry = null
	for entry in archive.entries():
		if entry.extension != "wav" or not entry.path.begins_with("music/wavetracks/"):
			continue
		if best == null or entry.size > best.size:
			best = entry
	return best


## Wraps raw WAV bytes as a stream. Godot parses a RIFF/WAVE container directly,
## so uncompressed tracks need no decoding.
func _to_stream(data: PackedByteArray) -> AudioStreamWAV:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	return AudioStreamWAV.load_from_buffer(data)
