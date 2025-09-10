extends Node3D
## Tile - Basic tile functionality without state management
## State management is now handled by TileStateManager

# Door constants
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

# Door detection - ONLY from Maze/Doors path
var door_markers: Dictionary = {}  # DoorDirection -> Marker3D node
var current_rotation: int = 0

# Global door tracking
var global_north_door: Marker3D = null
var global_east_door: Marker3D = null  
var global_south_door: Marker3D = null
var global_west_door: Marker3D = null

# Tile dimensions
var tile_size: Vector2 = Vector2.ZERO

# Permanent tile attribute
@export var is_permanent: bool = false

# State callbacks (called by TileStateManager)
var is_active_tile: bool = false
var is_connecting_tile: bool = false
var is_past_tile: bool = false

func _ready() -> void:
	detect_tile_size()
	detect_doors()
	setup_collision_layers()
	
	_register_collectibles()
	_register_backpacks()

func detect_tile_size() -> void:
	"""Detect tile dimensions from the floor mesh"""
	var floor_mesh: MeshInstance3D = get_node_or_null("Maze/Floor") as MeshInstance3D
	if floor_mesh and floor_mesh.mesh is PlaneMesh:
		var plane_mesh: PlaneMesh = floor_mesh.mesh as PlaneMesh
		tile_size = plane_mesh.size
		print("Detected tile size: ", tile_size)
	else:
		print("WARNING: Floor mesh is not a PlaneMesh, using default size")
		tile_size = Vector2(20, 20)

func get_tile_size() -> Vector2:
	return tile_size

func detect_doors() -> void:
	"""Detect door markers from Maze/Doors or fall back to old paths"""
	door_markers.clear()
	
	# First try: Look in Maze/Doors container
	var doors_container: Node = get_node_or_null("Maze/Doors")
	if doors_container:
		print("Found Maze/Doors container, detecting doors...")
		_detect_doors_from_container(doors_container)
	else:
		print("No Maze/Doors container, trying old door paths...")
		_detect_doors_legacy()
	
	if door_markers.is_empty():
		print("WARNING: No doors detected on this tile!")
	
	# Initialize global door tracking
	_update_global_door_assignments(0)
	
	print("Tile initialized with ", door_markers.size(), " doors")

func _detect_doors_from_container(container: Node) -> void:
	"""Detect doors from all Marker3D children in Doors container"""
	for child in container.get_children():
		if not child is Marker3D:
			continue
		
		var marker: Marker3D = child as Marker3D
		var door_direction: int = _determine_door_direction_from_marker(marker)
		
		if door_direction != -1:
			door_markers[door_direction] = marker
			print("  Detected door: ", get_direction_name(door_direction), " from marker '", marker.name, "'")

func _determine_door_direction_from_marker(marker: Marker3D) -> int:
	"""Determine door direction from marker name or position"""
	var marker_name: String = marker.name.to_lower()
	
	# Check name patterns first (most reliable)
	if "north" in marker_name or "ndoor" in marker_name or marker_name.begins_with("n"):
		return DoorDirection.NORTH
	elif "south" in marker_name or "sdoor" in marker_name or marker_name.begins_with("s"):
		return DoorDirection.SOUTH
	elif "east" in marker_name or "edoor" in marker_name or marker_name.begins_with("e"):
		return DoorDirection.EAST
	elif "west" in marker_name or "wdoor" in marker_name or marker_name.begins_with("w"):
		return DoorDirection.WEST
	
	# Fallback: determine from local position relative to tile center
	var local_pos: Vector3 = marker.position
	var half_size: Vector2 = tile_size / 2
	
	# Check which edge the marker is closest to
	var distances: Dictionary = {
		DoorDirection.NORTH: abs(local_pos.x - half_size.x),   # +X edge
		DoorDirection.SOUTH: abs(local_pos.x + half_size.x),   # -X edge  
		DoorDirection.EAST: abs(local_pos.z - half_size.y),    # +Z edge
		DoorDirection.WEST: abs(local_pos.z + half_size.y)     # -Z edge
	}
	
	# Find closest edge
	var min_distance: float = 999999
	var closest_direction: int = -1
	
	for direction in distances:
		if distances[direction] < min_distance:
			min_distance = distances[direction]
			closest_direction = direction
	
	# Only accept if reasonably close to an edge (within 2 units)
	if min_distance < 2.0:
		print("  Determined door direction from position: ", get_direction_name(closest_direction))
		return closest_direction
	
	print("  Could not determine door direction for marker: ", marker.name)
	return -1

func _detect_doors_legacy() -> void:
	"""Fallback to legacy door detection paths"""
	var door_paths: Dictionary = {
		DoorDirection.NORTH: "Maze/NDoor",
		DoorDirection.SOUTH: "Maze/SDoor", 
		DoorDirection.EAST: "Maze/EDoor",
		DoorDirection.WEST: "Maze/WDoor"
	}
	
	for direction in door_paths:
		var door_path: String = door_paths[direction]
		var door_marker: Node = get_node_or_null(door_path)
		
		if door_marker and door_marker is Marker3D:
			door_markers[direction] = door_marker as Marker3D
			print("  Detected legacy door: ", get_direction_name(direction), " at ", door_path)

