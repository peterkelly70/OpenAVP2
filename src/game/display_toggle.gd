# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DisplayToggle
extends RefCounted

## Fullscreen handling shared by the demos.
##
## The project opens fullscreen, which is how a level is meant to be viewed, but
## a window is needed for debugging, so the two are switchable at runtime.

## Switches between fullscreen and windowed.
static func toggle() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Whether the window is currently fullscreen.
static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Handles the fullscreen key. Returns whether the event was consumed.
static func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F11:
		toggle()
		return true
	return false
