# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

var _probe: SignatureProbe


func before_each() -> void:
	_probe = SignatureProbe.new()


func test_records_the_leading_bytes_as_hex() -> void:
	var result := _probe.probe("avp2.rez", "RezMgr Version 1".to_utf8_buffer())

	assert_eq(result["signature"], "52657A4D67722056657273696F6E2031")
	assert_eq(result["probe"], "signature")


func test_handles_a_file_shorter_than_the_signature_length() -> void:
	var result := _probe.probe("tiny.dat", PackedByteArray([0xDE, 0xAD]))

	assert_eq(result["signature"], "DEAD")


func test_returns_nothing_for_an_empty_file() -> void:
	assert_true(_probe.probe("empty.dat", PackedByteArray()).is_empty())


func test_accepts_every_file_because_no_format_is_assumed() -> void:
	assert_true(_probe.can_probe("anything.xyz"))
	assert_true(_probe.can_probe("no-extension"))


func test_requests_the_signature_length() -> void:
	assert_eq(_probe.required_bytes(), SignatureProbe.SIGNATURE_LENGTH)
