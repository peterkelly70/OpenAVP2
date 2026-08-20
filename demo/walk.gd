# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends Node3D

## Walk an AvP2 level on foot.
##
##   godot demo/walk.tscn -- <install-dir> <world-path> [screenshot.png]
##
## The level's own GameStartPoint is used, so the player spawns where the game
## would put them, and collision comes from the level's authored PhysicsBSP hull
## rather than from the visible geometry.
##
## WASD to move, mouse to look, Space to jump, Shift to sprint, Escape to
## release the mouse.

const PATCH_ARCHIVES: Array[String] = ["avp2p.rez", "avp2p1.rez", "avp2p5.rez", "lithserver.rez"]
const EXPANSION_ARCHIVES: Array[String] = ["avp2x.rez"]

## Height above the start point to spawn at, so the player settles onto the
## floor rather than starting inside it.
const SPAWN_CLEARANCE := 0.5

var _player: PlayerController
var _vfs: Vfs


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: walk.tscn -- <install-dir> <world-path> [screenshot.png]")
		get_tree().quit(2)
		return

	_vfs = _mount(args[0])
	var vfs := _vfs
	var data := vfs.read(args[1])
	if data.is_empty():
		printerr("[WALK] %s not found in any archive" % args[1])
		get_tree().quit(1)
		return

	var world := DatWorld.new()
	if not world.parse(data):
		printerr("[WALK] %s: %s" % [args[1], world.error()])
		get_tree().quit(1)
		return

	var builder := WorldBuilder.new(vfs)
	add_child(builder.build(world))

	var collision := builder.build_collision(world)
	if collision != null:
		add_child(collision)
	print("[WALK] %d models, collision %d triangles" % [
		world.world_models.size(), builder.collision_triangle_count(world)])

	_add_lighting()
	_spawn(world)

	if args.size() > 2:
		await get_tree().create_timer(1.5).timeout   # let the player settle
		# A third-person view for the screenshot, so that the player can be seen
		# standing in the level rather than only what they are looking at.
		if args.size() > 3 and args[3] == "--third-person":
			_third_person()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[2])
		print("[WALK] wrote %s, player at %s, on floor: %s" % [
			args[2], _player.global_position, _player.is_on_floor()])
		get_tree().quit(0)


## Places an observing camera behind and above the player, with a marker at
## their feet, to check that they are standing where they should be.
func _third_person() -> void:
	var marker := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = PlayerController.BODY_HEIGHT
	capsule.radius = PlayerController.BODY_RADIUS
	marker.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.1)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.2, 0.05)
	marker.material_override = material
	marker.position = _player.global_position + Vector3(0, PlayerController.BODY_HEIGHT * 0.5, 0)
	add_child(marker)

	var observer := Camera3D.new()
	observer.far = 8000.0
	add_child(observer)
	observer.global_position = _player.global_position + Vector3(4, 3, 6)
	observer.look_at(_player.global_position + Vector3(0, 1, 0), Vector3.UP)
	observer.current = true


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


## Spawns at the level's own start point, falling back to the world centre.
func _spawn(world: DatWorld) -> void:
	_player = PlayerController.new()

	var starts := world.objects_of_class("GameStartPoint")
	var position := Vector3.ZERO
	if starts.is_empty():
		push_warning("[WALK] no GameStartPoint; spawning at the world centre")
		position = WorldBuilder._convert((world.bounds_min + world.bounds_max) * 0.5)
	else:
		position = WorldBuilder._convert(starts[0].position())
		print("[WALK] spawning at %s" % starts[0])

	_player.position = position + Vector3(0, SPAWN_CLEARANCE, 0)
	add_child(_player)

	# Movement comes from the game's own data rather than from engine defaults.
	var attributes := MovementAttributes.new()
	if attributes.load_from(_vfs):
		_player.apply_attributes(attributes)
		print("[WALK] movement from attributes: %s" % attributes)
	else:
		print("[WALK] using built-in movement defaults")


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.41, 0.47)
	environment.ambient_light_energy = 1.0

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
