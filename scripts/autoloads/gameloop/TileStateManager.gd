extends BaseManager
## TileStateManager - Centralized authority for all tile states and transitions
## Handles tile lifecycle, state changes, and player movement between tiles

var _tile_manager: Node

# Tile state tracking
var _active_tiles: Dictionary = {} # Vector2i -> {node: Node3D, state: String, last_changed: float}
var _current_player_tile: Vector2i = Vector2i(0, 0)
var _previous_player_tile: Vector2i = Vector2i(-1000, -1000)

# Transition management
var _tile_transition_detectors: Dictionary = {} # Vector2i -> Area3D
var _transition_cooldown: float = 0.5
var _last_transition_time: float = 0.0
var _transition_threshold: float = 8.0 # Distance from tile center to trigger transition

# Prevent stack overflow - defer TileManager notifications
var _pending_tile_notifications: Array[Vector2i] = []
var _processing_notifications: bool = false

# Player tracking
var _player_node: Node3D = null
var _last_player_position: Vector3 = Vector3.ZERO

# Tile states
enum TileState {
	INACTIVE, # Tile exists but player not near
	CONNECTING, # Tile available for player to enter
	ACTIVE, # Player currently on this tile
	PREVIOUS # Tile player just came from
}

const TILE_SIZE: float = 20.0

func _ready() -> void:
	name = "TileStateManager"
	add_to_group("core_systems")
	require_systems(["MessageBus", "GameStateManager", "TileManager"])
	super._ready()

func _physics_process(delta: float) -> void:
	"""Check player position for tile transitions"""
	if _player_node and is_instance_valid(_player_node):
		_check_player_tile_position()

func _process(_delta: float) -> void:
	"""Process pending notifications to prevent stack overflow"""
	if not _processing_notifications and not _pending_tile_notifications.is_empty():
		_processing_notifications = true
		var next_position = _pending_tile_notifications.pop_front()
		_process_tile_notification(next_position)
		_processing_notifications = false

func _initialize_manager() -> void:
	"""Initialize connections to core systems"""
	_tile_manager = get_system_node("TileManager")
	if not _tile_manager:
		push_error("TileStateManager: Required core systems not found")
		return

	_connect_to_events()

	# Try to find player
	call_deferred("_find_player")

