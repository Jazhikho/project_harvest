extends Node
## Manages item definitions, availability, and effects
## Handles item data loading and gameplay logic

@export var spawn_catalog: SpawnCatalog
@export var sfx_library: SFX

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
const PICKUP_ITEM_DB: float = -8.0
const PICKUP_NOTE_DB: float = -12.0

# NEW: Map item_id to PackedScene for spawning
var _item_scene_map: Dictionary = {} # item_id -> PackedScene

func _ready() -> void:
	name = "ItemManager"
	_resolve_catalog()
	add_to_group("core_systems")
	call_deferred("_initialize")
	_export_sanity()

func _export_sanity() -> void:
	if spawn_catalog == null:
		push_error("ItemManager: spawn_catalog is NULL in export.")
		return
	
	# Validate catalog entries for export
	for ps: PackedScene in spawn_catalog.item_scenes:
		if ps == null:
			push_error("ItemManager: Null PackedScene found in catalog")
			continue
		var p := ps.resource_path
		if not ResourceLoader.exists(p, "PackedScene"):
			push_error("ItemManager: PackedScene not found in export: " + p)

func _initialize() -> void:
	"""Initialize connections and load data"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("ItemManager: Required core systems not found")
		return
	
	_load_item_definitions()
	_build_item_scene_map() # NEW: Build the scene map after loading definitions
	_connect_to_events()
	
func _resolve_catalog() -> void:
	if spawn_catalog == null:
		push_error("ItemManager: spawn_catalog is null. Assign SpawnCatalog.tres in Inspector.")
		return
	if spawn_catalog.item_scenes.is_empty():
		push_warning("ItemManager: catalog has zero item scenes.")

# NEW: Build a map of item_id -> PackedScene
## _build_item_scene_map
## Purpose: Build a mapping of item IDs to their PackedScenes for efficient spawning.
## @return void.
func _build_item_scene_map() -> void:
	_item_scene_map.clear()

	if spawn_catalog == null or spawn_catalog.item_scenes.is_empty():
		push_warning("ItemManager: No item scenes in catalog.")
		return

	for scene_ps: PackedScene in spawn_catalog.item_scenes:
		if scene_ps == null:
			continue

		var temp: Node = scene_ps.instantiate()
		var item_id: String = ""

		if temp.has_method("get_item_id"):
			item_id = String(temp.get_item_id())
		elif "item_id" in temp:
			item_id = String(temp.item_id)
		elif temp.has_meta("item_id"):
			item_id = String(temp.get_meta("item_id"))

		temp.queue_free()

		if item_id.is_empty():
			push_warning("ItemManager: Item scene has no item_id: " + scene_ps.resource_path)
		else:
			_item_scene_map[item_id] = scene_ps


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
## spawn_item_instance
## Purpose: Instantiate an item by ID and place it in the world.
## @param item_id: String
## @param position: Vector3
## @param parent: Node or null to use current_scene
## @return Node3D or null
func spawn_item_instance(item_id: String, position: Vector3, parent: Node = null) -> Node3D:
	var ps: PackedScene = get_item_scene(item_id)
	if ps == null:
		push_error("ItemManager: No scene found for item_id: " + item_id)
		return null

	var inst: Node = ps.instantiate()
	if inst == null:
		push_error("ItemManager: Failed to instantiate item: " + item_id)
		return null

	var host: Node = parent
	if host == null:
		host = get_tree().current_scene
	host.add_child(inst)

	if inst is Node3D:
		var n3d: Node3D = inst as Node3D
		n3d.global_position = position

	inst.set_meta("item_id", item_id)
	return inst as Node3D

## _load_item_definitions
## Purpose: Load item definitions from JSON; if unavailable in export, fall back to catalog-only.
## @return void.
func _load_item_definitions() -> void:
	_item_definitions.clear()
	_item_effects.clear()

	# Reset categories explicitly
	_item_categories["notes"] = []
	_item_categories["items"] = []

	if not FileAccess.file_exists(ITEM_DATA_PATH):
		push_warning("ItemManager: items.json not found at " + ITEM_DATA_PATH + " (export?). Falling back to catalog-only spawn.")
		return

	var file: FileAccess = FileAccess.open(ITEM_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("ItemManager: Could not open items.json at " + ITEM_DATA_PATH)
		return

	var txt: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_code: int = json.parse(txt)
	if parse_code != OK:
		push_error("ItemManager: Failed to parse items.json, code=" + str(parse_code))
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("ItemManager: items.json root is not a Dictionary.")
		return

	_process_item_data(json.data as Dictionary)


## _process_item_data
## Purpose: Ingest JSON into definitions, categories, and effects.
## @param data: Dictionary parsed from items.json
## @return void.
func _process_item_data(data: Dictionary) -> void:
	if not data.has("items"):
		return

	var items_arr: Array = data["items"]
	for entry in items_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = entry
		var item_id: String = String(item.get("id", ""))
		if item_id.is_empty():
			continue

		_item_definitions[item_id] = item.duplicate(true)

		var category: String = String(item.get("category", ""))
		if _item_categories.has(category):
			var cat_list: Array = _item_categories[category]
			if item_id not in cat_list:
				cat_list.append(item_id)
				_item_categories[category] = cat_list

		_item_effects[item_id] = (item.get("effects", {}) as Dictionary).duplicate(true)

	# initial unlocked notes
	var notes_list: Array = _item_categories.get("notes", []) as Array
	var initial_count: int = min(3, notes_list.size())
	_unlocked_notes = notes_list.slice(0, initial_count)


## can_item_spawn
## Purpose: Validate whether an item may spawn given context and current/save state.
## @param item_id: String
## @param context: Dictionary (tile_position, is_permanent, etc.)
## @return bool
func can_item_spawn(item_id: String, context: Dictionary) -> bool:
	# Must have a scene to spawn.
	if not _item_scene_map.has(item_id):
		return false

	# Treat "notes" as a special category only if JSON loaded them.
	var notes_list: Array = _item_categories.get("notes", []) as Array
	var is_note: bool = item_id in notes_list

	# Current-run collected list.
	var collected_items: Array = _state_manager.get_state("collected_items") as Array
	if collected_items == null:
		collected_items = []

	if is_note:
		if item_id in collected_items:
			return false
		if item_id not in _unlocked_notes:
			return false
	else:
		if item_id in collected_items:
			return false

	# Never random-spawn these.
	if item_id == "hollow_key" or item_id == "flashlight" or item_id == "journal":
		return false

	# Persistent save checks (optional).
	if SaveManager != null and SaveManager.has_method("is_puzzle_item_used"):
		if SaveManager.is_puzzle_item_used(item_id):
			return false

	var item_info: Dictionary = get_item_info(item_id)
	if item_info.has("puzzle_id") and SaveManager != null and SaveManager.has_method("is_puzzle_completed"):
		var puzzle_id: String = String(item_info.get("puzzle_id", ""))
		if not puzzle_id.is_empty() and SaveManager.is_puzzle_completed(puzzle_id):
			print("ItemManager: ", item_id, " cannot spawn - puzzle ", puzzle_id, " is completed")
			return false

	return true

## get_spawnable_items
## Purpose: Build a weighted list of items that can spawn, with catalog fallback if JSON missing.
## @param context: Dictionary with spawn context.
## @return Array of { "item_id": String, "weight": float }.
func get_spawnable_items(context: Dictionary) -> Array[Dictionary]:
	var spawnable: Array[Dictionary] = []
	var candidate_ids: Array[String] = []

	# Prefer JSON list; if empty (export miss), fall back to scenes we actually have.
	if _item_definitions.size() > 0:
		for k in _item_definitions.keys():
			candidate_ids.append(String(k))
	else:
		for k in _item_scene_map.keys():
			candidate_ids.append(String(k))

	for id_str: String in candidate_ids:
		if can_item_spawn(id_str, context):
			var entry := {"item_id": id_str, "weight": 1.0}
			spawnable.append(entry)

	return spawnable

## select_random_item
## Purpose: Pick one entry from a weighted list.
## @param spawnable_items: Array of { "item_id": String, "weight": float }.
## @return Item ID or "".
func select_random_item(spawnable_items: Array[Dictionary]) -> String:
	if spawnable_items.is_empty():
		return ""

	var total_weight: float = 0.0
	for row in spawnable_items:
		total_weight += float(row.get("weight", 1.0))

	var roll: float = randf() * total_weight
	var accum: float = 0.0

	for row2 in spawnable_items:
		accum += float(row2.get("weight", 1.0))
		if roll <= accum:
			return String(row2.get("item_id", ""))

	return String(spawnable_items[0].get("item_id", ""))

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
	# Play the pickup SFX first, at the collector’s position if available.
	var origin: Vector3 = Vector3.ZERO
	if collector != null and collector is Node3D:
		origin = collector.global_position
	else:
		# Fallback: try to find any remaining instance to grab a position from.
		var found: Vector3 = origin
		var got_pos: bool = false
		for node in get_tree().get_nodes_in_group("collectibles"):
			if is_instance_valid(node):
				var nid: String = ""
				if node.has_meta("item_id"):
					nid = String(node.get_meta("item_id"))
				elif node.has_method("get_item_id"):
					nid = String(node.get_item_id())
				elif "item_id" in node:
					nid = String(node.item_id)
				if nid == item_id and node is Node3D:
					found = node.global_position
					got_pos = true
					break
		if got_pos:
			origin = found
	_play_pickup_sfx(item_id, origin)

	# Then do your existing bookkeeping
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

## _play_stream_3d_at
## Purpose: Play an AudioStream at a world position on the SFX bus and auto-free.
## @param stream: AudioStream to play.
## @param position: World position.
## @param volume_db: Playback volume in dB.
## @return void.
func _play_stream_3d_at(stream: AudioStream, position: Vector3, volume_db: float) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "PickupSFX"
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	player.global_position = position
	# No falloff. It’s a local event sound originating at the pickup.
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## _play_pickup_sfx
## Purpose: Decide which pickup sound to play based on category (note vs item).
## @param item_id: Collected item id.
## @param origin: Where to play the sound (usually the collector or item position).
## @return void.
func _play_pickup_sfx(item_id: String, origin: Vector3) -> void:
	if sfx_library == null:
		return
	
	var notes_list: Array = _item_categories.get("notes", []) as Array
	var is_note: bool = false
	if notes_list != null:
		is_note = notes_list.has(item_id)

	if is_note:
		# Prefer dedicated notepickup if set; otherwise fall back to itempickup.
		if sfx_library.notepickup is AudioStream:
			_play_stream_3d_at(sfx_library.notepickup, origin, PICKUP_NOTE_DB)
			return
		if sfx_library.itempickup is AudioStream:
			_play_stream_3d_at(sfx_library.itempickup, origin, PICKUP_NOTE_DB)
			return
	else:
		if sfx_library.itempickup is AudioStream:
			_play_stream_3d_at(sfx_library.itempickup, origin, PICKUP_ITEM_DB)
			return
		# If someone misfiled the audio, a note sound is better than silence.
		if sfx_library.notepickup is AudioStream:
			_play_stream_3d_at(sfx_library.notepickup, origin, PICKUP_ITEM_DB)
			return
