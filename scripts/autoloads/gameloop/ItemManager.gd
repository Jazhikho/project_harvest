extends Node
## Manages item definitions, availability, and effects
## Handles item data loading and gameplay logic

var _item_definitions := {}
var _item_categories := {
	"notes": [],
	"items": [],
}

var _item_effects := {}
var _unlocked_notes := []

var _message_bus: Node
var _state_manager: Node

const ITEM_DATA_PATH := "res://data/items.json"
const MAX_UNLOCKED_NOTES := 10

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
		push_error("ItemManager: items.json not found at " + ITEM_DATA_PATH)
		return
	
	var file := FileAccess.open(ITEM_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("ItemManager: Could not open items.json")
		return
	
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("ItemManager: Failed to parse items.json")
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
		
		_item_effects[item_id] = item.get("effects", {})
	
	_unlocked_notes = _item_categories.notes.slice(0, min(3, _item_categories.notes.size()))

func can_item_spawn(item_id: String, context: Dictionary) -> bool:
	"""
	Check if item can spawn in given context
	
	@param item_id: Item identifier to check
	@param context: Spawning context with tile_position, is_permanent, etc.
	@return: True if item can spawn
	"""	
	# Check if already collected in THIS RUN
	var collected_items: Array = _state_manager.get_state("collected_items")
	if collected_items == null:
		collected_items = []
	
	# Notes can only be collected once per run
	if item_id in _item_categories.notes:
		if item_id in collected_items:
			return false
		# Also check if note is unlocked
		if item_id not in _unlocked_notes:
			return false
	else:
		# Non-note items: check if already collected this run
		if item_id in collected_items:
			return false
	
	# Special items that shouldn't spawn randomly
	if item_id in ["hollow_key", "flashlight", "journal"]:
		return false
	
	# Check if puzzle item has been used (persistent across runs)
	if SaveManager.has_method("is_puzzle_item_used"):
		if SaveManager.is_puzzle_item_used(item_id):
			return false
	
	return true

func get_spawnable_items(context: Dictionary) -> Array[Dictionary]:
	"""
	Get weighted list of items that can spawn
	
	@param context: Spawning context
	@return: Array of {item_id: String, weight: float} dictionaries
	"""
	var spawnable: Array[Dictionary] = []
	
	for item_id in _item_definitions:
		if can_item_spawn(item_id, context):
			spawnable.append({"item_id": item_id, "weight": 1})
	
	return spawnable

func select_random_item(spawnable_items: Array[Dictionary]) -> String:
	"""
	Select random item from list
	
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
	
	if effects.has("sanity_delta"):
		_state_manager.modify_sanity(effects.sanity_delta)
	
	if effects.has("set_flags"):
		for flag in effects.set_flags:
			_state_manager.set_flag(flag, true)
	
	if effects.has("unset_flags"):
		for flag in effects.unset_flags:
			_state_manager.set_flag(flag, false)
	
	if item_id in _item_categories.notes:
		_unlock_next_note(item_id)

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
	
	@param category: Category name (notes, weird_objects, puzzle_pieces, consumables)
	@return: Array of item IDs in category
	"""
	return _item_categories.get(category, []).duplicate()

func _unlock_next_note(collected_note_id: String) -> void:
	"""
	Unlock next note when one is collected
	
	@param collected_note_id: ID of note that was collected
	"""
	var note_index: int = _item_categories.notes.find(collected_note_id)
	if note_index < 0:
		return
	
	var all_notes: Array = _item_categories.notes
	var next_index := _unlocked_notes.size()
	
	if next_index < all_notes.size() and all_notes[next_index] not in _unlocked_notes:
		_unlocked_notes.append(all_notes[next_index])

func reset_for_new_run() -> void:
	"""Reset item availability for new game run"""
	_unlocked_notes = _item_categories.notes.slice(0, min(3, _item_categories.notes.size()))

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.game_started.connect(_on_game_started)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	apply_item_effects(item_id)
	mark_item_collected(item_id)
	_cleanup_duplicate_items(item_id)
	
func mark_item_collected(item_id: String) -> void:
	"""
	Mark an item as collected in the current run
	
	@param item_id: Item identifier that was collected
	"""
	var collected_items: Array = _state_manager.get_state("collected_items")
	if collected_items == null:
		collected_items = []
	
	if item_id not in collected_items:
		collected_items.append(item_id)
		_state_manager.set_state("collected_items", collected_items)
		print("ItemManager: Marked ", item_id, " as collected. Total collected: ", collected_items.size())

func _cleanup_duplicate_items(item_id: String) -> void:
	"""
	Remove all other instances of this item from the world
	Called after an item is collected to prevent duplicates
	
	@param item_id: Item identifier to remove duplicates of
	"""
	var items_removed := 0
	
	# Get all collectible nodes in the scene
	var collectibles := get_tree().get_nodes_in_group("collectibles")
	
	for collectible in collectibles:
		if not is_instance_valid(collectible):
			continue
		
		# Check if this is an instance of the collected item
		var collectible_item_id: String = ""
		
		# Try to get item_id from metadata
		if collectible.has_meta("item_id"):
			collectible_item_id = collectible.get_meta("item_id")
		# Try to get from property
		elif collectible.has_method("get_item_id"):
			collectible_item_id = collectible.get_item_id()
		elif "item_id" in collectible:
			collectible_item_id = collectible.item_id
		
		# If this is a duplicate of the collected item, remove it
		if collectible_item_id == item_id:
			print("ItemManager: Removing duplicate instance of ", item_id, " at ", collectible.global_position)
			collectible.queue_free()
			items_removed += 1
	
	if items_removed > 0:
		print("ItemManager: Cleaned up ", items_removed, " duplicate instances of ", item_id)

func _on_game_started() -> void:
	reset_for_new_run()
