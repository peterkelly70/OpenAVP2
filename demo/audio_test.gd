# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node

## Plays audio straight out of an AvP2 REZ archive.
##
## The first end-to-end proof that original game content reaches Godot's audio
## output: open the archive, resolve a logical path, read the bytes, wrap them
## as an AudioStream and play. Nothing is written to disk.
##
## Set [member archive_path] to an archive in your own installation. No game
## data is distributed with OpenAvP2.

## Path to a REZ archive in your AvP2 installation.
@export_file("*.rez") var archive_path: String = ""

## Logical path inside the archive. Leave empty to play the first WAV found.
@export var resource_path: String = ""

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

	if archive_path.is_empty():
		push_warning("Set archive_path to a .rez file in your AvP2 installation.")
		return

	var archive := RezArchive.new()
	if not archive.load(archive_path):
		push_error("[REZ] %s: %s" % [archive_path, archive.error()])
		return

	print("[REZ] %s: %d entries" % [archive_path.get_file(), archive.entries().size()])

	var entry := _choose(archive)
	if entry == null:
		push_error("[REZ] no playable WAV found in %s" % archive_path.get_file())
		return

	var stream := _to_stream(archive.read_entry(entry))
	if stream == null:
		push_error("[REZ] %s could not be decoded as WAV" % entry.path)
		return

	print("[AUDIO] playing %s (%d bytes, %.1fs)" % [entry.path, entry.size, stream.get_length()])
	_player.stream = stream
	_player.play()


func _choose(archive: RezArchive) -> RezEntry:
	if not resource_path.is_empty():
		return archive.find(resource_path)

	for entry in archive.entries():
		# Skip tiny files, which are usually silence or markers.
		if entry.extension == "wav" and entry.size > 8192:
			return entry
	return null


## Wraps raw WAV bytes as a stream. Godot can parse a RIFF/WAVE container
## directly, so no decoding is needed for the PCM audio in these archives.
func _to_stream(data: PackedByteArray) -> AudioStream:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	return AudioStreamWAV.load_from_buffer(data)
