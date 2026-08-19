# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name FormatProbe
extends RefCounted

## Inspects a single file and reports what can be determined about it.
##
## Probes are held as a collection and offered each file in turn, so that
## format-specific probes can be added as each format becomes understood without
## changing the orchestrator.


## A stable name identifying this probe in reports.
func probe_name() -> String:
	push_error("probe_name must be overridden")
	return ""


## Whether this probe wants to inspect the given file, judged from its canonical
## path alone so that files are not read unnecessarily.
func can_probe(_canonical_path: String) -> bool:
	push_error("can_probe must be overridden")
	return false


## Inspects the leading bytes of a file.
##
## Returns an empty Dictionary when nothing could be determined, otherwise a
## Dictionary with keys "probe", "signature" and "facts".
func probe(_canonical_path: String, _prefix: PackedByteArray) -> Dictionary:
	push_error("probe must be overridden")
	return {}


## How many leading bytes this probe needs.
func required_bytes() -> int:
	return 16
