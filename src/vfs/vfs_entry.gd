# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name VfsEntry
extends RefCounted

## Diagnostic metadata about a resolved resource.
##
## Exposed so that override problems can be diagnosed from a log or a support
## bundle rather than by guesswork, which is what makes mod load order
## debuggable.

## Canonical resource path.
var path: String
## Name of the mount that provided it.
var source: String
## Precedence of that mount.
var priority: MountPriority.Level
## Size in bytes.
var size: int
## Mounts that also provide this path but lost resolution, highest first.
var shadowed_by: PackedStringArray


func _init(resource_path: String, mount_source: String, mount_priority: MountPriority.Level,
		resource_size: int, shadowed: PackedStringArray = PackedStringArray()) -> void:
	path = resource_path
	source = mount_source
	priority = mount_priority
	size = resource_size
	shadowed_by = shadowed


## Whether another mount also provides this path.
func is_override() -> bool:
	return not shadowed_by.is_empty()


func _to_string() -> String:
	if is_override():
		return "%s from %s (overriding %s)" % [path, source, ", ".join(shadowed_by)]
	return "%s from %s" % [path, source]
