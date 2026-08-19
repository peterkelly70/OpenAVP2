# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Exercised against synthetic worlds built by DatBuilder, never game data.

const T := DatWorld.PropertyType


func _parsed(builder: DatBuilder) -> DatWorld:
	var world := DatWorld.new()
	assert_true(world.parse(builder.build()), world.error())
	return world


func test_reads_the_version() -> void:
	assert_eq(_parsed(DatBuilder.new()).version, 70)


func test_reads_the_world_info_string() -> void:
	# Carries directives such as AmbientLight that the renderer needs.
	var world := _parsed(DatBuilder.new().with_info_string("AmbientLight 10 15 20;"))

	assert_eq(world.info_string, "AmbientLight 10 15 20;")


func test_world_info_string_is_empty_when_absent() -> void:
	assert_eq(_parsed(DatBuilder.new()).info_string, "")


func test_reads_objects_and_their_classes() -> void:
	var world := _parsed(DatBuilder.new()
		.with_object("Door")
		.with_object("GameStartPoint"))

	assert_eq(world.objects.size(), 2)
	assert_eq(world.objects[0].class_name_, "Door")
	assert_eq(world.objects[1].class_name_, "GameStartPoint")


func test_reads_string_properties() -> void:
	var world := _parsed(DatBuilder.new()
		.with_object("Door", {"Name": [T.STRING, "FrontDoor"]}))

	assert_eq(world.objects[0].get_property("Name"), "FrontDoor")
	assert_eq(world.objects[0].object_name(), "FrontDoor")


func test_reads_vector_properties() -> void:
	var world := _parsed(DatBuilder.new()
		.with_object("Prop", {"Pos": [T.VECTOR, Vector3(160, 6.5, 544)]}))

	assert_eq(world.objects[0].position(), Vector3(160, 6.5, 544))


func test_reads_rotation_properties() -> void:
	var world := _parsed(DatBuilder.new()
		.with_object("Prop", {"Rotation": [T.ROTATION, Quaternion(0, 0.5, 0, 0.5)]}))

	assert_eq(world.objects[0].get_property("Rotation"), Quaternion(0, 0.5, 0, 0.5))


func test_reads_scalar_properties() -> void:
	var world := _parsed(DatBuilder.new().with_object("Light", {
		"Alpha": [T.REAL, 1.0],
		"Visible": [T.BOOL, true],
		"StartHidden": [T.BOOL, false],
		"AllowInGameType": [T.FLAGS, 2080],
		"LightColor": [T.COLOR, Vector3(255, 255, 255)],
	}))
	var light := world.objects[0]

	assert_almost_eq(light.get_property("Alpha"), 1.0, 0.001)
	assert_true(light.get_property("Visible"))
	assert_false(light.get_property("StartHidden"))
	assert_eq(light.get_property("AllowInGameType"), 2080)
	assert_eq(light.get_property("LightColor"), Vector3(255, 255, 255))


func test_finds_objects_by_class() -> void:
	var world := _parsed(DatBuilder.new()
		.with_object("Light").with_object("Door").with_object("Light"))

	assert_eq(world.objects_of_class("Light").size(), 2)
	assert_eq(world.objects_of_class("Nothing").size(), 0)


func test_counts_objects_by_class() -> void:
	# The histogram is how implementation order gets decided: the commonest
	# classes in real levels are the ones worth supporting first.
	var world := _parsed(DatBuilder.new()
		.with_object("Light").with_object("Light").with_object("Door"))

	assert_eq(world.class_histogram(), {"Light": 2, "Door": 1})


func test_missing_properties_return_the_fallback() -> void:
	var world := _parsed(DatBuilder.new().with_object("Door"))

	assert_eq(world.objects[0].get_property("Absent", "default"), "default")
	assert_eq(world.objects[0].position(), Vector3.ZERO)


func test_rejects_an_unsupported_version() -> void:
	var world := DatWorld.new()

	assert_false(world.parse(DatBuilder.new().with_version(66).build()))
	assert_string_contains(world.error(), "version")


func test_rejects_a_file_shorter_than_the_header() -> void:
	var world := DatWorld.new()
	var short := PackedByteArray()
	short.resize(16)

	assert_false(world.parse(short))
	assert_string_contains(world.error(), "header")


func test_detects_a_record_length_mismatch() -> void:
	# The declared record length is what makes a misread fail immediately rather
	# than silently corrupting every object that follows.
	var data := DatBuilder.new().with_object("Door", {"Name": [T.STRING, "A"]}).build()
	var world := DatWorld.new()
	assert_true(world.parse(data))

	# Corrupt the declared length of the first record.
	data.encode_u16(world.object_data_position + 4, 999)

	var broken := DatWorld.new()
	assert_false(broken.parse(data))
	assert_string_contains(broken.error(), "record declares")


func test_reports_which_versions_it_supports() -> void:
	# A reader pointed at a different LithTech generation should say what it
	# found and what it handles, not merely refuse.
	var world := DatWorld.new()

	assert_false(world.parse(DatBuilder.new().with_version(85).build()))
	assert_string_contains(world.error(), "85")
	assert_string_contains(world.error(), "70")
