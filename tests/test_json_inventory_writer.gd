# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

var _writer: JsonInventoryWriter


func before_each() -> void:
	_writer = JsonInventoryWriter.new()


func _sample_report() -> Dictionary:
	return {
		"installation_path": "/games/avp2",
		"is_valid_installation": true,
		"file_count": 2,
		"total_bytes": 1024,
		"extensions": [{
			"extension": "rez",
			"count": 1,
			"total_bytes": 512,
			"signatures": [{
				"signature": "52657A4D",
				"count": 1,
				"examples": PackedStringArray(["avp2.rez"]),
			}],
		}],
		"unreadable_files": {"locked.dtx": "denied"},
	}


func test_produces_parseable_json() -> void:
	var parsed: Dictionary = JSON.parse_string(_writer.to_json(_sample_report()))

	assert_eq(parsed["installation_path"], "/games/avp2")
	assert_eq(int(parsed["file_count"]), 2)
	assert_true(parsed["is_valid_installation"])


func test_preserves_signature_detail() -> void:
	var parsed: Dictionary = JSON.parse_string(_writer.to_json(_sample_report()))
	var signature: Dictionary = parsed["extensions"][0]["signatures"][0]

	assert_eq(signature["signature"], "52657A4D")
	assert_eq(signature["examples"][0], "avp2.rez")


func test_includes_unreadable_files_so_scans_are_diagnosable() -> void:
	var parsed: Dictionary = JSON.parse_string(_writer.to_json(_sample_report()))

	assert_eq(parsed["unreadable_files"]["locked.dtx"], "denied")


func test_writes_to_a_file() -> void:
	var path := "user://test_inventory.json"

	assert_true(_writer.write_to_file(_sample_report(), path))
	assert_true(FileAccess.file_exists(path))

	var contents := FileAccess.get_file_as_string(path)
	assert_eq(JSON.parse_string(contents)["file_count"], 2.0)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
