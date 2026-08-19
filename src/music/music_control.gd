# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MusicControl
extends RefCounted

## A parsed LithTech DirectMusic level control file.
##
## Each AvP2 theme ships one of these beside its segments, defining the
## intensity levels, the segments played at each, and the transitions between
## them. The format is documented in docs/formats/music-control.md.

## An intensity level.
class Intensity extends RefCounted:
	## Level number as written in the file.
	var number: int
	## How many times to loop; -1 loops forever.
	var loops: int
	## Level to switch to when finished; 0 stops.
	var next: int
	## Segment file names, in order.
	var segments: PackedStringArray

	func _init(n: int, l: int, nxt: int, segs: PackedStringArray) -> void:
		number = n
		loops = l
		next = nxt
		segments = segs


## A transition between two intensity levels.
class Transition extends RefCounted:
	## Level being left.
	var from: int
	## Level being entered.
	var to: int
	## When to enact: SEGMENT, MEASURE, BEAT, IMMEDIATE, GRID or DEFAULT.
	var enact: String
	## AUTOMATIC uses the sequencer's own transition machinery; MANUAL plays a
	## bridge segment, or simply starts the new intensity when none is named.
	var mode: String
	## Bridge segment to play, empty when none.
	var segment: String

	func _init(f: int, t: int, when: String, how: String, seg: String) -> void:
		from = f
		to = t
		enact = when
		mode = how
		segment = seg


## Intensity levels by number.
var intensities := {}
## Every transition, keyed "from:to".
var transitions := {}
## Level to start at; 0 means none.
var initial_intensity := 0
## Styles declared by the file.
var styles: PackedStringArray = []
## Bands declared, as {"style": ..., "band": ...}.
var bands: Array[Dictionary] = []
## Numeric settings such as VOICES and SYNTHSAMPLERATE, by directive name.
var settings := {}

var _error := ""


## Parses a control file's text. Returns whether it succeeded.
func parse(text: String) -> bool:
	_error = ""

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()

		# Comments start with a semicolon and run to end of line. Whole-line
		# comments are how the shipped files document themselves.
		var comment := line.find(";")
		if comment >= 0:
			line = line.substr(0, comment).strip_edges()
		if line.is_empty():
			continue

		var fields := _fields(line)
		if fields.is_empty():
			continue

		match fields[0].to_upper():
			"INTENSITY":
				if not _parse_intensity(fields):
					return false
			"TRANSITION":
				if not _parse_transition(fields):
					return false
			"INITIALINTENSITY":
				initial_intensity = int(fields[1]) if fields.size() > 1 else 0
			"STYLE":
				if fields.size() > 1:
					styles.append(fields[1])
			"BAND":
				if fields.size() > 2:
					bands.append({"style": fields[1], "band": fields[2]})
			_:
				# Remaining directives are scalar settings. Unknown directives are
				# kept rather than rejected, so an unfamiliar file still loads.
				if fields.size() > 1:
					settings[fields[0].to_upper()] = fields[1]

	if intensities.is_empty():
		_error = "no intensity levels defined"
		return false

	return true


## The reason parsing failed, or an empty string.
func error() -> String:
	return _error


## The intensity with the given number, or null.
func intensity(number: int) -> Intensity:
	return intensities.get(number, null)


## The transition between two levels, or null when none is declared.
##
## Undeclared transitions are legal: the file only lists those that differ from
## the default, which is to change on a measure boundary with no bridge segment.
func transition(from: int, to: int) -> Transition:
	return transitions.get("%d:%d" % [from, to], null)


func _parse_intensity(fields: PackedStringArray) -> bool:
	if fields.size() < 4:
		_error = "INTENSITY needs at least a number, loop count and next level"
		return false

	var segments := PackedStringArray()
	for i in range(4, fields.size()):
		segments.append(fields[i])

	var number := int(fields[1])
	intensities[number] = Intensity.new(number, int(fields[2]), int(fields[3]), segments)
	return true


func _parse_transition(fields: PackedStringArray) -> bool:
	if fields.size() < 5:
		_error = "TRANSITION needs from, to, enact time and mode"
		return false

	var from := int(fields[1])
	var to := int(fields[2])
	var segment := fields[5] if fields.size() > 5 else ""
	transitions["%d:%d" % [from, to]] = Transition.new(
		from, to, fields[3].to_upper(), fields[4].to_upper(), segment)
	return true


## Splits a line on runs of whitespace. The shipped files mix tabs and spaces
## freely, including within a single directive.
static func _fields(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	for field in line.replace("\t", " ").split(" ", false):
		if not field.is_empty():
			out.append(field)
	return out
