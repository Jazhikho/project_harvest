extends Node3D
## Crows Parliament Puzzle - Mirror reconstruction puzzle

class_name CrowsParliamentPuzzle

@export var puzzle_id: String = "crows_parliament"
@export var required_items: Array[String] = ["broken_glass_1", "broken_glass_2", "broken_glass_3"]

var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var _puzzle_ui: Control

var _items_placed: Array = []
var _completion_order: int = -1 # Which number puzzle this was (1st, 2nd, 3rd)

@onready var mirror_area: Area3D = $Area3D

func _ready() -> void:
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
		push_error("CrowsParliamentPuzzle: Required systems not found")
		return
	
	_load_puzzle_state()

func _setup_interaction_area() -> void:
	"""Setup interaction area for mirror"""
	if not mirror_area:
		var mirror_node: Node3D = get_node_or_null("BrokenMirror")
		if not mirror_node:
			push_error("CrowsParliamentPuzzle: BrokenMirror node not found")
			return
		
		mirror_area = Area3D.new()
		mirror_area.name = "Area3D"
		mirror_node.add_child(mirror_area)
		
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(2, 3, 0.5)
		collision.shape = shape
		mirror_area.add_child(collision)
	
	mirror_area.collision_layer = 8
	mirror_area.collision_mask = 1

func interact() -> bool:
	"""Called when player interacts with the mirror"""
	if _save_manager.is_puzzle_completed(puzzle_id):
		_show_message("The mirror shows your reflection clearly now.")
		return true
	
	_show_puzzle_ui()
	return true

func _show_puzzle_ui() -> void:
	"""Show the puzzle UI"""
	_puzzle_ui = get_tree().current_scene.get_node_or_null("PuzzleUI")
	
	if not _puzzle_ui:
		_puzzle_ui = preload("res://scenes/ui/PuzzleUI.tscn").instantiate()
		get_tree().current_scene.add_child(_puzzle_ui)
	
	if _puzzle_ui.has_method("show_mirror_puzzle"):
		_puzzle_ui.show_mirror_puzzle(self)

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
	"""Try to place a mirror shard"""
	if item_id in required_items:
		if item_id in _items_placed:
			return {
				"success": false,
				"message": "That piece is already in place."
			}
		
		_items_placed.append(item_id)
		_player_inventory.remove_item(item_id)
		_save_manager.mark_puzzle_item_used(puzzle_id, item_id)
		_save_puzzle_state()
		
		if _items_placed.size() == required_items.size():
			_complete_puzzle()
			
			var message = "The reflection seems strange..."
			
			return {
				"success": true,
				"message": message,
				"completed": true,
				"completion_order": _completion_order
			}
		else:
			var remaining: int = required_items.size() - _items_placed.size()
			return {
				"success": true,
				"message": "The shard fits perfectly. %d pieces remaining." % remaining,
				"completed": false
			}
	else:
		return {
			"success": false,
			"message": "This doesn't fit the mirror."
		}

func _complete_puzzle() -> void:
	"""Mark puzzle as completed"""
	# Determine completion order
	_completion_order = _get_completion_order()
	
	_save_manager.set_puzzle_state(puzzle_id, {
		"items_placed": _items_placed,
		"completion_order": _completion_order,
		"completed": true
	})
	
	_save_manager.mark_puzzle_completed(puzzle_id)
	
	var enemy_manager: Node = get_node_or_null("/root/EnemyManager")
	if enemy_manager and enemy_manager.has_method("spawn_aggressive_effigies"):
		enemy_manager.spawn_aggressive_effigies(_completion_order, self)
	
	if _message_bus:
		var tile_pos: Vector2i = Vector2i.ZERO
		var state_manager: Node = get_node_or_null("/root/GameStateManager")
		if state_manager:
			tile_pos = state_manager.get_state("current_tile_position")
		
		_message_bus.emit_event("puzzle_completed", [
			puzzle_id,
			tile_pos,
			{"completion_order": _completion_order}
		])

func _get_completion_order() -> int:
	"""Determine which number puzzle this is (1st, 2nd, or 3rd completed)"""
	var completed_count: int = 1 # This puzzle is being completed now
	
	if _save_manager.is_puzzle_completed("whispering_hollow"):
		completed_count += 1
	if _save_manager.is_puzzle_completed("watching_stones"):
		completed_count += 1
	
	return completed_count

func _load_puzzle_state() -> void:
	"""Load puzzle state from save"""
	var state: Dictionary = _save_manager.get_puzzle_state(puzzle_id)
	_items_placed = state.get("items_placed", [])
	_completion_order = state.get("completion_order", -1)

func _save_puzzle_state() -> void:
	"""Save current puzzle state"""
	_save_manager.set_puzzle_state(puzzle_id, {
		"items_placed": _items_placed,
		"completion_order": _completion_order
	})

func _show_message(text: String) -> void:
	"""Show message to player"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", [text, 3.0, 1])
