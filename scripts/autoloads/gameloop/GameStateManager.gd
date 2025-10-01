extends Node
## Centralized game state management
## Single source of truth for all game state data

var _state := {
	"sanity": 100,
	"flags": {},
	"inventory": [],
	"visited_tiles": {},
	"visited_tiles_this_run": {},
	"puzzle_progress": {},
	"player_position": Vector2i.ZERO,
	"current_tile_id": "",
	"current_tile_position": Vector2i.ZERO,
	"tiles_explored": 0,
	"game_active": false,
	"run_data": {},
	"death_locations": [],
	"collected_items": [],
	"spawned_items": {}
}

var _state_history: Array[Dictionary] = []
var _max_history: int = 50
var _message_bus: Node

const MAX_SANITY := 100
const MIN_SANITY := 0

func _ready() -> void:
	name = "GameStateManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to other core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	if not _message_bus:
		push_error("GameStateManager: MessageBus not found")
		return
	
	_connect_to_events()
	_initialize_run_data()

func _connect_to_events() -> void:
	"""Connect to relevant MessageBus events"""
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.game_ended.connect(_on_game_ended)
	_message_bus.player_moved.connect(_on_player_moved)
	_message_bus.player_died.connect(_on_player_died)
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.tile_entered.connect(_on_tile_entered)
	_message_bus.puzzle_completed.connect(_on_puzzle_completed)

func get_state(key: String = "") -> Variant:
	"""
	Get state value or entire state
	
	@param key: Optional key for specific state value (empty for entire state)
	@return: State value or entire state dictionary
	"""
	if key.is_empty():
		return _state.duplicate(true)
	
	if not _state.has(key):
		push_warning("GameStateManager: Requested unknown state key '%s'" % key)
		return null
	
	return _state[key]

func set_state(key: String, value: Variant) -> bool:
	"""
	Set state value with validation
	
	@param key: State key to modify
	@param value: New value to set
	@return: True if state was changed successfully
	"""
	if not _state.has(key):
		push_warning("GameStateManager: Cannot set unknown state key '%s'" % key)
		return false
	
	if not _validate_state_change(key, value):
		push_error("GameStateManager: Invalid value for state key '%s'" % key)
		return false
	
	var old_value: Variant = _state[key]
	_state[key] = value
	
	_log_state_change(key, old_value, value)
	_notify_state_change(key, old_value, value)
	
	return true

func modify_sanity(delta: int) -> int:
	"""
	Modify sanity by delta amount with clamping
	
	@param delta: Amount to change sanity (positive or negative)
	@return: New sanity value after modification
	"""
	var old_sanity: int = _state.sanity
	var new_sanity := clampi(old_sanity + delta, MIN_SANITY, MAX_SANITY)
	
	if new_sanity != old_sanity:
		_state.sanity = new_sanity
		_check_sanity_thresholds(old_sanity, new_sanity)
		_message_bus.emit_event("sanity_changed", [old_sanity, new_sanity, new_sanity - old_sanity])
		
		# Trigger death if sanity reaches 0
		if new_sanity <= 0:
			_message_bus.emit_event("player_died", ["Fragmented", _state.current_tile_position, {"sanity_death": true}])
	
	return new_sanity

func set_flag(flag: String, value: bool = true) -> void:
	"""
	Set a game flag
	
	@param flag: Flag identifier
	@param value: Boolean value to set
	"""
	var old_value: bool = _state.flags.get(flag, false)
	if old_value != value:
		_state.flags[flag] = value
		_log_state_change("flag:" + flag, old_value, value)

func has_flag(flag: String) -> bool:
	"""
	Check if a flag is set
	
	@param flag: Flag identifier to check
	@return: True if flag is set and true
	"""
	return _state.flags.get(flag, false)

## DEPRECATED METHOD REMOVED - Use PlayerInventory.add_item() instead

## DEPRECATED INVENTORY METHODS REMOVED - Use PlayerInventory autoload instead

func record_death_location(position: Vector2i, cause: String) -> void:
	"""
	Record a death location for echo spawning
	
	@param position: Grid position where death occurred
	@param cause: Cause of death string
	"""
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	var current_inventory = []
	if player_inventory and player_inventory.has_method("get_inventory"):
		current_inventory = player_inventory.get_inventory()
	else:
		current_inventory = _state.inventory.duplicate()
	
	# Special handling for start tile (0,0) - distribute inventory to adjacent tiles
	var final_position = position
	if position == Vector2i.ZERO and not current_inventory.is_empty():
		var adjacent_positions = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		# Pick a random adjacent tile for the backpack
		final_position = adjacent_positions[randi() % adjacent_positions.size()]
	
	var death_data := {
		"position": final_position,
		"original_death_position": position, # Keep track of actual death location
		"cause": cause,
		"inventory": current_inventory,
		"timestamp": Time.get_unix_time_from_system(),
		"run_id": _state.run_data.get("id", "unknown"),
		"used": false
	}
	
	_state.death_locations.append(death_data)
	
	if _state.death_locations.size() > 10:
		_state.death_locations.pop_front()

