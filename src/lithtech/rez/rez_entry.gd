# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name RezEntry
extends RefCounted

## One file inside a REZ archive.
##
## The archive stores the name and the extension separately, so [member path]
## is assembled by the reader from the directory chain, the entry name and the
## byte-reversed type code. See docs/formats/rez.md.

## Canonical path within the archive, extension included.
var path: String
## Offset of the file's data within the archive.
var position: int
## Length of the file in bytes.
var size: int
## Archive timestamp, as a Unix time.
var time: int
## Extension, lowercased, without the leading dot.
var extension: String


func _init(entry_path: String, entry_position: int, entry_size: int,
		entry_time: int, entry_extension: String) -> void:
	path = entry_path
	position = entry_position
	size = entry_size
	time = entry_time
	extension = entry_extension


func _to_string() -> String:
	return "%s (%d bytes @ %d)" % [path, size, position]
