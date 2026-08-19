# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name FakeFileSystem
extends FileSystemPort

## In-memory [FileSystemPort] so that installation and inventory services can be
## tested without a real AvP2 installation, and therefore without any game data
## in the repository.

var _files := {}
var _directories := {}
var _unreadable := {}


## Adds a file with the given contents, creating parent directories.
func with_file(path: String, contents: PackedByteArray = PackedByteArray()) -> FakeFileSystem:
	var normalized := _normalize(path)
	_files[normalized] = contents

	var directory := normalized.get_base_dir()
	while directory != "" and directory != "/":
		_directories[directory] = true
		directory = directory.get_base_dir()

	return self


## Adds a file whose contents are the given text.
func with_text_file(path: String, contents: String) -> FakeFileSystem:
	return with_file(path, contents.to_utf8_buffer())


## Adds a file of the given size, with arbitrary contents.
func with_sized_file(path: String, size: int) -> FakeFileSystem:
	var bytes := PackedByteArray()
	bytes.resize(size)
	return with_file(path, bytes)


## Adds an empty directory.
func with_directory(path: String) -> FakeFileSystem:
	_directories[_normalize(path)] = true
	return self


## Marks a file as failing to read, to exercise error handling.
func with_unreadable_file(path: String) -> FakeFileSystem:
	with_file(path, PackedByteArray([1, 2, 3, 4]))
	_unreadable[_normalize(path)] = true
	return self


func directory_exists(path: String) -> bool:
	return _directories.has(_normalize(path))


func file_exists(path: String) -> bool:
	return _files.has(_normalize(path))


func enumerate_files(directory: String) -> PackedStringArray:
	var prefix := _normalize(directory) + "/"
	var found := PackedStringArray()
	for path in _files:
		if path.begins_with(prefix):
			found.append(path)
	found.sort()
	return found


func read_prefix(path: String, max_bytes: int) -> PackedByteArray:
	var normalized := _normalize(path)
	if _unreadable.has(normalized) or not _files.has(normalized):
		return PackedByteArray()
	var contents: PackedByteArray = _files[normalized]
	return contents.slice(0, min(max_bytes, contents.size()))


func file_size(path: String) -> int:
	var normalized := _normalize(path)
	if not _files.has(normalized):
		return -1
	return (_files[normalized] as PackedByteArray).size()


## Normalises separators so the fake behaves identically regardless of the host
## platform's separator conventions.
static func _normalize(path: String) -> String:
	return path.replace("\\", "/")
