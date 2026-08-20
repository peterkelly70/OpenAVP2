# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name Settings
extends RefCounted

## User settings, stored under an OpenAvP2-owned path rather than in the game's
## installation, which is never written to.

const PATH := "user://settings.cfg"
const SECTION := "openavp2"

## Which artwork the interface uses.
enum ArtSource {
	## OpenAvP2's own generated artwork. The default, and the only art that can
	## be distributed.
	GENERATED,
	## The installation's original artwork, read from the user's own copy.
	ORIGINAL,
}

## Path to the AvP2 installation.
var installation := ""
## Which artwork the menus use.
var art_source := ArtSource.GENERATED
## Multiplier applied to original artwork, which was authored for 640 by 480.
var art_upscale := 2
## Where extracted assets are written.
var extract_directory := "user://extracted"


## Loads settings, returning whether a file was found.
func load_settings() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false

	installation = config.get_value(SECTION, "installation", installation)
	art_source = config.get_value(SECTION, "art_source", art_source)
	art_upscale = config.get_value(SECTION, "art_upscale", art_upscale)
	extract_directory = config.get_value(SECTION, "extract_directory", extract_directory)
	return true


## Saves settings.
func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, "installation", installation)
	config.set_value(SECTION, "art_source", art_source)
	config.set_value(SECTION, "art_upscale", art_upscale)
	config.set_value(SECTION, "extract_directory", extract_directory)
	return config.save(PATH) == OK


## Whether the menus should use the installation's artwork.
func uses_original_art() -> bool:
	return art_source == ArtSource.ORIGINAL
