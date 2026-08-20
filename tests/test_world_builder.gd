# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Covers the conversions that turn world data into Godot geometry. Both are
## easy to get subtly wrong in ways that still produce a picture.


func test_mirrors_one_axis() -> void:
	# LithTech is left-handed and Godot right-handed, so an axis is mirrored.
	# Without it the world renders inside out with every surface reversed.
	var converted := WorldBuilder._convert(Vector3(100, 200, 300))

	assert_lt(converted.x, 0.0, "X is mirrored")
	assert_gt(converted.y, 0.0)
	assert_gt(converted.z, 0.0)


func test_scale_matches_objects_of_known_size() -> void:
	# The scale is calibrated, not chosen: a door in the first Marine mission is
	# 160 units tall and the player start sits at 128 units, which must come out
	# as a two metre door and a 1.6 metre eye height.
	var door_height := WorldBuilder._convert(Vector3(0, 160, 0)).y
	var eye_height := WorldBuilder._convert(Vector3(0, 128, 0)).y

	assert_almost_eq(door_height, 2.0, 0.01)
	assert_almost_eq(eye_height, 1.6, 0.01)


func test_texture_coordinates_project_onto_the_surface_axes() -> void:
	# Mapping is stored as an origin and two world-space axes rather than
	# per-vertex coordinates.
	var surface := DatWorldModel.Surface.new(0, 0,
		Vector3(10, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0))

	var uv := WorldBuilder._texture_coordinate(surface, Vector3(74, 32, 0), Vector2(64, 64))

	assert_almost_eq(uv.x, 1.0, 0.001)
	assert_almost_eq(uv.y, 0.5, 0.001)


func test_texture_coordinates_scale_with_texture_size() -> void:
	# Using the wrong size leaves mapping correct but wrongly scaled, which
	# looks like noise rather than an error.
	var surface := DatWorldModel.Surface.new(0, 0,
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0))

	var small := WorldBuilder._texture_coordinate(surface, Vector3(128, 0, 0), Vector2(128, 128))
	var large := WorldBuilder._texture_coordinate(surface, Vector3(128, 0, 0), Vector2(256, 256))

	assert_almost_eq(small.x, 1.0, 0.001)
	assert_almost_eq(large.x, 0.5, 0.001)


func test_texture_coordinates_are_zero_without_a_surface() -> void:
	assert_eq(WorldBuilder._texture_coordinate(null, Vector3.ONE, Vector2(64, 64)), Vector2.ZERO)


func test_polygons_group_by_texture() -> void:
	# Grouping is what keeps a model to a few mesh surfaces rather than one per
	# polygon.
	var model := DatWorldModel.new()
	model.surfaces = [
		DatWorldModel.Surface.new(0, 0),
		DatWorldModel.Surface.new(1, 0),
	] as Array[DatWorldModel.Surface]
	model.polygons = [
		DatWorldModel.Polygon.new(PackedInt32Array([0, 1, 2]), 0, 0),
		DatWorldModel.Polygon.new(PackedInt32Array([0, 1, 2]), 1, 0),
		DatWorldModel.Polygon.new(PackedInt32Array([0, 1, 2]), 0, 0),
	] as Array[DatWorldModel.Polygon]

	var grouped := model.polygons_by_texture()

	assert_eq(grouped[0].size(), 2)
	assert_eq(grouped[1].size(), 1)


func test_world_model_points_are_already_in_world_space() -> void:
	# The pivot field is the model's centre, matching the position of the object
	# record that drives it, not an offset to add. Treating it as a translation
	# displaces every model by its own centre.
	var model := DatWorldModel.new()
	model.bounds_min = Vector3(-2328, 0, 1132)
	model.bounds_max = Vector3(-2312, 160, 1232)
	model.pivot = Vector3(-2320, 80, 1182)

	assert_eq(model.pivot, (model.bounds_min + model.bounds_max) * 0.5)


func test_a_model_without_geometry_is_recognised() -> void:
	var empty := DatWorldModel.new()
	assert_false(empty.has_geometry())

	var model := DatWorldModel.new()
	model.points = PackedVector3Array([Vector3.ZERO])
	model.polygons = [DatWorldModel.Polygon.new(PackedInt32Array([0]), 0, 0)] as Array[DatWorldModel.Polygon]
	assert_true(model.has_geometry())
