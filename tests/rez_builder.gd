# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name RezBuilder
extends RefCounted

## Builds synthetic REZ archives for tests.
##
## Tests must never depend on copyrighted game data, so the reader is exercised
## against archives constructed here to the layout documented in
## docs/formats/rez.md. Building archives independently of the reader also means
## a misunderstanding of the format cannot cancel itself out between the two.

const DATA_START := RezArchive.HEADER_OFFSET + 12

var _files: Array = []


## Adds a file at a slash-separated path, for example "music/theme.wav".
func with_file(path: String, data: PackedByteArray) -> RezBuilder:
	_files.append({"path": path, "data": data})
	return self


## Adds a file whose contents are the given text.
func with_text_file(path: String, text: String) -> RezBuilder:
	return with_file(path, text.to_utf8_buffer())


## Serialises the archive.
func build(version: int = RezArchive.SUPPORTED_VERSION) -> PackedByteArray:
	var blob := PackedByteArray()
	var placed := {}
	for f in _files:
		placed[f["path"]] = {"pos": DATA_START + blob.size(), "size": f["data"].size()}
		blob.append_array(f["data"])

	# Directory blocks are emitted post-order into one region, so every child
	# block is written before the parent that points at it, and the root block
	# ends the file. That is what makes dirPos + dirSize == fileSize hold.
	var region := PackedByteArray()
	var region_start := DATA_START + blob.size()
	var root := _emit(_tree(), placed, region, region_start)

	var out := PackedByteArray()
	out.append_array(_banner())
	out.append_array(_u32(version))
	out.append_array(_u32(root["pos"]))
	out.append_array(_u32(root["size"]))
	out.append_array(blob)
	out.append_array(region)
	return out


## Writes an archive to a path and returns that path.
func write(path: String, version: int = RezArchive.SUPPORTED_VERSION) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(build(version))
	file.close()
	return path


func _banner() -> PackedByteArray:
	var out := "\r\nRezMgr Version 1 Copyright (C) 1995 MONOLITH INC.".to_ascii_buffer()
	while out.size() < 0x7C:
		out.append(0x20)
	out.append_array(PackedByteArray([0x0D, 0x0A, 0x1A]))
	return out


func _tree() -> Dictionary:
	var root := {"dirs": {}, "files": []}
	for f in _files:
		var parts: PackedStringArray = f["path"].split("/")
		var node := root
		for i in parts.size() - 1:
			if not node["dirs"].has(parts[i]):
				node["dirs"][parts[i]] = {"dirs": {}, "files": []}
			node = node["dirs"][parts[i]]
		node["files"].append(f["path"])
	return root


## Appends this node's block to [param region] after its children, returning the
## block's absolute position and size.
func _emit(node: Dictionary, placed: Dictionary, region: PackedByteArray,
		region_start: int) -> Dictionary:
	var children := {}
	for name in node["dirs"]:
		children[name] = _emit(node["dirs"][name], placed, region, region_start)

	var block := PackedByteArray()

	for path in node["files"]:
		var info: Dictionary = placed[path]
		var leaf: String = path.get_file()
		block.append_array(_u32(0))
		block.append_array(_u32(info["pos"]))
		block.append_array(_u32(info["size"]))
		block.append_array(_u32(0))
		block.append_array(_u32(0))
		block.append_array(_reversed_type(leaf.get_extension()))
		block.append_array(_u32(0))
		block.append_array(leaf.get_basename().to_ascii_buffer())
		block.append(0)
		block.append(0)

	for name in children:
		var child: Dictionary = children[name]
		block.append_array(_u32(1))
		block.append_array(_u32(child["pos"]))
		block.append_array(_u32(child["size"]))
		block.append_array(_u32(0))
		block.append_array(name.to_ascii_buffer())
		block.append(0)

	var pos := region_start + region.size()
	region.append_array(block)
	return {"pos": pos, "size": block.size()}


## The extension as four bytes in reverse order, as the format stores it.
func _reversed_type(extension: String) -> PackedByteArray:
	var code := extension.to_upper().to_ascii_buffer()
	while code.size() < 4:
		code.append(0)
	code = code.slice(0, 4)
	code.reverse()
	return code


func _u32(value: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, value)
	return b
