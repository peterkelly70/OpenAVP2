# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name VfsPath
extends RefCounted

## Canonicalisation of LithTech resource paths.
##
## Original AvP2 data was authored on a case-insensitive filesystem using
## backslash separators, and the same resource is referenced with inconsistent
## case and separators throughout the game data. Every path is canonicalised
## once at the VFS boundary so that the rest of the runtime compares plain
## strings and behaves identically on case-sensitive filesystems.


## Converts a path as written in game data into its canonical form: lowercase,
## forward-slash separated, with no leading, trailing, empty or relative
## segments.
##
## Returns an empty string when the path has no segments. A path that escapes
## the root through ".." returns an empty string, which callers must treat as
## invalid rather than as the root.
static func canonicalize(path: String) -> String:
	var segments: Array[String] = []

	for raw in path.replace("\\", "/").split("/", false):
		if raw == "" or raw == ".":
			continue
		if raw == "..":
			if segments.is_empty():
				# Escaping the virtual root is never valid.
				return ""
			segments.remove_at(segments.size() - 1)
			continue
		segments.append(raw.to_lower())

	return "/".join(segments)


## Whether two paths as written in game data refer to the same resource.
static func are_equivalent(a: String, b: String) -> bool:
	return canonicalize(a) == canonicalize(b)


## The extension of a path, lowercased and without the leading dot, or an empty
## string when there is none.
static func extension(path: String) -> String:
	var normalized := path.replace("\\", "/")
	var last_separator := normalized.rfind("/")
	var last_dot := normalized.rfind(".")

	if last_dot <= last_separator or last_dot == normalized.length() - 1:
		return ""

	return normalized.substr(last_dot + 1).to_lower()
