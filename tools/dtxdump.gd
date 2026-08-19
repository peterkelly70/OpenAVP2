# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends SceneTree

## dtxdump -- inspect DTX textures and export them as PNG.
##
##   godot --headless --script tools/dtxdump.gd -- <archive.rez> [options]
##
##     --png <dir>     Export decoded textures as PNG.
##     --filter <text> Only textures whose path contains this.
##     --limit <n>     Stop after n textures.
##
## Without --png it prints a summary of every texture: dimensions, format,
## mip levels and command string.

const FORMAT_NAMES := {
	0: "32-bit", 1: "8-bit", 2: "16-bit", 3: "32-bit", 4: "DXT1", 5: "DXT3", 6: "DXT5",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: dtxdump <archive.rez> [--png <dir>] [--filter <text>] [--limit <n>]")
		quit(2)
		return

	var png_dir := ""
	var filter := ""
	var limit := 0

	var i := 1
	while i < args.size():
		match args[i]:
			"--png":
				i += 1
				png_dir = args[i]
			"--filter":
				i += 1
				filter = args[i].to_lower()
			"--limit":
				i += 1
				limit = int(args[i])
			_:
				printerr("unrecognised option: %s" % args[i])
				quit(2)
				return
		i += 1

	var archive := RezArchive.new()
	if not archive.load(args[0]):
		printerr("[REZ] %s: %s" % [args[0], archive.error()])
		quit(1)
		return

	var seen := 0
	var failed := 0
	var formats := {}

	for entry in archive.entries():
		if entry.extension != "dtx":
			continue
		if not filter.is_empty() and not entry.path.contains(filter):
			continue
		if limit > 0 and seen >= limit:
			break

		var data := archive.read_entry(entry)
		var texture := DtxTexture.new()
		if not texture.parse(data):
			printerr("  %s: %s" % [entry.path, texture.error()])
			failed += 1
			continue

		var name: String = FORMAT_NAMES.get(texture.format, "format %d" % texture.format)
		formats[name] = formats.get(name, 0) + 1
		seen += 1

		if png_dir.is_empty():
			print("  %-52s %4dx%-4d %-7s mips=%d %s" % [
				entry.path, texture.width, texture.height, name, texture.mipmaps,
				texture.command_string])
			continue

		var image := texture.to_image(data)
		if image == null:
			printerr("  %s: %s" % [entry.path, texture.error()])
			failed += 1
			continue

		# Compressed images must be decompressed before they can be saved.
		if texture.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)

		var dest: String = png_dir.path_join(entry.path.get_basename() + ".png")
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		image.save_png(dest)

	print("\n%d textures, %d failed" % [seen, failed])
	print("formats: %s" % formats)
	quit(0 if failed == 0 else 1)
