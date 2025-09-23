extends Node
class_name InteractionController

@export var camera_path: NodePath = NodePath("../Camera3D")
@export var interact_action: String = "interact"
@export var max_use_distance: float = 2.5

# Optional: narrow who counts as "in front of camera" (dot in [-1,1], higher = closer to center)
@export var min_aim_dot: float = 0.2

signal target_changed(target: InteractableArea)

var _camera: Camera3D = null
var _candidates: Array[InteractableArea] = []
var _current: InteractableArea = null

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		push_error("InteractionController: camera_path invalid. Set it to your Player's Camera3D.")
		set_process(false)

func _process(_dt: float) -> void:
	_select_target()
	if Input.is_action_just_pressed(interact_action):
		_try_interact()

# Called by InteractableArea on body_entered
func register_area(area: InteractableArea) -> void:
	if area == null:
		return
	if _candidates.has(area):
		return
	_candidates.append(area)

# Called by InteractableArea on body_exited
func unregister_area(area: InteractableArea) -> void:
	if area == null:
		return
	_candidates.erase(area)
	if _current == area:
		_set_current(null)

func _select_target() -> void:
	var best: InteractableArea = null
	var best_dot: float = -2.0
	var best_dist: float = 1e9

	var cam_pos: Vector3 = _camera.global_position
	var cam_fwd: Vector3 = -_camera.global_transform.basis.z

	for area in _candidates:
		if area == null or not is_instance_valid(area):
			continue
		if not area.is_available():
			continue

		var owner: Node3D = area.get_node_or_null(area.owner_path) as Node3D
		if owner == null:
			owner = area as Node3D
		if owner == null:
			continue

		var delta: Vector3 = owner.global_position - cam_pos
		var dist: float = delta.length()
		if dist > max_use_distance:
			continue

		var dir: Vector3 = delta.normalized()
		var dotv: float = cam_fwd.dot(dir)
		if dotv < min_aim_dot:
			continue

		var better_dot: bool = dotv > best_dot
		var closer_same_dot: bool = dotv == best_dot and dist < best_dist
		if better_dot or closer_same_dot:
			best = area
			best_dot = dotv
			best_dist = dist

	if best != _current:
		_set_current(best)

func _set_current(area: InteractableArea) -> void:
	_current = area
	emit_signal("target_changed", _current)
	# Toasts are owned by the Area on enter/exit. No UI here on purpose.

func _try_interact() -> void:
	if _current == null:
		return
	_current.interact(get_parent())
