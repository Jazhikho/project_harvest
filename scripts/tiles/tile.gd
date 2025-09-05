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

# Tile dimensions
var tile_size: Vector2 = Vector2.ZERO  # Will be detected from floor mesh

# Tile state
var is_active_tile: bool = false
var is_connecting_tile: bool = false
var is_past_tile: bool = false

# Permanent tile attribute (can be set in inspector)
@export var is_permanent: bool = false

func _ready():
	detect_tile_size()
	detect_doors()
	setup_collision_layers()
	# Don't setup door detection on _ready - only when tile becomes connecting

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

func get_tile_size() -> Vector2:
	return tile_size

func detect_doors():
	"""Automatically detect which doors are present in this tile"""
	door_markers.clear()
	
	for direction in door_paths:
		var door_node = get_node_or_null(door_paths[direction])
		if door_node and door_node is Marker3D:
			door_markers[direction] = door_node
			print("Detected door: ", get_direction_name(direction))
	
	print("Tile initialized with ", door_markers.size(), " doors")

func setup_tile_entrance_detection():
	"""Setup detection for when player enters THIS tile (connecting tile detection)"""
	print("TILE: Setting up entrance detection for tile at ", position)
	
	# Create a large Area3D that covers the entire tile
	var entrance_area = Area3D.new()
	entrance_area.name = "TileEntranceDetector"
	
	# Create collision shape covering the whole tile
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(tile_size.x - 2, 4.0, tile_size.y - 2)  # Slightly smaller to avoid edge cases
	collision.shape = shape
	
	# Add to tile
	add_child(entrance_area)
	entrance_area.add_child(collision)
	
	# Set collision layers/masks for player detection
	entrance_area.collision_layer = 0  # Don't collide with anything
	entrance_area.collision_mask = 1   # Detect layer 1 (player)
	
	# Connect signals
	entrance_area.body_entered.connect(_on_player_entered_tile)
	
	# Mark as connecting tile
	is_connecting_tile = true
	print("TILE: Entrance detection setup complete - tile is now CONNECTING")

func _on_player_entered_tile(body: Node3D):
	"""Called when player enters this tile - THE KEY DETECTION POINT"""
	if not body.is_in_group("player"):
		print("TILE: Non-player body entered: ", body.name)
		return
	
	if not is_connecting_tile:
		print("TILE: Player entered but this is not a connecting tile (state: active=", is_active_tile, " connecting=", is_connecting_tile, ")")
		return  # Only connecting tiles should trigger this
	
	var grid_pos = get_meta("grid_position", Vector2i(0, 0))
	print("TILE: *** PLAYER ENTERED CONNECTING TILE *** at position ", position, " grid: ", grid_pos)
	
	# Notify TileManager that this tile is now active
	var tile_manager = get_node("/root/TileManager")
	if tile_manager:
		print("TILE: Notifying TileManager of player entrance")
		tile_manager.on_player_entered_tile(grid_pos)
	else:
		print("TILE: ERROR - TileManager not found!")
	
	# This tile is now active, no longer connecting
	is_active_tile = true
	is_connecting_tile = false
	print("TILE: State changed - now ACTIVE")
	
	# Remove entrance detection (no longer needed)
	var entrance_detector = get_node_or_null("TileEntranceDetector")
	if entrance_detector:
		entrance_detector.queue_free()
		print("TILE: Removed entrance detector")

func set_as_active_tile():
	"""Mark this tile as the active tile"""
	is_active_tile = true
	is_connecting_tile = false
	is_past_tile = false
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now ACTIVE")

func set_as_connecting_tile():
	"""Mark this tile as a connecting tile and setup entrance detection"""
	is_active_tile = false
	is_connecting_tile = true
	is_past_tile = false
	setup_tile_entrance_detection()
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now CONNECTING")

func set_as_past_tile():
	"""Mark this tile as a past tile (also acts as connecting temporarily)"""
	is_active_tile = false
	is_connecting_tile = true  # Past tiles also act as connecting tiles temporarily
	is_past_tile = true
	setup_tile_entrance_detection()
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now PAST (also connecting)")

func has_door(direction: DoorDirection) -> bool:
	"""Check if tile has a specific door"""
	return door_markers.has(direction)

func is_tile_permanent() -> bool:
	"""Check if this tile is marked as permanent"""
	return is_permanent

func get_available_doors() -> Dictionary:
	"""Get all available doors with their world data"""
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

func get_door_world_position(direction: DoorDirection) -> Vector3:
	"""Get the world position of a door"""
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker = door_markers[direction]
	return marker.global_position

func get_door_world_orientation(direction: DoorDirection) -> Vector3:
	"""Get the world orientation (forward direction) of a door"""
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker = door_markers[direction]
	return -marker.global_transform.basis.z

func set_tile_rotation(rotation_steps: int):
	"""Set tile to specific rotation (0-3, representing 0°, 90°, 180°, 270°)"""
	current_rotation = rotation_steps % 4
	rotation.y = current_rotation * PI / 2
	print("Tile set to rotation: ", current_rotation * 90, " degrees")
	
	# After rotation, doors are automatically re-oriented by physical rotation
	# The door markers physically rotate with the tile, so their global orientations
	# are automatically re-designated to match their new global directions

func get_current_rotation() -> int:
	"""Get current rotation in steps (0-3)"""
	return current_rotation

func get_door_after_rotation(original_door: DoorDirection, rotation_steps: int) -> DoorDirection:
	"""Get what door direction becomes after rotation"""
	var door_index = _door_enum_to_index(original_door)
	var new_index = (door_index + rotation_steps) % 4
	return _index_to_door_enum(new_index)

func _door_enum_to_index(door_enum: DoorDirection) -> int:
	"""Convert door enum to index (0=North, 1=East, 2=South, 3=West)"""
	match door_enum:
		DoorDirection.NORTH: return 0
		DoorDirection.EAST: return 1
		DoorDirection.SOUTH: return 2
		DoorDirection.WEST: return 3
		_: return 0

func _index_to_door_enum(index: int) -> DoorDirection:
	"""Convert index back to door enum"""
	match index:
		0: return DoorDirection.NORTH
		1: return DoorDirection.EAST
		2: return DoorDirection.SOUTH
		3: return DoorDirection.WEST
		_: return DoorDirection.NORTH

func get_direction_name(direction: DoorDirection) -> String:
	"""Helper function to get direction name from enum value"""
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

# === DEBUG FUNCTIONS ===

func debug_print_tile_info():
	"""Debug function to print tile information"""
	print("=== TILE DEBUG INFO ===")
	print("Position: ", position)
	print("Rotation: ", current_rotation * 90, "°")
	print("Grid Position: ", get_meta("grid_position", "Unknown"))
	print("Is Active: ", is_active_tile)
	print("Is Connecting: ", is_connecting_tile)
	print("Is Past: ", is_past_tile)
	print("Is Permanent: ", is_permanent)
	print("Available Doors: ", door_markers.keys().size())
	for direction in door_markers:
		var marker = door_markers[direction]
		print("  ", get_direction_name(direction), ": ", marker.global_position)
	print("=====================")
