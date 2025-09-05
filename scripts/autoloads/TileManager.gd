extends Node
## Simple Tile Manager - Implements the exact game loop described
## Spawns tiles with simple positioning and door rotation logic

signal player_entered_tile(tile_position: Vector2i)

# Door constants matching tile.gd
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

# Available tile scenes (excluding start tile)
var available_tile_scenes: Array[String] = []
var start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"

# Active tiles: only the current player tile and its connections
var active_tiles: Dictionary = {}  # Vector2i -> Node3D
var current_player_tile: Vector2i = Vector2i(0, 0)
var active_tile_node: Node3D = null

# Permanent tiles system - tiles that can persist between maze shifts
var permanent_tiles: Dictionary = {}  # Vector2i -> Node3D
var permanent_tile_positions: Array[Vector2i] = []  # List of positions that can be permanent

func _ready():
	_load_available_tiles()
	_spawn_start_tile()

func _load_available_tiles():
	"""Load all available tile scenes except start tile"""
	available_tile_scenes.clear()
	
	var tiles_dir = DirAccess.open("res://scenes/tiles/")
	if tiles_dir:
		tiles_dir.list_dir_begin()
		var file_name = tiles_dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tscn") and file_name != "start_tile.tscn":
				available_tile_scenes.append("res://scenes/tiles/" + file_name)
			file_name = tiles_dir.get_next()
	
	print("TileManager: Loaded ", available_tile_scenes.size(), " tile scenes")

func _spawn_start_tile():
	"""Spawn the start tile and initialize the game"""
	# Check if start tile already exists in scene
	var maze_container = get_tree().current_scene.get_node_or_null("MazeContainer")
	if not maze_container:
		print("ERROR: MazeContainer not found in scene!")
		return
	
	var existing_start_tile = maze_container.get_node_or_null("StartTile")
	var start_tile: Node3D
	
	if existing_start_tile:
		start_tile = existing_start_tile
		start_tile.position = Vector3.ZERO
		print("TileManager: Using existing start tile")
	else:
		start_tile = _create_tile_from_scene(start_tile_scene, Vector2i(0, 0))
		if start_tile:
			start_tile.name = "StartTile"
			start_tile.position = Vector3.ZERO
		print("TileManager: Created new start tile")
	
	if not start_tile:
		print("ERROR: Failed to create start tile!")
		return
	
	# Register start tile
	active_tiles[Vector2i(0, 0)] = start_tile
	current_player_tile = Vector2i(0, 0)
	active_tile_node = start_tile
	
	# Mark start tile as active
	if start_tile.has_method("set_as_active_tile"):
		start_tile.set_as_active_tile()
	
	# Position player at start
	call_deferred("_position_player_at_start", start_tile)
	
	# Wait for tile to initialize, then run door detection and spawn connections
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for tile's _ready()
	
	_run_door_detection_and_spawn(start_tile, Vector2i(0, 0))
	
	print("TileManager: Start tile initialized with connections")

func _run_door_detection_and_spawn(tile: Node3D, tile_pos: Vector2i):
	"""Run door detection and spawn connecting tiles - THE CORE GAME LOOP"""
	print("=== DOOR DETECTION AND SPAWN for tile at ", tile_pos, " ===")
	
	if not tile.has_method("get_available_doors"):
		print("ERROR: Tile doesn't have get_available_doors method")
		return
	
	# Step 1: Door detection runs
	var available_doors = tile.get_available_doors()
	print("Door detection found ", available_doors.size(), " doors:")
	for door_dir in available_doors:
		print("  - Door ", _get_direction_name(door_dir), " at ", available_doors[door_dir]["world_position"])
	
	# Step 2: For each door, spawn a connecting tile
	for door_direction in available_doors:
		var door_data = available_doors[door_direction]
		var connecting_pos = _get_connecting_position(tile_pos, door_direction)
		
		print("Processing door ", _get_direction_name(door_direction), " -> connecting pos ", connecting_pos)
		
		# Skip if tile already exists and is valid at this position
		if active_tiles.has(connecting_pos) and is_instance_valid(active_tiles[connecting_pos]):
			print("  Tile already exists at ", connecting_pos, " - skipping")
			continue
		elif active_tiles.has(connecting_pos):
			# Tile is in dictionary but no longer valid (was queue_free'd) - remove from dict
			active_tiles.erase(connecting_pos)
			print("  Removed invalid tile reference at ", connecting_pos)
		
		# Don't spawn start tile again
		if connecting_pos == Vector2i(0, 0):
			print("  Would spawn at start position - skipping")
			continue
		
		# Step 3: Pre-spawn a random tile
		print("  Pre-spawning random tile...")
		var new_tile = _create_random_tile(connecting_pos)
		if not new_tile:
			print("  ✗ Failed to create tile")
			continue
		
		# Step 4: Position using simple formula: source_center + half_source + half_target
		_position_tile_simple(tile, new_tile, door_direction)
		
		# Step 5: Rotate tile so a random door connects to source door
		_rotate_and_align_tile(tile, new_tile, door_direction)
		
		# Step 6: Re-designate doors after rotation
		# This is handled automatically by physical rotation of markers in Godot
		
		# Step 7: Register on world map
		new_tile.set_meta("world_map_pos", connecting_pos)
		active_tiles[connecting_pos] = new_tile
		
		# Step 8: Mark as connecting tile (enables entrance detection)
		if new_tile.has_method("set_as_connecting_tile"):
			new_tile.set_as_connecting_tile()
			print("  ✓ Tile marked as CONNECTING - entrance detection enabled")
		else:
			print("  ✗ ERROR: Tile has no set_as_connecting_tile method!")
		
		print("  ✓ Successfully spawned and aligned tile at ", connecting_pos)
	
	print("=== Door detection complete ===\n")

