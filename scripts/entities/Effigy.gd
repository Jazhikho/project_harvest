extends BaseEntity
## Effigy Entity - Sanity-dependent stalking behavior
## Moves differently based on player sanity level and visibility
## Refactored to use GameConstants, BaseEntity, and simplified methods

@export var turn_speed: float = 999.0  # Instant turning
@export var follow_speed_base: float = 0.5  # Very slow base speed
@export var follow_speed_half: float = 0.7
@export var follow_speed_full: float = 1.0
@export var stop_distance: float = 1.5  # Distance to maintain from player
@export var visibility_check_interval: float = 0.1  # How often to check if player is looking
@export var camera_path: NodePath

# Stage references
@onready var stage1: Node3D = $Stage1
@onready var stage2: Node3D = $Stage2
@onready var stage3: Node3D = $Stage3
@onready var stage4: Node3D = $Stage4

# Detection area reference
@onready var detection_area: Area3D = $DetectionArea

# State tracking
var current_sanity: int = GameConstants.MAX_SANITY
var current_stage: int = 1
var is_player_looking: bool = false
var last_visibility_check: float = 0.0
var can_move: bool = false
var target_position: Vector3
var is_following: bool = false
var player_in_detection_range: bool = false
var aggression_mode: bool = false

# Movement state
var follow_speed: float
var last_player_position: Vector3

func _ready() -> void:
	entity_type = GameConstants.ENEMY_TYPE_EFFIGY
	name = "Effigy"
	add_to_group("enemies")
	add_to_group("effigies")
	
	# Setup collision layers properly
	CollisionHelper.setup_entity_collision(self)
	
	# Initialize stages - only stage 1 visible initially
	_setup_stages()
	
	follow_speed = follow_speed_base
	
	# Connect detection area signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
	else:
		push_error("Effigy: Detection area not found!")
	
	# Call parent _ready
	super()

func _setup_stages() -> void:
	"""Setup stage visibility"""
	if stage1: stage1.visible = true
	if stage2: stage2.visible = false
	if stage3: stage3.visible = false
	if stage4: stage4.visible = false

func _initialize_entity() -> void:
	"""Initialize effigy-specific behavior"""
	_connect_to_events()
	
	# Get initial sanity level
	current_sanity = get_current_sanity()
	_update_behavior_for_sanity()
	
	# Set initial active state based on sanity
	set_entity_active(true)

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	if _message_bus:
		if not _message_bus.sanity_changed.is_connected(_on_sanity_changed):
			_message_bus.sanity_changed.connect(_on_sanity_changed)
		if not _message_bus.game_ended.is_connected(_on_game_ended):
			_message_bus.game_ended.connect(_on_game_ended)

func _physics_process(delta: float) -> void:
	if not player or not is_active:
		return
	
	# Only check visibility if player is in detection range
	if player_in_detection_range:
		_check_player_visibility(delta)
		_update_behavior(delta)
		
		# ALL actions only when player is NOT looking
		if can_move:  # can_move = NOT is_player_looking
			# Always turn toward player when not being watched (regardless of following)
			_turn_toward_player()
			
			if is_following:
				# Move toward player when following and not being watched
				_move_toward_player(delta)
			else:
				# Just turning, not moving - but still need to apply the turn
				velocity.x = 0.0
				velocity.z = 0.0
				move_and_slide()  # Apply the movement with gravity
		else:
			# Player is looking - FREEZE completely (but keep gravity)
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()  # Apply movement with gravity
	else:
		# Player not in detection range - stop horizontal movement but keep gravity
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

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
	if not is_player_valid():
		return false
	
	var player_camera = _get_player_camera()
	if not player_camera:
		return false
	
	# Use the same logic as the player's is_looking_at_position method
	var to_target = (global_position - player_camera.global_position).normalized()
	var camera_forward = -player_camera.global_transform.basis.z
	
	# Check if effigy is within field of view (90 degrees default)
	var dot_product = camera_forward.dot(to_target)
	var angle = acos(clamp(dot_product, -1.0, 1.0))
	var fov_radians = deg_to_rad(90.0) 
	
	if angle > fov_radians:
		return false
	
	# Raycast to check if there are obstacles blocking view
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		player_camera.global_position,
		global_position
	)
	query.exclude = [player]  # Exclude player from raycast
	CollisionHelper.setup_visibility_raycast(query)
	
	var result = space_state.intersect_ray(query)
	
	# If ray hits something before reaching effigy, not visible
	if not result.is_empty():
		var hit_distance = player_camera.global_position.distance_to(result.position)
		var effigy_distance = player_camera.global_position.distance_to(global_position)
		
		# Allow small margin for floating point precision
		return hit_distance >= (effigy_distance - 0.1)
	
	return true

func _get_player_camera() -> Camera3D:
	var cam: Camera3D = null
	if camera_path != NodePath() and is_instance_valid(player):
		cam = player.get_node_or_null(camera_path)
	if cam == null and is_instance_valid(player):
		cam = player.get_node_or_null("Camera3D")  # fallback if you really have that node
	if cam == null:
		cam = get_viewport().get_camera_3d()  # the active 3D camera
	if cam == null:
		push_warning("Effigy: No active Camera3D found.")
	return cam