func get_unused_death_at_position(position: Vector2i) -> Dictionary:
	"""
	Get unused death data at specific position
	
	@param position: Grid position to check
	@return: Death data dictionary or empty if none found
	"""
	for death in _state.death_locations:
		if death.position == position and not death.used:
			return death
	return {}

func mark_death_used(position: Vector2i) -> void:
	"""
	Mark death location as used (backpack spawned)
	
	@param position: Grid position of death to mark
	"""
	for death in _state.death_locations:
		if death.position == position:
			death.used = true
			break

func reset_for_new_run() -> void:
	"""Reset state for new game run while preserving persistent data"""
	_state.sanity = MAX_SANITY
	_state.spawned_items.clear()
	_state.visited_tiles_this_run.clear()
	_state.player_position = Vector2i.ZERO
	_state.current_tile_id = ""
	_state.current_tile_position = Vector2i.ZERO
	_state.tiles_explored = 0
	_initialize_run_data()

func save_state_snapshot() -> Dictionary:
	"""
	Create a complete snapshot of current state
	
	@return: Deep copy of current state
	"""
	var snapshot := _state.duplicate(true)
	snapshot["timestamp"] = Time.get_unix_time_from_system()
	
	_state_history.append(snapshot)
	if _state_history.size() > _max_history:
		_state_history.pop_front()
	
	return snapshot

func load_state_snapshot(snapshot: Dictionary) -> bool:
	"""
	Load state from snapshot
	
	@param snapshot: State snapshot to load
	@return: True if loaded successfully
	"""
	if not snapshot.has("sanity") or not snapshot.has("inventory"):
		push_error("GameStateManager: Invalid state snapshot")
		return false
	
	_state = snapshot.duplicate(true)
	_message_bus.emit_event("inventory_changed", [_state.inventory, [], []])
	
	return true

func _initialize_run_data() -> void:
	"""Initialize or reset run-specific data"""
	_state.run_data = {
		"id": "RUN_%d" % Time.get_unix_time_from_system(),
		"start_time": Time.get_unix_time_from_system(),
		"death_type": "",
		"tiles_visited": 0,
		"items_collected": 0,
		"puzzles_completed": 0
	}

func _validate_state_change(key: String, value: Variant) -> bool:
	"""
	Validate state changes before applying
	
	@param key: State key being changed
	@param value: New value being set
	@return: True if change is valid
	"""
	match key:
		"sanity":
			return value is int and value >= MIN_SANITY and value <= MAX_SANITY
		"inventory":
			return value is Array
		"flags":
			return value is Dictionary
		"game_active":
			return value is bool
		_:
			return true

func _check_sanity_thresholds(old_value: int, new_value: int) -> void:
	"""
	Check and emit signals for sanity threshold crossings
	
	@param old_value: Previous sanity value
	@param new_value: New sanity value
	"""
	var thresholds := {
		"critical": 20,
		"low": 40,
		"normal": 60,
		"high": 80
	}
	
	for threshold_name in thresholds:
		var threshold_value: int = thresholds[threshold_name]
		
		if old_value > threshold_value and new_value <= threshold_value:
			_message_bus.emit_event("sanity_threshold_crossed", [threshold_name, new_value, true])
		elif old_value <= threshold_value and new_value > threshold_value:
			_message_bus.emit_event("sanity_threshold_crossed", [threshold_name, new_value, false])

func _notify_state_change(key: String, old_value: Variant, new_value: Variant) -> void:
	"""
	Notify other systems of state changes via MessageBus
	
	@param key: State key that changed
	@param old_value: Previous value
	@param new_value: New value
	"""
	match key:
		"current_tile_position":
			_message_bus.emit_event("player_moved", [old_value, new_value])
		"game_active":
			if new_value:
				_message_bus.emit_event("game_started", [])

func _log_state_change(key: String, old_value: Variant, new_value: Variant) -> void:
	"""
	Log state changes for debugging
	
	@param key: State key that changed
	@param old_value: Previous value
	@param new_value: New value
	"""

# === EVENT HANDLERS ===

func _on_game_started() -> void:
	"""Handle game start - reset state for new run"""
	reset_for_new_run()
	_state.game_active = true

func _on_game_ended(cause: String, data: Dictionary) -> void:
	_state.game_active = false
	_state.run_data.death_type = cause
	save_state_snapshot()

func _on_player_moved(from: Vector2i, to: Vector2i) -> void:
	_state.player_position = to

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	record_death_location(position, cause)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	# Just track the collection count - PlayerInventory handles the actual inventory
	_state.run_data.items_collected += 1

func _on_tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D) -> void:
	_state.current_tile_position = position
	_state.visited_tiles[str(position)] = true
	_state.visited_tiles_this_run[str(position)] = true
	_state.run_data.tiles_visited += 1

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	_state.puzzle_progress[puzzle_id] = "completed"
	_state.run_data.puzzles_completed += 1
