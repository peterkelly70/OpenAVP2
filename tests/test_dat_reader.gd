# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## The cursor underpins every structure reader, so an off-by-one here would
## surface as unexplained geometry corruption much later.


func _bytes(values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for v in values:
		out.append(v)
	return out


func test_reads_integers_and_advances() -> void:
	var reader := DatReader.new(_bytes([0x01, 0x02, 0x00, 0x00, 0x00]))

	assert_eq(reader.u8(), 1)
	assert_eq(reader.u32(), 2)
	assert_eq(reader.offset(), 5)


func test_reads_signed_values() -> void:
	var data := PackedByteArray()
	data.resize(4)
	data.encode_s32(0, -70)

	assert_eq(DatReader.new(data).s32(), -70)


func test_reads_floats_and_vectors() -> void:
	var data := PackedByteArray()
	data.resize(12)
	data.encode_float(0, 1.5)
	data.encode_float(4, -2.5)
	data.encode_float(8, 3.5)

	assert_eq(DatReader.new(data).vector(), Vector3(1.5, -2.5, 3.5))


func test_reads_a_length_prefixed_string() -> void:
	var data := PackedByteArray()
	data.resize(2)
	data.encode_u16(0, 7)
	data.append_array("BigPipe".to_ascii_buffer())

	assert_eq(DatReader.new(data).short_string(), "BigPipe")


func test_reads_a_nul_terminated_string() -> void:
	var data := "Walls\\a.dtx".to_ascii_buffer()
	data.append(0)
	data.append_array("next".to_ascii_buffer())

	var reader := DatReader.new(data)
	assert_eq(reader.c_string(), "Walls\\a.dtx")
	assert_eq(reader.offset(), 12, "the terminator is consumed")


func test_seek_and_skip_move_the_cursor() -> void:
	var reader := DatReader.new(_bytes([1, 2, 3, 4, 5, 6]))

	reader.skip(2)
	assert_eq(reader.u8(), 3)
	reader.seek(0)
	assert_eq(reader.u8(), 1)


func test_reading_past_the_end_is_recorded_not_fatal() -> void:
	# Geometry is reached by reading forwards, so an overrun must be detectable
	# rather than crashing partway through a level.
	var reader := DatReader.new(_bytes([1, 2]))

	reader.u32()

	assert_true(reader.failed())
	assert_false(DatReader.new(_bytes([1, 2, 3, 4])).failed())


func test_has_reports_remaining_space() -> void:
	var reader := DatReader.new(_bytes([1, 2, 3, 4]))

	assert_true(reader.has(4))
	assert_false(reader.has(5))
