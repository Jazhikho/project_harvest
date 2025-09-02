extends Node3D

# Door bit flags for export (readonly - automatically detected)
@export_flags("N","E","S","W") var doors := 0  # 1,2,4,8

# Door constants
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

var enterance: DoorDirection = -1  # The door the player first entered through
var entrance_set: bool = false  # Whether the entrance has been determined yet
var player_in_tile: bool = false  # Track if player is currently in this tile

# Door marker paths
var door_paths = {
	DoorDirection.NORTH: "Maze/NDoor",
	DoorDirection.SOUTH: "Maze/SDoor", 
	DoorDirection.EAST: "Maze/EDoor",
	DoorDirection.WEST: "Maze/WDoor"
}

# Current rotation state (in 90-degree increments)
var current_rotation: int = 0  # 0, 1, 2, 3 representing 0°, 90°, 180°, 270°

# Detected door data
var door_markers = {}  # DoorDirection -> Marker3D node
var door_positions = {}  # DoorDirection -> Vector3 (local position)
var door_orientations = {}  # DoorDirection -> Vector3 (forward direction)

# Called when the node enters the scene tree
func _ready():
	detect_doors()
	calculate_door_data()
	setup_entrance_detection()
	setup_collision_layers()

# Automatically detect which doors are present in this tile
func detect_doors():
	doors = 0  # Reset doors flag
	door_markers.clear()
	
	for direction in door_paths:
		var door_node = get_node_or_null(door_paths[direction])
		if door_node and door_node is Marker3D:
			doors |= direction  # Set the bit flag
			door_markers[direction] = door_node
			print("Detected door: ", get_direction_name(direction))

# Calculate door positions and orientations
func calculate_door_data():
	door_positions.clear()
	door_orientations.clear()
	
	for direction in door_markers:
		var marker = door_markers[direction]
		door_positions[direction] = marker.position
		
		# Get the forward direction from the marker's transform
		# Marker3D uses -Z as forward direction
		door_orientations[direction] = -marker.transform.basis.z
		
	print("Tile initialized with doors: ", get_door_list())

# Get list of available doors as strings
func get_door_list() -> Array[String]:
	var door_list: Array[String] = []
	if has_door(DoorDirection.NORTH): door_list.append("North")
	if has_door(DoorDirection.EAST): door_list.append("East") 
	if has_door(DoorDirection.SOUTH): door_list.append("South")
	if has_door(DoorDirection.WEST): door_list.append("West")
	return door_list

# Check if tile has a specific door
func has_door(direction: DoorDirection) -> bool:
	return (doors & direction) != 0

# Get the world position of a door
func get_door_world_position(direction: DoorDirection) -> Vector3:
	if not has_door(direction):
		push_warning("Tile does not have door in direction: " + str(direction))
		return Vector3.ZERO
	
	# Apply current rotation to the door position
	var rotated_direction = get_rotated_door_direction(direction)
	if rotated_direction in door_positions:
		return global_transform * door_positions[rotated_direction]
	return Vector3.ZERO

# Get the world orientation (forward direction) of a door
func get_door_world_orientation(direction: DoorDirection) -> Vector3:
	if not has_door(direction):
		push_warning("Tile does not have door in direction: " + str(direction))
		return Vector3.ZERO
	
	# Apply current rotation to the door orientation
	var rotated_direction = get_rotated_door_direction(direction)
	if rotated_direction in door_orientations:
		return global_transform.basis * door_orientations[rotated_direction]
	return Vector3.ZERO

# Rotate the tile by 90 degrees clockwise
func rotate_tile_clockwise():
	current_rotation = (current_rotation + 1) % 4
	rotation.y = current_rotation * PI / 2
	print("Tile rotated to: ", current_rotation * 90, " degrees")

# Rotate the tile by 90 degrees counter-clockwise  
func rotate_tile_counter_clockwise():
	current_rotation = (current_rotation - 1) % 4
	if current_rotation < 0:
		current_rotation = 3
	rotation.y = current_rotation * PI / 2
	print("Tile rotated to: ", current_rotation * 90, " degrees")

# Set tile to specific rotation (0-3, representing 0°, 90°, 180°, 270°)
func set_tile_rotation(rotation_steps: int):
	current_rotation = rotation_steps % 4
	rotation.y = current_rotation * PI / 2
	print("Tile set to rotation: ", current_rotation * 90, " degrees")

# Get the actual door direction after applying current rotation
func get_rotated_door_direction(original_direction: DoorDirection) -> DoorDirection:
	# Map directions to indices for easier rotation calculation
	var direction_order = [DoorDirection.NORTH, DoorDirection.EAST, DoorDirection.SOUTH, DoorDirection.WEST]
	var original_index = direction_order.find(original_direction)
	
	if original_index == -1:
		return original_direction
	
	# Apply rotation (clockwise)
	var rotated_index = (original_index + current_rotation) % 4
	return direction_order[rotated_index]

# Get all available doors in their current rotated positions
func get_available_doors() -> Dictionary:
	var available = {}
	for direction in door_markers:
		var current_logical_direction = get_logical_door_direction(direction)
		available[current_logical_direction] = {
			"world_position": get_door_world_position(current_logical_direction),
			"world_orientation": get_door_world_orientation(current_logical_direction), 
			"marker": door_markers[direction]
		}
	return available

# Get the logical direction of a physical door after rotation
func get_logical_door_direction(physical_direction: DoorDirection) -> DoorDirection:
	var direction_order = [DoorDirection.NORTH, DoorDirection.EAST, DoorDirection.SOUTH, DoorDirection.WEST]
	var physical_index = direction_order.find(physical_direction)
	
	if physical_index == -1:
		return physical_direction
	
	# Reverse the rotation to get logical direction
	var logical_index = (physical_index - current_rotation) % 4
	if logical_index < 0:
		logical_index += 4
		
	return direction_order[logical_index]

