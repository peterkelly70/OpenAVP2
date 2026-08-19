# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

const ROOT := "/games/avp2"


func _orchestrator(fs: FakeFileSystem) -> InventoryOrchestrator:
	var services := Services.new(fs)
	return services.inventory_orchestrator()


func _valid_installation() -> FakeFileSystem:
	return FakeFileSystem.new().with_text_file("%s/avp2.rez" % ROOT, "RezMgr Version 1")


func _extension(report: Dictionary, name: String) -> Dictionary:
	for entry in report["extensions"]:
		if entry["extension"] == name:
			return entry
	return {}


func test_counts_files_and_total_size() -> void:
	var fs := _valid_installation() \
		.with_sized_file("%s/sound/effect.wav" % ROOT, 100) \
		.with_sized_file("%s/sound/music.wav" % ROOT, 50)

	var report := _orchestrator(fs).scan(ROOT)

	assert_eq(report["file_count"], 3)
	assert_eq(report["total_bytes"], 166)  # 16 + 100 + 50


func test_groups_files_by_extension() -> void:
	var fs := _valid_installation() \
		.with_sized_file("%s/sound/a.wav" % ROOT, 10) \
		.with_sized_file("%s/sound/b.wav" % ROOT, 10)

	var wav := _extension(_orchestrator(fs).scan(ROOT), "wav")

	assert_eq(wav["count"], 2)
	assert_eq(wav["total_bytes"], 20)


func test_normalises_extension_case() -> void:
	# Extension case varies across the shipped data; the report must not show
	# DTX and dtx as two different formats.
	var fs := _valid_installation() \
		.with_sized_file("%s/textures/a.DTX" % ROOT, 4) \
		.with_sized_file("%s/textures/b.dtx" % ROOT, 4)

	assert_eq(_extension(_orchestrator(fs).scan(ROOT), "dtx")["count"], 2)


func test_counts_distinct_signatures_within_an_extension() -> void:
	# This is the point of stage 0: discovering how many variants of a format an
	# installation actually contains, without assuming any.
	var fs := _valid_installation() \
		.with_file("%s/worlds/a.dat" % ROOT, PackedByteArray([0x46, 0x00])) \
		.with_file("%s/worlds/b.dat" % ROOT, PackedByteArray([0x46, 0x00])) \
		.with_file("%s/worlds/c.dat" % ROOT, PackedByteArray([0x2A, 0x00]))

	var dat := _extension(_orchestrator(fs).scan(ROOT), "dat")

	assert_eq(dat["signatures"].size(), 2)
	assert_eq(dat["signatures"][0]["count"], 2, "most common signature first")
	assert_eq(dat["signatures"][0]["signature"], "4600")


func test_limits_example_count_per_signature() -> void:
	var fs := _valid_installation()
	for i in 10:
		fs.with_file("%s/worlds/w%d.dat" % [ROOT, i], PackedByteArray([0x46]))

	var dat := _extension(_orchestrator(fs).scan(ROOT), "dat")

	assert_eq(dat["signatures"][0]["examples"].size(), 3)
	assert_eq(dat["signatures"][0]["count"], 10)


func test_records_files_with_no_extension() -> void:
	var fs := _valid_installation().with_sized_file("%s/README" % ROOT, 8)

	assert_false(_extension(_orchestrator(fs).scan(ROOT), "(none)").is_empty())


func test_continues_past_an_unreadable_file_and_records_it() -> void:
	# One unreadable file must not abort the scan of an entire installation.
	var fs := _valid_installation() \
		.with_unreadable_file("%s/locked.dtx" % ROOT) \
		.with_sized_file("%s/sound/ok.wav" % ROOT, 4)

	var report := _orchestrator(fs).scan(ROOT)

	assert_eq(report["file_count"], 3)
	assert_true(report["unreadable_files"].has("locked.dtx"))


func test_reports_an_invalid_installation_instead_of_failing() -> void:
	# A near-miss directory should be diagnosable, not merely rejected.
	var fs := FakeFileSystem.new().with_sized_file("%s/readme.txt" % ROOT, 4)

	var report := _orchestrator(fs).scan(ROOT)

	assert_false(report["is_valid_installation"])
	assert_eq(report["file_count"], 1)


func test_reads_no_files_when_probing_is_disabled() -> void:
	var fs := _valid_installation().with_unreadable_file("%s/locked.dtx" % ROOT)

	var report := _orchestrator(fs).scan(ROOT, {"probe_contents": false})

	assert_eq(report["unreadable_files"].size(), 0)
	assert_eq(_extension(report, "dtx")["signatures"].size(), 0)


func test_orders_extensions_deterministically() -> void:
	# Two scans of the same installation must produce identical output so that
	# reports can be diffed.
	var fs := _valid_installation() \
		.with_sized_file("%s/a.wav" % ROOT, 1) \
		.with_sized_file("%s/b.wav" % ROOT, 1) \
		.with_sized_file("%s/c.dtx" % ROOT, 1)

	var first := _orchestrator(fs).scan(ROOT)
	var second := _orchestrator(fs).scan(ROOT)

	assert_eq(JSON.stringify(first["extensions"]), JSON.stringify(second["extensions"]))
	assert_eq(first["extensions"][0]["extension"], "wav", "most files first")
