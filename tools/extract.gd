# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## extract -- copy files out of a REZ archive.
##
##   godot --headless --script tools/extract.gd -- <archive.rez> <out-dir> [prefix]
##
## With a prefix, only paths beginning with it are extracted, for example
## "music/m1theme". Extracted content is copyrighted game data: it belongs in an
## OpenAvP2-owned directory and must never enter the repository.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: extract <archive.rez> <out-dir> [prefix]")
		quit(2)
		return

	var archive_path := args[0]
	var out_dir := args[1]
	var prefix := VfsPath.canonicalize(args[2]) if args.size() > 2 else ""

	var archive := RezArchive.new()
	if not archive.load(archive_path):
		printerr("[REZ] %s: %s" % [archive_path, archive.error()])
		quit(1)
		return

	var written := 0
	var bytes := 0
	for entry in archive.entries():
		if not prefix.is_empty() and not entry.path.begins_with(prefix):
			continue

		var dest := out_dir.path_join(entry.path)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())

		var file := FileAccess.open(dest, FileAccess.WRITE)
		if file == null:
			printerr("[EXTRACT] cannot write %s" % dest)
			continue
		file.store_buffer(archive.read_entry(entry))
		file.close()

		written += 1
		bytes += entry.size

	print("[EXTRACT] %d files, %.1f MB -> %s" % [written, bytes / 1048576.0, out_dir])
	quit(0 if written > 0 else 1)
