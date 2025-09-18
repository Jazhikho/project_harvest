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
	"spawned_items": {},
	"event_flags": {},  # NEW: Event progression tracking
	"completed_puzzles": [],  # NEW: Completed puzzle list
	"unlocked_notes": [],  # NEW: Available note sequence
	"current_note_index": 0,  # NEW: Next note to unlock
	"story_progress": 0  # NEW: Overall story progression (0-100)
}

var _state_history: Array[Dictionary] = []
var _max_history: int = 50
var _message_bus: Node

const MAX_SANITY := 100
const MIN_SANITY := 0
const INITIAL_NOTES_AVAILABLE := 5  # First 5 notes are available at start
const TOTAL_STORY_NOTES := 30  # Total research notes in sequence

# Story progression flags - these control major story beats
const STORY_FLAGS := {
	"intro_complete": 1,
	"first_puzzle_complete": 10,
	"second_puzzle_complete": 20,
	"third_puzzle_complete": 30,
	"truth_revealed": 40,
	"ending_unlocked": 50
}

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
	_initialize_note_system()

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

# === NEW EVENT FLAG SYSTEM ===

func set_event_flag(flag_name: String, value: bool = true) -> void:
	"""
	Set an event progression flag
	
	@param flag_name: Event flag identifier
	@param value: Boolean value to set
	"""
	var old_value: bool = _state.event_flags.get(flag_name, false)
	if old_value != value:
		_state.event_flags[flag_name] = value
		_log_state_change("event_flag:" + flag_name, old_value, value)
		
		# Check for story progression updates
		_check_story_progression()
		
		# Notify other systems of event flag changes
		if _message_bus:
			_message_bus.emit_event("event_flag_changed", [flag_name, value])

func has_event_flag(flag_name: String) -> bool:
	"""
	Check if an event flag is set
	
	@param flag_name: Event flag identifier to check
	@return: True if flag is set and true
	"""
	return _state.event_flags.get(flag_name, false)

func get_event_flags() -> Dictionary:
	"""
	Get all event flags
	
	@return: Dictionary of all event flags
	"""
	return _state.event_flags.duplicate()

# === PUZZLE SYSTEM ===

func get_puzzle_progress(puzzle_id: String) -> int:
	"""
	Get progress for a specific puzzle (number of pieces placed)
	
	@param puzzle_id: Puzzle identifier
	@return: Number of pieces placed (0 if not started)
	"""
	return _state.puzzle_progress.get(puzzle_id, 0)

func set_puzzle_progress(puzzle_id: String, pieces_placed: int) -> void:
	"""
	Set progress for a specific puzzle
	
	@param puzzle_id: Puzzle identifier  
	@param pieces_placed: Number of pieces placed
	"""
	var old_progress: int = _state.puzzle_progress.get(puzzle_id, 0)
	if old_progress != pieces_placed:
		_state.puzzle_progress[puzzle_id] = pieces_placed
		_log_state_change("puzzle:" + puzzle_id, old_progress, pieces_placed)
		
		# Notify puzzle progress change
		if _message_bus:
			_message_bus.emit_event("puzzle_progress_changed", [puzzle_id, pieces_placed, old_progress])

func complete_puzzle(puzzle_id: String) -> void:
	"""
	Mark a puzzle as completed
	
	@param puzzle_id: Puzzle identifier to complete
	"""
	if puzzle_id not in _state.completed_puzzles:
		_state.completed_puzzles.append(puzzle_id)
		
		# Set event flag for puzzle completion
		set_event_flag(puzzle_id + "_complete", true)
		
		# Check if all puzzles are completed
		if _state.completed_puzzles.size() >= 3:  # Assuming 3 total puzzles
			set_event_flag("all_puzzles_complete", true)
			_update_story_progress(STORY_FLAGS.ending_unlocked)

func is_puzzle_completed(puzzle_id: String) -> bool:
	"""
	Check if a puzzle is completed
	
	@param puzzle_id: Puzzle identifier to check
	@return: True if puzzle is completed
	"""
	return puzzle_id in _state.completed_puzzles

func get_completed_puzzles() -> Array[String]:
	"""
	Get list of completed puzzles
	
	@return: Array of completed puzzle IDs
	"""
	var result: Array[String] = []
	result.assign(_state.completed_puzzles.duplicate())
	return result

# === NOTE SEQUENCE SYSTEM ===

