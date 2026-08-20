# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name ModelDisplay
extends SubViewportContainer

## Shows a LithTech model in the menus.
##
## The original front end presents its species with the game's own models rather
## than with pictures, which is why the head turns. Rendering into a viewport
## keeps that three-dimensional while leaving the rest of the interface as
## ordinary controls.

## Degrees per second the model turns.
@export var spin_speed := 18.0

## Framing: distance as a multiple of the model's size.
const DISTANCE := 0.62
## Height to look at, as a fraction of the model's height.
const LOOK_HEIGHT := 0.55

var _vfs: Vfs
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _current := ""


func _init(vfs: Vfs) -> void:
	_vfs = vfs
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.44, 0.5)
	environment.ambient_light_energy = 1.0

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	# Two lights: a key from the front left and a cold rim from behind, which is
	# what gives the models shape against a dark background.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 35, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.75, 1.0)
	_viewport.add_child(rim)

	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)


## Shows a model, with a skin of the same name when one exists.
##
## Passing the same path twice is ignored, so a menu can call this on every
## highlight without rebuilding the model each time.
func show_model(path: String) -> void:
	if path == _current:
		return
	_current = path

	for child in _pivot.get_children():
		child.queue_free()

	if path.is_empty() or _vfs == null:
		return

	var data := _vfs.read(path)
	if data.is_empty():
		push_warning("[UI] model not found: %s" % path)
		return

	var model := AbcModel.new()
	if not model.parse(data):
		push_warning("[UI] %s: %s" % [path, model.error()])
		return

	var skins := PackedStringArray()
	var skin := _skin_for(path)
	if not skin.is_empty():
		# A menu model uses one skin across every material.
		for i in 64:
			skins.append(skin)

	var instance := ModelBuilder.new(_vfs).build(model, skins)
	if instance == null:
		return

	_pivot.add_child(instance)
	_frame(instance)


## Menu models keep their skin beside them under the same name.
func _skin_for(model_path: String) -> String:
	var candidate := model_path.get_base_dir().get_base_dir() \
		.path_join("skins").path_join(model_path.get_file().get_basename() + ".dtx")
	return candidate if _vfs.has(candidate) else ""


## Positions the camera so the model fills the frame regardless of its size.
func _frame(instance: MeshInstance3D) -> void:
	var bounds := instance.get_aabb()
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length(), 0.05)

	# Centre the model on the pivot so it turns about itself rather than orbiting.
	instance.position = -centre

	_camera.position = Vector3(0, bounds.size.y * (LOOK_HEIGHT - 0.5), radius * DISTANCE)
	_camera.look_at(Vector3(0, bounds.size.y * (LOOK_HEIGHT - 0.5), 0), Vector3.UP)
	_camera.near = 0.01
	_camera.far = radius * 8.0


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(deg_to_rad(spin_speed) * delta)
