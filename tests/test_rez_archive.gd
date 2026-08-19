# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Exercised against synthetic archives built by RezBuilder, never against game
## data. The builder writes the format independently of the reader, so a
## misunderstanding cannot cancel itself out between the two.

const TMP := "user://test_archive.rez"


func after_each() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _archive(builder: RezBuilder) -> RezArchive:
	builder.write(TMP)
	return RezArchive.open(TMP)


func test_reads_a_single_file_from_the_root() -> void:
	var archive := _archive(RezBuilder.new().with_text_file("readme.txt", "hello"))

	assert_not_null(archive)
	assert_eq(archive.entries().size(), 1)
	assert_eq(archive.entries()[0].path, "readme.txt")
	assert_eq(archive.read("readme.txt").get_string_from_utf8(), "hello")


func test_assembles_paths_from_the_directory_chain() -> void:
	# The archive stores name and extension separately and nests directories, so
	# the full logical path has to be reassembled by the reader.
	var archive := _archive(RezBuilder.new()
		.with_text_file("Music/WaveTracks/Theme.wav", "riff"))

	assert_eq(archive.entries()[0].path, "music/wavetracks/theme.wav")
	assert_eq(archive.entries()[0].extension, "wav")


func test_lookup_is_case_and_separator_insensitive() -> void:
	var archive := _archive(RezBuilder.new().with_text_file("Music/Theme.wav", "riff"))

	assert_true(archive.has("MUSIC\\THEME.WAV"))
	assert_eq(archive.read("Music/Theme.wav").get_string_from_utf8(), "riff")


func test_reads_several_files_with_correct_contents() -> void:
	# Guards against off-by-one errors in entry positions, which would otherwise
	# surface as subtly corrupt resources rather than as a failure.
	var archive := _archive(RezBuilder.new()
		.with_text_file("a.txt", "first")
		.with_text_file("dir/b.txt", "second")
		.with_text_file("dir/deep/c.txt", "third"))

	assert_eq(archive.entries().size(), 3)
	assert_eq(archive.read("a.txt").get_string_from_utf8(), "first")
	assert_eq(archive.read("dir/b.txt").get_string_from_utf8(), "second")
	assert_eq(archive.read("dir/deep/c.txt").get_string_from_utf8(), "third")


func test_preserves_binary_contents_exactly() -> void:
	var payload := PackedByteArray([0x00, 0xFF, 0x7F, 0x80, 0x0D, 0x0A, 0x1A, 0x00])
	var archive := _archive(RezBuilder.new().with_file("sound/blip.wav", payload))

	assert_eq(archive.read("sound/blip.wav"), payload)


func test_returns_empty_for_an_unknown_path() -> void:
	var archive := _archive(RezBuilder.new().with_text_file("a.txt", "x"))

	assert_false(archive.has("missing.txt"))
	assert_eq(archive.read("missing.txt").size(), 0)


func test_rejects_a_file_without_the_banner() -> void:
	var file := FileAccess.open(TMP, FileAccess.WRITE)
	file.store_buffer("not an archive at all, but long enough to pass the length check....".to_utf8_buffer())
	var padding := PackedByteArray()
	padding.resize(200)
	file.store_buffer(padding)
	file.close()

	var archive := RezArchive.new()
	assert_false(archive.load(TMP))
	assert_string_contains(archive.error(), "banner")


func test_rejects_an_unsupported_version() -> void:
	RezBuilder.new().with_text_file("a.txt", "x").write(TMP, 2)

	var archive := RezArchive.new()
	assert_false(archive.load(TMP))
	assert_string_contains(archive.error(), "version")


func test_rejects_a_truncated_archive() -> void:
	# The directory sits at the end of the file, so truncation breaks the
	# dirPos + dirSize == fileSize invariant. Failing here beats surfacing
	# corrupt resources later.
	var data := RezBuilder.new().with_text_file("a.txt", "x").build()
	var file := FileAccess.open(TMP, FileAccess.WRITE)
	file.store_buffer(data.slice(0, data.size() - 4))
	file.close()

	var archive := RezArchive.new()
	assert_false(archive.load(TMP))
	assert_string_contains(archive.error(), "does not reach the end")


func test_rejects_a_file_that_is_too_short() -> void:
	var file := FileAccess.open(TMP, FileAccess.WRITE)
	file.store_buffer("\r\nRezMgr".to_ascii_buffer())
	file.close()

	var archive := RezArchive.new()
	assert_false(archive.load(TMP))
	assert_string_contains(archive.error(), "too short")
