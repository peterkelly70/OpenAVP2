# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## vfsdump -- mount an installation and report how resources resolve.
##
##   godot --headless --script tools/vfsdump.gd -- <install-dir> [options]
##
##     --overrides      List every path provided by more than one archive.
##     --path <p>       Explain how one path resolves.
##     --prefix <p>     Count resources beneath a prefix.
##
## Mount precedence follows the design document: base archives, then official
## patches, then expansions.

## Archives treated as patches rather than base content.
const PATCH_ARCHIVES: Array[String] = ["avp2p.rez", "avp2p1.rez", "avp2p5.rez", "lithserver.rez"]

## Archives belonging to the expansion.
const EXPANSION_ARCHIVES: Array[String] = ["avp2x.rez"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: vfsdump <install-dir> [--overrides] [--path <p>] [--prefix <p>]")
		quit(2)
		return

	var install: String = args[0]
	var show_overrides := false
	var explain := ""
	var prefix := ""

	var i := 1
	while i < args.size():
		match args[i]:
			"--overrides": show_overrides = true
			"--path": i += 1; explain = args[i]
			"--prefix": i += 1; prefix = args[i]
			_:
				printerr("unrecognised option: %s" % args[i])
				quit(2)
				return
		i += 1

	var vfs := Vfs.new()
	var names := DirAccess.get_files_at(install)
	names.sort()

	for name in names:
		if not name.to_lower().ends_with(".rez"):
			continue
		var lower := name.to_lower()
		var priority := MountPriority.Level.BASE_GAME
		if lower in PATCH_ARCHIVES:
			priority = MountPriority.Level.OFFICIAL_PATCH
		elif lower in EXPANSION_ARCHIVES:
			priority = MountPriority.Level.EXPANSION
		if vfs.mount_archive(install.path_join(name), priority):
			print("  mounted %-18s as %s" % [name, MountPriority.level_name(priority)])

	print("\n%d mounts, %d resources after resolution" % [vfs.mount_count(), vfs.paths().size()])

	if not explain.is_empty():
		var entry := vfs.describe(explain)
		print("\n%s" % (entry if entry != null else "%s: not found" % explain))

	if not prefix.is_empty():
		print("\n%d resources under '%s'" % [vfs.paths(prefix).size(), prefix])

	if show_overrides:
		var overridden := vfs.overridden_paths()
		print("\n%d paths provided by more than one archive:" % overridden.size())
		for path in overridden.slice(0, 25):
			print("   %s" % vfs.describe(path))

	quit(0)