# Helper function to get direction name from enum value
func get_direction_name(direction: DoorDirection) -> String:
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East" 
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

# Debug function to print current tile state
func debug_tile_info():
	print("=== Tile Debug Info ===")
	print("Current rotation: ", current_rotation * 90, " degrees")
	print("Available doors: ", get_door_list())
	print("Entrance set: ", entrance_set)
	if entrance_set:
		print("Entrance: ", get_direction_name(enterance))
	print("Player in tile: ", player_in_tile)
	print("Door data:")
	for direction in door_markers:
		var logical_dir = get_logical_door_direction(direction)
		var entrance_marker = " (ENTRANCE)" if direction == enterance else ""
		print("  Physical ", get_direction_name(direction), " -> Logical ", get_direction_name(logical_dir), entrance_marker)
	print("=======================")

# Method to check if this tile can connect to another tile
func can_connect_to(other_tile: Node3D, my_door: DoorDirection, their_door: DoorDirection) -> bool:
	if not has_door(my_door):
		return false
	
	if not other_tile.has_method("has_door") or not other_tile.has_door(their_door):
		return false
	
	# Additional connection logic can be added here
	# For example, checking if door orientations are compatible
	return true

# === ENTRANCE DETECTION SYSTEM ===

func setup_entrance_detection():
	"""Setup Area3D collision detection for each door marker"""
	for direction in door_markers:
		var marker = door_markers[direction]
		
		# Create Area3D for entrance detection
		var area = Area3D.new()
		area.name = "EntranceDetector_" + get_direction_name(direction)
		
		# Create collision shape
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.5, 2.0, 1.5)  # Adjust size as needed
		collision.shape = shape
		
		# Add components to marker
		marker.add_child(area)
		area.add_child(collision)
		
		# Connect signals
		area.body_entered.connect(_on_door_area_entered.bind(direction))
		area.body_exited.connect(_on_door_area_exited.bind(direction))
		
		# Set collision layers/masks for player detection
		area.collision_layer = 0  # Don't collide with anything
		area.collision_mask = 1   # Detect layer 1 (player)

func _on_door_area_entered(direction: DoorDirection, body: Node3D):
	"""Handle when something enters a door area"""
	if not body.is_in_group("player"):
		return
	
	# If this is the first door crossed and player wasn't already in tile
	if not entrance_set and not player_in_tile:
		set_entrance(direction)
		print("TILE: Entrance set to ", get_direction_name(direction))
	
	player_in_tile = true

func _on_door_area_exited(direction: DoorDirection, body: Node3D):
	"""Handle when something exits a door area"""
	if not body.is_in_group("player"):
		return
	
	# Check if player has left the tile entirely
	_check_if_player_left_tile()

func _check_if_player_left_tile():
	"""Check if player has left all door areas (exited the tile)"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var player_in_any_door = false
	for direction in door_markers:
		var marker = door_markers[direction]
		var area = marker.get_node("EntranceDetector_" + get_direction_name(direction))
		
		# Check if player is still overlapping with this door area
		if area.has_overlapping_bodies():
			for body in area.get_overlapping_bodies():
				if body.is_in_group("player"):
					player_in_any_door = true
					break
		
		if player_in_any_door:
			break
	
	if not player_in_any_door:
		player_in_tile = false

func set_entrance(direction: DoorDirection):
	"""Set the tile's entrance to the specified direction"""
	if has_door(direction):
		enterance = direction
		entrance_set = true
		print("TILE: Entrance locked to ", get_direction_name(direction))
	else:
		push_warning("Attempted to set entrance to non-existent door: " + str(direction))

func get_entrance() -> DoorDirection:
	"""Get the current entrance direction"""
	return enterance

func has_entrance_set() -> bool:
	"""Check if the entrance has been determined"""
	return entrance_set

func reset_entrance():
	"""Reset the entrance (for special events that cause randomization)"""
	enterance = -1
	entrance_set = false
	player_in_tile = false
	print("TILE: Entrance reset - will be determined on next entry")

func randomize_entrance():
	"""Randomize the entrance to a different door (for special events)"""
	var available_doors = []
	for direction in door_markers.keys():
		if direction != enterance:  # Don't pick the current entrance
			available_doors.append(direction)
	
	if available_doors.size() > 0:
		var old_entrance = enterance
		enterance = available_doors[randi() % available_doors.size()]
		print("TILE: Entrance randomized from ", get_direction_name(old_entrance), 
			  " to ", get_direction_name(enterance))
	else:
		print("TILE: Cannot randomize entrance - no alternative doors available")

func get_entrance_world_position() -> Vector3:
	"""Get the world position of the entrance door"""
	if entrance_set and has_door(enterance):
		return get_door_world_position(enterance)
	return Vector3.ZERO

func get_entrance_world_orientation() -> Vector3:
	"""Get the world orientation of the entrance door"""
	if entrance_set and has_door(enterance):
		return get_door_world_orientation(enterance)
	return Vector3.ZERO

# Debug function to show entrance info
func debug_entrance_info():
	print("=== Entrance Debug Info ===")
	print("Entrance set: ", entrance_set)
	if entrance_set:
		print("Entrance direction: ", get_direction_name(enterance))
		print("Entrance position: ", get_entrance_world_position())
	else:
		print("Entrance not yet determined")
	print("Player in tile: ", player_in_tile)
	print("=============================")

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