func _position_tile_simple(source_tile: Node3D, target_tile: Node3D, source_door_direction):
	"""Position tile using simple formula: source_center + half_source + half_target"""
	var source_center = source_tile.position
	var source_size = source_tile.get_tile_size() if source_tile.has_method("get_tile_size") else Vector2(20, 20)
	var target_size = target_tile.get_tile_size() if target_tile.has_method("get_tile_size") else Vector2(20, 20)
	
	var position = Vector3.ZERO
	
	match source_door_direction:
		DoorDirection.NORTH:  # North = +X axis
			var offset = source_size.x * 0.5 + target_size.x * 0.5  # half + half
			position = Vector3(source_center.x + offset, source_center.y, source_center.z)
		DoorDirection.EAST:   # East = +Z axis
			var offset = source_size.y * 0.5 + target_size.y * 0.5  # half + half
			position = Vector3(source_center.x, source_center.y, source_center.z + offset)
		DoorDirection.SOUTH:  # South = -X axis
			var offset = source_size.x * 0.5 + target_size.x * 0.5  # half + half
			position = Vector3(source_center.x - offset, source_center.y, source_center.z)
		DoorDirection.WEST:   # West = -Z axis
			var offset = source_size.y * 0.5 + target_size.y * 0.5  # half + half
			position = Vector3(source_center.x, source_center.y, source_center.z - offset)
	
	target_tile.position = position
	print("    Positioned tile at: ", position, " (", _get_direction_name(source_door_direction), " door)")

func _rotate_and_align_tile(source_tile: Node3D, target_tile: Node3D, source_door_direction):
	"""Rotate target tile so one of its doors aligns with source door"""
	if not target_tile.has_method("get_available_doors"):
		print("    Target tile has no doors to align")
		return
	
	var target_doors = target_tile.get_available_doors()
	if target_doors.is_empty():
		print("    Target tile has no available doors")
		return
	
	# Pick a random door from target tile to connect
	var target_door_keys = target_doors.keys()
	var chosen_door = target_door_keys[randi() % target_door_keys.size()]
	print("    Chosen door ", _get_direction_name(chosen_door), " to connect to source door ", _get_direction_name(source_door_direction))
	
	# Calculate required rotation to align doors
	var rotation_needed = _calculate_door_alignment_rotation(chosen_door, source_door_direction)
	
	# Apply rotation to tile
	if target_tile.has_method("set_tile_rotation"):
		target_tile.set_tile_rotation(rotation_needed)
		print("    Applied ", rotation_needed * 90, "° rotation to align doors")
	else:
		# Fallback: direct rotation
		target_tile.rotation.y = rotation_needed * PI / 2
		print("    Applied direct rotation: ", rotation_needed * 90, "°")

func _calculate_door_alignment_rotation(target_door: int, source_door: int) -> int:
	"""Calculate rotation steps needed to align doors (0-3 for 0°, 90°, 180°, 270°)"""
	# Convert door enum to direction index (0=North, 1=East, 2=South, 3=West)
	var target_dir = _door_enum_to_index(target_door)
	var source_dir = _door_enum_to_index(source_door)
	
	# For doors to connect, target door should face opposite direction of source
	var required_target_dir = (source_dir + 2) % 4  # Opposite direction
	
	# Calculate rotation needed
	var rotation = (required_target_dir - target_dir) % 4
	
	print("    Target door index: ", target_dir, ", Source door index: ", source_dir)
	print("    Required target direction: ", required_target_dir, ", Rotation needed: ", rotation)
	
	return rotation

