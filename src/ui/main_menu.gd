# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MainMenu
extends Control

## OpenAvP2's front end.
##
## The artwork is the project's own by default, generated at the size the screen
## needs rather than upscaled from images authored for 640 by 480. The
## installation's original artwork can be used instead, read from the user's own
## copy; nothing of the game's is redistributed either way.

signal level_chosen(archive: String, world: String)
signal extract_requested()
signal quit_chosen()

## The installation's title image, used when original artwork is selected.
const ORIGINAL_LOGO := "interface/avp2_logo.pcx"

## Campaigns, in the order the menu lists them.
const CAMPAIGNS: Array = [
	{"name": "MARINE", "archive": "MARINE.REZ", "prefix": "worlds/singleplayer/m"},
	{"name": "ALIEN", "archive": "ALIEN.REZ", "prefix": "worlds/singleplayer/a"},
	{"name": "PREDATOR", "archive": "PREDATOR.REZ", "prefix": "worlds/singleplayer/p"},
]

var _settings: Settings
var _images: InterfaceImages
var _install := ""
var _list: ItemList
var _worlds: Array = []
var _background: TextureRect
var _art_button: Button


func _init(settings: Settings, install: String, images: InterfaceImages) -> void:
	_settings = settings
	_install = install
	_images = images


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = InterfaceTheme.build()

	_add_background()
	_add_layout()
	get_viewport().size_changed.connect(_on_resized)


## The background is generated at the viewport's size, so it is sharp at any
## resolution rather than being an enlargement of a smaller image.
func _add_background() -> void:
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Cover the screen without distorting the artwork's proportions.
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_refresh_background()


func _refresh_background() -> void:
	var size := get_viewport_rect().size
	if size.x < 16 or size.y < 16:
		return
	_background.texture = GeneratedArt.menu_background(Vector2i(size * 0.5))


func _on_resized() -> void:
	_refresh_background()


func _add_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 26)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(left)

	_add_title(left)
	_add_actions(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(right)

	_add_missions(right)


func _add_title(column: VBoxContainer) -> void:
	if _settings.uses_original_art():
		var logo := _images.texture(ORIGINAL_LOGO)
		if logo != null:
			var rect := TextureRect.new()
			rect.texture = logo
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.custom_minimum_size = Vector2(460, 220)
			column.add_child(rect)
			return

	# The project's own title treatment, set in the display face over a plate.
	var plate := Control.new()
	plate.custom_minimum_size = Vector2(460, 190)

	# A dim scrim behind the wordmark so it stays legible over the artwork.
	var backing := TextureRect.new()
	backing.texture = GeneratedArt.title_plate(Vector2i(460, 190))
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.add_child(backing)

	# Inset from the plate so the wordmark clears the accent rule along its
	# lower edge.
	# Inset from the plate's lower edge so the wordmark clears the accent rule.
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_bottom = -22
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -12)
	plate.add_child(stack)

	stack.add_child(_title_line("OPEN", 62, GeneratedArt.TEXT))
	stack.add_child(_title_line("AvP2", 74, GeneratedArt.ACCENT))

	column.add_child(plate)

	# The subtitle sits below the plate rather than inside it, so it cannot
	# collide with the accent rule along the plate's lower edge.
	var subtitle := _title_line("CROSS-PLATFORM REPLACEMENT RUNTIME", 15,
		GeneratedArt.TEXT_DIM)
	subtitle.add_theme_font_override("font", InterfaceTheme.monospace())
	column.add_child(subtitle)


func _title_line(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", InterfaceTheme.display())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _add_actions(column: VBoxContainer) -> void:
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)

	actions.add_child(_action("DEPLOY", _on_play))
	actions.add_child(_action("EXTRACT ASSETS", func() -> void: extract_requested.emit()))

	_art_button = _action(_art_label(), _on_toggle_art)
	actions.add_child(_art_button)

	actions.add_child(_action("QUIT", func() -> void: quit_chosen.emit()))
	column.add_child(actions)


func _action(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(460, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(handler)
	return button


func _art_label() -> String:
	return "ARTWORK:  ORIGINAL" if _settings.uses_original_art() else "ARTWORK:  OPENAVP2"


## Switches between the project's artwork and the installation's, saving the
## choice and rebuilding the title so the change is visible immediately.
func _on_toggle_art() -> void:
	_settings.art_source = Settings.ArtSource.GENERATED if _settings.uses_original_art() \
		else Settings.ArtSource.ORIGINAL
	_settings.save_settings()
	_art_button.text = _art_label()

	for child in get_children():
		child.queue_free()
	_add_background()
	_add_layout()


func _add_missions(column: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "SELECT MISSION"
	heading.add_theme_font_override("font", InterfaceTheme.display())
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", GeneratedArt.ACCENT)
	column.add_child(heading)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 520)
	_list.item_activated.connect(func(_index: int) -> void: _on_play())
	_worlds = []

	for campaign in CAMPAIGNS:
		var archive: String = _install.path_join(campaign["archive"])
		if not FileAccess.file_exists(archive):
			continue

		var missions := _missions(archive, campaign["prefix"])
		if missions.is_empty():
			continue

		_list.add_item("%s CAMPAIGN" % campaign["name"])
		_list.set_item_selectable(_list.item_count - 1, false)
		_list.set_item_custom_fg_color(_list.item_count - 1, GeneratedArt.ACCENT)
		_worlds.append(null)

		for mission in missions:
			_list.add_item("   %s" % mission.get_file().get_basename().to_upper())
			_worlds.append({"archive": archive, "world": mission})

	if _list.item_count == 0:
		_list.add_item("No campaign archives found in the installation")
		_list.set_item_selectable(0, false)
		_worlds.append(null)

	column.add_child(_list)


func _missions(archive_path: String, prefix: String) -> PackedStringArray:
	var archive := RezArchive.new()
	if not archive.load(archive_path):
		return PackedStringArray()

	var found := PackedStringArray()
	for entry in archive.entries():
		if entry.extension == "dat" and entry.path.begins_with(prefix):
			found.append(entry.path)
	found.sort()
	return found


func _on_play() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return
	var entry = _worlds[selected[0]]
	if entry != null:
		level_chosen.emit(entry["archive"], entry["world"])
