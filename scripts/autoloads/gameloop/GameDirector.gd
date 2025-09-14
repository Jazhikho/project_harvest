extends BaseManager
## Game Director - High-level game flow coordination
## Orchestrates game states and major events through MessageBus
## Refactored to use BaseManager for common initialization patterns

var _event_manager: Node

var _game_session_data: Dictionary = {}
var _maze_shift_timer: float = 0.0
var _current_difficulty: String = GameConstants.DIFFICULTY_NORMAL

# Game timing
var _session_start_time: float = 0.0
var _last_shift_time: float = 0.0

# Difficulty scaling
var _base_shift_interval: float = GameConstants.MAZE_SHIFT_INTERVAL_MIN
var _stressed_shift_interval: float = GameConstants.MAZE_SHIFT_INTERVAL_MAX / 6.0
var _current_shift_interval: float = GameConstants.MAZE_SHIFT_INTERVAL_MIN

func _ready() -> void:
	name = "GameDirector"
	add_to_group("core_systems")
	require_systems(["MessageBus", "GameStateManager", "EventManager"])
	super()

func _notification(what: int) -> void:
	"""Handle application quit as death if a game is active"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Check if a game is currently active
		if _state_manager and _state_manager.get_state("game_active"):
			end_game("Force Quit", {"forced_termination": true})
		# Let the quit proceed

func _initialize_manager() -> void:
	"""Initialize GameDirector-specific systems"""
	_event_manager = get_system_node("EventManager")
	_connect_to_events()
	_initialize_session()

func _process(delta: float) -> void:
	if not _is_game_active():
		return
	
	_update_maze_shift_timer(delta)
	_update_difficulty_scaling()

func start_new_game() -> void:
	"""Initialize a new game session"""
	
	_session_start_time = Time.get_unix_time_from_system()
	_maze_shift_timer = 0.0
	_current_difficulty = "normal"
	_current_shift_interval = _base_shift_interval
	
	_initialize_session_data()
	_message_bus.emit_event("game_started", [])
	
	# Process initial game events
	_event_manager.process_global_events("on_game_start", {})

func end_game(cause: String, additional_data: Dictionary = {}) -> void:
	"""
	End the current game session
	
	@param cause: Reason for game end
	@param additional_data: Additional data for game end
	"""
	
	var session_duration: float = Time.get_unix_time_from_system() - _session_start_time
	var end_data: Dictionary = {
		"cause": cause,
		"duration": session_duration,
		"difficulty": _current_difficulty,
		"session_data": _game_session_data.duplicate()
	}
	end_data.merge(additional_data)
	
	_message_bus.emit_event("game_ended", [cause, end_data])
	
	# Process game end events
	var context: Dictionary = {
		"cause": cause,
		"duration": session_duration,
		"data": end_data
	}
	_event_manager.process_global_events("on_game_end", context)

func pause_game(paused: bool) -> void:
	"""
	Pause or unpause the game
	
	@param paused: Whether game should be paused
	"""
	_message_bus.emit_event("game_paused", [paused])
	get_tree().paused = paused

func trigger_major_event(event_type: String, context: Dictionary = {}) -> void:
	"""
	Trigger a major game event
	
	@param event_type: Type of major event
	@param context: Event context data
	"""
	
	match event_type:
		"harvest_finale":
			_trigger_harvest_finale(context)
		"reality_break":
			_trigger_reality_break(context)
		"maze_collapse":
			_trigger_maze_collapse(context)
		"final_choice":
			_trigger_final_choice(context)
		_:
			push_warning("GameDirector: Unknown major event type - " + event_type)

func _trigger_harvest_finale(context: Dictionary) -> void:
	"""
	Trigger the harvest finale sequence
	
	@param context: Event context
	"""
	_message_bus.emit_event("screen_effect_requested", ["fade_black", 2.0, 1.0])
	_message_bus.emit_event("notification_requested", ["The harvest is complete...", 5.0, 3])
	
	await get_tree().create_timer(3.0).timeout
	end_game("Harvested", {"finale": true})

func _trigger_reality_break(context: Dictionary) -> void:
	"""
	Trigger reality break event
	
	@param context: Event context
	"""
	_message_bus.emit_event("weird_effect_triggered", ["reality_distortion", 1.0, Vector3.ZERO])
	_message_bus.emit_event("notification_requested", ["Reality fragments around you...", 4.0, 3])
	
	# Accelerate maze shifting
	_current_shift_interval *= 0.3
	_current_difficulty = "nightmare"

func _trigger_maze_collapse(context: Dictionary) -> void:
	"""
	Trigger maze collapse event
	
	@param context: Event context
	"""
	var player_pos: Vector2i = _state_manager.get_state("current_tile_position")
	
	for i in range(3):
		_message_bus.emit_event("maze_shift_triggered", [player_pos, i + 1, []])
		await get_tree().create_timer(2.0).timeout

func _trigger_final_choice(context: Dictionary) -> void:
	"""
	Trigger final choice event
	
	@param context: Event context
	"""
	_message_bus.emit_event("notification_requested", ["A choice must be made...", 5.0, 3])
	# This would trigger a UI choice system when implemented

func _update_maze_shift_timer(delta: float) -> void:
	"""
	Update maze shift timing
	
	@param delta: Frame time delta
	"""
	_maze_shift_timer += delta
	
	if _maze_shift_timer >= _current_shift_interval:
		_maze_shift_timer = 0.0
		_trigger_maze_shift()

func _trigger_maze_shift() -> void:
	"""Trigger periodic maze shift"""
	var player_pos: Vector2i = _state_manager.get_state("current_tile_position")
	var shift_center: Vector2i = _calculate_shift_center(player_pos)
	var shift_radius: int = _calculate_shift_radius()
	
	_message_bus.emit_event("maze_shift_triggered", [shift_center, shift_radius, []])
	_message_bus.emit_event("notification_requested", ["The maze reshapes itself...", 3.0, 2])
	
	_last_shift_time = Time.get_unix_time_from_system()
	
	# Process maze shift events
	var context: Dictionary = {
		"center": shift_center,
		"radius": shift_radius,
		"player_position": player_pos
	}
	_event_manager.process_global_events("on_maze_shift", context)

func _calculate_shift_center(player_pos: Vector2i) -> Vector2i:
	"""
	Calculate center point for maze shift
	
	@param player_pos: Current player position
	@return: Shift center position
	"""
	# Shift near but not at player position
	var offset: Vector2i = Vector2i(
		randi_range(-3, 3),
		randi_range(-3, 3)
	)
	return player_pos + offset

func _calculate_shift_radius() -> int:
	"""
	Calculate radius for maze shift based on difficulty
	
	@return: Shift radius
	"""
	match _current_difficulty:
		"easy": return 2
		"normal": return 3
		"hard": return 4
		"nightmare": return 5
		_: return 3

func _update_difficulty_scaling() -> void:
	"""Update game difficulty based on various factors"""
	var current_sanity: int = _state_manager.get_state("sanity")
	var session_time: float = Time.get_unix_time_from_system() - _session_start_time
	
	var old_difficulty: String = _current_difficulty
	
	# Difficulty based on sanity and time
	if current_sanity <= 20:
		_current_difficulty = "nightmare"
		_current_shift_interval = _stressed_shift_interval * 0.5
	elif current_sanity <= 40:
		_current_difficulty = "hard"
		_current_shift_interval = _stressed_shift_interval
	elif session_time > 300:  # 5 minutes
		_current_difficulty = "hard"
		_current_shift_interval = _stressed_shift_interval
	else:
		_current_difficulty = "normal"
		_current_shift_interval = _base_shift_interval
	
	# Notify of difficulty change
	if old_difficulty != _current_difficulty:
		_on_difficulty_changed(old_difficulty, _current_difficulty)

func _on_difficulty_changed(old_difficulty: String, new_difficulty: String) -> void:
	"""
	Handle difficulty changes
	
	@param old_difficulty: Previous difficulty level
	@param new_difficulty: New difficulty level
	"""
	var context: Dictionary = {
		"old_difficulty": old_difficulty,
		"new_difficulty": new_difficulty
	}
	
	_event_manager.process_global_events("on_difficulty_change", context)

func _initialize_session() -> void:
	"""Initialize session tracking data"""
	_game_session_data = {
		"start_time": Time.get_unix_time_from_system(),
		"shifts_triggered": 0,
		"major_events": [],
		"difficulty_changes": []
	}

func _initialize_session_data() -> void:
	"""Reset session data for new game"""
	_game_session_data = {
		"start_time": _session_start_time,
		"shifts_triggered": 0,
		"major_events": [],
		"difficulty_changes": []
	}

func _is_game_active() -> bool:
	"""
	Check if game is currently active
	
	@return: True if game is active
	"""
	return _state_manager.get_state("game_active")

# Public API for external systems

func get_current_difficulty() -> String:
	"""Get current difficulty level"""
	return _current_difficulty

func get_session_duration() -> float:
	"""Get current session duration in seconds"""
	if _session_start_time == 0.0:
		return 0.0
	return Time.get_unix_time_from_system() - _session_start_time

func get_session_data() -> Dictionary:
	"""Get current session data"""
	return _game_session_data.duplicate()

func is_finale_available() -> bool:
	"""Check if finale events can trigger"""
	return _state_manager.has_flag("final_event_available")

# Event handlers

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.player_died.connect(_on_player_died)
	_message_bus.sanity_threshold_crossed.connect(_on_sanity_threshold_crossed)
	_message_bus.puzzle_completed.connect(_on_puzzle_completed)
	_message_bus.weird_effect_triggered.connect(_on_weird_effect_triggered)
	_message_bus.maze_shift_triggered.connect(_on_maze_shift_triggered)

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	"""Handle player death"""
	end_game(cause, data)

func _on_sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool) -> void:
	"""Handle sanity threshold changes"""
	if threshold_name == "critical" and crossed_down:
		_current_difficulty = GameConstants.DIFFICULTY_NIGHTMARE
		emit_event("notification_requested", ["The walls close in...", GameConstants.NOTIFICATION_MEDIUM, GameConstants.UI_PRIORITY_HIGH])

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion"""
	_game_session_data.major_events.append({
		"type": "puzzle_completed",
		"puzzle_id": puzzle_id,
		"position": tile_pos,
		"time": Time.get_unix_time_from_system()
	})

func _on_weird_effect_triggered(effect_type: String, intensity: float, position: Vector3) -> void:
	"""Handle weird effects"""
	if effect_type == "maze_shift":
		_trigger_maze_shift()

func _on_maze_shift_triggered(center: Vector2i, radius: int, affected_tiles: Array) -> void:
	"""Handle maze shift events"""
	_game_session_data.shifts_triggered += 1
	
	# Trigger reality break after many shifts
	if _game_session_data.shifts_triggered >= 10:
		trigger_major_event("reality_break")
