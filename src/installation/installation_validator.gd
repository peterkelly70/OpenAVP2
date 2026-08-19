# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name InstallationValidator
extends RefCounted

## Decides whether a directory is a usable AvP2 installation.
##
## Matching is done on canonicalised names so that validation behaves the same on
## case-sensitive filesystems, where the shipped casing of a file cannot be
## relied on.
##
## This establishes that a directory [i]is[/i] an AvP2 installation. Identifying
## which version and patch level it is requires reading archive contents and is
## the job of the inventory scan.

## Archives expected in the root of any AvP2 installation.
const REQUIRED_ARCHIVES: Array[String] = ["avp2.rez"]

## Directories whose absence is reported but is not disqualifying, since content
## may live entirely in archives.
const EXPECTED_DIRECTORIES: Array[String] = ["sound", "custom"]

var _file_system: FileSystemPort


func _init(file_system: FileSystemPort) -> void:
	_file_system = file_system


## Validates a candidate directory, reporting every check performed so that a
## user can see what is missing rather than only that validation failed.
func validate(path: String) -> InstallationValidation:
	var checks: Array[Dictionary] = []

	if not _file_system.directory_exists(path):
		checks.append(InstallationValidation.make_check(
			"Installation directory exists", false, "Not found: %s" % path))
		return InstallationValidation.new(path, false, checks)

	checks.append(InstallationValidation.make_check(
		"Installation directory exists", true, path))

	var root_names := _root_file_names(path)
	var satisfied := 0

	for archive in REQUIRED_ARCHIVES:
		var found := root_names.has(archive)
		if found:
			satisfied += 1
		checks.append(InstallationValidation.make_check(
			"Base archive %s" % archive,
			found,
			"Found" if found else "Missing from the installation root"))

	for directory in EXPECTED_DIRECTORIES:
		var found := _file_system.directory_exists(path.path_join(directory))
		checks.append(InstallationValidation.make_check(
			"Directory %s" % directory,
			found,
			"Found" if found else "Not present; content may be archived instead"))

	# Only the required archives determine validity, so an installation that
	# keeps everything in archives still validates.
	return InstallationValidation.new(path, satisfied == REQUIRED_ARCHIVES.size(), checks)


func _root_file_names(path: String) -> Dictionary:
	var names := {}
	for file in _file_system.enumerate_files(path):
		var name := VfsPath.canonicalize(file.get_file())
		if name != "":
			names[name] = true
	return names
