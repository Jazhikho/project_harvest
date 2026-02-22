extends CharacterBody3D
## BaseEntity - Base class for all game entities
## Provides common functionality like system references, player detection, and event handling
## Follows SOLID principles by providing a stable base for entity behavior

class_name BaseEntity

# Core system references
var _message_bus: Node
var _state_manager: Node
var player: Node

# Common entity state
var is_active: bool = false
var entity_type: String = ""
var detection_range: float = GameConstants.ENEMY_DETECTION_RANGE

# Initialization tracking
var _systems_initialized: bool = false

func _ready() -> void:
	# Set up collision by default
	CollisionHelper.setup_entity_collision(self)
	
	# Initialize after scene is ready
	call_deferred("_initialize_base_entity")

func _initialize_base_entity() -> void:
	"""Initialize base entity systems and connections"""
	if _systems_initialized:
		return
	
	# Get system references
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("%s: Required core systems not found" % get_entity_name())
		return
	
	# Find player
	_find_player()
	
	# Connect base events
	_connect_base_events()
	
	# Call derived class initialization
	_initialize_entity()
	
	_systems_initialized = true

func _initialize_entity() -> void:
	"""Override in derived classes for specific initialization"""
	pass

func _find_player() -> void:
	"""Find and store reference to player"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		_log_error("Player not found in scene")

func _connect_base_events() -> void:
	"""Connect to common events that entities need"""
	if _message_bus:
		if _message_bus.has_signal("game_ended"):
			_message_bus.game_ended.connect(_on_game_ended)
		if _message_bus.has_signal("sanity_changed"):
			_message_bus.sanity_changed.connect(_on_sanity_changed)

# Common utility methods
func get_entity_name() -> String:
	"""Get entity name for logging"""
	if name != "":
		return name
	else:
		return entity_type

func is_player_valid() -> bool:
	"""Check if player reference is valid"""
	return player != null and is_instance_valid(player)

func get_distance_to_player() -> float:
	"""Get distance to player"""
	if not is_player_valid():
		return INF
	return global_position.distance_to(player.global_position)

func is_player_in_range(range_override: float = -1.0) -> bool:
	"""Check if player is within detection range"""
	var check_range: float
	if range_override > 0.0:
		check_range = range_override
	else:
		check_range = detection_range
	return get_distance_to_player() <= check_range

func get_direction_to_player() -> Vector3:
	"""Get normalized direction vector to player"""
	if not is_player_valid():
		return Vector3.ZERO
	return (player.global_position - global_position).normalized()

func turn_toward_player(instant: bool = true) -> void:
	"""Turn to face player"""
	if not is_player_valid():
		return
	
	var direction = get_direction_to_player()
	var target_rotation = atan2(direction.x, direction.z)
	
	if instant:
		rotation.y = target_rotation
	else:
		# Smooth rotation can be implemented here
		rotation.y = lerp_angle(rotation.y, target_rotation, get_physics_process_delta_time() * 5.0)

# Event emission helpers
func emit_entity_event(event_name: String, args: Array = []) -> void:
	"""Emit event with entity context"""
	if not _message_bus:
		return
	
	# Prepend entity type and self reference to args
	var full_args = [entity_type, self] + args
	_message_bus.emit_event(event_name, full_args)

func emit_detection_event() -> void:
	"""Emit player detection event"""
	emit_entity_event("entity_detected_player", [get_distance_to_player()])

func emit_lost_player_event() -> void:
	"""Emit lost player event"""
	emit_entity_event("entity_lost_player")

# Logging helpers
func _log_warning(message: String) -> void:
	"""Log warning message with entity name"""
	push_warning("%s: %s" % [get_entity_name(), message])

func _log_error(message: String) -> void:
	"""Log error message with entity name"""
	push_error("%s: %s" % [get_entity_name(), message])

# Base event handlers - override in derived classes
func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end - override in derived classes"""
	is_active = false

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity changes - override in derived classes"""
	pass

# Physics helpers
func move_toward_target(target: Vector3, speed: float, min_distance: float = 1.0) -> void:
	"""Move toward target position with minimum distance check"""
	var distance = global_position.distance_to(target)
	
	if distance <= min_distance:
		velocity = Vector3.ZERO
		return
	
	var direction = (target - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

# Validation helpers
func validate_required_nodes(node_paths: Array[String]) -> bool:
	"""Validate that required child nodes exist"""
	for path in node_paths:
		var node = get_node_or_null(path)
		if not node:
			_log_error("Required node not found: %s" % path)
			return false
	return true

# State management helpers
func set_entity_active(active: bool) -> void:
	"""Set entity active state with event emission"""
	if is_active != active:
		var old_state_str: String = "active" if is_active else "inactive"
		var new_state_str: String = "active" if active else "inactive"
		is_active = active
		emit_entity_event("entity_state_changed", [old_state_str, new_state_str])

func get_current_sanity() -> int:
	"""Get current sanity from state manager"""
	if not _state_manager:
		return GameConstants.MAX_SANITY
	return SanityManager.get_current_sanity()

# Cleanup
func cleanup() -> void:
	"""Clean up entity resources - call before removing"""
	is_active = false
	player = null
	_message_bus = null
	_state_manager = null
