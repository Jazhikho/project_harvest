extends Node

const SAVE_PATH = "user://save_data.sav"

# Track if save existed at scene load (before start_run creates it)
var had_existing_save: bool = false

var save_data: Dictionary = {
	"time_played": 0.0,
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

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	var message_bus: Node = get_node_or_null("/root/MessageBus")
	if message_bus:
		if message_bus.has_signal("game_started"):
			message_bus.game_started.connect(_on_game_started)
		if message_bus.has_signal("item_collected"):
			message_bus.item_collected.connect(_on_item_collected)

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
			
			# Save the updated structure
			save_game()
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
	_transfer_collectibles_to_backpack()
	save_data.deaths += 1
	save_data.run_active = false
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
	Transfer notes and puzzle pieces from collectibles to backpack
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
		
		# Only transfer notes and puzzle pieces
		if category in ["notes", "puzzle_pieces"]:
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
		MessageBus.emit_event("puzzle_completed", [puzzle_id, ])
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
	Transfer notes and puzzle pieces from current inventory to backpack
	Called at the start of each run
	
	@param current_inventory: Current player inventory items
	"""
	var item_manager = get_node_or_null("/root/ItemManager")
	if not item_manager:
		push_error("SaveManager: ItemManager not found")
		return
	
	# Get notes and puzzle pieces from inventory
	for item_id in current_inventory:
		var item_info = item_manager.get_item_info(item_id)
		var category = item_info.get("category", "")
		
		# Only transfer notes and puzzle pieces
		if category in ["notes", "puzzle_pieces"]:
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

func add_to_backpack(item_id: String) -> void:
	"""
	Add an item to the backpack
	
	@param item_id: Item to add
	"""
	if item_id not in save_data.backpack_inventory:
		save_data.backpack_inventory.append(item_id)
		save_game()