func _door_enum_to_index(door_enum: int) -> int:
	"""Convert door enum to directional index (0=North, 1=East, 2=South, 3=West)"""
	match door_enum:
		DoorDirection.NORTH: return 0
		DoorDirection.EAST: return 1  
		DoorDirection.SOUTH: return 2
		DoorDirection.WEST: return 3
		_: return 0

func on_player_entered_tile(tile_position: Vector2i):
	"""Handle player entering a new tile - THIS IS THE KEY TRANSITION LOGIC"""
	print("TILMGR: *** PLAYER ENTERED TILE: ", tile_position, " (was at ", current_player_tile, ") ***")
	
	var old_tile_pos = current_player_tile
	current_player_tile = tile_position
	
	# Ensure the new tile exists
	if not active_tiles.has(tile_position):
		print("ERROR: Player entered non-existent tile at ", tile_position)
		return
	
	# Set new active tile
	active_tile_node = active_tiles[tile_position]
	
	# Mark new tile as active
	if active_tile_node.has_method("set_as_active_tile"):
		active_tile_node.set_as_active_tile()
	
	# Check if this tile should become permanent (first 5 visited tiles)
	_check_for_permanent_tile_registration(tile_position)
	
	# IMPORTANT: Clean up previous tile connections (except the one player came from)
	if old_tile_pos != tile_position:
		_cleanup_previous_tile_connections(old_tile_pos, tile_position)
	
	# Wait for tile to be ready, then spawn new connections
	await get_tree().process_frame
	print("TILMGR: About to run door detection and spawn for tile at ", tile_position)
	_run_door_detection_and_spawn(active_tile_node, tile_position)
	print("TILMGR: Door detection and spawn completed for tile at ", tile_position)
	
	emit_signal("player_entered_tile", tile_position)

func _cleanup_previous_tile_connections(old_pos: Vector2i, current_pos: Vector2i):
	"""Clean up tiles connected to the previous tile (except current tile)"""
	print("=== CLEANUP: Previous tile ", old_pos, " -> Current tile ", current_pos, " ===")
	print("  Active tiles before cleanup: ", active_tiles.keys())
	
	if not active_tiles.has(old_pos):
		print("  ERROR: Previous tile not found in active_tiles")
		return
	
	var old_tile = active_tiles[old_pos]
	if not old_tile or not old_tile.has_method("get_available_doors"):
		print("  ERROR: Previous tile has no get_available_doors method")
		return
	
	var old_doors = old_tile.get_available_doors()
	print("  Previous tile has ", old_doors.size(), " doors")
	
	var destroyed_count = 0
	for door_direction in old_doors:
		var connecting_pos = _get_connecting_position(old_pos, door_direction)
		print("  Checking connection at ", connecting_pos, " (", _get_direction_name(door_direction), " door)")
		
		# Don't destroy the tile the player is currently on
		if connecting_pos == current_pos:
			print("    SKIP: This is current player tile")
			continue
		
		# Don't destroy permanent tiles
		if permanent_tiles.has(connecting_pos):
			print("    SKIP: This is a permanent tile")
			continue
		
		# Don't destroy the start tile
		if connecting_pos == Vector2i(0, 0):
			print("    SKIP: This is the start tile")
			continue
		
		# Destroy the connecting tile
		if active_tiles.has(connecting_pos):
			var tile_to_destroy = active_tiles[connecting_pos]
			active_tiles.erase(connecting_pos)
			tile_to_destroy.queue_free()
			destroyed_count += 1
			print("    DESTROYED: Tile at ", connecting_pos)
		else:
			print("    NOT FOUND: No tile at ", connecting_pos, " to destroy")
	
	print("  Active tiles after cleanup: ", active_tiles.keys())
	print("=== CLEANUP COMPLETE: Destroyed ", destroyed_count, " tiles ===\n")

func _get_connecting_position(tile_pos: Vector2i, door_direction) -> Vector2i:
	"""Get grid position where connecting tile should be placed"""
	match door_direction:
		DoorDirection.NORTH: return tile_pos + Vector2i(1, 0)   # North = +X in grid
		DoorDirection.EAST: return tile_pos + Vector2i(0, 1)    # East = +Y in grid
		DoorDirection.SOUTH: return tile_pos + Vector2i(-1, 0)  # South = -X in grid
		DoorDirection.WEST: return tile_pos + Vector2i(0, -1)   # West = -Y in grid
		_: return tile_pos

