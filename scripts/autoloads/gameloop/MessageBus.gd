extends Node
## Central communication hub for game-wide events
## Decouples systems by providing event-based messaging with circular reference protection

# === GAME STATE EVENTS ===
signal game_started()
signal game_ended(cause: String, data: Dictionary)
signal game_paused(paused: bool)

# === PLAYER EVENTS ===
signal player_spawned(player_node: Node3D)
signal player_moved(from: Vector2i, to: Vector2i)
signal player_died(cause: String, position: Vector2i, data: Dictionary)
signal player_interacted(target: Node3D, interaction_type: String)

# === VISIBILITY EVENTS ===
signal player_looking_at(target: Node3D, target_type: String)
signal player_looked_away(target: Node3D, target_type: String)
signal visibility_changed(entity: Node3D, is_visible: bool, viewer: Node3D)

# === ITEM EVENTS ===
signal item_spawned(item_id: String, position: Vector3, tile_pos: Vector2i, item_data: Dictionary)
signal item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i)
signal item_used(item_id: String, target: Node3D, user: Node3D)
signal inventory_changed(new_inventory: Array, added_items: Array, removed_items: Array)

# === TILE EVENTS ===
signal tile_generated(tile_node: Node3D, position: Vector2i, tile_data: Dictionary)
signal tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D)
signal tile_exited(tile_node: Node3D, position: Vector2i, player: Node3D)
signal tile_cleaned_up(position: Vector2i, items_removed: Array)
signal tile_state_changed(tile_node: Node3D, position: Vector2i, old_state: String, new_state: String)

# === PUZZLE EVENTS ===
signal puzzle_started(puzzle_id: String, tile_pos: Vector2i)
signal puzzle_piece_placed(piece_id: String, puzzle_id: String, progress: float)
signal puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary)
signal puzzle_failed(puzzle_id: String, reason: String)

# === SANITY EVENTS ===
signal sanity_changed(old_value: int, new_value: int, delta: int)
signal sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool)
signal sanity_effect_triggered(effect_type: String, intensity: float)

# === MAZE EVENTS ===
signal maze_shift_triggered(center: Vector2i, radius: int, affected_tiles: Array)
signal maze_generated(size: Vector2i, seed_value: int)

# === WEIRD/HORROR EVENTS ===
signal weird_thing_collected(thing_id: String, position: Vector2i, effects: Dictionary)
signal weird_effect_triggered(effect_type: String, intensity: float, position: Vector3)
signal echo_spawned(echo_type: String, position: Vector3, data: Dictionary)

# === COMBAT/ENTITY EVENTS ===
signal entity_spawned(entity_type: String, entity_node: Node3D, position: Vector3)
signal entity_state_changed(entity_type: String, entity_node: Node3D, old_state: String, new_state: String)
signal entity_detected_player(entity_type: String, entity_node: Node3D, distance: float)
signal entity_lost_player(entity_type: String, entity_node: Node3D)
signal entity_stage_changed(entity_type: String, entity_node: Node3D, old_stage: int, new_stage: int)

# === UI EVENTS ===
signal notification_requested(message: String, duration: float, priority: int)
signal screen_effect_requested(effect_type: String, duration: float, intensity: float)
signal dialogue_started(dialogue_id: String, speaker: String)
signal dialogue_ended(dialogue_id: String)
signal show_interaction_prompt(message: String, target: Node3D)
signal hide_interaction_prompt(target: Node3D)
signal narration_requested(text: String, duration: float)
signal note_unlocked(note_id: String)  

# === SETTINGS EVENTS ===
signal setting_changed(category: String, key: String, old_value: Variant, new_value: Variant)
signal settings_category_reset(category: String)
signal settings_reset()

var _event_history: Array[Dictionary] = []
var _max_history: int = 100
var _debug_mode: bool = false

# Circular reference protection
var _emission_stack: Array[String] = []
var _max_stack_depth: int = 10

func _ready() -> void:
	name = "MessageBus"
	add_to_group("core_systems")

