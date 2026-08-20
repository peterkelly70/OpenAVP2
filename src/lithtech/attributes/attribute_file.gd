# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name AttributeFile
extends RefCounted

## Reader for LithTech attribute files.
##
## The game keeps its tuning in plain text under `attributes/`: movement speeds,
## weapon behaviour, AI parameters, pickups, objectives. Sections are named in
## brackets and hold `key = value` pairs.
##
## This matters more than its size suggests. Values such as movement speed are
## data rather than code, so they can be read from the installation instead of
## being guessed or measured by observation.

## One named section of key/value pairs.
class Section extends RefCounted:
	## Section name as written in brackets.
	var name := ""
	## Values by key, preserving the case they were written in.
	var values := {}

	func _init(section_name: String) -> void:
		name = section_name

	## A value as a float.
	func number(key: String, fallback: float = 0.0) -> float:
		var raw = values.get(key)
		return float(raw) if raw != null and str(raw).is_valid_float() else fallback

	## A value as an integer.
	func integer(key: String, fallback: int = 0) -> int:
		var raw = values.get(key)
		return int(float(raw)) if raw != null and str(raw).is_valid_float() else fallback

	## A value as a string, with surrounding quotes removed.
	func text(key: String, fallback: String = "") -> String:
		var raw = values.get(key)
		return str(raw) if raw != null else fallback

	## A value as a boolean, where any non-zero number is true.
	func flag(key: String, fallback: bool = false) -> bool:
		var raw = values.get(key)
		if raw == null:
			return fallback
		return str(raw).is_valid_float() and float(raw) != 0.0

	## A value written as <x, y, z>.
	func vector(key: String, fallback := Vector3.ZERO) -> Vector3:
		var raw := text(key)
		if not raw.begins_with("<") or not raw.ends_with(">"):
			return fallback
		var parts := raw.substr(1, raw.length() - 2).split(",")
		if parts.size() != 3:
			return fallback
		return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

	## Whether the section defines a key.
	func has(key: String) -> bool:
		return values.has(key)


var _sections := {}
var _order: PackedStringArray = []


## Parses an attribute file's text.
func parse(text: String) -> bool:
	_sections = {}
	_order = []

	var current: Section = null

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()

		# Comments run to end of line and may follow a value.
		var comment := line.find("//")
		if comment >= 0:
			line = line.substr(0, comment).strip_edges()
		if line.is_empty():
			continue

		if line.begins_with("[") and line.ends_with("]"):
			var name := line.substr(1, line.length() - 2).strip_edges()
			current = Section.new(name)
			_sections[name.to_lower()] = current
			_order.append(name)
			continue

		if current == null:
			continue

		var separator := line.find("=")
		if separator < 0:
			continue

		var key := line.substr(0, separator).strip_edges()
		var value := line.substr(separator + 1).strip_edges()
		if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		current.values[key] = value

	return not _sections.is_empty()


## A section by name, case-insensitively, or null.
func section(name: String) -> Section:
	return _sections.get(name.to_lower(), null)


## Whether a section exists.
func has_section(name: String) -> bool:
	return _sections.has(name.to_lower())


## Section names in file order.
func section_names() -> PackedStringArray:
	return _order


## Looks a key up in the first of several sections that defines it.
##
## The files are written with a base section holding shared values and specific
## sections overriding only what differs, so a lookup has to fall back rather
## than read one section in isolation.
func resolve(names: Array, key: String) -> Variant:
	for name in names:
		var found := section(name)
		if found != null and found.has(key):
			return found.values[key]
	return null
