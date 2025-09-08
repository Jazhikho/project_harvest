extends "res://scripts/tiles/tile.gd"
## Permanent Tile - A tile with a puzzle that persists until solved

@export var puzzle_id: String = "puzzle_1"
@export var required_pieces: Array[String] = []
@export var interaction_marker_path: NodePath = "Maze/PuzzleInteraction"

var placed_pieces: Array[String] = []
var is_completed: bool = false

func _ready():
	super._ready()
	is_permanent = true  # Mark as permanent
	add_to_group("puzzle_tiles")
	
	# Register with EventManager
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		event_manager.register_permanent_tile_puzzle(get_meta("world_map_pos", Vector2i()), puzzle_id)

func get_puzzle_id() -> String:
	return puzzle_id

func get_interaction_point() -> Vector3:
	"""Get the world position of the puzzle interaction point"""
	var marker = get_node_or_null(interaction_marker_path)
	if marker:
		return marker.global_position
	return global_position

func add_puzzle_piece(piece_id: String):
	"""Add a piece to this puzzle"""
	if piece_id not in placed_pieces:
		placed_pieces.append(piece_id)
		_update_puzzle_visual()
		
		# Check if puzzle is complete
		if _check_completion():
			_complete_puzzle()

func _check_completion() -> bool:
	"""Check if all required pieces are placed"""
	for piece in required_pieces:
		if piece not in placed_pieces:
			return false
	return true

func _complete_puzzle():
	"""Handle puzzle completion"""
	is_completed = true
	is_permanent = false  # No longer permanent
	
	print("PUZZLE COMPLETED: ", puzzle_id)
	
	# Visual feedback
	_show_completion_effect()
	
	# Remove from puzzle tiles group
	remove_from_group("puzzle_tiles")
	
	# Notify TileManager to remove from permanent tiles
	var tile_manager = get_node_or_null("/root/TileManager")
	if tile_manager:
		tile_manager.remove_permanent_tile(get_meta("world_map_pos", Vector2i()))

func _update_puzzle_visual():
	"""Update the visual representation of the puzzle"""
	# TODO: Update mesh/material based on placed pieces
	print("Puzzle progress: ", placed_pieces.size(), "/", required_pieces.size())

func _show_completion_effect():
	"""Show visual effect when puzzle is completed"""
	# TODO: Particle effect, sound, etc.
	pass

func get_save_data() -> Dictionary:
	"""Get data to save for this puzzle"""
	return {
		"puzzle_id": puzzle_id,
		"placed_pieces": placed_pieces,
		"is_completed": is_completed
	}

func load_save_data(data: Dictionary):
	"""Load saved puzzle state"""
	placed_pieces = data.get("placed_pieces", [])
	is_completed = data.get("is_completed", false)
	_update_puzzle_visual()
