extends BaseManager
## Event Manager - Processes events.json triggers and conditions
## Focused solely on event processing, delegates everything else to appropriate systems

var _event_data: Dictionary = {}
var _processed_events: Dictionary = {} # Track once/once_per_run events

const EVENTS_DATA_PATH: String = "res://data/events.json"

func _ready() -> void:
	name = "EventManager"
	add_to_group("game_systems")
	require_systems(["MessageBus", "GameStateManager"])
	super._ready()

func _initialize_manager() -> void:
	"""Initialize connections and load event data"""
	_connect_to_events()

func _create_default_events() -> void:
	"""Create minimal default events as fallback"""
	_event_data = {
		"version": "1.0",
		"tiles": {},
		"speeches": {},
		"notes": {},
		"echo_templates": []
	}

func process_tile_events(tile_id: String, trigger: String, context: Dictionary = {}) -> void:
	"""
	Process events for a specific tile and trigger
	
	@param tile_id: Tile identifier
	@param trigger: Event trigger (on_enter, on_exit, on_interact)
	@param context: Additional context data
	"""
	var tile_data: Dictionary = _event_data.get("tiles", {}).get(tile_id, {})
	if tile_data.is_empty():
		return
	
	var events: Array = tile_data.get("events", [])
	for event in events:
		if event.get("trigger", "") == trigger:
			_process_single_event(event, context)

func process_global_events(trigger: String, context: Dictionary = {}) -> void:
	"""
	Process global events with specific trigger
	
	@param trigger: Event trigger type
	@param context: Event context data
	"""
	var global_events: Array = _event_data.get("global_events", [])
	for event in global_events:
		if event.get("trigger", "") == trigger:
			_process_single_event(event, context)

func _process_single_event(event: Dictionary, context: Dictionary) -> void:
	"""
	Process a single event if conditions are met
	
	@param event: Event data from JSON
	@param context: Context data for condition checking
	"""
	var event_id: String = event.get("id", "")
	
	# Check if event should be processed
	if not _check_event_conditions(event, context):
		return
	
	# Mark event as processed if needed
	_mark_event_processed(event)
	
	# Execute event actions
	var actions: Array = event.get("actions", [])
	for action in actions:
		_execute_event_action(action, context)

func _check_event_conditions(event: Dictionary, context: Dictionary) -> bool:
	"""
	Check if event conditions are satisfied
	
	@param event: Event data
	@param context: Context data
	@return: True if conditions are met
	"""
	var conditions: Dictionary = event.get("conditions", {})
	if conditions.is_empty():
		return true
	
	var event_id: String = event.get("id", "")
	
	# Check once/once_per_run restrictions
	if conditions.get("once", false):
		if _processed_events.get("once_" + event_id, false):
			return false
	
	if conditions.get("once_per_run", false):
		if _processed_events.get("run_" + event_id, false):
			return false
	
	# Check sanity conditions
	var current_sanity: int = _state_manager.get_state("sanity")
	
	if conditions.has("sanity_min") and current_sanity < conditions.sanity_min:
		return false
	
	if conditions.has("sanity_max") and current_sanity > conditions.sanity_max:
		return false
	
	# Check flag conditions
	if conditions.has("flags_all"):
		for flag in conditions.flags_all:
			if not _state_manager.has_flag(flag):
				return false
	
	if conditions.has("flags_any"):
		var has_any: bool = false
		for flag in conditions.flags_any:
			if _state_manager.has_flag(flag):
				has_any = true
				break
		if not has_any:
			return false
	
	if conditions.has("flags_not"):
		for flag in conditions.flags_not:
			if _state_manager.has_flag(flag):
				return false
	
	# Check inventory conditions
	if conditions.has("has_items"):
		for item_id in conditions.has_items:
			if not _state_manager.has_item(item_id):
				return false
	
	return true

func _mark_event_processed(event: Dictionary) -> void:
	"""
	Mark event as processed for once/once_per_run tracking
	
	@param event: Event data
	"""
	var conditions: Dictionary = event.get("conditions", {})
	var event_id: String = event.get("id", "")
	
	if conditions.get("once", false):
		_processed_events["once_" + event_id] = true
	
	if conditions.get("once_per_run", false):
		_processed_events["run_" + event_id] = true

func _execute_event_action(action: Dictionary, context: Dictionary) -> void:
	"""
	Execute a single event action by delegating to appropriate system
	
	@param action: Action data from event
	@param context: Event context
	"""
	var action_type: String = action.get("action", "")
	
	match action_type:
		"adjust_sanity":
			var amount: int = action.get("amount", 0)
			_state_manager.modify_sanity(amount)
		
		"set_flag":
			var flag: String = action.get("flag", "")
			var value: bool = action.get("value", true)
			_state_manager.set_flag(flag, value)
		
		"show_note":
			var note_id: String = action.get("id", "")
			_show_note(note_id)
		
		"show_speech":
			var speech_id: String = action.get("id", "")
			_show_speech(speech_id)
		
		"spawn_entity":
			var entity_type: String = action.get("type", "")
			var position: Vector3 = _get_spawn_position(action, context)
			emit_event("entity_spawned", [entity_type, null, position])
		
		"give_item":
			var item_id: String = action.get("id", "")
			emit_event("item_collected", [item_id, null, Vector2i.ZERO])
		
		"trigger_effect":
			var effect_type: String = action.get("type", "")
			var intensity: float = action.get("intensity", 0.5)
			emit_event("weird_effect_triggered", [effect_type, intensity, Vector3.ZERO])
		
		"show_notification":
			var message: String = action.get("message", "")
			var duration: float = action.get("duration", 3.0)
			var priority: int = action.get("priority", 1)
			emit_event("notification_requested", [message, duration, priority])
		
		"screen_effect":
			var effect_type: String = action.get("type", "")
			var duration: float = action.get("duration", 2.0)
			var intensity: float = action.get("intensity", 0.5)
			emit_event("screen_effect_requested", [effect_type, duration, intensity])
		
		"maze_shift":
			var center: Vector2i = _get_position_from_context(context)
			var radius: int = action.get("radius", 3)
			emit_event("maze_shift_triggered", [center, radius, []])
		
		"end_game":
			var cause: String = action.get("cause", "Unknown")
			var data: Dictionary = action.get("data", {})
			emit_event("game_ended", [cause, data])
		
		"play_sound":
			var sound_id: String = action.get("id", "")
		
		_:
			push_warning("EventManager: Unknown action type - " + action_type)