func _update_behavior(delta: float) -> void:
	"""Update effigy behavior based on sanity level"""
	if not is_player_valid():
		return
	
	var player_moved = _check_player_movement()
	
	# Effigy can only move/turn when player is NOT looking at it
	can_move = not is_player_looking
	
	_update_following_behavior()

func _check_player_movement() -> bool:
	"""Check if player has moved since last update"""
	var current_player_pos = player.global_position
	var moved = last_player_position.distance_to(current_player_pos) > 0.1
	
	if moved:
		last_player_position = current_player_pos
	
	return moved

func _orientation_allows_follow() -> bool:
	# Forward is -Z in Godot. Dot >= 0 means within ±90°
	var player_forward = -player.global_transform.basis.z
	var player_to_effigy = (global_position - player.global_position).normalized()
	return player_forward.dot(player_to_effigy) < 0.0

func _update_following_behavior() -> void:
	"""Update following behavior based on sanity levels"""
	var was_following = is_following
	
	# Determine if effigy should follow based on sanity
	# Above 80: No following, just watching/turning
	# 60-80: Follow at slow speed
	# 40-60: Follow at medium speed  
	# Below 40: Follow at max speed
	if current_sanity < GameConstants.SANITY_THRESHOLD_HIGH \
		and player_in_detection_range \
		and _orientation_allows_follow():
		is_following = true
		_emit_detection_event_if_needed(was_following)
	else:
		is_following = false
		_emit_lost_player_event_if_needed(was_following)

func _emit_detection_event_if_needed(was_following: bool) -> void:
	"""Emit detection event when starting to follow"""
	if not was_following and is_following and _message_bus:
		var distance = get_distance_to_player()
		_message_bus.emit_event("entity_detected_player", ["effigy", self, distance])

func _emit_lost_player_event_if_needed(was_following: bool) -> void:
	"""Emit lost player event when stopping follow"""
	if was_following and not is_following and _message_bus:
		_message_bus.emit_event("entity_lost_player", ["effigy", self])

func _turn_toward_player() -> void:
	"""Turn to face player - only happens when player is NOT looking"""
	if not player: return
	var dir = (player.global_position - global_position).normalized()
	var target_yaw = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * get_physics_process_delta_time(), 0.0, 1.0))

func _move_toward_player(delta: float) -> void:
	"""Move toward player at appropriate speed - only when player is NOT looking"""
	if not player:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Stop if too close
	if distance_to_player <= stop_distance:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	# Calculate movement direction (keep Y unchanged for gravity)
	var direction = (player.global_position - global_position)
	direction.y = 0  # Don't affect vertical movement
	direction = direction.normalized()
	
	# Apply horizontal movement only (preserve Y velocity for gravity)
	velocity.x = direction.x * follow_speed
	velocity.z = direction.z * follow_speed
	
	# Move and allow slide (clipping through walls is now a feature)
	move_and_slide()

func _update_behavior_for_sanity() -> void:
	"""Update behavior and appearance based on current sanity"""
	var new_stage = _calculate_stage_for_sanity(current_sanity)
	
	if new_stage != current_stage:
		_change_stage(new_stage)
	
	# Update follow speed based on sanity thresholds
	# Speed increases as sanity drops
	if current_sanity >= GameConstants.SANITY_THRESHOLD_HIGH:  # Above 80
		# No following, speed doesn't matter but set to base
		follow_speed = 0.0  # Don't move at all
	elif current_sanity >= GameConstants.SANITY_THRESHOLD_MEDIUM:  # 60-80
		follow_speed = follow_speed_base  # 0.5 - slowest following
	elif current_sanity >= GameConstants.SANITY_THRESHOLD_LOW:  # 40-60
		follow_speed = follow_speed_half  # 0.7 - medium speed
	else:  # Below 40
		follow_speed = follow_speed_full  # 1.0 - max speed

func _calculate_stage_for_sanity(sanity: int) -> int:
	"""Calculate which stage should be active for given sanity level"""
	return GameConstants.sanity_to_stage(sanity)

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
	

# Detection Area Signal Handlers
func _on_detection_area_entered(body: Node3D) -> void:
	if body == player or body.is_in_group("player"):
		player_in_detection_range = true

func _on_detection_area_exited(body: Node3D) -> void:
	if body == player or body.is_in_group("player"):
		player_in_detection_range = false
		is_following = false
		velocity = Vector3.ZERO
		if is_player_looking and _message_bus:
			_message_bus.emit_event("player_looked_away", [self, "effigy"])
			_message_bus.emit_event("visibility_changed", [self, false, player])
		is_player_looking = false

# Event handlers
func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity level changes"""
	current_sanity = new_value
	_update_behavior_for_sanity()

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end"""
	is_following = false
	can_move = false
	player_in_detection_range = false

# Public API
func get_current_stage() -> int:
	"""Get current stage number"""
	return current_stage

# is_active property inherited from BaseEntity
# Use set_entity_active(bool) to change state with proper event emission

# get_distance_to_player() inherited from BaseEntity
