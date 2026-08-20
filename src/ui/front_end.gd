# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name FrontEnd
extends Control

## The front end and its screen flow.
##
## The shape follows the game's own: a main screen, a single player screen
## offering the three campaigns, and a mission list for the chosen species. The
## wording comes from the strings in the game's resource DLL, and the missions
## from its mission data, so neither is invented here.

signal level_chosen(archive: String, world: String)
signal extract_requested()
signal quit_chosen()

var _vfs: Vfs
var _install := ""
var _settings: Settings
var _campaign: Campaign
var _background: TextureRect
var _screen: MenuScreen
var _species := ""


func _init(vfs: Vfs, install: String, settings: Settings) -> void:
	_vfs = vfs
	_install = install
	_settings = settings


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_campaign = Campaign.new()
	if not _campaign.load_from(_vfs):
		push_warning("[UI] mission data unavailable; falling back to archive contents")

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture = GeneratedArt.menu_background(
		Vector2i(get_viewport_rect().size * 0.5))
	add_child(_background)

	_screen = MenuScreen.new(_vfs)
	_screen.chosen.connect(_on_chosen)
	_screen.back.connect(_on_back)
	add_child(_screen)

	_show_main()

	# A starting screen can be named on the command line, which is how the
	# deeper screens are captured for review without navigating to them.
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screen" and i + 1 < args.size():
			var target: String = args[i + 1]
			if target == "single":
				_show_single_player()
			elif target.begins_with("missions:"):
				_show_missions(target.substr(9))


func _show_main() -> void:
	_species = ""
	_screen.set_heading("MAIN MENU")
	_screen.set_back_visible(false)
	_screen.set_model("interface/menus/models/menu_dropship.abc")
	_screen.set_items([
		{"id": "single", "text": "SINGLE PLAYER", "hint": "Play a campaign mission"},
		{"id": "extract", "text": "EXTRACT ASSETS", "hint": "Write the installation's content to disk"},
		{"id": "artwork", "text": _artwork_text(), "hint": "Choose between OpenAvP2's artwork and the game's"},
		{"id": "quit", "text": "QUIT", "hint": "Leave the game"},
	])


func _show_single_player() -> void:
	_species = ""
	_screen.set_heading("SINGLE PLAYER")
	_screen.set_back_visible(true)
	_screen.set_model("interface/menus/models/sp_marine.abc")

	var items: Array = []
	for species in Campaign.SPECIES:
		var id: String = species["id"]
		items.append({
			"id": "species:" + id,
			"text": "%s MISSIONS" % String(species["name"]).to_upper(),
			"hint": "Choose a %s mission" % species["name"],
		})
	_screen.set_items(items)


## Shows a species' missions, taken from the game's mission chain where it is
## available and from the archive's contents otherwise.
func _show_missions(species_id: String) -> void:
	_species = species_id
	var name := ""
	for species in Campaign.SPECIES:
		if species["id"] == species_id:
			name = species["name"]
	_screen.set_heading("%s MISSIONS" % name.to_upper())
	_screen.set_back_visible(true)
	_screen.set_model(Campaign.model_for(species_id))

	var items: Array = []
	for mission in _campaign.missions_for(species_id):
		items.append({
			"id": "mission:" + mission.world_path(),
			"text": mission.name.to_upper(),
			"hint": mission.level,
		})

	if items.is_empty():
		for world in _worlds_in_archive(species_id):
			items.append({
				"id": "mission:" + world,
				"text": world.get_file().get_basename().to_upper(),
				"hint": world,
			})

	if items.is_empty():
		items.append({"id": "none", "text": "NO MISSIONS FOUND",
			"hint": "This campaign's archive is not present"})

	_screen.set_items(items)


## Falls back to listing an archive when the mission chain cannot be read.
func _worlds_in_archive(species_id: String) -> PackedStringArray:
	var archive := RezArchive.new()
	if not archive.load(_install.path_join(Campaign.archive_for(species_id))):
		return PackedStringArray()

	var prefix := ""
	for species in Campaign.SPECIES:
		if species["id"] == species_id:
			prefix = species["prefix"]

	var found := PackedStringArray()
	for entry in archive.entries():
		if entry.extension == "dat" and entry.path.begins_with(prefix):
			found.append(entry.path)
	found.sort()
	return found


func _on_chosen(id: String) -> void:
	if id == "single":
		_show_single_player()
	elif id == "extract":
		extract_requested.emit()
	elif id == "quit":
		quit_chosen.emit()
	elif id == "artwork":
		_toggle_artwork()
	elif id.begins_with("species:"):
		_show_missions(id.substr(8))
	elif id.begins_with("mission:"):
		var world := id.substr(8)
		var archive := _install.path_join(Campaign.archive_for(_species))
		level_chosen.emit(archive, world)


func _on_back() -> void:
	if not _species.is_empty():
		_show_single_player()
	else:
		_show_main()

	# A starting screen can be named on the command line, which is how the
	# deeper screens are captured for review without navigating to them.
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screen" and i + 1 < args.size():
			var target: String = args[i + 1]
			if target == "single":
				_show_single_player()
			elif target.begins_with("missions:"):
				_show_missions(target.substr(9))


func _artwork_text() -> String:
	return "ARTWORK:  ORIGINAL" if _settings.uses_original_art() else "ARTWORK:  OPENAVP2"


func _toggle_artwork() -> void:
	_settings.art_source = Settings.ArtSource.GENERATED if _settings.uses_original_art() \
		else Settings.ArtSource.ORIGINAL
	_settings.save_settings()
	_show_main()

	# A starting screen can be named on the command line, which is how the
	# deeper screens are captured for review without navigating to them.
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screen" and i + 1 < args.size():
			var target: String = args[i + 1]
			if target == "single":
				_show_single_player()
			elif target.begins_with("missions:"):
				_show_missions(target.substr(9))
