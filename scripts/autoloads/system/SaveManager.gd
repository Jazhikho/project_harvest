extends Node

const SAVE_PATH = "user://save_data.sav"

# Track if save existed at scene load (before start_run creates it)
var had_existing_save: bool = false

# Signal emitted when save data is loaded (for continue games)
signal save_data_loaded()

var save_data: Dictionary = {
	"time_played": 0.0,
	"tiles_explored": 0,
	"deaths": 0,
	"collectibles": [],
	"backpack_inventory": [],
	"run_active": false,
	"last_position": Vector3.ZERO,
	"permanent_tiles": {},
	"event_flags": [],
	"settings": {},
	"puzzles": {},
	"puzzle_items_used": [],
	"controls_shown_this_run": false
}

func _ready() -> void:
	# Connect to game events to manage run state
	call_deferred("_connect_to_events")
	# Note: had_existing_save is set in _on_game_started() when game scene loads
	load_game()
	# Connect to settings events for audio settings persistence
	call_deferred("_connect_to_settings")

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	var message_bus: Node = get_node_or_null("/root/MessageBus")
	if message_bus:
		if message_bus.has_signal("game_started"):
			message_bus.game_started.connect(_on_game_started)
		if message_bus.has_signal("item_collected"):
			message_bus.item_collected.connect(_on_item_collected)

func _connect_to_settings() -> void:
	"""Connect to SettingsManager for audio settings persistence"""
	var message_bus: Node = get_node_or_null("/root/MessageBus")
	if message_bus and message_bus.has_signal("setting_changed"):
		message_bus.connect_event("setting_changed", _on_setting_changed)
	elif message_bus:
		# Wait for SettingsManager to be ready
		await get_tree().process_frame
		call_deferred("_connect_to_settings")

func _on_game_started() -> void:
	"""Handle game start event"""
	# Update the flag before start_run creates a new save
	had_existing_save = has_save_data()
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
			
			# Ensure all keys exist (for backwards compatibility with old saves)
			if not save_data.has("puzzles"):
				save_data.puzzles = {}
			if not save_data.has("puzzle_items_used"):
				save_data.puzzle_items_used = []
			if not save_data.has("backpack_inventory"):
				save_data.backpack_inventory = []
			if not save_data.has("collectibles"):
				save_data.collectibles = []
			if not save_data.has("controls_shown_this_run"):
				save_data.controls_shown_this_run = false
			if not save_data.has("tiles_explored"):
				save_data.tiles_explored = 0
			if not save_data.has("settings"):
				save_data.settings = {}
			if not save_data.settings.has("audio"):
				save_data.settings.audio = {}
			
			# Save the updated structure
			save_game()
			
			# Audio settings are now handled by SettingsManager directly
			# No need to load them from save data
			
			# Emit signal that save data is loaded (important for continue games)
			# Only emit if this is not the initial app startup load
			if get_tree().current_scene and get_tree().current_scene.name != "Main":
				save_data_loaded.emit()
		else:
			push_error("SaveManager: Failed to open save file for reading")

func delete_save() -> void:
	if has_save_data():
		DirAccess.remove_absolute(SAVE_PATH)
	_reset_save_data()

func _reset_save_data() -> void:
	save_data = {
		"time_played": 0.0,
		"tiles_explored": 0,
		"deaths": 0,
		"collectibles": [],
		"backpack_inventory": [],
		"run_active": false,
		"last_position": Vector3.ZERO,
		"permanent_tiles": {},
		"event_flags": [],
		"settings": {},
		"puzzles": {},
		"puzzle_items_used": [],
		"controls_shown_this_run": false
	}

func start_run() -> void:
	"""Mark a run as active and save the state"""
	if save_data.collectibles.size() > 0:
		_transfer_collectibles_to_backpack()
	save_data.run_active = true
	save_data.controls_shown_this_run = false
	save_game()

