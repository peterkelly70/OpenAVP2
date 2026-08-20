# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MenuScreen
extends Control

## One screen of the front end, laid out as the original does.
##
## A heading at the top left, a column of plain text beneath it, the species or
## scene model filling the right, a hint line along the bottom, and Back at the
## bottom left. Every screen shares this frame; only its heading, items and
## model differ.

signal chosen(id: String)
signal back()

## Fraction of the width the model occupies.
const MODEL_WIDTH := 0.52

var _vfs: Vfs
var _heading: Label
var _hint: Label
var _list: MenuList
var _display: ModelDisplay
var _back: MenuList


func _init(vfs: Vfs) -> void:
	_vfs = vfs


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = InterfaceTheme.build()

	_build_model_pane()
	_build_text_pane()


## The model sits behind the text rather than beside it, as the original does:
## the head overlaps the right of the screen while the words stay legible on the
## dark left.
func _build_model_pane() -> void:
	_display = ModelDisplay.new(_vfs)
	_display.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_display.anchor_left = 1.0 - MODEL_WIDTH
	_display.offset_left = 0
	_display.offset_right = 0
	_display.offset_top = 0
	_display.offset_bottom = 0
	add_child(_display)


func _build_text_pane() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 56)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	margin.add_child(column)

	_heading = Label.new()
	_heading.add_theme_font_override("font", InterfaceTheme.display())
	_heading.add_theme_font_size_override("font_size", 44)
	_heading.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(_heading)

	_list = MenuList.new()
	_list.chosen.connect(func(id: String) -> void: chosen.emit(id))
	_list.highlighted.connect(_on_highlighted)
	column.add_child(_list)

	# A spacer pushes Back and the hint to the bottom, as the original has them.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_back = MenuList.new()
	_back.add_item("back", "BACK", "Return to the previous screen")
	_back.chosen.connect(func(_id: String) -> void: back.emit())
	_back.highlighted.connect(_on_highlighted)
	column.add_child(_back)

	_hint = Label.new()
	_hint.add_theme_font_override("font", InterfaceTheme.monospace())
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", GeneratedArt.TEXT_DIM)
	column.add_child(_hint)


## Sets the screen's title.
func set_heading(text: String) -> void:
	_heading.text = text


## Replaces the screen's items.
func set_items(items: Array) -> void:
	_list.clear_items()
	for item in items:
		_list.add_item(item["id"], item["text"], item.get("hint", ""))
	_list.focus_first()
	_list.grab_focus()


## Shows a model on the right, or nothing when the path is empty.
func set_model(path: String) -> void:
	_display.show_model(path)


## Shows or hides the Back item, since the top screen has nothing to go back to.
func set_back_visible(visible_: bool) -> void:
	_back.visible = visible_


func _on_highlighted(_id: String, hint: String) -> void:
	_hint.text = hint


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE \
			and _back.visible:
		back.emit()
		accept_event()
