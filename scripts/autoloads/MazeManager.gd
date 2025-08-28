extends Node
## Maze Manager - Handles maze generation and dynamic shifting
## Ported from JavaScript mazeGenerator.js

signal maze_generated
signal maze_section_shifted(center: Vector2i)

@export var grid_width: int = 100
@export var grid_height: int = 100
@export var cell_size: float = 4.0

# Maze data structure - 2D array of cells
var maze: Array[Array] = []
var maze_chunks: Dictionary = {}  # 3D mesh instances for visualization

# Cell structure: { walls: { top: bool, right: bool, bottom: bool, left: bool }, visited: bool }
class MazeCell:
	var walls: Dictionary = { "top": true, "right": true, "bottom": true, "left": true }
	var visited: bool = false
	var distorted: bool = false

func _ready():
	# Initialize empty maze grid
	_initialize_maze_grid()

func _initialize_maze_grid():
	"""Initialize the maze grid with empty cells"""
	maze.clear()
	for y in range(grid_height):
		var row: Array = []
		for x in range(grid_width):
			row.append(MazeCell.new())
		maze.append(row)

func generate_new_maze():
	"""Generate a complete new maze using depth-first search algorithm"""
	_initialize_maze_grid()
	
	# Start from a random position
	var start_x = 1 + randi() % (grid_width - 2) 
	var start_y = 1 + randi() % (grid_height - 2)
	
	maze[start_y][start_x].visited = true
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	
	while stack.size() > 0:
		var current = stack[-1]
		var neighbors = _get_unvisited_neighbors(current.x, current.y)
		
		if neighbors.size() > 0:
			var next = neighbors[randi() % neighbors.size()]
			_remove_wall(current, next)
			maze[next.y][next.x].visited = true
			stack.push_back(next)
		else:
			stack.pop_back()
	
	# Reset visited flags
	for y in range(grid_height):
		for x in range(grid_width):
			maze[y][x].visited = false
	
	# Add creepy distortion patterns
	_add_distortion_zones()
	
	emit_signal("maze_generated")

func _get_unvisited_neighbors(x: int, y: int) -> Array[Vector2i]:
	"""Get all unvisited neighboring cells"""
	var neighbors: Array[Vector2i] = []
	
	# Check all four directions
	var directions = [
		Vector2i(0, -1),  # Top
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Bottom
		Vector2i(-1, 0)   # Left
	]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		
		if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
			if not maze[ny][nx].visited:
				neighbors.append(Vector2i(nx, ny))
	
	return neighbors

func _remove_wall(cell1: Vector2i, cell2: Vector2i):
	"""Remove the wall between two adjacent cells"""
	var dx = cell2.x - cell1.x
	var dy = cell2.y - cell1.y
	
	if dy == -1:  # cell2 is above cell1
		maze[cell1.y][cell1.x].walls["top"] = false
		maze[cell2.y][cell2.x].walls["bottom"] = false
	elif dy == 1:  # cell2 is below cell1
		maze[cell1.y][cell1.x].walls["bottom"] = false
		maze[cell2.y][cell2.x].walls["top"] = false
	elif dx == -1:  # cell2 is left of cell1
		maze[cell1.y][cell1.x].walls["left"] = false
		maze[cell2.y][cell2.x].walls["right"] = false
	elif dx == 1:  # cell2 is right of cell1
		maze[cell1.y][cell1.x].walls["right"] = false
		maze[cell2.y][cell2.x].walls["left"] = false

func _add_distortion_zones():
	"""Add creepy distortion patterns to the maze"""
	var distortion_zones = randi_range(3, 6)
	
	for i in range(distortion_zones):
		var center_x = 4 + randi() % (grid_width - 8)
		var center_y = 4 + randi() % (grid_height - 8)
		var radius = randi_range(2, 4)
		
		for y in range(center_y - radius, center_y + radius + 1):
			for x in range(center_x - radius, center_x + radius + 1):
				if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
					maze[y][x].distorted = true
					
					# Randomly modify walls in distorted areas
					if randf() < 0.4:
						_randomly_toggle_walls(x, y)

func _randomly_toggle_walls(x: int, y: int):
	"""Randomly toggle walls for a cell to create distortion"""
	var wall_types = ["top", "right", "bottom", "left"]
	
	for wall_type in wall_types:
		if randf() < 0.3:  # 30% chance to toggle each wall
			var neighbor_pos = _get_neighbor_position(x, y, wall_type)
			
			if _is_valid_position(neighbor_pos):
				# Toggle the wall and its neighbor's corresponding wall
				maze[y][x].walls[wall_type] = !maze[y][x].walls[wall_type]
				var opposite_wall = _get_opposite_wall(wall_type)
				maze[neighbor_pos.y][neighbor_pos.x].walls[opposite_wall] = maze[y][x].walls[wall_type]

func shift_maze_section():
	"""Dynamically shift a section of the maze"""
	var player_pos = _get_player_position()  # TODO: Get from player
	
	# Find an area to modify near but not adjacent to player
	var center_x = clamp(player_pos.x + randi_range(-5, 5), 3, grid_width - 3)
	var center_y = clamp(player_pos.y + randi_range(-5, 5), 3, grid_height - 3)
	
	# Shift walls in a 3x3 area
	for y in range(center_y - 1, center_y + 2):
		for x in range(center_x - 1, center_x + 2):
			if _is_valid_position(Vector2i(x, y)):
				_randomly_toggle_walls(x, y)
	
	emit_signal("maze_section_shifted", Vector2i(center_x, center_y))

func _get_player_position() -> Vector2i:
	"""Get current player grid position"""
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_grid_position"):
		return player.get_grid_position()
	return Vector2i(grid_width / 2, grid_height / 2)  # Default center

func _get_neighbor_position(x: int, y: int, wall_type: String) -> Vector2i:
	"""Get the position of the neighbor across a specific wall"""
	match wall_type:
		"top": return Vector2i(x, y - 1)
		"right": return Vector2i(x + 1, y)
		"bottom": return Vector2i(x, y + 1)
		"left": return Vector2i(x - 1, y)
		_: return Vector2i(x, y)

func _get_opposite_wall(wall_type: String) -> String:
	"""Get the opposite wall type"""
	match wall_type:
		"top": return "bottom"
		"right": return "left"
		"bottom": return "top"
		"left": return "right"
		_: return "top"

func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if a position is within maze bounds"""
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

# Public API
func get_cell(x: int, y: int) -> MazeCell:
	"""Get maze cell at specific coordinates"""
	if _is_valid_position(Vector2i(x, y)):
		return maze[y][x]
	return null

func can_move(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	"""Check if movement between two adjacent cells is possible"""
	if not _is_valid_position(Vector2i(from_x, from_y)) or not _is_valid_position(Vector2i(to_x, to_y)):
		return false
	
	var dx = to_x - from_x
	var dy = to_y - from_y
	
	# Only check adjacent cells
	if abs(dx) + abs(dy) != 1:
		return false
	
	var cell = maze[from_y][from_x]
	
	if dx == 1:  # Moving right
		return not cell.walls["right"]
	elif dx == -1:  # Moving left
		return not cell.walls["left"]
	elif dy == 1:  # Moving down
		return not cell.walls["bottom"]
	elif dy == -1:  # Moving up
		return not cell.walls["top"]
	
	return false

func get_maze_size() -> Vector2i:
	"""Get the size of the maze grid"""
	return Vector2i(grid_width, grid_height)

func is_distorted_area(x: int, y: int) -> bool:
	"""Check if a cell is in a distorted zone"""
	if _is_valid_position(Vector2i(x, y)):
		return maze[y][x].distorted
	return false
