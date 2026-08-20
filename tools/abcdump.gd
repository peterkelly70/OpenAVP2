# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## abcdump -- inspect LithTech models.
##
##   godot --headless --script tools/abcdump.gd -- <archive.rez> [--filter <text>] [--limit <n>]
##
## Reports each model's version, pieces, levels of detail, bones and sockets.
## Sockets matter beyond diagnostics: weapons, effects and equipment attach to
## them, so a model whose sockets are missing cannot be equipped correctly.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: abcdump <archive.rez> [--filter <text>] [--limit <n>]")
		quit(2)
		return

	var filter := ""
	var limit := 0
	var i := 1
	while i < args.size():
		match args[i]:
			"--filter":
				i += 1
				filter = args[i].to_lower()
			"--limit":
				i += 1
				limit = int(args[i])
			_:
				printerr("unrecognised option: %s" % args[i])
				quit(2)
				return
		i += 1

	var archive := RezArchive.new()
	if not archive.load(args[0]):
		printerr("[REZ] %s: %s" % [args[0], archive.error()])
		quit(1)
		return

	var seen := 0
	var failed := 0
	var versions := {}

	for entry in archive.entries():
		if entry.extension != "abc":
			continue
		if not filter.is_empty() and not entry.path.contains(filter):
			continue
		if limit > 0 and seen >= limit:
			break

		var model := AbcModel.new()
		if not model.parse(archive.read_entry(entry)):
			printerr("  %s: %s" % [entry.path, model.error()])
			failed += 1
			continue

		seen += 1
		versions[model.version] = versions.get(model.version, 0) + 1

		var triangles := 0
		var levels := 0
		for piece in model.pieces:
			levels = maxi(levels, piece.levels.size())
			if not piece.levels.is_empty():
				triangles += piece.levels[0].indices.size() / 3

		print("  %-54s v%-3d %3d pieces %2d lod %5d tris %3d bones %2d sockets %s" % [
			entry.path, model.version, model.pieces.size(), levels, triangles,
			model.nodes.size(), model.sockets.size(), model.command_string])

	print("\n%d models, %d failed" % [seen, failed])
	print("versions: %s" % versions)
	quit(0 if failed == 0 else 1)
