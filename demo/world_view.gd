# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node3D

## Loads an AvP2 level and lets you fly through it.
##
##   godot demo/world_view.tscn -- <install-dir> <world-path>
##
## for example
##
##   godot demo/world_view.tscn -- /path/to/avp2 worlds/singleplayer/m1s1.dat
##
## Mount precedence follows the design document, so a patched world is loaded in
## preference to the base one.

const PATCH_ARCHIVES: Array[String] = ["avp2p.rez", "avp2p1.rez", "avp2p5.rez", "lithserver.rez"]
const EXPANSION_ARCHIVES: Array[String] = ["avp2x.rez"]

## Movement speed in metres per second.
@export var speed := 40.0
## Multiplier while the sprint key is held.
@export var sprint := 4.0
## Screenshot to write once the level is built, then quit. Empty to stay open.
@export var screenshot := ""

var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _captured := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: world_view.tscn -- <install-dir> <world-path> [screenshot.png]")
		get_tree().quit(2)
		return
	if args.size() > 2:
		screenshot = args[2]

	var vfs := _mount(args[0])
	var world := _load_world(vfs, args[1])
	if world == null:
		get_tree().quit(1)
		return

	var builder := WorldBuilder.new(vfs)
	var geometry := builder.build(world)
	add_child(geometry)

	var missing := builder.missing_textures()
	print("[WORLD] %d models, %d textures unresolved" % [
		world.world_models.size(), missing.size()])

	_add_lighting()
	_add_camera(world)

	if not screenshot.is_empty():
		# Two frames: one to build the scene, one with everything drawn.
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(screenshot)
		print("[WORLD] wrote %s" % screenshot)
		get_tree().quit(0)


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


func _load_world(vfs: Vfs, path: String) -> DatWorld:
	var data := vfs.read(path)
	if data.is_empty():
		printerr("[WORLD] %s not found in any archive" % path)
		return null

	var world := DatWorld.new()
	if not world.parse(data):
		printerr("[WORLD] %s: %s" % [path, world.error()])
		return null
	return world


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.36, 0.42)
	environment.ambient_light_energy = 1.0

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


## Places the camera inside the level's bounds looking towards its centre.
func _add_camera(world: DatWorld) -> void:
	_camera = Camera3D.new()
	_camera.far = 8000.0
	_camera.current = true

	var centre := Vector3.ZERO
	var count := 0
	for model in world.world_models:
		if model.name == "MainTerrain" or model.name == "PhysicsBSP":
			centre += (model.bounds_min + model.bounds_max) * 0.5
			count += 1
	if count > 0:
		centre /= count
	centre = WorldBuilder._convert(centre)

	# The camera must be in the tree before look_at can resolve a global basis.
	add_child(_camera)
	_camera.position = centre + Vector3(0, 12, 45)
	_camera.look_at(centre, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if DisplayToggle.handle(event):
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.5, 1.5)
		_camera.rotation = Vector3(_pitch, _yaw, 0)
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	if _camera == null:
		return

	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): direction += _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): direction -= _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): direction += _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q): direction -= Vector3.UP

	if direction != Vector3.ZERO:
		var rate := speed * (sprint if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		_camera.position += direction.normalized() * rate * delta