func _create_random_tile(grid_pos: Vector2i) -> Node3D:
	"""Create a random tile at the given grid position"""
	if available_tile_scenes.is_empty():
		print("ERROR: No available tile scenes!")
		return null
	
	var random_scene = available_tile_scenes[randi() % available_tile_scenes.size()]
	print("  Creating: ", random_scene.get_file())
	return _create_tile_from_scene(random_scene, grid_pos)

func _create_tile_from_scene(scene_path: String, grid_pos: Vector2i) -> Node3D:
	"""Create tile instance from scene file"""
	var tile_scene: PackedScene = load(scene_path)
	if not tile_scene:
		print("ERROR: Failed to load scene: ", scene_path)
		return null
	
	var tile_instance: Node3D = tile_scene.instantiate()
	if not tile_instance:
		print("ERROR: Failed to instantiate scene: ", scene_path)
		return null
	
	# Store metadata
	tile_instance.set_meta("grid_position", grid_pos)
	tile_instance.set_meta("scene_path", scene_path)
	
	# Add to maze container
	var maze_container = get_tree().current_scene.get_node("MazeContainer")
	if maze_container:
		maze_container.add_child(tile_instance)
	else:
		print("ERROR: MazeContainer not found!")
		tile_instance.queue_free()
		return null
	
	return tile_instance

func _position_player_at_start(start_tile: Node3D):
	"""Position player at start marker"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("WARNING: Player not found!")
		return
	
	var start_marker = start_tile.get_node_or_null("PlayerStart")
	if start_marker:
		player.global_position = start_marker.global_position
		print("Player positioned at start marker: ", start_marker.global_position)
	else:
		print("WARNING: PlayerStart marker not found!")

func _check_for_permanent_tile_registration(tile_pos: Vector2i):
	"""Check if this tile should be registered as permanent (first 5 unique tiles visited)"""
	if permanent_tile_positions.size() < 5 and not permanent_tiles.has(tile_pos):
		add_permanent_tile(tile_pos)

# Permanent tile system
func add_permanent_tile(pos: Vector2i):
	"""Add a tile to the permanent tile system"""
	if active_tiles.has(pos):
		permanent_tiles[pos] = active_tiles[pos]
		permanent_tile_positions.append(pos)
		active_tiles[pos].set_meta("is_permanent", true)
		print("Added PERMANENT tile at ", pos, " (", permanent_tile_positions.size(), "/5)")

func shift_permanent_tiles():
	"""Shift permanent tiles (50% chance to move 1 position)"""
	for pos in permanent_tile_positions:
		if randf() < 0.5:  # 50% chance to move
			var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var new_pos = pos + directions[randi() % directions.size()]
			
			# Handle wrapping (if at edge, wrap to other side)
			new_pos = _wrap_position(new_pos)
			
			if permanent_tiles.has(pos):
				var tile = permanent_tiles[pos]
				permanent_tiles.erase(pos)
				permanent_tiles[new_pos] = tile
				# Update tile position
				tile.position = Vector3(new_pos.x * 20.0, 0.0, new_pos.y * 20.0)
				print("Shifted permanent tile from ", pos, " to ", new_pos)

func _wrap_position(pos: Vector2i) -> Vector2i:
	"""Handle world map wrapping (edges wrap to opposite side)"""
	var world_size = 20  # Configurable world map size
	var wrapped_x = pos.x
	var wrapped_y = pos.y
	
	if pos.x > world_size / 2:
		wrapped_x = -(world_size / 2) + (pos.x - world_size / 2)
	elif pos.x < -(world_size / 2):
		wrapped_x = (world_size / 2) + (pos.x + world_size / 2)
		
	if pos.y > world_size / 2:
		wrapped_y = -(world_size / 2) + (pos.y - world_size / 2)
	elif pos.y < -(world_size / 2):
		wrapped_y = (world_size / 2) + (pos.y + world_size / 2)
	
	return Vector2i(wrapped_x, wrapped_y)

# Utility functions
func _get_direction_name(direction: int) -> String:
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East"
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

# Public API
func get_current_player_tile() -> Vector2i:
	return current_player_tile

func get_active_tile_count() -> int:
	return active_tiles.size()

func get_active_tile_node() -> Node3D:
	return active_tile_node
