# Effigy.gd (trimmed to essentials)
extends CharacterBody3D
class_name Effigy

# Movement tuning
@export var turn_speed: float = 999.0
@export var follow_speed_base: float = 0.5
@export var follow_speed_half: float = 0.7
@export var follow_speed_full: float = 1.0
@export var stop_distance: float = 1.5

# Visibility polling
@export var visibility_check_interval: float = 0.1

# Optional direct player reference; else found by group "player"
@export var player_path: NodePath = NodePath("")

# Stages
@onready var stage1: Node3D = $Stage1
@onready var stage2: Node3D = $Stage2
@onready var stage3: Node3D = $Stage3
@onready var stage4: Node3D = $Stage4

# Areas and audio
@onready var detection_area: Area3D = $DetectionArea
@onready var audio_move: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Signals
signal stage_changed(stage: int)

# State
var player: Node3D = null
var current_sanity: int = 100
var current_stage: int = 1
var follow_speed: float = 0.5
var is_player_looking: bool = false
var player_in_detection_range: bool = false
var is_following: bool = false
var _vis_accum: float = 0.0

func _ready() -> void:
	_resolve_player()
	_connect_signals()
	_setup_stages_initial()

	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("get_state"):
		var s: Variant = sm.call("get_state", "sanity")
		if typeof(s) == TYPE_INT:
			current_sanity = int(s)
	_update_behavior_for_sanity()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	_vis_accum += delta
	if _vis_accum >= visibility_check_interval:
		_vis_accum = 0.0
		is_player_looking = _query_player_visibility()

	if not player_in_detection_range or is_player_looking:
		_stop_horizontal_motion()
		_apply_move_and_audio(false)
		return

	_turn_toward_player(delta)
	_update_following_flag()
	if is_following:
		_move_toward_player(delta)
		_apply_move_and_audio(true)
	else:
		_stop_horizontal_motion()
		_apply_move_and_audio(false)

func _resolve_player() -> void:
	if player_path != NodePath(""):
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_error("Effigy: player not found (need group 'player' or set player_path).")

func _connect_signals() -> void:
	if detection_area != null:
		detection_area.connect("body_entered", Callable(self, "_on_detection_area_entered"))
		detection_area.connect("body_exited", Callable(self, "_on_detection_area_exited"))

	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_signal("sanity_changed"):
		sm.connect("sanity_changed", Callable(self, "_on_sanity_changed"))

func _setup_stages_initial() -> void:
	if stage1 != null: stage1.visible = true
	if stage2 != null: stage2.visible = false
	if stage3 != null: stage3.visible = false
	if stage4 != null: stage4.visible = false
	follow_speed = follow_speed_base

func _query_player_visibility() -> bool:
	# Preferred: ask the Player’s API
	if player != null and player.has_method("can_see_node"):
		var v: Variant = player.call("can_see_node", self)
		if typeof(v) == TYPE_BOOL:
			return bool(v)

	# Fallback: angle + ray from active camera (optional safety net)
	var cam: Camera3D = _get_player_camera()
	if cam == null:
		return false
	var to_here: Vector3 = (global_position - cam.global_position).normalized()
	var forward: Vector3 = -cam.global_transform.basis.z
	var dotv: float = forward.dot(to_here)
	var fov_radians: float = deg_to_rad(90.0)
	var angle: float = acos(clamp(dotv, -1.0, 1.0))
	if angle > fov_radians:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, global_position)
	query.exclude = [player]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_pos: Vector3 = result["position"]
	var hit_d: float = cam.global_position.distance_to(hit_pos)
	var eff_d: float = cam.global_position.distance_to(global_position)
	if hit_d >= eff_d - 0.1:
		return true
	return false

func _get_player_camera() -> Camera3D:
	if player == null:
		return null
	var cam: Camera3D = player.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		return cam
	return get_viewport().get_camera_3d()

# Sanity -> stage and speed
func _on_sanity_changed(_old_value: int, new_value: int, _delta: int) -> void:
	current_sanity = new_value
	_update_behavior_for_sanity()

func _update_behavior_for_sanity() -> void:
	var new_stage: int = GameConstants.sanity_to_stage(current_sanity)
	if new_stage != current_stage:
		_change_stage(new_stage)

	if current_sanity >= GameConstants.SANITY_THRESHOLD_HIGH:
		follow_speed = 0.0
	elif current_sanity >= GameConstants.SANITY_THRESHOLD_MEDIUM:
		follow_speed = follow_speed_base
	elif current_sanity >= GameConstants.SANITY_THRESHOLD_LOW:
		follow_speed = follow_speed_half
	else:
		follow_speed = follow_speed_full

func _change_stage(new_stage: int) -> void:
	if stage1 != null: stage1.visible = false
	if stage2 != null: stage2.visible = false
	if stage3 != null: stage3.visible = false
	if stage4 != null: stage4.visible = false

	if new_stage == 1:
		if stage1 != null: stage1.visible = true
	elif new_stage == 2:
		if stage2 != null: stage2.visible = true
	elif new_stage == 3:
		if stage3 != null: stage3.visible = true
	else:
		if stage4 != null: stage4.visible = true

	current_stage = new_stage
	emit_signal("stage_changed", current_stage)

# Following logic
func _update_following_flag() -> void:
	var allow_follow: bool = false
	if current_sanity < GameConstants.SANITY_THRESHOLD_HIGH:
		if player_in_detection_range:
			if _orientation_allows_follow():
				allow_follow = true
	is_following = allow_follow

func _orientation_allows_follow() -> bool:
	if player == null:
		return false
	var player_forward: Vector3 = -player.global_transform.basis.z
	var player_to_effigy: Vector3 = (global_position - player.global_position).normalized()
	var d: float = player_forward.dot(player_to_effigy)
	if d < 0.0:
		return true
	return false

# Movement helpers
func _turn_toward_player(delta: float) -> void:
	if player == null:
		return
	var to_player: Vector3 = (player.global_position - global_position).normalized()
	var target_yaw: float = atan2(to_player.x, to_player.z)
	var t: float = turn_speed * delta
	if t > 1.0:
		t = 1.0
	rotation.y = lerp_angle(rotation.y, target_yaw, t)

func _move_toward_player(_delta: float) -> void:
	if player == null:
		_stop_horizontal_motion()
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= stop_distance:
		_stop_horizontal_motion()
		move_and_slide()
		return
	var dir: Vector3 = player.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * follow_speed
	velocity.z = dir.z * follow_speed
	move_and_slide()

func _stop_horizontal_motion() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

func _apply_move_and_audio(moving: bool) -> void:
	if audio_move == null:
		return
	if moving:
		if not audio_move.playing:
			audio_move.play()
	else:
		if audio_move.playing:
			audio_move.stop()

# Proximity handlers
func _on_detection_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_detection_range = true

func _on_detection_area_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_detection_range = false
		is_following = false
		_stop_horizontal_motion()
		_apply_move_and_audio(false)

# Public API
func get_stage() -> int:
	return current_stage

func get_current_stage() -> int:
	return current_stage
