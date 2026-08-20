# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name Vfs
extends RefCounted

## Virtual filesystem over archives and directories.
##
## Hides whether a resource came from a base archive, a patch, an expansion, a
## mod or a loose override file. A resource is resolved from the highest
## priority mount that provides it, and where several mounts provide the same
## path the losers are recorded so that an unexpected override can be explained.
##
## Mount order matters within a priority level: a later mount at the same level
## wins, which is how a declared mod load order is expressed.

## One mounted source.
class Mount extends RefCounted:
	var name: String
	var priority: MountPriority.Level
	var archive: RezArchive
	var directory: String
	var sequence: int

	func _init(mount_name: String, level: MountPriority.Level, seq: int) -> void:
		name = mount_name
		priority = level
		sequence = seq

	## Whether this mount provides a canonical path.
	func has_path(canonical: String) -> bool:
		if archive != null:
			return archive.has(canonical)
		return FileAccess.file_exists(directory.path_join(canonical))

	## Reads a resource, or an empty array when absent.
	func read(canonical: String) -> PackedByteArray:
		if archive != null:
			return archive.read(canonical)
		var path := directory.path_join(canonical)
		if not FileAccess.file_exists(path):
			return PackedByteArray()
		return FileAccess.get_file_as_bytes(path)

	## Size of a resource, or -1 when absent.
	func size_of(canonical: String) -> int:
		if archive != null:
			var entry := archive.find(canonical)
			return entry.size if entry != null else -1
		var path := directory.path_join(canonical)
		if not FileAccess.file_exists(path):
			return -1
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return -1
		var length := file.get_length()
		file.close()
		return length

	## Every canonical path this mount provides.
	func paths() -> PackedStringArray:
		if archive != null:
			var out := PackedStringArray()
			for entry in archive.entries():
				out.append(entry.path)
			return out
		return _walk(directory, "")

	func _walk(root: String, prefix: String) -> PackedStringArray:
		var out := PackedStringArray()
		var base := root.path_join(prefix)
		for name in DirAccess.get_files_at(base):
			out.append(VfsPath.canonicalize(prefix.path_join(name)))
		for sub in DirAccess.get_directories_at(base):
			out.append_array(_walk(root, prefix.path_join(sub)))
		return out


var _mounts: Array[Mount] = []
var _sequence := 0
var _index := {}
var _dirty := true


## Mounts a REZ archive. Returns whether it opened.
func mount_archive(path: String, priority: MountPriority.Level) -> bool:
	var archive := RezArchive.new()
	if not archive.load(path):
		push_warning("[VFS] cannot mount %s: %s" % [path, archive.error()])
		return false

	var mount := Mount.new(path.get_file(), priority, _sequence)
	mount.archive = archive
	_mounts.append(mount)
	_sequence += 1
	_dirty = true
	return true


## Mounts a directory of loose files.
func mount_directory(path: String, priority: MountPriority.Level) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		push_warning("[VFS] cannot mount %s: not a directory" % path)
		return false

	var mount := Mount.new(path.get_file(), priority, _sequence)
	mount.directory = path
	_mounts.append(mount)
	_sequence += 1
	_dirty = true
	return true


## Number of mounts.
func mount_count() -> int:
	return _mounts.size()


## Whether any mount provides a resource.
func has(path: String) -> bool:
	return _resolve(VfsPath.canonicalize(path)) != null


## Reads a resource from the highest priority mount that provides it.
##
## Returns an empty array when no mount does.
func read(path: String) -> PackedByteArray:
	var canonical := VfsPath.canonicalize(path)
	var mount := _resolve(canonical)
	return mount.read(canonical) if mount != null else PackedByteArray()


## Describes how a resource resolves, including which mounts it shadows.
##
## Returns null when no mount provides it.
func describe(path: String) -> VfsEntry:
	var canonical := VfsPath.canonicalize(path)
	var winner := _resolve(canonical)
	if winner == null:
		return null

	var shadowed := PackedStringArray()
	for mount in _ordered():
		if mount != winner and mount.has_path(canonical):
			shadowed.append(mount.name)

	return VfsEntry.new(canonical, winner.name, winner.priority,
		winner.size_of(canonical), shadowed)


## Every resource path, after override resolution.
func paths(prefix: String = "") -> PackedStringArray:
	_rebuild()
	var canonical_prefix := VfsPath.canonicalize(prefix)
	var out := PackedStringArray()
	for path in _index:
		if canonical_prefix.is_empty() or path.begins_with(canonical_prefix):
			out.append(path)
	out.sort()
	return out


## Paths provided by more than one mount, which is where load order problems
## show up first.
func overridden_paths() -> PackedStringArray:
	_rebuild()
	var seen := {}
	var out := PackedStringArray()
	for mount in _mounts:
		for path in mount.paths():
			if seen.has(path):
				if not out.has(path):
					out.append(path)
			else:
				seen[path] = true
	out.sort()
	return out


## Mounts in resolution order, lowest priority first.
func _ordered() -> Array[Mount]:
	var sorted := _mounts.duplicate()
	sorted.sort_custom(func(a: Mount, b: Mount) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.sequence < b.sequence)
	return sorted


func _rebuild() -> void:
	if not _dirty:
		return
	_index = {}
	# Later mounts overwrite earlier ones, so iterating lowest priority first
	# leaves the winner in place.
	for mount in _ordered():
		for path in mount.paths():
			_index[path] = mount
	_dirty = false


func _resolve(canonical: String) -> Mount:
	if canonical.is_empty():
		return null
	_rebuild()
	return _index.get(canonical, null)
