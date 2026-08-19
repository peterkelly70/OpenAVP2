# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name DatObject
extends RefCounted

## One object record from a DAT world.
##
## Objects are the point at which a world stops being geometry and becomes a
## level: doors, triggers, lights, player starts and AI volumes are all object
## records carrying a class name and a property list.

## Class name, for example "Door" or "GameStartPoint".
var class_name_ := ""

## Properties by name. Values are already converted to Godot types.
var properties := {}


func _init(cls: String = "", props: Dictionary = {}) -> void:
	class_name_ = cls
	properties = props


## A property value, or [param fallback] when absent.
func get_property(name: String, fallback: Variant = null) -> Variant:
	return properties.get(name, fallback)


## The object's position, or the zero vector when it has none.
func position() -> Vector3:
	var value = properties.get("Pos")
	return value if value is Vector3 else Vector3.ZERO


## The object's name within the level, which scripts and triggers refer to.
func object_name() -> String:
	var value = properties.get("Name")
	return value if value is String else ""


func _to_string() -> String:
	return "%s '%s' at %s" % [class_name_, object_name(), position()]
