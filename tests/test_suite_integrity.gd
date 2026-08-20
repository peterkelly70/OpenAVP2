# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Guards the test suite against silently shrinking.
##
## A test script that fails to parse is skipped with a warning rather than an
## error, so the suite still reports success while covering less. That happened
## once already: removing a constant broke a helper class, which made two test
## scripts unparseable, and the run went green with 25 fewer tests.
##
## A dropped test is worse than a failing one, because nothing draws attention
## to it. The primary defence is tools/check_scripts.gd, run before the suite.

const TESTS := "res://tests"


func _test_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_files_at(TESTS):
		if name.begins_with("test_") and name.ends_with(".gd"):
			out.append(TESTS.path_join(name))
	return out


func test_every_test_script_loads() -> void:
	var broken: Array[String] = []

	for path in _test_scripts():
		var script := load(path)
		if script == null:
			broken.append(path)

	assert_eq(broken, [] as Array[String],
		"These scripts fail to parse and are therefore not running at all.")


func test_every_helper_class_loads() -> void:
	# Helpers are not named test_ and so are never collected by the runner. A
	# broken one takes its dependent test scripts down with it, which is exactly
	# how the suite shrank before.
	var broken: Array[String] = []

	for name in DirAccess.get_files_at(TESTS):
		if name.ends_with(".gd") and not name.begins_with("test_"):
			if load(TESTS.path_join(name)) == null:
				broken.append(name)

	assert_eq(broken, [] as Array[String])


func test_the_runner_checks_every_script_before_running_tests() -> void:
	# The real guarantee is that scripts/run-tests.sh runs check_scripts.gd
	# first, which loads every script and exits non-zero on failure. That check
	# is deterministic; an earlier version scraped the runner's log for warning
	# text, which would have stopped working silently if the wording changed.
	var runner := FileAccess.get_file_as_string("res://scripts/run-tests.sh")

	assert_string_contains(runner, "check_scripts.gd")
	assert_not_null(load("res://tools/check_scripts.gd"))
