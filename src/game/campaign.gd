# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name Campaign
extends RefCounted

## The campaigns, read from the game's own mission data.
##
## `attributes/missions.txt` defines the chain: each mission names its level and
## the mission that follows, so the campaign order is data rather than a guess
## from filenames. It also carries the fade time between missions, which the
## presentation needs.

const MISSIONS_PATH := "attributes/missions.txt"

## The three playable species, with the archive each campaign's levels live in
## and the prefix its levels share.
const SPECIES: Array = [
	{"id": "marine", "name": "Marine", "archive": "MARINE.REZ", "prefix": "worlds/singleplayer/m"},
	{"id": "predator", "name": "Predator", "archive": "PREDATOR.REZ", "prefix": "worlds/singleplayer/p"},
	{"id": "alien", "name": "Alien", "archive": "ALIEN.REZ", "prefix": "worlds/singleplayer/a"},
]

## The menu model shown for each species.
const SPECIES_MODELS := {
	"marine": "interface/menus/models/sp_marine.abc",
	"predator": "interface/menus/models/sp_predator.abc",
	"alien": "interface/menus/models/sp_drone.abc",
}


## One mission.
class Mission extends RefCounted:
	## Name as the game gives it, for example "Marine Start".
	var name := ""
	## Level path, without extension.
	var level := ""
	## Seconds the screen fades for on entry.
	var fade_time := 0.0
	## Index in the file, which is the order missions are played in.
	var index := 0

	func _init(mission_name: String, mission_level: String,
			fade: float, mission_index: int) -> void:
		name = mission_name
		level = mission_level
		fade_time = fade
		index = mission_index

	## The level's path within an archive.
	func world_path() -> String:
		return VfsPath.canonicalize(level) + ".dat"

	func _to_string() -> String:
		return "%s (%s)" % [name, level]


var _missions: Array[Mission] = []


## Loads the mission list. Returns whether it succeeded.
func load_from(vfs: Vfs) -> bool:
	_missions = []
	if vfs == null:
		return false

	var data := vfs.read(MISSIONS_PATH)
	if data.is_empty():
		return false

	var file := AttributeFile.new()
	if not file.parse(data.get_string_from_utf8()):
		return false

	var index := 0
	for section_name in file.section_names():
		var section := file.section(section_name)
		if section == null or not section.has("NextLevel"):
			continue
		_missions.append(Mission.new(
			section.text("Name", section_name),
			section.text("NextLevel"),
			section.number("ScreenFadeTime"),
			index))
		index += 1

	return not _missions.is_empty()


## Every mission, in campaign order.
func missions() -> Array[Mission]:
	return _missions


## Missions belonging to a species, matched by the level path prefix its
## campaign uses.
func missions_for(species_id: String) -> Array[Mission]:
	var prefix := ""
	for species in SPECIES:
		if species["id"] == species_id:
			prefix = species["prefix"]
			break
	if prefix.is_empty():
		return [] as Array[Mission]

	var out: Array[Mission] = []
	for mission in _missions:
		if mission.world_path().begins_with(prefix):
			out.append(mission)
	return out


## The archive a species' levels live in.
static func archive_for(species_id: String) -> String:
	for species in SPECIES:
		if species["id"] == species_id:
			return species["archive"]
	return ""


## The menu model for a species.
static func model_for(species_id: String) -> String:
	return SPECIES_MODELS.get(species_id, "")
