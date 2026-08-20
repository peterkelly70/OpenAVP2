# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## check_scripts -- verify every GDScript in the project loads.
##
##   godot --headless --script tools/check_scripts.gd
##
## Exits non-zero naming any script that fails to parse. This runs before the
## test suite because a script that does not parse is skipped rather than
## failed, so without it a broken helper can remove whole test files from the
## run while the run still reports success.
##
## A script that fails to parse still returns a Script object from load(), so
## merely loading it proves nothing. Such a script cannot be instantiated,
## which is the property this checks. The result comes from the engine rather
## than from any wording in a log.

const DIRECTORIES: Array[String] = ["res://src", "res://tests", "res://tools", "res://demo"]


func _init() -> void:
	var scripts: Array[String] = []
	for directory in DIRECTORIES:
		_collect(directory, scripts)

	var broken: Array[String] = []
	for path in scripts:
		var script := load(path)
		if script == null or not (script is GDScript):
			broken.append("%s (did not load)" % path)
			continue
		# A script that fails to parse still returns a Script object, but it
		# cannot be instantiated. That distinction is what identifies it.
		if not (script as GDScript).can_instantiate():
			broken.append("%s (does not compile)" % path)

	if broken.is_empty():
		print("[CHECK] %d scripts load" % scripts.size())
		quit(0)
		return

	printerr("[CHECK] %d of %d scripts failed to load:" % [broken.size(), scripts.size()])
	for path in broken:
		printerr("  %s" % path)
	quit(1)


func _collect(directory: String, into: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			into.append(directory.path_join(name))
	for sub in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(sub), into)
