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
	"puzzle_2": ["puzzle_2_piece_1", "puzzle_2_piece_2", "puzzle_2_piece_3"],
	"puzzle_3": ["puzzle_3_piece_1", "puzzle_3_piece_2", "puzzle_3_piece_3"]
}

const ITEM_DATA_PATH := "res://data/items.json"

func _ready() -> void:
	name = "ItemManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus or not _state_manager:
		push_error("ItemManager: Required core systems not found")
		return
	
	_load_item_definitions()
	_connect_to_events()

func _load_item_definitions() -> void:
	if not FileAccess.file_exists(ITEM_DATA_PATH):
		push_error("ItemManager: items.json not found - required for item definitions")
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
	
	_item_categories.notes.sort()

func can_item_spawn(item_id: String, context: Dictionary) -> bool:
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
	var current_sanity = _state_manager.get_state("sanity")
	
	if rules.has("min_sanity") and current_sanity < rules.min_sanity:
		return false
	
	if rules.has("max_sanity") and current_sanity > rules.max_sanity:
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
	var spawnable: Array[Dictionary] = []
	
	# Get spawnable notes (only from unlocked list)
	var unlocked_notes = _state_manager.get_unlocked_notes()
	for note_id in unlocked_notes:
		if can_item_spawn(note_id, context):
			var weight: float = _spawn_rules[note_id].get("weight", 1.0)
			spawnable.append({"item_id": note_id, "weight": weight})
	
	# Get spawnable puzzle pieces
	var available_pieces = _get_available_puzzle_pieces()
	for piece_id in available_pieces:
		if can_item_spawn(piece_id, context):
			var weight: float = _spawn_rules[piece_id].get("weight", 1.0)
			spawnable.append({"item_id": piece_id, "weight": weight})
	return spawnable

func _get_available_puzzle_pieces() -> Array[String]:
	var available: Array[String] = []
	var player_inventory = get_node_or_null("/root/PlayerInventory")
	
	for item_id in _item_categories.puzzle_pieces:
		if player_inventory and player_inventory.has_method("has_item"):
			if not player_inventory.has_item(item_id):
				available.append(item_id)
		else:
			available.append(item_id)
	
	return available

func select_random_item(spawnable_items: Array[Dictionary]) -> String:
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
	return _item_definitions.get(item_id, {})

func get_category_items(category: String) -> Array:
	return _item_categories.get(category, []).duplicate()

func get_puzzle_pieces_for_puzzle(puzzle_id: String) -> Array[String]:
	return _puzzle_pieces.get(puzzle_id, []).duplicate()

func is_puzzle_piece(item_id: String) -> bool:
	return item_id in _item_categories.puzzle_pieces

func get_puzzle_for_piece(piece_id: String) -> String:
	for puzzle_id in _puzzle_pieces:
		if piece_id in _puzzle_pieces[puzzle_id]:
			return puzzle_id
	return ""

func get_puzzle_completion(puzzle_id: String) -> Dictionary:
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

func _connect_to_events() -> void:
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.game_started.connect(_on_game_started)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	apply_item_effects(item_id)

func _on_game_started() -> void:
	pass

# === ITEM VISUAL CREATION FUNCTIONS ===
# Moved from SpawnManager for better organization

func spawn_item_visual(tile_node: Node3D, item_id: String, position: Vector3) -> bool:
	# Handle notes differently - use random note scene
	if item_id.begins_with("note_"):
		return spawn_note_item(tile_node, item_id, position)
	
	var item_scene_path := "res://scenes/items/%s.tscn" % item_id
	
	if not FileAccess.file_exists(item_scene_path):
		push_error("ItemManager: Item scene not found: %s" % item_scene_path)
		return false
	
	var item_scene := load(item_scene_path) as PackedScene
	if not item_scene:
		push_error("ItemManager: Failed to load item scene: %s" % item_scene_path)
		return false
	
	var item_instance := item_scene.instantiate()
	tile_node.add_child(item_instance)
	item_instance.global_position = position
	
	# Configure the item instance for interaction
	_configure_spawned_item(item_instance, item_id)
	
	return true

