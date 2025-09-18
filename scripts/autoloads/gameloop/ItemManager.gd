extends Node
## Manages item definitions for notes and puzzle pieces
## Handles item data loading and spawning logic

var _item_definitions := {}
var _item_categories := {
	"notes": [],
	"puzzle_pieces": [],
	# "weird_objects": [],  # GHOSTED - Keep for future use
	# "consumables": []      # GHOSTED - Keep for future use
}

var _spawn_rules := {}
var _item_effects := {}

var _message_bus: Node
var _state_manager: Node

# Puzzle piece tracking - which pieces belong to which puzzle
var _puzzle_pieces := {
	"puzzle_1": ["puzzle_1_piece_1", "puzzle_1_piece_2", "puzzle_1_piece_3"],
	"puzzle_2": ["puzzle_2_piece_1", "puzzle_2_piece_2", "puzzle_2_piece_3", "puzzle_2_piece_4"],
	"puzzle_3": ["puzzle_3_piece_1", "puzzle_3_piece_2", "puzzle_3_piece_3", "puzzle_3_piece_4", "puzzle_3_piece_5"]
}

const ITEM_DATA_PATH := "res://data/items.json"

func _ready() -> void:
	name = "ItemManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections and load data"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("ItemManager: Required core systems not found")
		return
	
	_load_item_definitions()
	_connect_to_events()

