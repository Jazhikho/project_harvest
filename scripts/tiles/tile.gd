extends Node3D

# Door constants
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

# Door marker paths
var door_paths = {
	DoorDirection.NORTH: "Maze/NDoor",
	DoorDirection.SOUTH: "Maze/SDoor", 
	DoorDirection.EAST: "Maze/EDoor",
	DoorDirection.WEST: "Maze/WDoor"
}

# Detected door data
var door_markers = {}  # DoorDirection -> Marker3D node
var current_rotation: int = 0  # 0, 1, 2, 3 representing 0°, 90°, 180°, 270°

# Tile dimensions (must be set by scene or detected from floor mesh)
var tile_size: Vector2 = Vector2.ZERO  # Will be detected from floor mesh

# Called when the node enters the scene tree
func _ready():
	detect_tile_size()
	detect_doors()
	setup_door_detection()
	setup_collision_layers()

# Detect tile size from floor mesh
func detect_tile_size():
	"""Detect tile dimensions from the floor mesh"""
	var floor_mesh = get_node_or_null("Maze/Floor")
	if floor_mesh and floor_mesh is MeshInstance3D:
		var mesh = floor_mesh.mesh
		if mesh is PlaneMesh:
			tile_size = mesh.size
			print("Detected tile size: ", tile_size)
		else:
			print("WARNING: Floor mesh is not a PlaneMesh, using default size")
			tile_size = Vector2(20, 20)  # Default fallback
	else:
		print("WARNING: Could not find floor mesh, using default size")
		tile_size = Vector2(20, 20)  # Default fallback

# Get tile dimensions
func get_tile_size() -> Vector2:
	return tile_size

# Automatically detect which doors are present in this tile
func detect_doors():
	door_markers.clear()
	
	for direction in door_paths:
		var door_node = get_node_or_null(door_paths[direction])
		if door_node and door_node is Marker3D:
			door_markers[direction] = door_node
			print("Detected door: ", get_direction_name(direction))
	
	print("Tile initialized with ", door_markers.size(), " doors")

# Set up door detection areas for player crossing
func setup_door_detection():
	"""Setup Area3D collision detection for each door marker"""
	for direction in door_markers:
		var marker = door_markers[direction]
		
		# Create Area3D for door crossing detection
		var area = Area3D.new()
		area.name = "DoorDetector_" + get_direction_name(direction)
		
		# Create collision shape
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2.0, 3.0, 2.0)  # Door threshold area
		collision.shape = shape
		
		# Add components to marker
		marker.add_child(area)
		area.add_child(collision)
		
		# Connect signals for player crossing detection
		area.body_entered.connect(func(body): _on_door_crossed(direction, body))
		
		# Set collision layers/masks for player detection
		area.collision_layer = 0  # Don't collide with anything
		area.collision_mask = 1   # Detect layer 1 (player)

func _on_door_crossed(direction: DoorDirection, body: Node3D):
	"""Handle when player crosses a door threshold"""
	if not body.is_in_group("player"):
		return
	
	print("Player crossed door: ", get_direction_name(direction))
	
	# Get the tile position from TileManager
	var tile_manager = get_node("/root/TileManager")
	if tile_manager:
		# Calculate which tile position this door leads to
		var current_pos = tile_manager.get_current_player_tile()
		var target_pos = _get_door_target_position(current_pos, direction)
		
		# Notify TileManager that player entered a new tile
		tile_manager.on_player_entered_tile(target_pos)

func _get_door_target_position(current_pos: Vector2i, door_direction: DoorDirection) -> Vector2i:
	"""Get the target tile position when crossing a door"""
	match door_direction:
		DoorDirection.NORTH: return current_pos + Vector2i(1, 0)   # North = +X in grid
		DoorDirection.EAST: return current_pos + Vector2i(0, 1)    # East = +Y in grid  
		DoorDirection.SOUTH: return current_pos + Vector2i(-1, 0)  # South = -X in grid
		DoorDirection.WEST: return current_pos + Vector2i(0, -1)   # West = -Y in grid
		_: return current_pos

# Check if tile has a specific door
func has_door(direction: DoorDirection) -> bool:
	return door_markers.has(direction)

# Get all available doors with their world data
func get_available_doors() -> Dictionary:
	"""Get all available doors with their world positions and orientations"""
	var available = {}
	
	print("TILE: Getting available doors - found ", door_markers.size(), " door markers")
	
	for direction in door_markers:
		var marker = door_markers[direction]
		available[direction] = {
			"world_position": marker.global_position,
			"world_orientation": -marker.global_transform.basis.z,  # Forward direction
			"marker": marker
		}
		print("  - Door ", get_direction_name(direction), " at ", marker.global_position)
	
	return available

# Get the world position of a door
func get_door_world_position(direction: DoorDirection) -> Vector3:
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker = door_markers[direction]
	return marker.global_position

# Get the world orientation (forward direction) of a door  
func get_door_world_orientation(direction: DoorDirection) -> Vector3:
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker = door_markers[direction]
	return -marker.global_transform.basis.z

# Set tile to specific rotation (0-3, representing 0°, 90°, 180°, 270°)
func set_tile_rotation(rotation_steps: int):
	current_rotation = rotation_steps % 4
	rotation.y = current_rotation * PI / 2
	print("Tile set to rotation: ", current_rotation * 90, " degrees")
	
	# Note: Door markers physically rotate with the tile, so we don't need to remap directions

# Helper function to get direction name from enum value
func get_direction_name(direction: DoorDirection) -> String:
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East" 
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

# === COLLISION LAYER SETUP ===

func setup_collision_layers():
	"""Set up proper collision layers for this tile"""
	_set_walls_collision_layer(self, 2)  # Set all walls to layer 2

func _set_walls_collision_layer(node: Node, layer: int):
	"""Recursively set collision layers for all StaticBody3D nodes (walls)"""
	if node is StaticBody3D:
		# This is a wall - set it to layer 2
		node.collision_layer = layer
		node.collision_mask = 0  # Walls don't need to detect anything
	
	# Recursively process children
	for child in node.get_children():
		_set_walls_collision_layer(child, layer)