func mark_controls_shown() -> void:
	"""Mark that controls have been shown this run"""
	save_data.controls_shown_this_run = true
	save_game()
	
func should_show_controls() -> bool:
	"""Check if controls should be shown this run"""
	return not save_data.get("controls_shown_this_run", false)

func record_death() -> void:
	"""Record death and save current run statistics"""
	_transfer_collectibles_to_backpack()
	save_data.deaths += 1
	save_data.run_active = false
	
	# Save current run statistics
	var state_manager = get_node_or_null("/root/GameStateManager")
	var game_director = get_node_or_null("/root/GameDirector")
	
	if state_manager:
		# Save tiles explored from current run
		var tiles_explored = state_manager.get_state("tiles_explored")
		if tiles_explored > 0:
			save_data["tiles_explored"] = tiles_explored
	
	if game_director and game_director.has_method("get_session_duration"):
		# Save time played from current session
		var session_time = game_director.get_session_duration()
		if session_time > 0:
			save_data["time_played"] = session_time
	
	save_game()
	
func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""
	Handle item collection - save to collectibles
	
	@param item_id: ID of collected item
	@param collector: Node that collected (usually player)
	@param tile_pos: Tile position where collected
	"""
	if item_id not in save_data.collectibles:
		save_data.collectibles.append(item_id)
		print("SaveManager: Saved collected item: ", item_id, " (total: ", save_data.collectibles.size(), ")")
		save_game()
		
func _transfer_collectibles_to_backpack() -> void:
	"""
	Transfer notes, puzzle pieces, and special items from collectibles to backpack
	Called at start of new run
	"""
	var item_manager = get_node_or_null("/root/ItemManager")
	if not item_manager:
		return
	
	# Ensure backpack_inventory exists
	if not save_data.has("backpack_inventory"):
		save_data.backpack_inventory = []
	
	# Ensure collectibles exists
	if not save_data.has("collectibles"):
		save_data.collectibles = []
		return
	
	for item_id in save_data.collectibles:
		var item_info = item_manager.get_item_info(item_id)
		var category = item_info.get("category", "")
		
		# Only transfer notes, puzzle pieces, and special items
		if category in ["notes", "puzzle_pieces", "special"]:
			# Skip puzzle pieces that have already been used
			if category == "puzzle_pieces" and is_puzzle_item_used(item_id):
				print("SaveManager: Skipping used puzzle piece ", item_id)
				continue
			
			if item_id not in save_data.backpack_inventory:
				save_data.backpack_inventory.append(item_id)
				print("SaveManager: Moved ", item_id, " to backpack for next run")
	
	# Clear collectibles for new run
	save_data.collectibles = []
	save_game()

func is_puzzle_completed(puzzle_id: String) -> bool:
	"""Check if a puzzle has been completed (persists across runs)"""
	return save_data.puzzles.get(puzzle_id, {}).get("completed", false)

func mark_puzzle_completed(puzzle_id: String) -> void:
	"""Mark a puzzle as permanently completed"""
	if not save_data.puzzles.has(puzzle_id):
		save_data.puzzles[puzzle_id] = {}
		save_game()
	
	save_data.puzzles[puzzle_id]["completed"] = true
	save_data.puzzles[puzzle_id]["completion_time"] = Time.get_unix_time_from_system()
	if MessageBus:
		MessageBus.emit_event("puzzle_completed", [puzzle_id, Vector2i.ZERO, {}])
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

func transfer_inventory_to_backpack(current_inventory: Array) -> void:
	"""
	Transfer notes, puzzle pieces, and special items from current inventory to backpack
	Called at the start of each run
	
	@param current_inventory: Current player inventory items
	"""
	var item_manager = get_node_or_null("/root/ItemManager")
	if not item_manager:
		push_error("SaveManager: ItemManager not found")
		return
	
	# Get notes, puzzle pieces, and special items from inventory
	for item_id in current_inventory:
		var item_info = item_manager.get_item_info(item_id)
		var category = item_info.get("category", "")
		
		# Only transfer notes, puzzle pieces, and special items
		if category in ["notes", "puzzle_pieces", "special"]:
			# Skip puzzle pieces that have already been used
			if category == "puzzle_pieces" and is_puzzle_item_used(item_id):
				print("SaveManager: Skipping used puzzle piece ", item_id, " from inventory transfer")
				continue
			
			if item_id not in save_data.backpack_inventory:
				save_data.backpack_inventory.append(item_id)
				print("SaveManager: Transferred ", item_id, " to backpack")
	
	save_game()

func get_backpack_inventory() -> Array:
	"""Get items currently stored in backpack"""
	return save_data.get("backpack_inventory", [])

func clear_backpack_inventory() -> void:
	"""Clear backpack inventory (called when player collects backpack)"""
	save_data.backpack_inventory = []
	save_game()
	print("SaveManager: Backpack inventory cleared")

func get_all_collected_notes() -> Array:
	"""
	Get all notes that have been collected across all runs
	
	@return: Array of note item IDs
	"""
	var notes: Array = []
	var item_manager = get_node_or_null("/root/ItemManager")
	if not item_manager:
		return notes
	
	# Get notes from current collectibles
	for item_id in save_data.get("collectibles", []):
		var item_info = item_manager.get_item_info(item_id)
		if item_info.get("category", "") == "notes":
			notes.append(item_id)
	
	# Get notes from backpack inventory (previously collected)
	for item_id in save_data.get("backpack_inventory", []):
		var item_info = item_manager.get_item_info(item_id)
		if item_info.get("category", "") == "notes":
			notes.append(item_id)
	
	return notes

func add_to_backpack(item_id: String) -> void:
	"""
	Add an item to the backpack
	
	@param item_id: Item to add
	"""
	if item_id not in save_data.backpack_inventory:
		save_data.backpack_inventory.append(item_id)
		save_game()

func _on_setting_changed(category: String, key: String, old_value: Variant, new_value: Variant) -> void:
	"""
	Handle settings changes from SettingsManager
	Note: Audio settings are now handled by SettingsManager directly via user://settings.json
	This method is kept for backwards compatibility but no longer saves audio settings
	
	@param category: Settings category
	@param key: Setting key
	@param old_value: Previous value
	@param new_value: New value
	"""
	# Audio settings are now persisted by SettingsManager directly
	# No need to duplicate them in save data
	pass

func load_audio_settings() -> void:
	"""
	Load audio settings from save data to SettingsManager
	Note: Audio settings are now handled by SettingsManager directly via user://settings.json
	This method is kept for backwards compatibility but no longer loads audio settings
	"""
	# Audio settings are now loaded by SettingsManager directly from user://settings.json
	# No need to load them from save data
	pass

func test_audio_persistence() -> void:
	"""
	Test function to verify audio settings persistence
	This can be called from debug console or UI for testing
	"""
	print("=== Audio Persistence Test ===")
	
	# Get current audio settings
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if not settings_manager:
		print("ERROR: SettingsManager not found")
		return
	
	var current_audio = settings_manager.get_audio_settings()
	print("Current audio settings: ", current_audio)
	
	# Check save data
	if save_data.settings.has("audio"):
		print("Save data audio settings: ", save_data.settings.audio)
	else:
		print("No audio settings in save data")
	
	# Test setting a value
	var test_value = 0.5
	settings_manager.set_setting("audio", "master_volume", test_value)
	await get_tree().process_frame
	
	print("After setting master_volume to ", test_value, ":")
	print("Current audio settings: ", settings_manager.get_audio_settings())
	print("Save data audio settings: ", save_data.settings.audio)
	
	# Test loading
	load_audio_settings()
	await get_tree().process_frame
	
	print("After loading from save data:")
	print("Current audio settings: ", settings_manager.get_audio_settings())
	print("=== Test Complete ===")
