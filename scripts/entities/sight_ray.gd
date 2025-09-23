# SightCheckRay.gd
# Attach this to the SightRay (RayCast3D) on BOTH Player and Effigy.
extends RayCast3D
class_name SightCheckRay

enum Role { PLAYER, EFFIGY }
@export var role: Role = Role.PLAYER

@export var player_group: String = "player"
@export var effigy_group: String = "effigy"

@export var view_distance: float = 20.0
@export var fov_degrees: float = 90.0

# Layers: characters on 1, world occluders on 2 (change if your walls use a different layer)
@export var character_layer_index: int = 1
@export var world_layer_index: int = 2
@export var ray_hits_character: bool = true

# Node references
@export var eye_path: NodePath = NodePath("")      # Marker3D/Node3D at eye height
@export var forward_node_path: NodePath = NodePath("")  # if empty, uses parent

signal sight_result_changed(visible: bool)

var is_target_visible: bool = false
var _eye: Node3D
var _forward_node: Node3D
var _target: Node3D
var _cos_half_fov: float = 0.0

func _ready() -> void:
	_resolve_eye()
	_resolve_forward_node()
	_configure_ray_mask()
	exclude_parent = true
	enabled = true
	_cos_half_fov = cos(deg_to_rad(fov_degrees * 0.5))
	_update_target_ref()

func _physics_process(_dt: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_update_target_ref()
		if _target == null:
			_set_visible(false)
			return

	var from: Vector3 = _eye.global_transform.origin
	var to: Vector3 = _target.global_transform.origin
	var delta: Vector3 = to - from
	var dist: float = delta.length()
	if dist <= 0.0001:
		_set_visible(false)
		return
	if dist > view_distance:
		_set_visible(false)
		return

	# Godot forward is -Z
	var forward: Vector3 = -_forward_node.global_transform.basis.z.normalized()
	var dir: Vector3 = delta / dist
	if forward.dot(dir) < _cos_half_fov:
		_set_visible(false)
		return

	global_transform.origin = from
	target_position = to_local(to)
	force_raycast_update()

	if ray_hits_character:
		if is_colliding():
			var hit: Object = get_collider()
			var seen: bool = hit == _target
			_set_visible(seen)
		else:
			_set_visible(false)
	else:
		var blocked: bool = is_colliding()
		_set_visible(not blocked)

func _set_visible(v: bool) -> void:
	if is_target_visible == v:
		return
	is_target_visible = v
	emit_signal("sight_result_changed", v)

func _resolve_eye() -> void:
	var node: Node = null
	if eye_path != NodePath(""):
		node = get_node_or_null(eye_path)
	if node == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			node = parent_node.get_node_or_null("Eyes")
		if node == null and parent_node != null:
			node = parent_node.get_node_or_null("Eye")
	if node == null:
		node = get_node_or_null("Eyes")
	if node == null:
		node = get_node_or_null("Eye")
	_eye = node as Node3D
	if _eye == null:
		push_error("SightCheckRay: Eye/Eyes Node3D not found. Assign eye_path or add a node named Eye or Eyes.")
		set_physics_process(false)

func _resolve_forward_node() -> void:
	var node: Node = null
	if forward_node_path != NodePath(""):
		node = get_node_or_null(forward_node_path)
	if node == null:
		node = get_parent()
	_forward_node = node as Node3D
	if _forward_node == null:
		_forward_node = self

func _configure_ray_mask() -> void:
	var mask: int = 0
	if world_layer_index > 0:
		var world_bit: int = 1 << int(world_layer_index - 1)
		mask |= world_bit
	if ray_hits_character:
		if character_layer_index > 0:
			var char_bit: int = 1 << int(character_layer_index - 1)
			mask |= char_bit
	collision_mask = mask

func _update_target_ref() -> void:
	var want_group: String = ""
	if role == Role.PLAYER:
		want_group = effigy_group
	else:
		want_group = player_group
	_target = get_tree().get_first_node_in_group(want_group) as Node3D
