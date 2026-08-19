# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## installinventory -- scan an AvP2 installation and write a machine-readable
## manifest of everything it contains (roadmap stage 0).
##
##   godot --headless --script tools/installinventory.gd -- <path> [options]
##
##     --out <file>   Write the report to a file instead of standard output.
##     --no-probe     Record names and sizes only; do not read any file.
##
## This script is a composition root and nothing else: it parses arguments,
## builds the object graph through Services, and hands off to the orchestrator.

const USAGE := """Usage: godot --headless --script tools/installinventory.gd -- <path> [options]

  --out <file>   Write the report to a file instead of standard output.
  --no-probe     Record names and sizes only; do not read any file.

Scans an Aliens vs. Predator 2 installation and reports every extension, with
files grouped by their observed leading bytes so that the number of distinct
format variants can be counted before any format is documented."""


func _init() -> void:
	var args := _script_arguments()

	if args.is_empty() or args[0] in ["-h", "--help"]:
		print(USAGE)
		quit(2 if args.is_empty() else 0)
		return

	var installation_path := args[0]
	var output_path := ""
	var probe_contents := true

	var i := 1
	while i < args.size():
		match args[i]:
			"--out":
				if i + 1 >= args.size():
					printerr("--out requires a file path")
					quit(2)
					return
				i += 1
				output_path = args[i]
			"--no-probe":
				probe_contents = false
			_:
				printerr("Unrecognised option: %s" % args[i])
				quit(2)
				return
		i += 1

	var services := Services.new()
	var report := services.inventory_orchestrator().scan(
		installation_path, {"probe_contents": probe_contents})
	var writer := services.inventory_writer()

	if output_path == "":
		print(writer.to_json(report))
	elif not writer.write_to_file(report, output_path):
		quit(1)
		return

	# A directory that is not a valid installation is still reported, but the
	# exit code distinguishes it so that scripts and CI can tell the difference.
	quit(0 if report["is_valid_installation"] else 1)


## Arguments after "--", so that Godot's own options are not mistaken for ours.
func _script_arguments() -> PackedStringArray:
	return OS.get_cmdline_user_args()
