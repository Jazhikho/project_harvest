extends CharacterBody3D
## Effigy Entity - Sanity-dependent stalking behavior
## Moves differently based on player sanity level and visibility

@export var turn_speed: float = 999.0  # Instant turning
@export var follow_speed_base: float = 0.5  # Very slow base speed
@export var follow_speed_half: float = 2.0
@export var follow_speed_full: float = 4.0
@export var stop_distance: float = 1.0  # Distance to maintain from player
@export var visibility_check_interval: float = 0.1  # How often to check if player is looking

# Stage references
@onready var stage1: Node3D = $Stage1
@onready var stage2: Node3D = $Stage2
@onready var stage3: Node3D = $Stage3
@onready var stage4: Node3D = $Stage4

# System references
var _message_bus: Node
var _state_manager: Node
var player: Node

# State tracking
var current_sanity: int = 100
var current_stage: int = 1
var is_player_looking: bool = false
var last_visibility_check: float = 0.0
var can_move: bool = false
var target_position: Vector3
var is_following: bool = false

# Movement state
var follow_speed: float
var last_player_position: Vector3

func _ready() -> void:
	name = "Effigy"
	add_to_group("enemies")
	add_to_group("effigies")
	
	# Set collision properties using CollisionHelper
	CollisionHelper.setup_entity_collision(self)
	
	# Initialize stages - only stage 1 visible initially
	_setup_stages()
	
	# Initialize systems after scene is ready
	call_deferred("_initialize_systems")
	
	follow_speed = follow_speed_base

func _setup_stages() -> void:
	"""Setup stage visibility"""
	if stage1: stage1.visible = true
	if stage2: stage2.visible = false
	if stage3: stage3.visible = false
	if stage4: stage4.visible = false

func _initialize_systems() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("Effigy: Required core systems not found")
		return
	
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		push_error("Effigy: Player not found")
		return
	
	_connect_to_events()
	
	# Get initial sanity level
	if _state_manager:
		current_sanity = _state_manager.get_sanity()
		_update_behavior_for_sanity()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	if _message_bus:
		_message_bus.sanity_changed.connect(_on_sanity_changed)
		_message_bus.game_ended.connect(_on_game_ended)

func _physics_process(delta: float) -> void:
	if not player or not _should_be_active():
		return
	
	_check_player_visibility(delta)
	_update_behavior(delta)
	
	if can_move and is_following:
		_move_toward_player(delta)

func _should_be_active() -> bool:
	"""Check if effigy should be active based on sanity"""
	return current_sanity < 90

func _check_player_visibility(delta: float) -> void:
	"""Check if player is looking at the effigy"""
	last_visibility_check += delta
	
	if last_visibility_check >= visibility_check_interval:
		last_visibility_check = 0.0
		
		var was_looking = is_player_looking
		
		if player.has_method("is_looking_at_position"):
			is_player_looking = player.is_looking_at_position(global_position)
		else:
			is_player_looking = _manual_visibility_check()
		
		# Emit events when visibility state changes
		if was_looking != is_player_looking:
			if _message_bus:
				if is_player_looking:
					_message_bus.emit_event("player_looking_at", [self, "effigy"])
					_message_bus.emit_event("visibility_changed", [self, true, player])
				else:
					_message_bus.emit_event("player_looked_away", [self, "effigy"])
					_message_bus.emit_event("visibility_changed", [self, false, player])

func _manual_visibility_check() -> bool:
	"""Manual visibility check using raycasting and angle checking"""
	if not player:
		return false
	
	var player_camera = player.get_node("Camera3D")
	if not player_camera:
		return false
	
	var to_effigy = (global_position - player_camera.global_position).normalized()
	var camera_forward = -player_camera.global_transform.basis.z
	
	# Check if effigy is within camera's field of view (roughly 90 degrees)
	var dot_product = camera_forward.dot(to_effigy)
	var angle = acos(clamp(dot_product, -1.0, 1.0))
	var fov_radians = deg_to_rad(45)  # Half of 90 degree FOV
	
	if angle > fov_radians:
		return false
	
	# Raycast to check if there are obstacles between player and effigy
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		player_camera.global_position,
		global_position
	)
	query.exclude = [self, player]  # Exclude self and player from raycast
	query.collision_mask = 2 | 4  # Check against environment and obstacles
	
	var result = space_state.intersect_ray(query)
	
	# If ray hits something, player can't see effigy clearly
	return result.is_empty()

