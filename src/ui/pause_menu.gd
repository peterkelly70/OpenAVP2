# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name PauseMenu
extends Control

## The in-game pause menu.
##
## Follows the front end's idiom: a heading, a column of plain text options, and
## a hint line beneath. The level stays visible behind a dimming scrim rather
## than being replaced, so pausing reads as stopping rather than leaving.

signal resumed()
signal quit_to_menu()

var _hint: Label
var _list: MenuList


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = InterfaceTheme.build()
	# Pause must keep processing input, or the menu cannot be dismissed.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 90)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 30)
	margin.add_child(column)

	column.add_child(_heading("PAUSED"))

	_list = MenuList.new()
	_list.add_item("resume", "RESUME", "Return to the mission")
	_list.add_item("quit", "QUIT TO MENU", "Abandon the mission and return to the main menu")
	_list.chosen.connect(_on_chosen)
	_list.highlighted.connect(func(_id: String, hint: String) -> void: _hint.text = hint)
	column.add_child(_list)

	_hint = Label.new()
	_hint.add_theme_font_override("font", InterfaceTheme.monospace())
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", GeneratedArt.TEXT_DIM)
	column.add_child(_hint)

	_list.focus_first()
	_list.grab_focus()


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", InterfaceTheme.display())
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label


func _on_chosen(id: String) -> void:
	if id == "resume":
		resumed.emit()
	elif id == "quit":
		quit_to_menu.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resumed.emit()
		accept_event()
