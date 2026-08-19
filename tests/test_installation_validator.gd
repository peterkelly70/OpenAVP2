# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

const ROOT := "/games/avp2"


func _validator(fs: FakeFileSystem) -> InstallationValidator:
	return InstallationValidator.new(fs)


func _has_failure(result: InstallationValidation, fragment: String) -> bool:
	for failure in result.failures():
		if fragment in failure["requirement"]:
			return true
	return false


func test_accepts_an_installation_containing_the_base_archive() -> void:
	var fs := FakeFileSystem.new() \
		.with_text_file("%s/AVP2.REZ" % ROOT, "archive") \
		.with_directory("%s/Sound" % ROOT)

	var result := _validator(fs).validate(ROOT)

	assert_true(result.is_valid)
	assert_false(_has_failure(result, "avp2.rez"))


func test_is_case_insensitive_about_archive_names() -> void:
	# The shipped casing cannot be relied on, and on Linux the filesystem will
	# not paper over a mismatch.
	var fs := FakeFileSystem.new().with_text_file("%s/avp2.rez" % ROOT, "archive")

	assert_true(_validator(fs).validate(ROOT).is_valid)


func test_rejects_a_directory_without_the_base_archive() -> void:
	var fs := FakeFileSystem.new().with_text_file("%s/readme.txt" % ROOT, "not a game")

	var result := _validator(fs).validate(ROOT)

	assert_false(result.is_valid)
	assert_true(_has_failure(result, "avp2.rez"))


func test_rejects_a_missing_directory_without_failing() -> void:
	var result := _validator(FakeFileSystem.new()).validate("/nonexistent")

	assert_false(result.is_valid)
	assert_true(_has_failure(result, "directory exists"))


func test_reports_every_check_so_the_user_can_see_what_is_missing() -> void:
	var fs := FakeFileSystem.new().with_text_file("%s/AVP2.REZ" % ROOT, "archive")

	var result := _validator(fs).validate(ROOT)

	# Directory exists, the required archive, and each expected directory.
	assert_eq(result.checks.size(), 4)
	for check in result.checks:
		assert_false(check["detail"].strip_edges().is_empty())


func test_treats_missing_optional_directories_as_advisory_only() -> void:
	# Content may live entirely in archives, so absent directories must not
	# disqualify an otherwise valid installation.
	var fs := FakeFileSystem.new().with_text_file("%s/avp2.rez" % ROOT, "archive")

	var result := _validator(fs).validate(ROOT)

	assert_true(result.is_valid)
	assert_true(_has_failure(result, "Directory"))
