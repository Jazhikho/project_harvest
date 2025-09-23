# res://scripts/entities/Player.gd
extends CharacterBody3D
class_name Player

signal move_state(speed: float, grounded: bool, sprinting: bool)

@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.5
@export var acceleration: float = 10.0
@export var gravity: float = 9.8

@export var camera_path: NodePath = NodePath("Camera3D")

@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _sight: SightCheckRay = get_node_or_null("SightRay") as SightCheckRay
@onready var _interaction: Node = get_node_or_null("Interaction")   # InteractionController, optional

var _input: Node = null           # /root/InputManager (autoload)
var _sprinting: bool = false
var _move_vec_2d: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	_input = get_node_or_null("/root/InputManager")
	if _camera == null:
		_camera = get_node_or_null("Camera3D") as Camera3D

func _physics_process(dt: float) -> void:
	_apply_gravity(dt)
	_read_input()
	_apply_movement(dt)
	move_and_slide()
	_emit_move_signal()

func _apply_gravity(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * dt
	else:
		# keep a tiny downward bias so is_on_floor stays consistent
		if velocity.y > 0.0:
			velocity.y = 0.0

func _read_input() -> void:
	# Movement vector comes from InputManager if present, else fallback to raw Input
	var v: Vector2 = Vector2.ZERO
	if _input != null and _input.has_method("get_movement_vector"):
		var any_v: Variant = _input.call("get_movement_vector")
		if typeof(any_v) == TYPE_VECTOR2:
			v = any_v
	else:
		if Input.is_action_pressed("move_forward"):
			v.y -= 1.0
		if Input.is_action_pressed("move_back"):
			v.y += 1.0
		if Input.is_action_pressed("move_left"):
			v.x -= 1.0
		if Input.is_action_pressed("move_right"):
			v.x += 1.0
		if v.length() > 1.0:
			v = v.normalized()
	_move_vec_2d = v

	# Sprint comes from Input if defined; InputManager doesn’t expose sprint today
	_sprinting = false
	if InputMap.has_action("sprint"):
		if Input.is_action_pressed("sprint"):
			_sprinting = true

func _apply_movement(dt: float) -> void:
	# Move relative to facing. If you want camera-relative, swap basis to the camera.
	var basis: Basis
	if _camera != null:
		basis = _camera.global_transform.basis
	else:
		basis = global_transform.basis

	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var dir: Vector3 = (right * _move_vec_2d.x) + (forward * _move_vec_2d.y)
	if dir.length() > 0.0:
		dir = dir.normalized()

	var target_speed: float = walk_speed
	if _sprinting:
		target_speed = sprint_speed

	var target_vel: Vector3 = dir * target_speed
	target_vel.y = velocity.y

	var lerp_t: float = acceleration * dt
	if lerp_t > 1.0:
		lerp_t = 1.0

	velocity.x = lerp(velocity.x, target_vel.x, lerp_t)
	velocity.z = lerp(velocity.z, target_vel.z, lerp_t)

func _emit_move_signal() -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var grounded: bool = is_on_floor()
	emit_signal("move_state", horiz_speed, grounded, _sprinting)

# -------- Vision delegate for Effigy --------
func can_see_node(_target: Node3D) -> bool:
	if _sight == null:
		return false
	return _sight.is_target_visible

# -------- Interaction registration from Areas --------
func register_interactable(area: InteractableArea) -> void:
	if _interaction == null:
		return
	if _interaction.has_method("register_area"):
		_interaction.call("register_area", area)

func unregister_interactable(area: InteractableArea) -> void:
	if _interaction == null:
		return
	if _interaction.has_method("unregister_area"):
		_interaction.call("unregister_area", area)
