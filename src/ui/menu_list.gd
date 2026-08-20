# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MenuList
extends VBoxContainer

## A menu in the game's own idiom: a column of plain text, no boxes or frames.
##
## The original front end draws its options as bare words, with the one under
## the cursor picked out in colour. Buttons with borders and fills read as a
## generic application; this reads as the game.

signal chosen(id: String)
signal highlighted(id: String, hint: String)

## Colour of the item under the cursor.
const HIGHLIGHT := Color(0.45, 0.78, 1.0)
## Colour of the other items.
const NORMAL := Color(0.86, 0.88, 0.9)
## Colour of items that cannot be chosen.
const DISABLED := Color(0.36, 0.38, 0.4)

var _items: Array[Dictionary] = []
var _labels: Array[Label] = []
var _current := -1


func _init() -> void:
	add_theme_constant_override("separation", 4)
	# Containers do not take focus by default, and without it the arrow keys
	# never reach the menu.
	focus_mode = Control.FOCUS_ALL


## Adds an item. [param hint] is shown by the host while the item is under the
## cursor, as the original does beneath its menus.
func add_item(id: String, text: String, hint: String = "", enabled: bool = true) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", InterfaceTheme.display())
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", NORMAL if enabled else DISABLED)
	label.mouse_filter = Control.MOUSE_FILTER_STOP

	var index := _items.size()
	label.mouse_entered.connect(func() -> void: _highlight(index))
	label.gui_input.connect(func(event: InputEvent) -> void: _on_item_input(event, index))

	add_child(label)
	_labels.append(label)
	_items.append({"id": id, "hint": hint, "enabled": enabled})


## Removes every item.
func clear_items() -> void:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_items.clear()
	_current = -1


## Moves the cursor to the first item that can be chosen.
func focus_first() -> void:
	for i in _items.size():
		if _items[i]["enabled"]:
			_highlight(i)
			return


func _on_item_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_activate(index)


func _highlight(index: int) -> void:
	if index < 0 or index >= _items.size() or not _items[index]["enabled"]:
		return
	if _current == index:
		return

	if _current >= 0 and _current < _labels.size():
		var previous: Dictionary = _items[_current]
		_labels[_current].add_theme_color_override("font_color",
			NORMAL if previous["enabled"] else DISABLED)

	_current = index
	_labels[index].add_theme_color_override("font_color", HIGHLIGHT)
	highlighted.emit(_items[index]["id"], _items[index]["hint"])


func _activate(index: int) -> void:
	if index < 0 or index >= _items.size() or not _items[index]["enabled"]:
		return
	chosen.emit(_items[index]["id"])


## Keyboard navigation, so the menus work without a mouse as the original did.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return

	match event.keycode:
		KEY_DOWN:
			_step(1)
		KEY_UP:
			_step(-1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate(_current)
		_:
			return
	accept_event()


func _step(direction: int) -> void:
	if _items.is_empty():
		return
	var index := _current
	for i in _items.size():
		index = wrapi(index + direction, 0, _items.size())
		if _items[index]["enabled"]:
			_highlight(index)
			return
