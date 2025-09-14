extends Node
## Player Interaction - Handles collecting items and interacting with puzzles

@export var interaction_range: float = 2.0

var inventory: Node
var event_manager: Node
var current_puzzle_tile: Node3D = null

func _ready():
	inventory = get_node_or_null("../PlayerInventory")
	if not inventory:
		push_error("PlayerInteraction: PlayerInventory not found!")
	
	event_manager = get_node_or_null("/root/EventManager")

func _input(event):
	if event.is_action_pressed("interact"):  # Assuming 'E' key
		_try_interact()

func _try_interact():
	"""Try to interact with nearby objects"""
	# Get all bodies in range
	var space_state = get_parent().get_world_3d().direct_space_state
	var player_pos = get_parent().global_position
	
	# Check for collectibles
	_check_for_collectibles(player_pos)
	
	# Check for puzzles
	_check_for_puzzles(player_pos)
	
	# Check for backpacks
	_check_for_backpacks(player_pos)

func _check_for_collectibles(player_pos: Vector3):
	"""Check for nearby collectible items"""
	# Find all items within range
	var items = get_tree().get_nodes_in_group("collectibles")
	
	for item in items:
		if item.has_meta("is_collectible") and item.global_position.distance_to(player_pos) <= interaction_range:
			_collect_item(item)
			return  # Only collect one item at a time

func _collect_item(item: Node3D):
	"""Collect an item"""
	var item_id = item.get_meta("item_id", "")
	if item_id == "":
		return
	
	if inventory and inventory.add_item(item_id):
		var tile_pos = item.get_meta("tile_position", Vector2i())
		
		# Notify EventManager
		if event_manager:
			event_manager.on_item_collected(item_id, tile_pos)
		
		# Remove the item
		item.queue_free()
	else:
		pass

func _check_for_backpacks(player_pos: Vector3):
	"""Check for nearby backpacks from previous runs"""
	var backpacks = get_tree().get_nodes_in_group("backpacks")
	
	for backpack in backpacks:
		if backpack.has_meta("is_backpack") and backpack.global_position.distance_to(player_pos) <= interaction_range:
			_collect_backpack(backpack)
			return

func _collect_backpack(backpack: Node3D):
	"""Collect items from a backpack"""
	var backpack_inventory = backpack.get_meta("inventory", [])
	
	if inventory:
		inventory.load_from_backpack(backpack_inventory)
	
	# Remove the backpack
	backpack.queue_free()

func _check_for_puzzles(player_pos: Vector3):
	"""Check for nearby puzzle interaction points"""
	var puzzles = get_tree().get_nodes_in_group("puzzle_tiles")
	
	for puzzle_tile in puzzles:
		if puzzle_tile.has_method("get_interaction_point"):
			var interaction_point = puzzle_tile.get_interaction_point()
			if interaction_point.distance_to(player_pos) <= interaction_range:
				current_puzzle_tile = puzzle_tile
				_show_puzzle_ui()
				return

func _show_puzzle_ui():
	"""Show UI for puzzle interaction"""
	if not current_puzzle_tile or not inventory:
		return
	
	var puzzle_id = current_puzzle_tile.get_puzzle_id()
	var available_pieces = inventory.get_puzzle_pieces()
	
	if available_pieces.is_empty():
		return
	
	# For now, try the first piece
	_try_use_puzzle_piece(available_pieces[0], puzzle_id)

func _try_use_puzzle_piece(piece_id: String, puzzle_id: String):
	"""Attempt to use a puzzle piece on a puzzle"""
	if not event_manager:
		return
	
	var tile_pos = current_puzzle_tile.get_meta("world_map_pos", Vector2i())
	
	if event_manager.on_puzzle_piece_used(piece_id, puzzle_id, tile_pos):
		# Piece was correct, remove from inventory
		if inventory:
			inventory.remove_item(piece_id)
		
		# Update the puzzle tile visually
		if current_puzzle_tile.has_method("add_puzzle_piece"):
			current_puzzle_tile.add_puzzle_piece(piece_id)
		
		pass
	else:
		pass
