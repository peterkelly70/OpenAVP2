# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## datdump -- inspect the object records in DAT worlds.
##
##   godot --headless --script tools/datdump.gd -- <archive.rez> [options]
##
##     --world <text>   Only worlds whose path contains this.
##     --class <name>   List every object of this class, with its properties.
##     --histogram      Object class counts, summed across the worlds selected.
##
## Without options it prints one line per world. This is the tool the design
## document calls for before implementing entities: implementation order should
## follow what real levels actually contain.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: datdump <archive.rez> [--world <text>] [--class <name>] [--histogram]")
		quit(2)
		return

	var world_filter := ""
	var class_filter := ""
	var histogram := false

	var i := 1
	while i < args.size():
		match args[i]:
			"--world":
				i += 1
				world_filter = args[i].to_lower()
			"--class":
				i += 1
				class_filter = args[i]
			"--histogram":
				histogram = true
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

	var totals := {}
	var worlds := 0
	var failed := 0
	var objects := 0

	for entry in archive.entries():
		if entry.extension != "dat":
			continue
		if not world_filter.is_empty() and not entry.path.contains(world_filter):
			continue

		var world := DatWorld.new()
		if not world.parse(archive.read_entry(entry)):
			printerr("  %s: %s" % [entry.path, world.error()])
			failed += 1
			continue

		worlds += 1
		objects += world.objects.size()

		if not class_filter.is_empty():
			for object in world.objects_of_class(class_filter):
				print("  %s" % object)
				for name in object.properties:
					print("      %-24s %s" % [name, object.properties[name]])
			continue

		if histogram:
			for cls in world.class_histogram():
				totals[cls] = totals.get(cls, 0) + world.class_histogram()[cls]
			continue

		print("  %-46s v%d  %5d objects  %s" % [
			entry.path, world.version, world.objects.size(), world.info_string])

	if histogram:
		var names := totals.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])
		for cls in names:
			print("  %7d  %s" % [totals[cls], cls])

	print("\n%d worlds, %d objects, %d failed" % [worlds, objects, failed])
	quit(0 if failed == 0 else 1)
