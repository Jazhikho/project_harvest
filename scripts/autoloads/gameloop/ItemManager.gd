extends Node
## Manages item definitions, availability, and effects
## Handles item data loading and gameplay logic

@export var spawn_catalog: SpawnCatalog

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

# NEW: Map item_id to PackedScene for spawning
var _item_scene_map: Dictionary = {}  # item_id -> PackedScene

func _ready() -> void:
	name = "ItemManager"
	_resolve_catalog()
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
	_build_item_scene_map()  # NEW: Build the scene map after loading definitions
	_connect_to_events()
	
func _resolve_catalog() -> void:
	if spawn_catalog == null:
		push_error("ItemManager: spawn_catalog is null. Assign SpawnCatalog.tres in Inspector.")
		return
	if spawn_catalog.item_scenes.is_empty():
		push_warning("ItemManager: catalog has zero item scenes.")

# NEW: Build a map of item_id -> PackedScene
func _build_item_scene_map() -> void:
	"""Build a mapping of item IDs to their PackedScenes for efficient spawning"""
	_item_scene_map.clear()
	
	if not spawn_catalog or spawn_catalog.item_scenes.is_empty():
		push_warning("ItemManager: No item scenes in catalog")
		return
	
	for scene in spawn_catalog.item_scenes:
		if not scene:
			continue
		
		# Instantiate temporarily to get the item_id
		var temp_instance = scene.instantiate()
		var item_id: String = ""
		
		if temp_instance.has_method("get_item_id"):
			item_id = temp_instance.get_item_id()
		elif "item_id" in temp_instance:
			item_id = temp_instance.item_id
		elif temp_instance.has_meta("item_id"):
			item_id = temp_instance.get_meta("item_id")
		
		temp_instance.queue_free()
		
		if not item_id.is_empty():
			_item_scene_map[item_id] = scene
			print("ItemManager: Mapped item_id '", item_id, "' to scene")
		else:
			push_warning("ItemManager: Item scene has no item_id: ", scene.resource_path)
	
	print("ItemManager: Built scene map with ", _item_scene_map.size(), " items")

func get_all_item_scenes() -> Array[PackedScene]:
	if not spawn_catalog:
		return []
	return spawn_catalog.item_scenes.duplicate()

# NEW: Get specific item scene by ID
func get_item_scene(item_id: String) -> PackedScene:
	"""
	Get the PackedScene for a specific item
	
	@param item_id: Item identifier
	@return: PackedScene or null if not found
	"""
	return _item_scene_map.get(item_id, null)

# NEW: Spawn an item instance
func spawn_item_instance(item_id: String, position: Vector3, parent: Node = null) -> Node3D:
	"""
	Spawn an item in the world
	
	@param item_id: Item to spawn
	@param position: World position
	@param parent: Parent node (defaults to current scene)
	@return: Spawned item instance or null
	"""
	var scene = get_item_scene(item_id)
	if not scene:
		push_error("ItemManager: No scene found for item_id: ", item_id)
		return null
	
	var instance = scene.instantiate()
	if not instance:
		push_error("ItemManager: Failed to instantiate item: ", item_id)
		return null
	
	# Add to scene
	if parent:
		parent.add_child(instance)
	else:
		get_tree().current_scene.add_child(instance)
	
	# Set position
	if instance is Node3D:
		instance.global_position = position
	
	# Ensure metadata is set
	instance.set_meta("item_id", item_id)
	
	return instance

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
	# NEW: First check if we actually have a scene for this item
	if not _item_scene_map.has(item_id):
		return false
	
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
	
	# Check if this item belongs to a completed puzzle
	var item_info = get_item_info(item_id)
	if item_info.has("puzzle_id"):
		var puzzle_id = item_info.get("puzzle_id")
		if SaveManager.has_method("is_puzzle_completed"):
			if SaveManager.is_puzzle_completed(puzzle_id):
				print("ItemManager: ", item_id, " cannot spawn - puzzle ", puzzle_id, " is completed")
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
		
func remove_item_from_inventory(item_id: String) -> void:
	"""
	Remove an item from player inventory (when used in puzzle)
	
	@param item_id: Item to remove
	"""
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	if player_inventory and player_inventory.has_method("remove_item"):
		player_inventory.remove_item(item_id)
		print("ItemManager: Removed ", item_id, " from inventory")

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
