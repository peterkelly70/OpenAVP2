# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name MountPriority
extends RefCounted

## Virtual filesystem mount precedence, lowest to highest priority.
##
## A resource is resolved from the highest-priority mount that provides it. The
## values are deliberately ordered and stable: mod tooling and diagnostics report
## precedence by this ordering, so they must not be reassigned once content
## depends on them.

enum Level {
	## Archives shipped with the retail game.
	BASE_GAME = 0,
	## Official patch archives, which override base content.
	OFFICIAL_PATCH = 1,
	## Expansion archives, mounted only when the expansion is enabled.
	EXPANSION = 2,
	## Content supplied by OpenAvP2 itself for compatibility purposes.
	COMPATIBILITY_CONTENT = 3,
	## Installed mods, ordered among themselves by declared load order.
	MOD = 4,
	## Loose files supplied by the user. Always wins.
	USER_OVERRIDE = 5,
}


## A human-readable name for a precedence level, for diagnostics.
static func level_name(level: Level) -> String:
	match level:
		Level.BASE_GAME: return "base game"
		Level.OFFICIAL_PATCH: return "official patch"
		Level.EXPANSION: return "expansion"
		Level.COMPATIBILITY_CONTENT: return "compatibility content"
		Level.MOD: return "mod"
		Level.USER_OVERRIDE: return "user override"
	return "unknown"
