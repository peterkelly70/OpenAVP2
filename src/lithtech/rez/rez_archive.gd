# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name RezArchive
extends RefCounted

## Reader for LithTech REZ archives.
##
## The format is documented in docs/formats/rez.md, derived independently from a
## retail installation. In summary: a 127-byte ASCII banner, a small binary
## header, and a directory tree stored at the end of the file.

## The banner every valid archive begins with.
const MAGIC := "\r\nRezMgr"

## Offset of the binary header, immediately after the banner.
const HEADER_OFFSET := 0x7F

## Size of a directory entry's fixed part, before its name.
const DIRECTORY_ENTRY_SIZE := 16

## Size of a file entry's fixed part, before its name.
const FILE_ENTRY_SIZE := 28

## Format version this reader understands.
const SUPPORTED_VERSION := 1

## Guards against a malformed archive causing unbounded recursion.
const MAX_DEPTH := 32

var _file: FileAccess
var _entries: Array[RezEntry] = []
var _by_path := {}
var _error := ""


## Opens an archive, or returns null when the file is not a valid archive.
##
## Deliberately silent: a rejected archive is an expected outcome when probing
## an installation, so reporting it is the caller's decision. Use [method load]
## when the reason matters.
static func open(path: String) -> RezArchive:
	var archive := RezArchive.new()
	return archive if archive.load(path) else null


## Opens an archive, returning whether it succeeded. On failure the reason is
## available from [method error].
func load(path: String) -> bool:
	return _open(path)


## Every file in the archive, in directory order.
func entries() -> Array[RezEntry]:
	return _entries


## Looks up an entry by canonical path, or null when absent.
func find(path: String) -> RezEntry:
	var canonical := VfsPath.canonicalize(path)
	return _by_path.get(canonical, null)


## Whether the archive contains a path.
func has(path: String) -> bool:
	return _by_path.has(VfsPath.canonicalize(path))


## Reads a file's contents. Returns an empty array when the path is absent.
func read(path: String) -> PackedByteArray:
	var entry := find(path)
	if entry == null:
		return PackedByteArray()
	return read_entry(entry)


## Reads an entry's contents.
func read_entry(entry: RezEntry) -> PackedByteArray:
	_file.seek(entry.position)
	return _file.get_buffer(entry.size)


## The reason the archive failed to open, or an empty string.
func error() -> String:
	return _error


func _open(path: String) -> bool:
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null:
		_error = "cannot be opened"
		return false

	var length := _file.get_length()
	if length < HEADER_OFFSET + 24:
		_error = "too short to be a REZ archive"
		return false

	if _file.get_buffer(MAGIC.length()).get_string_from_ascii() != MAGIC:
		_error = "missing the RezMgr banner"
		return false

	_file.seek(HEADER_OFFSET)
	var version := _file.get_32()
	if version != SUPPORTED_VERSION:
		_error = "unsupported version %d" % version
		return false

	var directory_position := _file.get_32()
	var directory_size := _file.get_32()

	# The directory is stored at the very end of the archive. This invariant
	# holds for every retail archive, so a mismatch means truncation, and
	# failing here is far better than surfacing corrupt resources later.
	if directory_position + directory_size != length:
		_error = "directory extent %d+%d does not reach the end of the %d byte file" \
			% [directory_position, directory_size, length]
		return false

	return _read_directory(directory_position, directory_size, "", 0)


func _read_directory(position: int, size: int, prefix: String, depth: int) -> bool:
	if depth > MAX_DEPTH:
		_error = "directory nesting exceeds %d levels" % MAX_DEPTH
		return false

	_file.seek(position)
	var block := _file.get_buffer(size)
	if block.size() != size:
		_error = "directory at %d is truncated" % position
		return false

	var offset := 0
	while offset < block.size():
		if offset + DIRECTORY_ENTRY_SIZE > block.size():
			_error = "trailing bytes in directory at %d" % position
			return false

		var flag := block.decode_u32(offset)
		var entry_position := block.decode_u32(offset + 4)
		var entry_size := block.decode_u32(offset + 8)
		var entry_time := block.decode_u32(offset + 12)

		if flag == 1:
			offset += DIRECTORY_ENTRY_SIZE
			var name := _read_name(block, offset)
			if name.is_empty():
				return false
			offset += name.length() + 1
			if not _read_directory(entry_position, entry_size,
					prefix + name + "/", depth + 1):
				return false
		elif flag == 0:
			var type_code := block.slice(offset + 20, offset + 24)
			offset += FILE_ENTRY_SIZE
			var name := _read_name(block, offset)
			if name.is_empty():
				return false
			# The name is followed by its NUL and one further byte, zero in every
			# entry observed across a retail installation.
			offset += name.length() + 2
			_add_entry(prefix, name, entry_position, entry_size, entry_time, type_code)
		else:
			_error = "unknown entry discriminator %d at %d" % [flag, position + offset]
			return false

	return true


func _add_entry(prefix: String, name: String, position: int, size: int,
		time: int, type_code: PackedByteArray) -> void:
	# The extension is stored as four bytes in reverse order, NUL padded. The
	# padding must be removed before reversing: reversing first would put a NUL
	# in front and truncate the string to nothing.
	var code := PackedByteArray()
	for byte in type_code:
		if byte != 0:
			code.append(byte)
	code.reverse()
	var extension := code.get_string_from_ascii().strip_edges().to_lower()

	var path := prefix + name
	if not extension.is_empty():
		path += "." + extension

	# Entries with no type carry a zero extent and are metadata, not files.
	if extension.is_empty() and size == 0:
		return

	var entry := RezEntry.new(VfsPath.canonicalize(path), position, size, time, extension)
	_entries.append(entry)
	_by_path[entry.path] = entry


func _read_name(block: PackedByteArray, offset: int) -> String:
	var end := offset
	while end < block.size() and block[end] != 0:
		end += 1
	if end >= block.size():
		_error = "unterminated entry name at %d" % offset
		return ""
	return block.slice(offset, end).get_string_from_ascii()
