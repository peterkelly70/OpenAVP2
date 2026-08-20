# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DatWorldModel
extends RefCounted

## One world model: a named piece of level geometry.
##
## A world file holds many of these. The first is the level hull; the rest are
## the separately addressed pieces that doors, lifts and destructibles are
## attached to, which is why each carries its own name.

## One polygon, as a set of indices into the model's shared arrays.
class Polygon extends RefCounted:
	## Indices into [member points].
	var indices: PackedInt32Array
	## Index into [member surfaces].
	var surface: int
	## Index into the model's plane list.
	var plane: int

	func _init(vertex_indices: PackedInt32Array, surface_index: int, plane_index: int) -> void:
		indices = vertex_indices
		surface = surface_index
		plane = plane_index


## One surface: the material applied to a set of polygons.
class Surface extends RefCounted:
	## Index into [member textures], or -1 when untextured.
	var texture: int
	## Surface flags from the file.
	var flags: int
	## Texture mapping origin.
	var uv_origin := Vector3.ZERO
	## Texture mapping axes. A vertex's coordinates are its offset from the
	## origin projected onto these, divided by the texture's dimensions.
	var uv_u := Vector3.ZERO
	var uv_v := Vector3.ZERO

	func _init(texture_index: int, surface_flags: int,
			origin := Vector3.ZERO, u := Vector3.ZERO, v := Vector3.ZERO) -> void:
		texture = texture_index
		flags = surface_flags
		uv_origin = origin
		uv_u = u
		uv_v = v


## Model name, for example "BigPipe". The level hull is usually unnamed.
var name := ""
## Texture paths this model references.
var textures: PackedStringArray = []
## Shared vertex positions.
var points: PackedVector3Array = []
## Polygons, indexing into [member points].
var polygons: Array[Polygon] = []
## Surfaces, indexed by polygons.
var surfaces: Array[Surface] = []
## Axis-aligned bounds.
var bounds_min := Vector3.ZERO
var bounds_max := Vector3.ZERO
## The model's pivot in world space.
##
## Not an offset: the points are already world-space, and this matches the
## position of the object record that drives the model. A door's pivot equals
## its Door object's Pos, which is how the two are related. Applying it as a
## translation displaces the model by its own centre.
var pivot := Vector3.ZERO


## Whether the model has geometry worth building a mesh from.
func has_geometry() -> bool:
	return not points.is_empty() and not polygons.is_empty()


## Polygons grouped by the texture they use, so a mesh can be built with one
## surface per texture rather than one per polygon.
func polygons_by_texture() -> Dictionary:
	var grouped := {}
	for polygon in polygons:
		var texture := -1
		if polygon.surface >= 0 and polygon.surface < surfaces.size():
			texture = surfaces[polygon.surface].texture
		if not grouped.has(texture):
			grouped[texture] = []
		grouped[texture].append(polygon)
	return grouped


func _to_string() -> String:
	return "%s: %d points, %d polygons, %d textures" % [
		name if not name.is_empty() else "(level hull)",
		points.size(), polygons.size(), textures.size()]