func _show_note(note_id: String) -> void:
	"""
	Display a note to the player
	
	@param note_id: Note identifier
	"""
	var note_text: String = _get_note_text(note_id)
	if not note_text.is_empty():
		emit_event("note_shown", [note_id, note_text])
		emit_event("notification_requested", ["Found research note...", 2.0, 1])

func _show_speech(speech_id: String) -> void:
	"""
	Display speech text to the player
	
	@param speech_id: Speech identifier
	"""
	var speech_text: String = _event_data.get("speeches", {}).get(speech_id, "")
	if not speech_text.is_empty():
		emit_event("speech_played", [speech_id, speech_text])
		emit_event("notification_requested", [speech_text, 4.0, 2])

func _get_note_text(note_id: String) -> String:
	"""
	Get note text from various note categories
	
	@param note_id: Note identifier
	@return: Note text or empty string
	"""
	var note_categories: Array[String] = ["dr_a_logs", "dr_a_drafts", "staff_memos", "notes_env"]
	
	for category in note_categories:
		var notes: Array = _event_data.get(category, [])
		for note in notes:
			if note.get("id", "") == note_id:
				return note.get("text", "")
	
	return ""

func _get_spawn_position(action: Dictionary, context: Dictionary) -> Vector3:
	"""
	Get spawn position from action data or context
	
	@param action: Action data
	@param context: Event context
	@return: Spawn position
	"""
	if action.has("position"):
		var pos_data: Dictionary = action.position
		return Vector3(pos_data.get("x", 0), pos_data.get("y", 0), pos_data.get("z", 0))
	
	# Default to player position or tile center
	var tile_pos: Vector2i = _get_position_from_context(context)
	return Vector3(tile_pos.x * 20.0, 0, tile_pos.y * 20.0)

func _get_position_from_context(context: Dictionary) -> Vector2i:
	"""
	Extract position from context data
	
	@param context: Event context
	@return: Grid position
	"""
	if context.has("tile_position"):
		return context.tile_position
	
	return _state_manager.get_state("current_tile_position")

func reset_for_new_run() -> void:
	"""Reset run-specific event tracking"""
	var keys_to_remove: Array[String] = []
	for key in _processed_events.keys():
		if key.begins_with("run_"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_processed_events.erase(key)

func get_event_data(category: String = "") -> Dictionary:
	"""
	Get event data for external systems
	
	@param category: Specific category to get (empty for all data)
	@return: Event data dictionary
	"""
	if category.is_empty():
		return _event_data.duplicate(true)
	
	return _event_data.get(category, {})

func _connect_to_events() -> void:
	"""Connect to MessageBus events (game_started/game_ended from BaseManager)"""
	_message_bus.tile_entered.connect(_on_tile_entered)
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.player_interacted.connect(_on_player_interacted)
	_message_bus.sanity_threshold_crossed.connect(_on_sanity_threshold_crossed)
	_message_bus.puzzle_completed.connect(_on_puzzle_completed)

func _on_tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D) -> void:
	"""Handle tile entry events"""
	var tile_id: String = ""
	if tile_node.has_meta("scene_path"):
		tile_id = tile_node.get_meta("scene_path", "").get_file().get_basename()
	
	var context: Dictionary = {
		"tile_position": position,
		"tile_node": tile_node,
		"player": player
	}
	
	process_tile_events(tile_id, "on_enter", context)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""Handle item collection events"""
	var context: Dictionary = {
		"item_id": item_id,
		"collector": collector,
		"tile_position": tile_pos
	}
	
	process_global_events("on_item_collected", context)

func _on_player_interacted(target: Node3D, interaction_type: String) -> void:
	"""Handle player interaction events"""
	var context: Dictionary = {
		"target": target,
		"interaction_type": interaction_type
	}
	
	process_global_events("on_interact", context)

func _on_sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool) -> void:
	"""Handle sanity threshold events"""
	if not crossed_down:
		return
	
	var context: Dictionary = {
		"threshold": threshold_name,
		"sanity": value
	}
	
	process_global_events("on_sanity_" + threshold_name, context)

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion events"""
	var context: Dictionary = {
		"puzzle_id": puzzle_id,
		"tile_position": tile_pos,
		"reward": reward
	}
	
	process_global_events("on_puzzle_completed", context)

func _on_game_started() -> void:
	"""Handle game start"""
	reset_for_new_run()
	process_global_events("on_game_start", {})
