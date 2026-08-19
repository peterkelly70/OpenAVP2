# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name InstallationValidation
extends RefCounted

## The outcome of validating a candidate AvP2 installation directory.

## The directory that was validated.
var path: String
## Whether the directory can be used as a game installation.
var is_valid: bool
## Every check performed, satisfied or not, in display order.
## Each entry is a Dictionary with keys "requirement", "satisfied" and "detail".
var checks: Array[Dictionary]


func _init(validated_path: String, valid: bool, performed_checks: Array[Dictionary]) -> void:
	path = validated_path
	is_valid = valid
	checks = performed_checks


## Checks that failed. Empty when [member is_valid] is true and nothing advisory
## was reported.
func failures() -> Array[Dictionary]:
	var failed: Array[Dictionary] = []
	for check in checks:
		if not check["satisfied"]:
			failed.append(check)
	return failed


## Builds a single check entry.
static func make_check(requirement: String, satisfied: bool, detail: String) -> Dictionary:
	return {"requirement": requirement, "satisfied": satisfied, "detail": detail}