func _update_behavior(delta: float) -> void:
	"""Update effigy behavior based on sanity level"""
	if not player:
		return
	
	var player_moved = false
	if last_player_position.distance_to(player.global_position) > 0.1:
		player_moved = true
		last_player_position = player.global_position
	
	can_move = not is_player_looking
	
	var was_following = is_following
	
	if current_sanity < 90:
		if not is_player_looking and player_moved:
			_turn_head_toward_player()
	
	if current_sanity < 80:
		is_following = true
		if can_move:
			_turn_toward_player()
		
		# Emit detection event when starting to follow
		if not was_following and is_following and _message_bus:
			var distance = get_distance_to_player()
			_message_bus.emit_event("entity_detected_player", ["effigy", self, distance])
	else:
		is_following = false
		# Emit lost player event when stopping follow
		if was_following and not is_following and _message_bus:
			_message_bus.emit_event("entity_lost_player", ["effigy", self])

func _turn_head_toward_player() -> void:
	"""Turn head to track player (visual only for now)"""
	# This would ideally animate just the head/neck bones
	# For now, we'll do a subtle body turn
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	var target_rotation = atan2(direction.x, direction.z)
	
	# Instant head turn (can be modified for just head later)
	rotation.y = target_rotation

func _turn_toward_player() -> void:
	"""Instantly turn to face player"""
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	var target_rotation = atan2(direction.x, direction.z)
	
	# Instant turn
	rotation.y = target_rotation

func _move_toward_player(delta: float) -> void:
	"""Move toward player at appropriate speed"""
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Stop if too close
	if distance_to_player <= stop_distance:
		velocity = Vector3.ZERO
		return
	
	# Calculate movement direction
	var direction = (player.global_position - global_position).normalized()
	
	# Apply movement
	velocity = direction * follow_speed
	move_and_slide()

func _update_behavior_for_sanity() -> void:
	"""Update behavior and appearance based on current sanity"""
	var new_stage = _calculate_stage_for_sanity(current_sanity)
	
	if new_stage != current_stage:
		_change_stage(new_stage)
	
	# Update follow speed based on sanity
	if current_sanity >= 60:
		follow_speed = follow_speed_base
	elif current_sanity >= 40:
		follow_speed = follow_speed_half
	else:
		follow_speed = follow_speed_full

func _calculate_stage_for_sanity(sanity: int) -> int:
	"""Calculate which stage should be active for given sanity level"""
	if sanity >= 70:
		return 1
	elif sanity >= 50:
		return 2
	elif sanity >= 40:
		return 3
	else:
		return 4

func _change_stage(new_stage: int) -> void:
	"""Change visible stage model"""
	var old_stage = current_stage
	
	# Hide all stages
	if stage1: stage1.visible = false
	if stage2: stage2.visible = false
	if stage3: stage3.visible = false
	if stage4: stage4.visible = false
	
	# Show appropriate stage
	match new_stage:
		1:
			if stage1: stage1.visible = true
		2:
			if stage2: stage2.visible = true
		3:
			if stage3: stage3.visible = true
		4:
			if stage4: stage4.visible = true
	
	current_stage = new_stage
	
	# Emit stage change event
	if _message_bus and old_stage != new_stage:
		_message_bus.emit_event("entity_stage_changed", ["effigy", self, old_stage, new_stage])
	
	print("Effigy: Changed to stage ", new_stage, " (sanity: ", current_sanity, ")")

# Event handlers
func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity level changes"""
	current_sanity = new_value
	_update_behavior_for_sanity()

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end"""
	is_following = false
	can_move = false

# Public API
func get_current_stage() -> int:
	"""Get current stage number"""
	return current_stage

func is_active() -> bool:
	"""Check if effigy is currently active"""
	return _should_be_active()

func get_distance_to_player() -> float:
	"""Get distance to player"""
	if not player:
		return INF
	return global_position.distance_to(player.global_position)