func _update_global_door_assignments(rotation_steps: int) -> void:
	"""Update which doors are pointing in which global directions after rotation"""
	global_north_door = null
	global_east_door = null
	global_south_door = null
	global_west_door = null
	
	for original_direction in door_markers:
		var marker: Marker3D = door_markers[original_direction]
		var current_global_direction: int = get_door_after_rotation(original_direction, rotation_steps)
		
		match current_global_direction:
			DoorDirection.NORTH:
				global_north_door = marker
			DoorDirection.EAST:
				global_east_door = marker
			DoorDirection.SOUTH:
				global_south_door = marker
			DoorDirection.WEST:
				global_west_door = marker
	
	print("TILE: Updated global door assignments after ", rotation_steps * 90, "° rotation:")
	if global_north_door: print("  Global NORTH door: ", global_north_door.name)
	if global_east_door: print("  Global EAST door: ", global_east_door.name)
	if global_south_door: print("  Global SOUTH door: ", global_south_door.name)
	if global_west_door: print("  Global WEST door: ", global_west_door.name)

# State management callbacks (called by TileStateManager)
func set_as_active_tile() -> void:
	"""Called by TileStateManager when tile becomes active"""
	is_active_tile = true
	is_connecting_tile = false
	is_past_tile = false
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now ACTIVE")

func set_as_connecting_tile() -> void:
	"""Called by TileStateManager when tile becomes connecting"""
	is_active_tile = false
	is_connecting_tile = true
	is_past_tile = false
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now CONNECTING")

func set_as_past_tile() -> void:
	"""Called by TileStateManager when tile becomes past"""
	is_active_tile = false
	is_connecting_tile = true  # Past tiles are also connecting
	is_past_tile = true
	print("TILE: [", get_meta("grid_position", "?"), "] at ", position, " is now PAST")

func has_door(direction: int) -> bool:
	"""Check if tile has a specific door"""
	return door_markers.has(direction)

func is_tile_permanent() -> bool:
	"""Check if this tile is marked as permanent"""
	return is_permanent

func get_available_doors() -> Dictionary:
	"""Get all available doors using GLOBAL directions"""
	var available: Dictionary = {}
	
	print("TILE: Getting available doors using global directions")
	
	# Check each global direction
	var global_doors: Dictionary = {
		DoorDirection.NORTH: global_north_door,
		DoorDirection.EAST: global_east_door,
		DoorDirection.SOUTH: global_south_door,
		DoorDirection.WEST: global_west_door
	}
	
	for global_direction in global_doors:
		var marker: Marker3D = global_doors[global_direction]
		if marker:
			available[global_direction] = {
				"world_position": marker.global_position,
				"world_orientation": -marker.global_transform.basis.z,
				"marker": marker
			}
			print("  - Global ", get_direction_name(global_direction), " door at ", marker.global_position)
	
	return available

func get_door_world_position(direction: int) -> Vector3:
	"""Get the world position of a door"""
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker: Marker3D = door_markers[direction]
	return marker.global_position

func get_door_world_orientation(direction: int) -> Vector3:
	"""Get the world orientation (forward direction) of a door"""
	if not has_door(direction):
		return Vector3.ZERO
	
	var marker: Marker3D = door_markers[direction]
	return -marker.global_transform.basis.z

func set_tile_rotation(rotation_steps: int) -> void:
	"""Set tile to specific rotation and update global door assignments"""
	current_rotation = rotation_steps % 4
	rotation.y = current_rotation * PI / 2
	
	_update_global_door_assignments(current_rotation)
	
	print("Tile set to rotation: ", current_rotation * 90, " degrees (counter-clockwise)")

func get_current_rotation() -> int:
	"""Get current rotation in steps (0-3)"""
	return current_rotation

func get_door_after_rotation(original_door: int, rotation_steps: int) -> int:
	"""Get what door direction becomes after rotation (counter-clockwise)"""
	var door_index: int = _door_enum_to_index(original_door)
	var new_index: int = (door_index - rotation_steps + 4) % 4
	return _index_to_door_enum(new_index)

func _door_enum_to_index(door_enum: int) -> int:
	"""Convert door enum to index (0=North, 1=East, 2=South, 3=West)"""
	match door_enum:
		DoorDirection.NORTH: return 0
		DoorDirection.EAST: return 1
		DoorDirection.SOUTH: return 2
		DoorDirection.WEST: return 3
		_: return 0

func _index_to_door_enum(index: int) -> int:
	"""Convert index back to door enum"""
	match index:
		0: return DoorDirection.NORTH
		1: return DoorDirection.EAST
		2: return DoorDirection.SOUTH
		3: return DoorDirection.WEST
		_: return DoorDirection.NORTH

func get_direction_name(direction: int) -> String:
	"""Helper function to get direction name from enum value"""
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East" 
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

func setup_collision_layers() -> void:
	"""Set up proper collision layers for this tile"""
	_set_walls_collision_layer(self, 2)

func _set_walls_collision_layer(node: Node, layer: int) -> void:
	"""Recursively set collision layers for all StaticBody3D nodes (walls)"""
	if node is StaticBody3D:
		node.collision_layer = layer
		node.collision_mask = 0
	
	for child in node.get_children():
		_set_walls_collision_layer(child, layer)

func _register_collectibles() -> void:
	"""Register all collectible items in this tile"""
	for child in get_children():
		if child.has_meta("is_collectible"):
			child.add_to_group("collectibles")

func _register_backpacks() -> void:
	"""Register all backpacks in this tile"""
	for child in get_children():
		if child.has_meta("is_backpack"):
			child.add_to_group("backpacks")

func get_spawn_points() -> Array[Vector3]:
	"""Get all item spawn points in this tile"""
	var spawn_points: Array[Vector3] = []
	var spawn_parent: Node = get_node_or_null("Maze/SpawnPoints")
	
	if spawn_parent:
		for child in spawn_parent.get_children():
			if child is Marker3D:
				spawn_points.append(child.global_position)
	
	return spawn_points

func debug_print_tile_info() -> void:
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
		var marker: Marker3D = door_markers[direction]
		print("  ", get_direction_name(direction), ": ", marker.global_position)
	print("=====================")
