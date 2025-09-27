extends Node
## Manages run persistence and death location tracking
## Handles saving/loading run data for echo system

var _message_bus: Node
var _state_manager: Node

var _save_file_path: String = "user://harvest_runs.json"
var _max_stored_runs: int = 10

func _ready() -> void:
	name = "HarvestLogger"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("HarvestLogger: Required core systems not found")
		return
	
	_connect_to_events()
	_load_previous_runs()

func log_run_completion(cause: String, final_position: Vector2i) -> void:
	"""
	Log completed run for future echo generation
	
	@param cause: Cause of run end (death type)
	@param final_position: Final player position
	"""
	var state: Dictionary = _state_manager.get_state()
	var run_data: Dictionary = state.get("run_data", {})
	
	var log_entry: Dictionary = {
		"run_id": run_data.get("id", "unknown"),
		"timestamp": Time.get_datetime_string_from_system(),
		"unix_time": Time.get_unix_time_from_system(),
		"cause": cause,
		"final_position": {"x": final_position.x, "y": final_position.y},
		"final_sanity": state.get("sanity", 0),
		"items_collected": run_data.get("items_collected", 0),
		"tiles_visited": run_data.get("tiles_visited", 0),
		"puzzles_completed": run_data.get("puzzles_completed", 0),
		"survival_time": Time.get_unix_time_from_system() - run_data.get("start_time", 0)
	}
	
	_save_run_log(log_entry)
	_message_bus.emit_event("echo_spawned", ["run_logged", Vector3.ZERO, log_entry])

func get_recent_runs(count: int = 5) -> Array:
	"""
	Get recent run data for echo generation
	
	@param count: Number of recent runs to return
	@return: Array of run data dictionaries
	"""
	var runs: Array = _load_run_history()
	return runs.slice(max(0, runs.size() - count))

func clear_run_history() -> void:
	"""Clear all stored run history (for testing/reset)"""
	if FileAccess.file_exists(_save_file_path):
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.remove("harvest_runs.json")
	_message_bus.emit_event("notification_requested", ["Run history cleared", 2.0, 1])

func _save_run_log(run_data: Dictionary) -> void:
	"""
	Save run data to persistent storage
	
	@param run_data: Run data to save
	"""
	var existing_runs: Array = _load_run_history()
	existing_runs.append(run_data)
	
	# Trim to max stored runs
	if existing_runs.size() > _max_stored_runs:
		existing_runs = existing_runs.slice(-_max_stored_runs)
	
	var save_data: Dictionary = {
		"version": "1.0",
		"runs": existing_runs,
		"last_updated": Time.get_datetime_string_from_system()
	}
	
	var file: FileAccess = FileAccess.open(_save_file_path, FileAccess.WRITE)
	if not file:
		push_error("HarvestLogger: Could not open save file for writing")
		return
	
	file.store_string(JSON.stringify(save_data))
	file.close()

func _load_run_history() -> Array:
	"""
	Load run history from persistent storage
	
	@return: Array of run data dictionaries
	"""
	if not FileAccess.file_exists(_save_file_path):
		return []
	
	var file: FileAccess = FileAccess.open(_save_file_path, FileAccess.READ)
	if not file:
		push_error("HarvestLogger: Could not open save file for reading")
		return []
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("HarvestLogger: Failed to parse save file")
		return []
	
	return json.data.get("runs", [])

func _load_previous_runs() -> void:
	"""Load previous runs and populate death locations in state"""
	var runs: Array = get_recent_runs()
	
	for run_data in runs:
		var pos: Vector2i = Vector2i(run_data.final_position.x, run_data.final_position.y)
		_state_manager.record_death_location(pos, run_data.cause)

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.game_ended.connect(_on_game_ended)
	_message_bus.player_died.connect(_on_player_died)

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end logging"""
	var final_pos: Vector2i = _state_manager.get_state("current_tile_position")
	log_run_completion(cause, final_pos)

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	"""Handle player death logging"""
	log_run_completion(cause, position)