func _configure_spawned_item(item_instance: Node3D, item_id: String) -> void:
	# Set metadata for interaction systems
	item_instance.set_meta("item_id", item_id)
	item_instance.set_meta("is_collectible", true)
	item_instance.set_meta("is_interactable", true)
	item_instance.add_to_group("collectibles")
	item_instance.add_to_group("interactable_items")
	
	# Set item_id property if the item has it
	if item_instance.has_method("set") and item_instance.get("item_id") != null:
		item_instance.item_id = item_id
	
	# Get item info and set name/description if the item has these properties
	var item_info = get_item_info(item_id)
	if not item_info.is_empty():
		# Only set properties if they actually exist on the item instance
		if item_instance.has_method("set") and item_instance.get("item_name") != null:
			if item_instance.item_name.is_empty():
				item_instance.item_name = item_info.get("name", "Item")
		if item_instance.has_method("set") and item_instance.get("item_description") != null:
			if item_instance.item_description.is_empty():
				item_instance.item_description = item_info.get("description", "A mysterious item")

func spawn_note_item(tile_node: Node3D, item_id: String, position: Vector3) -> bool:
	# Get available note scenes
	var note_scenes = ["note_1.tscn", "note_2.tscn", "note_3.tscn", "note_4.tscn"]
	var random_note_scene = note_scenes[randi() % note_scenes.size()]
	var note_scene_path = "res://scenes/notes/" + random_note_scene
	
	if not FileAccess.file_exists(note_scene_path):
		return false
	
	var note_scene := load(note_scene_path) as PackedScene
	if not note_scene:
		return false
	
	var note_instance := note_scene.instantiate()
	tile_node.add_child(note_instance)
	note_instance.global_position = position
	
	# Configure the note instance for interaction
	_configure_spawned_note(note_instance, item_id)
	
	return true

func _configure_spawned_note(note_instance: Node3D, item_id: String) -> void:
	# Set metadata for interaction systems
	note_instance.set_meta("item_id", item_id)
	note_instance.set_meta("is_collectible", true)
	note_instance.set_meta("is_interactable", true)
	note_instance.add_to_group("collectibles")
	note_instance.add_to_group("interactable_items")
	
	# Find and configure the Area3D for interaction
	var area_3d = note_instance.get_node_or_null("Area3D")
	if area_3d:
		# Connect area signals for interaction detection
		if not area_3d.body_entered.is_connected(_on_note_area_entered):
			area_3d.body_entered.connect(_on_note_area_entered.bind(note_instance))
		if not area_3d.body_exited.is_connected(_on_note_area_exited):
			area_3d.body_exited.connect(_on_note_area_exited.bind(note_instance))
		
		# Set up collision layers for player detection
		area_3d.collision_layer = 0 # Don't collide with anything
		area_3d.collision_mask = 1 # Detect player layer
		
		# Add interaction method to the note instance
		note_instance.set_script(preload("res://scripts/items/ResearchNote.gd"))
		note_instance.item_id = item_id
		
		# Get item info and set name/description
		var item_info = get_item_info(item_id)
		if not item_info.is_empty():
			note_instance.item_name = item_info.get("name", "Research Note")
			note_instance.item_description = item_info.get("description", "Dr. Amundsen's research notes")
		
	else:
		push_error("ItemManager: WARNING - No Area3D found in note scene!")

func _on_note_area_entered(body: Node3D, note_instance: Node3D) -> void:
	if body.is_in_group("player"):
		if _message_bus:
			# Show observation toast first
			var save_manager = get_node_or_null("/root/SaveManager")
			var has_collected_notes = false
			if save_manager and save_manager.has_method("has_event_flag"):
				has_collected_notes = save_manager.has_event_flag("has_collected_note")
			
			var observation_text = "A note? Out here?" if not has_collected_notes else "Another note"
			_message_bus.emit_event("narration_requested", [observation_text, 2.5])
			
			# Then show interaction prompt
			var prompt_text = "Press E to collect"
			_message_bus.emit_event("show_interaction_prompt", [prompt_text, note_instance])

func _on_note_area_exited(body: Node3D, note_instance: Node3D) -> void:
	if body.is_in_group("player"):
		if _message_bus:
			_message_bus.emit_event("hide_interaction_prompt", [note_instance])

func _on_item_interaction_enter(body: Node3D, item_node: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	
	var item_id: String = item_node.get_meta("item_id", "")
	if item_id.is_empty():
		return
	
	# Show interaction prompt via NarrationSystem
	if _message_bus:
		_message_bus.emit_event("show_interaction_prompt", [item_id, item_node])

func _on_item_interaction_exit(body: Node3D, item_node: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Hide interaction prompt
	if _message_bus:
		_message_bus.emit_event("hide_interaction_prompt", [item_node])

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
