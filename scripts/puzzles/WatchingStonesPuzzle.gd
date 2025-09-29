extends Node3D
## Watching Stones Puzzle - Multiple interaction points (brazier and altar)

class_name WatchingStonesPuzzle

@export var puzzle_id: String = "watching_stones"
@export var required_items = ["phone", "holy_book", "flag"]

var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var _puzzle_ui: Control

var _items_placed = []
var _altar_items = []  # Track items placed on altar specifically
var _brazier_items = []  # Track items placed in brazier

@onready var altar_area: Area3D = $altar/Area3D
@onready var brazier_area: Area3D = $wbrazier/Area3D

func _ready() -> void:
	set_meta("is_puzzle", true)
	set_meta("puzzle_id", puzzle_id)
	
	call_deferred("_initialize_systems")
	_setup_interaction_areas()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")
	_save_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus or not _player_inventory or not _save_manager:
		push_error("WatchingStonesPuzzle: Required systems not found")
		return
	
	_load_puzzle_state()

func _setup_interaction_areas() -> void:
	"""Setup interaction areas for both altar and brazier"""
	# Setup altar interaction
	if not altar_area:
		altar_area = _create_interaction_area($altar, "Altar")
	
	# Setup brazier interaction
	if not brazier_area:
		brazier_area = _create_interaction_area($brazier, "Brazier")

func _create_interaction_area(parent: Node3D, area_name: String) -> Area3D:
	"""Create an interaction area for a puzzle object"""
	var area: Area3D = Area3D.new()
	area.name = "Area3D"
	parent.add_child(area)
	
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision.shape = shape
	area.add_child(collision)
	
	area.collision_layer = 8
	area.collision_mask = 1
	
	# Add interaction metadata to parent
	parent.set_meta("is_puzzle_part", true)
	parent.set_meta("interaction_type", area_name.to_lower())
	parent.set_meta("parent_puzzle", self)
	
	return area

func interact_with_altar() -> bool:
	"""Called when player interacts with altar"""
	if _save_manager.is_puzzle_completed(puzzle_id):
		_show_message("The altar is quiet now.")
		return true
	
	_show_puzzle_ui("altar")
	return true

func interact_with_brazier() -> bool:
	"""Called when player interacts with brazier"""
	if _save_manager.is_puzzle_completed(puzzle_id):
		_show_message("The brazier's flame has died.")
		return true
	
	_show_puzzle_ui("brazier")
	return true

func interact() -> bool:
	"""Generic interact - determine which object based on raycast"""
	return interact_with_altar()

func _show_puzzle_ui(interaction_type: String) -> void:
	"""Show puzzle UI for specific interaction type"""
	_puzzle_ui = get_tree().current_scene.get_node_or_null("PuzzleUI")
	
	if not _puzzle_ui:
		_puzzle_ui = preload("res://scenes/ui/PuzzleUI.tscn").instantiate()
		get_tree().current_scene.add_child(_puzzle_ui)
	
	if _puzzle_ui.has_method("show_watching_stones_puzzle"):
		_puzzle_ui.show_watching_stones_puzzle(self, interaction_type)

func get_available_puzzle_pieces() -> Array[Dictionary]:
	"""Get all puzzle pieces in player inventory"""
	var puzzle_pieces: Array[Dictionary] = []
	
	if not _player_inventory:
		return puzzle_pieces
	
	var inventory: Array = _player_inventory.get_inventory()
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	
	for item_id in inventory:
		if item_manager and item_manager.has_method("get_item_info"):
			var item_info: Dictionary = item_manager.get_item_info(item_id)
			if item_info.get("category", "") == "puzzle_pieces":
				puzzle_pieces.append({
					"id": item_id,
					"name": item_info.get("name", item_id),
					"puzzle_id": item_info.get("puzzle_id", "")
				})
	
	return puzzle_pieces

func try_place_item_on_altar(item_id: String) -> Dictionary:
	"""Try to place an item on the altar"""
	return _try_place_item(item_id, "altar")

func try_place_item_in_brazier(item_id: String) -> Dictionary:
	"""Try to place an item in the brazier"""
	return _try_place_item(item_id, "brazier")

func try_place_item(item_id: String, location: String = "altar") -> Dictionary:
	"""Route to appropriate placement method"""
	if location == "brazier":
		return try_place_item_in_brazier(item_id)
	else:
		return try_place_item_on_altar(item_id)

func _try_place_item(item_id: String, location: String) -> Dictionary:
	"""Internal method to place items"""
	if item_id in required_items:
		if item_id in _items_placed:
			return {
				"success": false,
				"message": "You already placed that item."
			}
		
		_items_placed.append(item_id)
		
		# Track which location got the item
		if location == "altar":
			_altar_items.append(item_id)
		else:
			_brazier_items.append(item_id)
		
		_player_inventory.remove_item(item_id)
		_save_manager.mark_puzzle_item_used(puzzle_id, item_id)
		_save_puzzle_state()
		
		if _items_placed.size() == required_items.size():
			_complete_puzzle()
			var altar_count: int = _altar_items.size()
			return {
				"success": true,
				"completed": true,
				"altar_count": altar_count
			}
		else:
			var location_name: String = "altar" if location == "altar" else "brazier"
			return {
				"success": true,
				"completed": false
			}
	else:
		return {
			"success": false,
			"message": "This doesn't belong here."
		}

func _complete_puzzle() -> void:
	"""Mark puzzle as completed"""
	# Save the altar count as important data
	_save_manager.set_puzzle_state(puzzle_id, {
		"items_placed": _items_placed,
		"altar_items": _altar_items,
		"brazier_items": _brazier_items,
		"altar_count": _altar_items.size(),
		"completed": true
	})
	
	_save_manager.mark_puzzle_completed(puzzle_id)
	
	var effigy_count = min(_altar_items.size(), 3)
	SpawnManager.spawn_aggressive_effigies(effigy_count, get_tree().current_scene)
	
	if _message_bus:
		var tile_pos: Vector2i = Vector2i.ZERO
		var state_manager: Node = get_node_or_null("/root/GameStateManager")
		if state_manager:
			tile_pos = state_manager.get_state("current_tile_position")
		
		_message_bus.emit_event("puzzle_completed", [
			puzzle_id, 
			tile_pos, 
			{"altar_count": _altar_items.size()}
		])

func _load_puzzle_state() -> void:
	"""Load puzzle state from save"""
	var state: Dictionary = _save_manager.get_puzzle_state(puzzle_id)
	_items_placed = state.get("items_placed", [])
	_altar_items = state.get("altar_items", [])
	_brazier_items = state.get("brazier_items", [])

func _save_puzzle_state() -> void:
	"""Save current puzzle state"""
	_save_manager.set_puzzle_state(puzzle_id, {
		"items_placed": _items_placed,
		"altar_items": _altar_items,
		"brazier_items": _brazier_items
	})

func _show_message(text: String) -> void:
	"""Show message to player"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", [text, 3.0, 1])

func get_altar_count() -> int:
	"""Get number of items on altar"""
	return _altar_items.size()
	