func _initialize_note_system() -> void:
	"""Initialize the note unlocking system"""
	# Generate initial available notes (note_1 through note_5)
	_state.unlocked_notes.clear()
	for i in range(1, INITIAL_NOTES_AVAILABLE + 1):
		_state.unlocked_notes.append("note_%d" % i)
	
	_state.current_note_index = INITIAL_NOTES_AVAILABLE

func unlock_next_note() -> String:
	"""
	Unlock the next note in sequence when one is collected
	
	@return: ID of newly unlocked note, or empty string if none to unlock
	"""
	if _state.current_note_index < TOTAL_STORY_NOTES:
		_state.current_note_index += 1
		var next_note_id := "note_%d" % _state.current_note_index
		
		if next_note_id not in _state.unlocked_notes:
			_state.unlocked_notes.append(next_note_id)
			
			# Notify systems that a new note is available
			if _message_bus:
				_message_bus.emit_event("note_unlocked", [next_note_id])
			
			return next_note_id
	
	return ""

func get_unlocked_notes() -> Array[String]:
	"""
	Get list of currently unlocked notes
	
	@return: Array of unlocked note IDs
	"""
	var result: Array[String] = []
	result.assign(_state.unlocked_notes.duplicate())
	return result

func is_note_unlocked(note_id: String) -> bool:
	"""
	Check if a specific note is unlocked and available for spawning
	
	@param note_id: Note identifier to check
	@return: True if note is unlocked
	"""
	return note_id in _state.unlocked_notes

# === STORY PROGRESSION ===

func _update_story_progress(new_progress: int) -> void:
	"""
	Update overall story progress
	
	@param new_progress: New progress value (0-100)
	"""
	if new_progress > _state.story_progress:
		var old_progress: int = _state.story_progress
		_state.story_progress = new_progress
		
		if _message_bus:
			_message_bus.emit_event("story_progress_changed", [old_progress, new_progress])

func _check_story_progression() -> void:
	"""Check event flags and update story progression accordingly"""
	# Check major story beats
	if has_event_flag("first_puzzle_complete") and _state.story_progress < STORY_FLAGS.first_puzzle_complete:
		_update_story_progress(STORY_FLAGS.first_puzzle_complete)
	
	if has_event_flag("second_puzzle_complete") and _state.story_progress < STORY_FLAGS.second_puzzle_complete:
		_update_story_progress(STORY_FLAGS.second_puzzle_complete)
	
	if has_event_flag("third_puzzle_complete") and _state.story_progress < STORY_FLAGS.third_puzzle_complete:
		_update_story_progress(STORY_FLAGS.third_puzzle_complete)

func get_story_progress() -> int:
	"""
	Get current story progress
	
	@return: Story progress value (0-100)
	"""
	return _state.story_progress

func can_access_ending() -> bool:
	"""
	Check if player can access the ending
	
	@return: True if all requirements for ending are met
	"""
	return has_event_flag("all_puzzles_complete") and _state.story_progress >= STORY_FLAGS.ending_unlocked

# === EXISTING METHODS (unchanged) ===

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
		"original_death_position": position,  # Keep track of actual death location
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
	_state.inventory.clear()
	_state.collected_items.clear()
	_state.spawned_items.clear()
	_state.visited_tiles_this_run.clear()
	_state.player_position = Vector2i.ZERO
	_state.current_tile_id = ""
	_state.current_tile_position = Vector2i.ZERO
	_state.tiles_explored = 0
	_state.puzzle_progress.clear()
	
	# Reset event flags but preserve story progression across runs
	_state.event_flags.clear()
	_state.completed_puzzles.clear()
	
	# Reset note system
	_initialize_note_system()
	
	_initialize_run_data()
	
	_message_bus.emit_event("inventory_changed", [[], [], []])

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
		"event_flags":
			return value is Dictionary
		"completed_puzzles":
			return value is Array
		"unlocked_notes":
			return value is Array
		"story_progress":
			return value is int and value >= 0 and value <= 100
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
	pass

# === EVENT HANDLERS ===

func _on_game_started() -> void:
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
	# Track the collection count
	_state.run_data.items_collected += 1
	
	# If it's a note, unlock the next one
	if item_id.begins_with("note_"):
		unlock_next_note()

func _on_tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D) -> void:
	_state.current_tile_position = position
	_state.visited_tiles[str(position)] = true
	_state.visited_tiles_this_run[str(position)] = true
	_state.run_data.tiles_visited += 1

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	complete_puzzle(puzzle_id)
	_state.run_data.puzzles_completed += 1
