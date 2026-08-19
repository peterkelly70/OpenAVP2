# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name JsonInventoryWriter
extends RefCounted

## Writes an inventory report as indented JSON.
##
## Stage 0 calls for a machine-readable manifest. JSON keeps the report diffable
## between runs, so that a patched installation can be compared against an
## unpatched one.


## Serialises a report to a string.
func to_json(report: Dictionary) -> String:
	return JSON.stringify(report, "  ", false)


## Writes a report to a file. Returns true on success.
func write_to_file(report: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open for writing: %s" % path)
		return false

	file.store_string(to_json(report))
	file.close()
	return true
