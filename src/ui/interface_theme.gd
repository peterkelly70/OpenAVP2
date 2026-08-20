# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name InterfaceTheme
extends RefCounted

## Builds OpenAvP2's interface theme.
##
## Without this the menus look like a Godot demo: rounded grey boxes and a
## default font. The look here is angular and dark with a single accent, which
## is the idiom the game belongs to, built from styles rather than images so it
## scales with the display.
##
## Fonts are shipped rather than looked up on the host, so the interface looks
## the same everywhere instead of depending on what happens to be installed.
## All are Open Font Licence, which permits redistribution; see THIRD_PARTY.md.

## Headings and buttons. A squared technical face rather than a bookish one.
const DISPLAY_FONT := "res://assets/fonts/ChakraPetch-Bold.ttf"

## Body text and lists.
const BODY_FONT := "res://assets/fonts/Rajdhani-Medium.ttf"
const BODY_BOLD_FONT := "res://assets/fonts/Rajdhani-Bold.ttf"

## Readouts and counters, where digits must not shift as they change.
const MONO_FONT := "res://assets/fonts/ShareTechMono-Regular.ttf"


## Builds the theme.
static func build(base_size: int = 20) -> Theme:
	var theme := Theme.new()

	theme.default_font = body()
	theme.default_font_size = base_size

	_style_buttons(theme, display(), base_size)
	_style_lists(theme, body(), base_size)
	_style_labels(theme, base_size)
	_style_panels(theme)
	return theme


## The display face, for headings and buttons.
static func display() -> Font:
	return _font(DISPLAY_FONT)


## The body face.
static func body() -> Font:
	return _font(BODY_FONT)


## The bold body face.
static func body_bold() -> Font:
	return _font(BODY_BOLD_FONT)


## A monospaced face for readouts such as ammunition counters.
static func monospace() -> Font:
	return _font(MONO_FONT)


## Loads a shipped font, falling back to the engine's own if it is absent so
## that a stripped build still renders text.
static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var font := load(path)
		if font is Font:
			return font
	push_warning("[UI] %s is missing; falling back to the default font" % path)
	return ThemeDB.fallback_font


## An angular panel. Corners are square and one edge carries the accent, which
## is what makes it read as machined rather than as a rounded card.
static func _box(fill: Color, border: Color, border_width: int = 1,
		accent_edge: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if accent_edge:
		box.border_width_left = 4
		box.border_color = GeneratedArt.ACCENT
	return box


static func _style_buttons(theme: Theme, font: Font, base_size: int) -> void:
	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", base_size + 2)

	theme.set_stylebox("normal", "Button",
		_box(GeneratedArt.PANEL, GeneratedArt.ACCENT_DIM))
	theme.set_stylebox("hover", "Button",
		_box(GeneratedArt.PANEL_LIGHT, GeneratedArt.ACCENT, 1, true))
	theme.set_stylebox("pressed", "Button",
		_box(GeneratedArt.ACCENT_DIM, GeneratedArt.ACCENT, 1, true))
	theme.set_stylebox("focus", "Button",
		_box(Color(0, 0, 0, 0), GeneratedArt.ACCENT))
	theme.set_stylebox("disabled", "Button",
		_box(GeneratedArt.PANEL, GeneratedArt.PANEL_LIGHT))

	theme.set_color("font_color", "Button", GeneratedArt.TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", GeneratedArt.TEXT_DIM)


static func _style_lists(theme: Theme, font: Font, base_size: int) -> void:
	theme.set_font("font", "ItemList", font)
	theme.set_font_size("font_size", "ItemList", base_size)

	theme.set_stylebox("panel", "ItemList",
		_box(Color(0.05, 0.058, 0.06, 0.92), GeneratedArt.ACCENT_DIM))
	theme.set_stylebox("focus", "ItemList",
		_box(Color(0, 0, 0, 0), GeneratedArt.ACCENT))

	var selected := StyleBoxFlat.new()
	selected.bg_color = GeneratedArt.ACCENT_DIM
	selected.set_corner_radius_all(0)
	selected.border_width_left = 4
	selected.border_color = GeneratedArt.ACCENT
	theme.set_stylebox("selected", "ItemList", selected)
	theme.set_stylebox("selected_focus", "ItemList", selected)
	theme.set_stylebox("hovered", "ItemList",
		_box(Color(0.1, 0.12, 0.12, 0.6), Color(0, 0, 0, 0), 0))

	theme.set_color("font_color", "ItemList", GeneratedArt.TEXT)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_constant("h_separation", "ItemList", 12)


static func _style_labels(theme: Theme, base_size: int) -> void:
	theme.set_color("font_color", "Label", GeneratedArt.TEXT)
	theme.set_font_size("font_size", "Label", base_size)


static func _style_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer",
		_box(Color(0.05, 0.058, 0.06, 0.85), GeneratedArt.ACCENT_DIM))
