# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name PlayerController
extends CharacterBody3D

## A first-person controller for walking an AvP2 level.
##
## This is the Marine's movement: upright, gravity-bound, with the world's own
## down. The Alien needs surface-relative gravity instead, so nothing here may
## assume that down is always negative Y beyond the [member gravity_direction]
## this exposes.
##
## Values are provisional. Original movement has not been measured yet, and the
## design document is explicit that it should be tuned against reference
## behaviour rather than left at engine defaults.

## Character height in metres.
##
## Derived from the game's own data: the eye sits at CameraHeightPercent of the
## character's height, and the first Marine mission places the player start at
## 1.6 metres, which gives a character of very nearly this height.
const BODY_HEIGHT := 1.95

## Capsule radius in metres.
const BODY_RADIUS := 0.4

## Speeds in metres per second. Replaced by the values in the installation's
## attribute data when it is available, which is the design document's
## instruction to tune against reference behaviour rather than engine defaults.
@export var walk_speed := 1.56
## Speed when the run key is held. In AvP2 running is the faster gait rather
## than a brief sprint.
@export var run_speed := 3.75
## Speed while crouched.
@export var crouch_speed := 1.13
## Upward speed applied on jumping.
@export var jump_speed := 6.88
## Eye height as a fraction of the character's height.
@export var camera_height_percent := 0.82
## Acceleration towards the target velocity on the ground.
@export var ground_acceleration := 60.0
## Acceleration while airborne, which is deliberately lower.
@export var air_acceleration := 8.0
## Downward acceleration.
@export var gravity := 22.0
## Direction gravity pulls. Exposed so that surface-relative movement can
## replace it without changing the rest of the controller.
@export var gravity_direction := Vector3.DOWN
## Mouse look sensitivity, radians per pixel.
@export var look_sensitivity := 0.0025

var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.height = BODY_HEIGHT
	shape.radius = BODY_RADIUS

	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, BODY_HEIGHT * 0.5, 0)
	add_child(collider)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, BODY_HEIGHT * camera_height_percent, 0)
	_camera.far = 8000.0
	_camera.current = true
	add_child(_camera)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## The camera, so a host can read where the player is looking.
func camera() -> Camera3D:
	return _camera


## Applies movement read from the installation's attribute data.
func apply_attributes(attributes: MovementAttributes) -> void:
	if not attributes.loaded():
		return
	walk_speed = attributes.walk_speed
	run_speed = attributes.run_speed
	crouch_speed = attributes.crouch_speed
	jump_speed = attributes.jump_speed
	camera_height_percent = attributes.camera_height_percent
	if _camera != null:
		_camera.position = Vector3(0, BODY_HEIGHT * camera_height_percent, 0)


func _unhandled_input(event: InputEvent) -> void:
	if DisplayToggle.handle(event):
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.5, 1.5)
		rotation.y = _yaw
		_camera.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	var wish := _wish_direction()
	var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	if Input.is_key_pressed(KEY_CTRL):
		speed = crouch_speed

	# Horizontal and vertical motion are handled separately so that gravity is
	# not smoothed by the same acceleration as steering.
	var up := -gravity_direction
	var vertical := velocity.project(up)
	var horizontal := velocity - vertical

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	horizontal = horizontal.move_toward(wish * speed, acceleration * delta)

	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			vertical = up * jump_speed
		else:
			# A small downward bias keeps the controller attached to slopes
			# rather than skipping off them.
			vertical = gravity_direction * 0.1
	else:
		vertical += gravity_direction * gravity * delta

	velocity = horizontal + vertical
	up_direction = up
	move_and_slide()


func _wish_direction() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	if input == Vector2.ZERO:
		return Vector3.ZERO

	input = input.normalized()
	var basis_ := global_transform.basis
	return (basis_.x * input.x + basis_.z * input.y).normalized()
