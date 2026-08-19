# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name PhysicalFileSystem
extends FileSystemPort

## [FileSystemPort] backed by the real filesystem.


func directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func enumerate_files(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	_walk(directory, found)
	return found


func read_prefix(path: String, max_bytes: int) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(max_bytes)
	file.close()
	return bytes


func file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


func _walk(directory: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		# An unreadable directory is skipped rather than aborting the scan.
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := directory.path_join(name)
			if dir.current_is_dir():
				_walk(full, found)
			else:
				found.append(full)
		name = dir.get_next()
	dir.list_dir_end()
