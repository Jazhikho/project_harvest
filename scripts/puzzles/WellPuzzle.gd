extends Node3D
## Well Puzzle - Player must drop correct items into the well

class_name WellPuzzle

## Unique puzzle identifier for save/events
@export var puzzle_id: String = "whispering_hollow"
## Item IDs required to complete puzzle
@export var required_items: Array[String] = ["symbol_watch", "symbol_coin", "symbol_ticket"]

var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var _puzzle_ui: Control

var _items_placed: Array = []
var _wrong_attempts: Array = []

@onready var interaction_area: Area3D = $Area3D

func _ready() -> void:
	# Set metadata for interaction
	set_meta("is_puzzle", true)
	set_meta("puzzle_id", puzzle_id)
	
	call_deferred("_initialize_systems")
	_setup_interaction_area()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")
	_save_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus or not _player_inventory or not _save_manager:
		push_error("WellPuzzle: Required systems not found")
		return
	
	# Load puzzle state
	_load_puzzle_state()

func _setup_interaction_area() -> void:
	"""Setup interaction collision area"""
	if not interaction_area:
		interaction_area = Area3D.new()
		interaction_area.name = "Area3D"
		add_child(interaction_area)
		
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 2.0
		shape.height = 3.0
		collision.shape = shape
		interaction_area.add_child(collision)
	
	interaction_area.collision_layer = 1 << (CollisionHelper.LAYER_PUZZLE_OBJECTS - 1)
	interaction_area.collision_mask = 1 << (CollisionHelper.LAYER_PLAYER - 1)
	if not interaction_area.body_entered.is_connected(_on_interaction_body_entered):
		interaction_area.body_entered.connect(_on_interaction_body_entered)
	if not interaction_area.body_exited.is_connected(_on_interaction_body_exited):
		interaction_area.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node3D) -> void:
	if body and body.is_in_group("player") and body.has_method("register_nearby_interactable"):
		body.register_nearby_interactable(self)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body and body.is_in_group("player") and body.has_method("unregister_nearby_interactable"):
		body.unregister_nearby_interactable(self)

func interact() -> bool:
	"""Called when player interacts with the well"""
	# Check if puzzle already completed
	if _save_manager.is_puzzle_completed(puzzle_id):
		_show_message("The well is silent now.")
		return true
	
	# Show the puzzle UI
	_show_puzzle_ui()
	return true

func _show_puzzle_ui() -> void:
	"""Show the puzzle interaction UI"""
	# Get or create puzzle UI
	_puzzle_ui = get_tree().current_scene.get_node_or_null("PuzzleUI")
	
	if not _puzzle_ui:
		# Create puzzle UI dynamically
		_puzzle_ui = preload("res://scenes/ui/PuzzleUI.tscn").instantiate()
		get_tree().current_scene.add_child(_puzzle_ui)
	
	# Configure UI for this puzzle
	if _puzzle_ui.has_method("show_well_puzzle"):
		_puzzle_ui.show_well_puzzle(self)

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

func try_place_item(item_id: String) -> Dictionary:
	"""
	Try to place an item in the well
	
	@param item_id: ID of item to place
	@return: Dictionary with result {success: bool, message: String}
	"""
	# Check if item is correct for this puzzle
	if item_id in required_items:
		# Check if already placed
		if item_id in _items_placed:
			return {
				"success": false,
				"message": "You already placed that item."
			}
		
		# Place the item
		_items_placed.append(item_id)
		_player_inventory.remove_item(item_id)
		
		# Mark item as permanently used
		_save_manager.mark_puzzle_item_used(puzzle_id, item_id)
		
		# Save state
		_save_puzzle_state()
		
		# Check if puzzle complete
		if _items_placed.size() == required_items.size():
			_complete_puzzle()
			return {
				"success": true,
				"message": "You hear a distant echo...",
				"completed": true
			}
		else:
			return {
				"success": true,
				"message": "The item drops into the well with a soft splash.",
				"completed": false
			}
	else:
		# Wrong item
		if item_id not in _wrong_attempts:
			_wrong_attempts.append(item_id)
			_save_puzzle_state()
		
		return {
			"success": false,
			"message": "No, not that one."
		}

func _complete_puzzle() -> void:
	"""Mark puzzle as completed"""
	_save_manager.mark_puzzle_completed(puzzle_id)
	
	var effigy_count: int = min(_wrong_attempts.size(), 3)
	var enemy_manager: Node = get_node_or_null("/root/EnemyManager")
	if enemy_manager and enemy_manager.has_method("spawn_aggressive_effigies"):
		enemy_manager.spawn_aggressive_effigies(effigy_count, self)
	
	# Emit completion event
	if _message_bus:
		var tile_pos: Vector2i = Vector2i.ZERO
		var state_manager: Node = get_node_or_null("/root/GameStateManager")
		if state_manager:
			tile_pos = state_manager.get_state("current_tile_position")
		
		_message_bus.emit_event("puzzle_completed", [puzzle_id, tile_pos, {}])

func _load_puzzle_state() -> void:
	"""Load puzzle state from save"""
	var state: Dictionary = _save_manager.get_puzzle_state(puzzle_id)
	_items_placed = state.get("items_placed", [])
	_wrong_attempts = state.get("wrong_attempts", [])

func _save_puzzle_state() -> void:
	"""Save current puzzle state"""
	_save_manager.set_puzzle_state(puzzle_id, {
		"items_placed": _items_placed,
		"wrong_attempts": _wrong_attempts
	})

func _show_message(text: String) -> void:
	"""Show message to player"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", [text, 3.0, 1])

func get_puzzle_id() -> String:
	"""Get puzzle identifier"""
	return puzzle_id

func is_completed() -> bool:
	"""Check if puzzle is completed"""
	return _save_manager.is_puzzle_completed(puzzle_id)

func get_items_placed() -> Array[String]:
	"""Get items already placed"""
	return _items_placed.duplicate()

func get_wrong_attempts() -> Array[String]:
	"""Get items that were attempted incorrectly"""
	return _wrong_attempts.duplicate()
