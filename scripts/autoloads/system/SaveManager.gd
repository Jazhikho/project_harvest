extends Node

const SAVE_PATH = "user://save_data.sav"

var save_data: Dictionary = {
	"time_played": 0.0,
	"deaths": 0,
	"collectibles": [],
	"run_active": false,
	"last_position": Vector3.ZERO,
	"permanent_tiles": {},
	"event_flags": [],
	"settings": {},
	"puzzles": {},  # Puzzle states and completion
	"puzzle_items_used": []  # Items permanently used in puzzles
}

func _ready() -> void:
	# Connect to game events to manage run state
	call_deferred("_connect_to_events")
	load_game()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	var message_bus: Node = get_node_or_null("/root/MessageBus")
	if message_bus:
		if message_bus.has_signal("game_started"):
			message_bus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	"""Handle game start event"""
	start_run()

func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
	else:
		push_error("SaveManager: Failed to open save file for writing")

func load_game() -> void:
	if has_save_data():
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			save_data = file.get_var()
			file.close()
			
			# Ensure new keys exist
			if not save_data.has("puzzles"):
				save_data.puzzles = {}
			if not save_data.has("puzzle_items_used"):
				save_data.puzzle_items_used = []
		else:
			push_error("SaveManager: Failed to open save file for reading")

func delete_save() -> void:
	if has_save_data():
		DirAccess.remove_absolute(SAVE_PATH)
	_reset_save_data()

func _reset_save_data() -> void:
	save_data = {
		"time_played": 0.0,
		"deaths": 0,
		"collectibles": [],
		"run_active": false,
		"last_position": Vector3.ZERO,
		"permanent_tiles": {},
		"event_flags": [],
		"settings": {},
		"puzzles": {},
		"puzzle_items_used": []
	}

func start_run() -> void:
	"""Mark a run as active and save the state"""
	save_data.run_active = true
	save_game()

func record_death() -> void:
	save_data.deaths += 1
	save_data.run_active = false
	save_game()

func is_puzzle_completed(puzzle_id: String) -> bool:
	"""Check if a puzzle has been completed (persists across runs)"""
	return save_data.puzzles.get(puzzle_id, {}).get("completed", false)

func mark_puzzle_completed(puzzle_id: String) -> void:
	"""Mark a puzzle as permanently completed"""
	if not save_data.puzzles.has(puzzle_id):
		save_data.puzzles[puzzle_id] = {}
	
	save_data.puzzles[puzzle_id]["completed"] = true
	save_data.puzzles[puzzle_id]["completion_time"] = Time.get_unix_time_from_system()
	save_game()

func is_puzzle_item_used(item_id: String) -> bool:
	"""Check if a puzzle item has been permanently used"""
	return item_id in save_data.puzzle_items_used

func mark_puzzle_item_used(puzzle_id: String, item_id: String) -> void:
	"""Mark an item as permanently used in a puzzle"""
	if item_id not in save_data.puzzle_items_used:
		save_data.puzzle_items_used.append(item_id)
	save_game()

func get_puzzle_state(puzzle_id: String) -> Dictionary:
	"""Get the current state of a puzzle"""
	return save_data.puzzles.get(puzzle_id, {})

func set_puzzle_state(puzzle_id: String, state: Dictionary) -> void:
	"""Set the state of a puzzle"""
	save_data.puzzles[puzzle_id] = state
	save_game()
