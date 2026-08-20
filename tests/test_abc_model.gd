# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Built from synthetic models rather than game data.


func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(2); b.encode_u16(0, v); return b


func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_u32(0, v); return b


func _f32(v: float) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4); b.encode_float(0, v); return b


func _string(text: String) -> PackedByteArray:
	var out := _u16(text.length())
	out.append_array(text.to_ascii_buffer())
	return out


## Builds a model with one piece, one level of detail and one triangle.
func _model(version: int = 12, lod_count: int = 1) -> PackedByteArray:
	var header := PackedByteArray()
	header.append_array(_u32(version))
	header.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	header.append_array(_u32(1))            # node count
	for i in 20: header.append(0)
	header.append_array(_u32(lod_count))
	header.append_array(_u32(0))
	header.append_array(_u32(0))            # weight set count
	for i in 8: header.append(0)
	if version >= 13:
		for i in 4: header.append(0)
	header.append_array(_string("Test"))    # command string
	header.append_array(_f32(1.0))          # internal radius
	header.append_array(_u32(0))            # distance count
	for i in 60: header.append(0)

	var pieces := PackedByteArray()
	pieces.append_array(_u32(0))            # weight count
	pieces.append_array(_u32(1))            # piece count
	pieces.append_array(_u16(0))            # material index
	pieces.append_array(_f32(0.0))
	pieces.append_array(_f32(0.0))
	if version > 9:
		pieces.append_array(_f32(0.0))
	pieces.append_array(_u16(0))            # padding
	pieces.append_array(_string("Body"))

	for lod in lod_count:
		pieces.append_array(_u32(1))        # face count
		for corner in 3:
			pieces.append_array(_f32(float(corner) * 0.5))
			pieces.append_array(_f32(0.25))
			pieces.append_array(_u16(corner))
		pieces.append_array(_u32(3))        # vertex count
		for v in 3:
			pieces.append_array(_u16(0))    # weight count
			pieces.append_array(_u16(0))    # sub-level index
			pieces.append_array(_f32(float(v) * 80.0))
			pieces.append_array(_f32(0.0))
			pieces.append_array(_f32(0.0))
			pieces.append_array(_f32(0.0))
			pieces.append_array(_f32(1.0))
			pieces.append_array(_f32(0.0))

	var out := PackedByteArray()
	var header_section := _string("Header")
	var pieces_section := _string("Pieces")

	var header_start := header_section.size() + 4
	var pieces_start := header_start + header.size()
	var end := pieces_start + pieces_section.size() + 4 + pieces.size()

	out.append_array(header_section)
	out.append_array(_u32(pieces_start))
	out.append_array(header)
	out.append_array(pieces_section)
	out.append_array(_u32(AbcModel.END_OF_SECTIONS))
	out.append_array(pieces)
	return out


func test_reads_the_header() -> void:
	var model := AbcModel.new()

	assert_true(model.parse(_model()), model.error())
	assert_eq(model.version, 12)
	assert_eq(model.command_string, "Test")


func test_reads_pieces_and_geometry() -> void:
	var model := AbcModel.new()
	assert_true(model.parse(_model()), model.error())

	assert_eq(model.pieces.size(), 1)
	assert_eq(model.pieces[0].name, "Body")
	assert_eq(model.pieces[0].levels.size(), 1)

	var level: AbcModel.Level = model.pieces[0].levels[0]
	assert_eq(level.indices.size(), 3, "one triangle")
	assert_eq(level.positions.size(), 3)
	assert_eq(level.uvs.size(), 3, "coordinates are per index, not per vertex")


func test_reads_several_levels_of_detail() -> void:
	var model := AbcModel.new()
	assert_true(model.parse(_model(12, 3)), model.error())

	assert_eq(model.pieces[0].levels.size(), 3)


func test_handles_the_older_layout() -> void:
	# Version 9 omits the level of detail weight, so a reader that always reads
	# it drifts by four bytes and everything after is wrong.
	var model := AbcModel.new()

	assert_true(model.parse(_model(9)), model.error())
	assert_eq(model.pieces[0].name, "Body")


func test_rejects_an_unsupported_version() -> void:
	var model := AbcModel.new()

	assert_false(model.parse(_model(3)))
	assert_string_contains(model.error(), "version")


func test_rejects_a_file_that_is_not_a_model() -> void:
	var model := AbcModel.new()
	var junk := PackedByteArray()
	junk.resize(64)

	assert_false(model.parse(junk))