func _find_player() -> void:
	"""Find and cache player reference"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_node = players[0]
		_last_player_position = _player_node.global_position
	else:
		# Retry in a moment
		await get_tree().create_timer(0.5).timeout
		_find_player()

func _check_player_tile_position() -> void:
	"""Check if player has moved to a different tile"""
	if not _player_node or not is_instance_valid(_player_node) or not _player_node.is_inside_tree():
		return
	
	var player_pos = _player_node.global_position
	
	# Only check if player has moved significantly
	if player_pos.distance_to(_last_player_position) < 0.1:
		return
	
	_last_player_position = player_pos
	
	# Find which tile the player is closest to
	var closest_tile_pos: Vector2i = Vector2i(-9999, -9999)
	var closest_distance: float = INF
	
	for pos in _active_tiles.keys():
		var tile_data = _active_tiles[pos]
		var tile_node = tile_data.node
		
		if not is_instance_valid(tile_node):
			continue
		
		var tile_center = tile_node.global_position
		var distance = player_pos.distance_to(tile_center)
		
		# Check if player is within this tile's bounds
		if distance < _transition_threshold and distance < closest_distance:
			closest_distance = distance
			closest_tile_pos = pos
	
	# Check if we found a valid tile and it's different from current
	if closest_tile_pos != Vector2i(-9999, -9999) and closest_tile_pos != _current_player_tile:
		# Additional cooldown check
		var current_time = Time.get_unix_time_from_system()
		if current_time - _last_transition_time >= _transition_cooldown:
			_execute_tile_transition(closest_tile_pos)

func register_tile(tile_node: Node3D, position: Vector2i, initial_state: TileState = TileState.INACTIVE) -> void:
	"""
	Register a tile with the state manager
	
	@param tile_node: The tile node to register
	@param position: Grid position of the tile
	@param initial_state: Initial state for the tile
	"""
	var tile_data = {
		"node": tile_node,
		"state": initial_state,
		"last_changed": Time.get_unix_time_from_system(),
		"position": position
	}
	
	_active_tiles[position] = tile_data
	_setup_tile_for_state(tile_node, position, initial_state)
	

func set_tile_state(position: Vector2i, new_state: TileState) -> bool:
	"""
	Change a tile's state
	
	@param position: Grid position of tile
	@param new_state: New state to set
	@return: True if state was changed
	"""
	if not _active_tiles.has(position):
		push_warning("TileStateManager: Cannot set state for unregistered tile at " + str(position))
		return false
	
	var tile_data = _active_tiles[position]
	var old_state = tile_data.state
	
	if old_state == new_state:
		return false # No change needed
	
	tile_data.state = new_state
	tile_data.last_changed = Time.get_unix_time_from_system()
	
	_setup_tile_for_state(tile_data.node, position, new_state)
	
	
	# Emit state change event (but avoid recursive loops)
	call_deferred("_emit_state_change_event", tile_data.node, position, _get_state_name(old_state), _get_state_name(new_state))
	
	return true

func _emit_state_change_event(tile_node: Node3D, position: Vector2i, old_state_name: String, new_state_name: String) -> void:
	"""Safely emit state change event"""
	emit_event("tile_state_changed", [tile_node, position, old_state_name, new_state_name])

func _setup_tile_for_state(tile_node: Node3D, position: Vector2i, state: TileState) -> void:
	"""
	Setup tile node for its current state
	
	@param tile_node: Tile node to setup
	@param position: Grid position
	@param state: State to setup for
	"""
	# Always remove old detector first
	_remove_transition_detector(position)
	
	match state:
		TileState.INACTIVE:
			pass # No detector needed
		
		TileState.CONNECTING:
			# We're using position-based detection now, so no Area3D needed
			if tile_node.has_method("set_as_connecting_tile"):
				tile_node.set_as_connecting_tile()
		
		TileState.ACTIVE:
			if tile_node.has_method("set_as_active_tile"):
				tile_node.set_as_active_tile()
		
		TileState.PREVIOUS:
			# Previous tiles can be re-entered
			if tile_node.has_method("set_as_past_tile"):
				tile_node.set_as_past_tile()

func _create_transition_detector(tile_node: Node3D, position: Vector2i) -> void:
	"""
	DEPRECATED - Using position-based detection instead
	Create transition detector for a tile
	
	@param tile_node: Tile to create detector for
	@param position: Grid position of tile
	"""
	pass # No longer using Area3D detectors

func _remove_transition_detector(position: Vector2i) -> void:
	"""
	Remove transition detector for a tile if it exists
	
	@param position: Grid position of tile
	"""
	if _tile_transition_detectors.has(position):
		var detector = _tile_transition_detectors[position]
		if is_instance_valid(detector):
			detector.queue_free()
		_tile_transition_detectors.erase(position)

func _execute_tile_transition(new_tile_position: Vector2i) -> void:
	"""
	Execute transition to new tile
	
	@param new_tile_position: Position of tile being entered
	"""
	var old_tile_position = _current_player_tile
	
	
	_last_transition_time = Time.get_unix_time_from_system()
	_previous_player_tile = _current_player_tile
	_current_player_tile = new_tile_position
	
	# Update state manager's tracking
	if _state_manager:
		_state_manager.set_state("current_tile_position", new_tile_position)
		
		# Increment tiles explored counter (only for new tiles, not revisits)
		if old_tile_position != Vector2i(-1000, -1000): # Not initial spawn
			var current_tiles_explored = _state_manager.get_state("tiles_explored")
			if current_tiles_explored == null:
				current_tiles_explored = 0
			_state_manager.set_state("tiles_explored", current_tiles_explored + 1)
	
	# Update tile states
	_update_tile_states_for_transition(old_tile_position, new_tile_position)
	
	# Get player and new tile for events
	var new_tile_data = _active_tiles.get(new_tile_position, {})
	var new_tile_node = new_tile_data.get("node", null)
	
	# Emit transition events
	if new_tile_node and _player_node:
		emit_event("tile_entered", [new_tile_node, new_tile_position, _player_node])
	
	emit_event("player_moved", [old_tile_position, new_tile_position])
	
	# Queue TileManager notification to prevent stack overflow
	# _queue_tile_notification(new_tile_position)
	if _tile_manager and _tile_manager.has_method("on_player_entered_tile"):
		_tile_manager.call_deferred("on_player_entered_tile", new_tile_position)

func _queue_tile_notification(position: Vector2i) -> void:
	"""
	Queue tile notification to prevent stack overflow
	
	@param position: Tile position to notify about
	"""
	if position not in _pending_tile_notifications:
		_pending_tile_notifications.append(position)

func _process_tile_notification(tile_position: Vector2i) -> void:
	"""
	Process a single tile notification
	
	@param tile_position: Position to notify TileManager about
	"""
	if _tile_manager and _tile_manager.has_method("on_player_entered_tile"):
		_tile_manager.on_player_entered_tile(tile_position)

func _update_tile_states_for_transition(old_pos: Vector2i, new_pos: Vector2i) -> void:
	"""
	Update all tile states when player transitions
	
	@param old_pos: Previous tile position
	@param new_pos: New tile position
	"""
	
	# Set new tile as active
	set_tile_state(new_pos, TileState.ACTIVE)
	
	# Set old tile as previous (connecting)
	if _active_tiles.has(old_pos) and old_pos != Vector2i(-1000, -1000):
		set_tile_state(old_pos, TileState.PREVIOUS)
	
	# Set all other tiles as connecting if they're adjacent to active tile
	for pos in _active_tiles.keys():
		if pos != new_pos and pos != old_pos:
			if _is_adjacent_to(pos, new_pos):
				set_tile_state(pos, TileState.CONNECTING)
			else:
				set_tile_state(pos, TileState.INACTIVE)

func _is_adjacent_to(pos1: Vector2i, pos2: Vector2i) -> bool:
	"""
	Check if two positions are adjacent (Manhattan distance = 1)
	
	@param pos1: First position
	@param pos2: Second position
	@return: True if positions are adjacent
	"""
	var diff = pos1 - pos2
	return abs(diff.x) + abs(diff.y) == 1

func cleanup_tile(position: Vector2i) -> void:
	"""
	Remove tile from state management
	
	@param position: Position of tile to cleanup
	"""
	if _active_tiles.has(position):
		var tile_data = _active_tiles[position]
		var tile_node = tile_data.get("node", null)
		
		# Safely remove transition detector
		if is_instance_valid(tile_node):
			_remove_transition_detector(position)
		_active_tiles.erase(position)

func get_tile_state(position: Vector2i) -> TileState:
	"""
	Get current state of a tile
	
	@param position: Grid position of tile
	@return: Current tile state
	"""
	if not _active_tiles.has(position):
		return TileState.INACTIVE
	
	return _active_tiles[position].state

func get_current_player_tile() -> Vector2i:
	"""Get current player tile position"""
	return _current_player_tile

func get_previous_player_tile() -> Vector2i:
	"""Get previous player tile position"""
	return _previous_player_tile

func get_tile_node(position: Vector2i) -> Node3D:
	"""
	Get the tile node at the specified position
	
	@param position: Grid position of tile
	@return: Tile node or null if not found
	"""
	if not _active_tiles.has(position):
		return null
	
	var tile_data = _active_tiles[position]
	return tile_data.get("node", null)

func get_tiles_in_state(state: TileState) -> Array[Vector2i]:
	"""
	Get all tiles currently in a specific state
	
	@param state: State to search for
	@return: Array of tile positions in that state
	"""
	var positions: Array[Vector2i] = []
	for pos in _active_tiles.keys():
		if _active_tiles[pos].state == state:
			positions.append(pos)
	return positions

func set_initial_player_position(position: Vector2i) -> void:
	"""
	Set initial player position without triggering transitions
	
	@param position: Initial tile position
	"""
	_current_player_tile = position
	_previous_player_tile = Vector2i(-1000, -1000)
	
	if _active_tiles.has(position):
		set_tile_state(position, TileState.ACTIVE)
	
	# Also update state manager
	if _state_manager:
		_state_manager.set_state("current_tile_position", position)

func _get_state_name(state: TileState) -> String:
	"""Get string name for tile state"""
	match state:
		TileState.INACTIVE: return "INACTIVE"
		TileState.CONNECTING: return "CONNECTING"
		TileState.ACTIVE: return "ACTIVE"
		TileState.PREVIOUS: return "PREVIOUS"
		_: return "UNKNOWN"

func _connect_to_events() -> void:
	"""Connect to MessageBus events (game_started/game_ended from BaseManager)"""
	_message_bus.player_spawned.connect(_on_player_spawned)

func _on_game_started() -> void:
	"""Handle game start - reset state for new run"""
	# Clear all previous run state
	_active_tiles.clear()
	_find_player()

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end - cleanup all detectors"""
	for position in _tile_transition_detectors.keys():
		_remove_transition_detector(position)
	_active_tiles.clear()
	_pending_tile_notifications.clear()

func _on_player_spawned(player: Node3D) -> void:
	"""Handle player spawn"""
	_player_node = player
	_last_player_position = player.global_position

# Debug functions
func debug_print_tile_states() -> void:
	"""Debug function to print all tile states"""
	pass

func force_check_transition() -> void:
	"""Force a transition check (for debugging)"""
	if _player_node:
		_check_player_tile_position()
