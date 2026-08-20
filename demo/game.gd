# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node

## OpenAvP2's front end: pick a mission, then play it.
##
##   godot demo/game.tscn -- <install-dir> [screenshot.png]
##
## Menus use the installation's own artwork, optionally upscaled, and the
## mission list is built from the archives present rather than hardcoded, so it
## shows what the user actually owns.

const PATCH_ARCHIVES: Array[String] = ["avp2p.rez", "avp2p1.rez", "avp2p5.rez", "lithserver.rez"]
const EXPANSION_ARCHIVES: Array[String] = ["avp2x.rez"]

var _vfs: Vfs
var _install := ""
var _menu: MainMenu
var _settings: Settings
var _pause: PauseMenu
var _level: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: game.tscn -- <install-dir> [screenshot.png]")
		get_tree().quit(2)
		return

	_install = args[0]
	_vfs = _mount(_install)

	_settings = Settings.new()
	_settings.load_settings()
	_settings.installation = _install

	_build_menu()

	if args.size() > 1:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[1])
		print("[UI] wrote %s" % args[1])
		get_tree().quit(0)


## Builds the front end. Also used when returning from a mission.
func _build_menu() -> void:
	var images := InterfaceImages.new(_vfs)
	images.scale = _settings.art_upscale
	images.upscale = InterfaceImages.Upscale.LANCZOS

	_menu = MainMenu.new(_settings, _install, images)
	_menu.level_chosen.connect(_on_level_chosen)
	_menu.extract_requested.connect(_on_extract)
	_menu.quit_chosen.connect(func() -> void: get_tree().quit(0))
	add_child(_menu)

	if images.missing().size() > 0:
		print("[UI] %d interface images unavailable" % images.missing().size())


func _mount(install: String) -> Vfs:
	var vfs := Vfs.new()
	var names := DirAccess.get_files_at(install)
	names.sort()
	for name in names:
		if not name.to_lower().ends_with(".rez"):
			continue
		var lower := name.to_lower()
		var priority := MountPriority.Level.BASE_GAME
		if lower in PATCH_ARCHIVES:
			priority = MountPriority.Level.OFFICIAL_PATCH
		elif lower in EXPANSION_ARCHIVES:
			priority = MountPriority.Level.EXPANSION
		vfs.mount_archive(install.path_join(name), priority)
	return vfs


## Loads the chosen mission and hands control to the player.
##
## Campaign worlds live in the per-species archives, which the menu already
## resolved, so the archive is mounted at expansion priority for the session
## rather than relying on it being mounted at start-up.
func _on_level_chosen(archive: String, world: String) -> void:
	_menu.queue_free()
	_menu = null

	var data := _vfs.read(world)
	if data.is_empty():
		var direct := RezArchive.new()
		if direct.load(archive):
			data = direct.read(world)
	if data.is_empty():
		printerr("[GAME] %s could not be read" % world)
		return

	var parsed := DatWorld.new()
	if not parsed.parse(data):
		printerr("[GAME] %s: %s" % [world, parsed.error()])
		return

	print("[GAME] %s: %d models, %d objects" % [
		world, parsed.world_models.size(), parsed.objects.size()])

	_level = Node3D.new()
	add_child(_level)

	var builder := WorldBuilder.new(_vfs)
	_level.add_child(builder.build(parsed))
	var collision := builder.build_collision(parsed)
	if collision != null:
		_level.add_child(collision)

	_add_lighting()
	_spawn(parsed)


func _spawn(world: DatWorld) -> void:
	var player := PlayerController.new()
	var starts := world.objects_of_class("GameStartPoint")
	var position := WorldBuilder._convert((world.bounds_min + world.bounds_max) * 0.5)
	if not starts.is_empty():
		position = WorldBuilder._convert(starts[0].position())

	player.position = position + Vector3(0, 0.5, 0)
	_level.add_child(player)

	var attributes := MovementAttributes.new()
	if attributes.load_from(_vfs):
		player.apply_attributes(attributes)


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	_level.add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.41, 0.47)

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_level.add_child(world_environment)


## Extracts the installation's content to an OpenAvP2-owned directory.
##
## Extraction is offered rather than required: the runtime reads archives
## directly, and this exists for inspecting or converting content. Output never
## goes into the project.
func _on_extract() -> void:
	var destination := ProjectSettings.globalize_path(_settings.extract_directory)
	DirAccess.make_dir_recursive_absolute(destination)

	var written := 0
	var bytes := 0
	for path in _vfs.paths(""):
		var data := _vfs.read(path)
		if data.is_empty():
			continue
		var target := destination.path_join(path)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(data)
		file.close()
		written += 1
		bytes += data.size()

	print("[EXTRACT] %d files, %.1f MB -> %s" % [written, bytes / 1048576.0, destination])


## Escape pauses while a level is running, and dismisses the pause menu again.
##
## The pause menu handles its own Escape, so this only opens it.
func _unhandled_input(event: InputEvent) -> void:
	if DisplayToggle.handle(event):
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _level == null or _pause != null:
		return

	_open_pause()
	get_viewport().set_input_as_handled()


func _open_pause() -> void:
	_pause = PauseMenu.new()
	_pause.resumed.connect(_close_pause)
	_pause.quit_to_menu.connect(_on_quit_to_menu)
	add_child(_pause)

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_pause() -> void:
	if _pause == null:
		return
	_pause.queue_free()
	_pause = null

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Abandons the mission and rebuilds the front end.
func _on_quit_to_menu() -> void:
	_close_pause()

	if _level != null:
		_level.queue_free()
		_level = null

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_menu()
