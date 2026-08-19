# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name SignatureProbe
extends FormatProbe

## Records the leading bytes of every file, without interpreting them.
##
## This is the probe that makes the stage 0 inventory possible before any format
## is documented. Rather than assuming magic numbers and version offsets, it
## groups the files in a real installation by their observed leading bytes, so
## that the number of distinct variants of each format becomes an observation
## instead of an assumption. The resulting signatures are the starting point for
## the format notes in docs/formats/.

## Number of leading bytes recorded from each file.
const SIGNATURE_LENGTH := 16


func probe_name() -> String:
	return "signature"


func can_probe(_canonical_path: String) -> bool:
	return true


func required_bytes() -> int:
	return SIGNATURE_LENGTH


func probe(_canonical_path: String, prefix: PackedByteArray) -> Dictionary:
	if prefix.is_empty():
		return {}

	return {
		"probe": probe_name(),
		"signature": prefix.hex_encode().to_upper(),
		"facts": {},
	}