func emit_event(signal_name: String, args: Array = []) -> bool:
	"""
	Safely emit a signal with error handling and circular reference protection
	
	@param signal_name: Name of the signal to emit
	@param args: Array of arguments to pass with the signal (max 5)
	@return: True if signal was emitted successfully, false otherwise
	"""
	if not has_signal(signal_name):
		push_error("MessageBus: Unknown signal '%s'" % signal_name)
		return false
	
	if args.size() > 5:
		push_error("MessageBus: Too many arguments for signal '%s' (max 5)" % signal_name)
		return false
	
	# Check for circular references
	if _is_circular_emission(signal_name):
		push_warning("MessageBus: Circular emission detected for signal '%s', skipping" % signal_name)
		return false
	
	_emission_stack.append(signal_name)
	_log_event(signal_name, args)
	
	match args.size():
		0: emit_signal(signal_name)
		1: emit_signal(signal_name, args[0])
		2: emit_signal(signal_name, args[0], args[1])
		3: emit_signal(signal_name, args[0], args[1], args[2])
		4: emit_signal(signal_name, args[0], args[1], args[2], args[3])
		5: emit_signal(signal_name, args[0], args[1], args[2], args[3], args[4])
	
	_emission_stack.pop_back()
	return true

func _is_circular_emission(signal_name: String) -> bool:
	"""
	Check if emitting this signal would create a circular reference
	
	@param signal_name: Signal to check
	@return: True if circular reference detected
	"""
	if _emission_stack.size() >= _max_stack_depth:
		return true
	
	# Check if this signal is already in the current emission stack
	return signal_name in _emission_stack

func connect_event(signal_name: String, callable: Callable, flags: int = 0) -> int:
	"""
	Safely connect to a signal with validation
	
	@param signal_name: Name of the signal to connect to
	@param callable: The callable to connect
	@param flags: Optional connection flags
	@return: Error code (OK if successful)
	"""
	if not has_signal(signal_name):
		push_error("MessageBus: Cannot connect to unknown signal '%s'" % signal_name)
		return ERR_DOES_NOT_EXIST
	
	if is_connected(signal_name, callable):
		push_warning("MessageBus: Callable already connected to signal '%s'" % signal_name)
		return ERR_ALREADY_EXISTS
	
	return connect(signal_name, callable, flags)

func disconnect_event(signal_name: String, callable: Callable) -> void:
	"""
	Safely disconnect from a signal
	
	@param signal_name: Name of the signal to disconnect from
	@param callable: The callable to disconnect
	"""
	if has_signal(signal_name) and is_connected(signal_name, callable):
		disconnect(signal_name, callable)

func get_event_history(count: int = -1) -> Array[Dictionary]:
	"""
	Get recent event history for debugging
	
	@param count: Number of events to return (-1 for all)
	@return: Array of event dictionaries with signal name, args, and timestamp
	"""
	if count < 0 or count >= _event_history.size():
		return _event_history.duplicate()
	
	return _event_history.slice(-count)

func clear_event_history() -> void:
	"""Clear the event history log"""
	_event_history.clear()

func set_debug_mode(enabled: bool) -> void:
	"""
	Enable or disable debug mode for verbose event logging
	
	@param enabled: Whether debug mode should be enabled
	"""
	_debug_mode = enabled

func _log_event(signal_name: String, args: Array) -> void:
	"""
	Log event to history and optionally print debug info
	
	@param signal_name: Name of the emitted signal
	@param args: Arguments passed with the signal
	"""
	var event := {
		"signal": signal_name,
		"args": args.duplicate(),
		"timestamp": Time.get_ticks_msec(),
		"stack_depth": _emission_stack.size()
	}
	
	_event_history.append(event)
	
	if _event_history.size() > _max_history:
		_event_history.pop_front()
	
	if _debug_mode:
		var indent = "  ".repeat(_emission_stack.size())
		# Debug print removed - not referencing gameloop steps

func _format_args(args: Array) -> String:
	"""
	Format arguments array for debug printing
	
	@param args: Arguments to format
	@return: Formatted string representation
	"""
	var formatted := []
	for arg in args:
		formatted.append(str(arg))
	return ", ".join(formatted)

# Debug functions
func debug_print_emission_stack() -> void:
	"""Print current emission stack for debugging"""
	pass