func _load_item_definitions() -> void:
	"""Load item definitions from JSON data file"""
	if not FileAccess.file_exists(ITEM_DATA_PATH):
		push_warning("ItemManager: items.json not found, using defaults")
		_create_default_definitions()
		return
	
	var file := FileAccess.open(ITEM_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("ItemManager: Could not open items.json")
		_create_default_definitions()
		return
	
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("ItemManager: Failed to parse items.json")
		_create_default_definitions()
		return
	
	_process_item_data(json.data)

func _process_item_data(data: Dictionary) -> void:
	"""
	Process loaded item data into internal structures
	
	@param data: Parsed JSON data dictionary
	"""
	for item in data.get("items", []):
		var item_id: String = item.get("id", "")
		if item_id.is_empty():
			continue
		
		_item_definitions[item_id] = item
		
		var category: String = item.get("category", "")
		if category in _item_categories:
			_item_categories[category].append(item_id)
		
		_spawn_rules[item_id] = item.get("spawn_rules", {})
		_item_effects[item_id] = item.get("effects", {})
	
	# Sort notes by ID to ensure consistent ordering
	_item_categories.notes.sort()

func _create_default_definitions() -> void:
	"""Create minimal default item definitions as fallback"""
	var default_items := []
	
	# Create default research notes (1-30)
	for i in range(1, 31):
		default_items.append({
			"id": "note_%d" % i,
			"category": "notes",
			"name": "Research Note #%d" % i,
			"description": "Dr. Amundsen's research documentation",
			"spawn_rules": {"weight": 1.0},
			"effects": {"sanity_delta": -5}
		})
	
	# Create default puzzle pieces
	for puzzle_id in _puzzle_pieces:
		for piece_id in _puzzle_pieces[puzzle_id]:
			default_items.append({
				"id": piece_id,
				"category": "puzzle_pieces",
				"name": "Puzzle Piece",
				"description": "A piece of the larger puzzle",
				"spawn_rules": {"weight": 0.8},
				"effects": {}
			})
	
	var data := {"items": default_items}
	_process_item_data(data)

func can_item_spawn(item_id: String, context: Dictionary) -> bool:
	"""
	Check if item can spawn in given context
	
	@param item_id: Item identifier to check
	@param context: Spawning context with tile_position, etc.
	@return: True if item can spawn
	"""
	if item_id not in _spawn_rules:
		return false
	
	# Check if already collected
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	if player_inventory and player_inventory.has_method("has_item"):
		if player_inventory.has_item(item_id):
			return false
	
	# For notes, check if it's in the unlocked list
	if item_id in _item_categories.notes:
		if not _state_manager.is_note_unlocked(item_id):
			return false
	
	# Check spawn rules
	var rules: Dictionary = _spawn_rules[item_id]
	var state: Dictionary = _state_manager.get_state()
	
	if rules.has("min_sanity") and state.sanity < rules.min_sanity:
		return false
	
	if rules.has("max_sanity") and state.sanity > rules.max_sanity:
		return false
	
	if rules.has("required_flags"):
		for flag in rules.required_flags:
			if not _state_manager.has_event_flag(flag):
				return false
	
	if rules.has("forbidden_flags"):
		for flag in rules.forbidden_flags:
			if _state_manager.has_event_flag(flag):
				return false
	
	return true

func get_spawnable_items(context: Dictionary) -> Array[Dictionary]:
	"""
	Get weighted list of items that can spawn
	
	@param context: Spawning context
	@return: Array of {item_id: String, weight: float} dictionaries
	"""
	var spawnable: Array[Dictionary] = []
	
	# Get spawnable notes (only from unlocked list)
	var unlocked_notes = _state_manager.get_unlocked_notes()
	for note_id in unlocked_notes:
		if can_item_spawn(note_id, context):
			var weight: float = _spawn_rules[note_id].get("weight", 1.0)
			spawnable.append({"item_id": note_id, "weight": weight})
	
	# Get spawnable puzzle pieces
	for piece_id in _get_available_puzzle_pieces():
		if can_item_spawn(piece_id, context):
			var weight: float = _spawn_rules[piece_id].get("weight", 1.0)
			spawnable.append({"item_id": piece_id, "weight": weight})
	
	return spawnable

func _get_available_puzzle_pieces() -> Array[String]:
	"""
	Get puzzle pieces that haven't been collected
	
	@return: Array of available puzzle piece IDs
	"""
	var available: Array[String] = []
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	
	for puzzle_id in _puzzle_pieces:
		for piece_id in _puzzle_pieces[puzzle_id]:
			if player_inventory and player_inventory.has_method("has_item"):
				if not player_inventory.has_item(piece_id):
					available.append(piece_id)
			else:
				available.append(piece_id)
	
	return available

func select_random_item(spawnable_items: Array[Dictionary]) -> String:
	"""
	Select random item from weighted list
	
	@param spawnable_items: Array of {item_id, weight} dictionaries
	@return: Selected item ID or empty string if none available
	"""
	if spawnable_items.is_empty():
		return ""
	
	var total_weight := 0.0
	for item_data in spawnable_items:
		total_weight += item_data.weight
	
	var roll := randf() * total_weight
	var current_weight := 0.0
	
	for item_data in spawnable_items:
		current_weight += item_data.weight
		if roll <= current_weight:
			return item_data.item_id
	
	return spawnable_items[0].item_id

func apply_item_effects(item_id: String) -> void:
	"""
	Apply effects when item is collected
	
	@param item_id: Item identifier
	"""
	if item_id not in _item_effects:
		return
	
	var effects: Dictionary = _item_effects[item_id]
	
	# Apply sanity effects
	if effects.has("sanity_delta"):
		_state_manager.modify_sanity(effects.sanity_delta)
	
	# Set event flags
	if effects.has("set_flags"):
		for flag in effects.set_flags:
			_state_manager.set_event_flag(flag, true)
	
	if effects.has("unset_flags"):
		for flag in effects.unset_flags:
			_state_manager.set_event_flag(flag, false)

func get_item_info(item_id: String) -> Dictionary:
	"""
	Get complete item information
	
	@param item_id: Item identifier
	@return: Item definition dictionary or empty if not found
	"""
	return _item_definitions.get(item_id, {})

func get_category_items(category: String) -> Array:
	"""
	Get all items in a category
	
	@param category: Category name (notes, puzzle_pieces)
	@return: Array of item IDs in category
	"""
	return _item_categories.get(category, []).duplicate()

func get_puzzle_pieces_for_puzzle(puzzle_id: String) -> Array[String]:
	"""
	Get all piece IDs for a specific puzzle
	
	@param puzzle_id: Puzzle identifier
	@return: Array of piece IDs for this puzzle
	"""
	return _puzzle_pieces.get(puzzle_id, []).duplicate()

func is_puzzle_piece(item_id: String) -> bool:
	"""
	Check if an item is a puzzle piece
	
	@param item_id: Item identifier to check
	@return: True if item is a puzzle piece
	"""
	return item_id in _item_categories.puzzle_pieces

func get_puzzle_for_piece(piece_id: String) -> String:
	"""
	Get which puzzle a piece belongs to
	
	@param piece_id: Puzzle piece identifier
	@return: Puzzle ID or empty string if not found
	"""
	for puzzle_id in _puzzle_pieces:
		if piece_id in _puzzle_pieces[puzzle_id]:
			return puzzle_id
	return ""

func get_puzzle_completion(puzzle_id: String) -> Dictionary:
	"""
	Get completion status for a puzzle
	
	@param puzzle_id: Puzzle identifier
	@return: Dictionary with total pieces and found pieces
	"""
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	var total_pieces: int = _puzzle_pieces.get(puzzle_id, []).size()
	var found_pieces: int = 0
	
	if player_inventory and player_inventory.has_method("has_item"):
		for piece_id in _puzzle_pieces.get(puzzle_id, []):
			if player_inventory.has_item(piece_id):
				found_pieces += 1
	
	return {
		"puzzle_id": puzzle_id,
		"total_pieces": total_pieces,
		"found_pieces": found_pieces,
		"completed": found_pieces >= total_pieces
	}

func reset_for_new_run() -> void:
	"""Reset item availability for new game run"""
	# Note unlocking is handled by GameStateManager
	pass

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.game_started.connect(_on_game_started)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""Handle item collection"""
	apply_item_effects(item_id)
	
	# Note unlocking is now handled by GameStateManager

func _on_game_started() -> void:
	"""Handle game start"""
	reset_for_new_run()

# ===== GHOSTED WEIRD OBJECTS CODE - Keep for future use =====
"""
func apply_weird_object_effects(item_id: String) -> void:
	# Weird objects cause significant sanity loss
	var sanity_loss := 0
	match item_id:
		"porcelain_doll":
			sanity_loss = 15
		"music_box":
			sanity_loss = 12
		"mirror_fragment":
			sanity_loss = 7
		_:
			sanity_loss = 10
	
	_state_manager.modify_sanity(-sanity_loss)
	
	# Trigger weird effects via WeirdThingsManager
	var weird_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_manager and weird_manager.has_method("trigger_weird_effect"):
		var tile_pos = _state_manager.get_state("current_tile_position")
		weird_manager.trigger_weird_effect(item_id, tile_pos)
"""
