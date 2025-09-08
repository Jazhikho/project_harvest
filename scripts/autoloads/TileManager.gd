extends Node
## Tile Manager - Now integrated with EventManager for item spawning

signal player_entered_tile(tile_position: Vector2i)

# Door constants matching tile.gd
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

# Available tile scenes
var available_tile_scenes: Array[String] = []
var start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"
var final_tile_scene: String = "res://scenes/tiles/final_event_tile.tscn"  # Special final tile

# Active tiles: only the current player tile and its connections
var active_tiles: Dictionary = {}  # Vector2i -> Node3D
var current_player_tile: Vector2i = Vector2i(0, 0)
var active_tile_node: Node3D = null
var past_tile_position: Vector2i = Vector2i(-1000, -1000)  # Invalid position initially
var past_tile_node: Node3D = null

# Permanent tiles system - tiles that can persist between maze shifts
var permanent_tiles: Dictionary = {}  # Vector2i -> Node3D
var permanent_tile_positions: Array[Vector2i] = []  # List of positions that can be permanent
var permanent_puzzle_tiles: Dictionary = {}  # tile_position -> puzzle_id

# Reference to EventManager
var event_manager: Node

func _ready():
	_load_available_tiles()
	
	# Get EventManager reference
	event_manager = get_node_or_null("/root/EventManager")
	if not event_manager:
		push_error("TileManager: EventManager not found!")
	
	_spawn_start_tile()

func _load_available_tiles():
	"""Load all available tile scenes except start and final tiles"""
	available_tile_scenes.clear()
	
	var tiles_dir = DirAccess.open("res://scenes/tiles/")
	if tiles_dir:
		tiles_dir.list_dir_begin()
		var file_name = tiles_dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tscn") and file_name != "start_tile.tscn" and file_name != "final_event_tile.tscn":
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
	
	# Reset past tile tracking
	past_tile_position = Vector2i(-1000, -1000)
	past_tile_node = null
	
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
		
		# Check if there's a permanent tile at this position
		if _has_permanent_tile_at_position(connecting_pos):
			print("  Permanent tile exists at ", connecting_pos, " - skipping spawn")
			continue
		
		# Step 3: Decide which tile to spawn (check for final event)
		var new_tile: Node3D
		if event_manager and event_manager.is_final_event_available() and randf() < event_manager.get_final_tile_spawn_weight():
			print("  Pre-spawning FINAL EVENT tile...")
			new_tile = _create_tile_from_scene(final_tile_scene, connecting_pos)
		else:
			print("  Pre-spawning random tile...")
			new_tile = _create_random_tile(connecting_pos)
		
		if not new_tile:
			print("  ✗ Failed to create tile")
			continue
		
		# Step 4: Rotate tile FIRST so a random door faces the right direction
		_rotate_and_align_tile(tile, new_tile, door_direction)
		
		# Step 5: Position using simple formula (now the rotated door will align)
		_position_tile_simple(tile, new_tile, door_direction)
		
		# Step 6: Register on world map
		new_tile.set_meta("world_map_pos", connecting_pos)
		active_tiles[connecting_pos] = new_tile
		
		# Step 7: Check if this tile is permanent and handle accordingly
		if new_tile.has_method("is_tile_permanent") and new_tile.is_tile_permanent():
			_register_permanent_tile(new_tile, connecting_pos)
		else:
			# Step 8: Process item spawning for non-permanent tiles
			_process_tile_item_spawning(new_tile, connecting_pos)
		
		# Step 9: Mark as connecting tile (enables entrance detection)
		if new_tile.has_method("set_as_connecting_tile"):
			new_tile.set_as_connecting_tile()
			print("  ✓ Tile marked as CONNECTING - entrance detection enabled")
		else:
			print("  ✗ ERROR: Tile has no set_as_connecting_tile method!")
		
		print("  ✓ Successfully spawned and aligned tile at ", connecting_pos)
	
	print("=== Door detection complete ===\n")

func _process_tile_item_spawning(tile: Node3D, tile_position: Vector2i):
	"""Process item spawning for a newly created tile"""
	print("Processing item spawning for tile at ", tile_position)
	
	if not event_manager:
		print("  ERROR: EventManager not available for item spawning")
		return
	
	# Get spawn points from the tile
	var spawn_points = _get_tile_spawn_points(tile)
	if spawn_points.is_empty():
		print("  No spawn points found on tile")
		return
	
	print("  Found ", spawn_points.size(), " spawn points")
	
	# Check if tile is permanent
	var is_permanent = tile.has_method("is_tile_permanent") and tile.is_tile_permanent()
	
	# Query EventManager for what should spawn
	var spawn_data = event_manager.on_tile_spawning(tile_position, spawn_points, is_permanent)
	
	# Process backpack spawn
	if spawn_data.get("spawn_backpack", false):
		_spawn_backpack(tile, spawn_data.get("backpack_pos", Vector3.ZERO), spawn_data.get("backpack_inventory", []))
		
		# Process effigy spawn
		if spawn_data.get("spawn_effigy", false):
			_spawn_effigy(tile, spawn_data.get("effigy_pos", Vector3.ZERO))
	
	# Process item spawns
	var items = spawn_data.get("items", [])
	for item_data in items:
		_spawn_item(tile, item_data.get("id", ""), item_data.get("position", Vector3.ZERO))

func _get_tile_spawn_points(tile: Node3D) -> Array:
	"""Get all spawn points from a tile (Maze/SpawnPoints markers)"""
	var spawn_points = []
	
	var spawn_parent = tile.get_node_or_null("Maze/SpawnPoints")
	if not spawn_parent:
		print("  No Maze/SpawnPoints node found")
		return spawn_points
	
	# Get all Marker3D children
	for child in spawn_parent.get_children():
		if child is Marker3D:
			spawn_points.append(child.global_position)
	
	return spawn_points

func _spawn_backpack(tile: Node3D, position: Vector3, inventory: Array):
	"""Spawn a backpack containing previous run's inventory"""
	print("  Spawning backpack at ", position, " with ", inventory.size(), " items")
	
	# TODO: Load actual backpack scene when created
	# For now, create a placeholder
	var backpack = MeshInstance3D.new()
	backpack.name = "Backpack"
	
	# Create a simple box mesh as placeholder
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.5)
	backpack.mesh = box_mesh
	
	# Add material to make it visible
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.3, 0.1)  # Brown color
	backpack.set_surface_override_material(0, material)
	
	# Position it
	tile.add_child(backpack)
	backpack.global_position = position
	backpack.position.y = 0.25  # Slightly above ground
	
	# Store inventory data
	backpack.set_meta("inventory", inventory)
	backpack.set_meta("is_backpack", true)
	
	# Add collision for pickup
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = shape
	
	backpack.add_child(static_body)
	static_body.add_child(collision)
	
	print("  ✓ Backpack spawned with inventory: ", inventory)

func _spawn_effigy(tile: Node3D, position: Vector3):
	"""Spawn an enemy effigy"""
	print("  Spawning effigy at ", position)
	
	# TODO: Load actual effigy/enemy scene when created
	# For now, create a placeholder
	var effigy = MeshInstance3D.new()
	effigy.name = "Effigy"
	
	# Create a simple capsule mesh as placeholder
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.height = 2.0
	capsule_mesh.radius = 0.3
	effigy.mesh = capsule_mesh
	
	# Add material to make it look spooky
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)  # Dark gray
	effigy.set_surface_override_material(0, material)
	
	# Position it
	tile.add_child(effigy)
	effigy.global_position = position
	effigy.position.y = 1.0  # Standing height
	
	# Make it face the backpack (simple look-at)
	var backpack = tile.get_node_or_null("Backpack")
	if backpack:
		effigy.look_at(backpack.global_position, Vector3.UP)
	
	effigy.set_meta("is_effigy", true)
	
	print("  ✓ Effigy spawned")
	
	# TODO: When enemy system is implemented, this should spawn an actual enemy

func _spawn_item(tile: Node3D, item_id: String, position: Vector3):
	"""Spawn a collectible item"""
	print("  Spawning item '", item_id, "' at ", position)
	
	# TODO: Load actual item scenes based on item_id
	# For now, create a placeholder
	var item = MeshInstance3D.new()
	item.name = "Item_" + item_id
	
	# Create a simple sphere mesh as placeholder
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	item.mesh = sphere_mesh
	
	# Add material based on item type
	var material = StandardMaterial3D.new()
	if "note" in item_id:
		material.albedo_color = Color(1.0, 1.0, 0.8)  # Yellowish for notes
	elif "puzzle" in item_id:
		material.albedo_color = Color(0.5, 0.8, 1.0)  # Blue for puzzle pieces
	else:
		material.albedo_color = Color(0.8, 0.5, 0.8)  # Purple for weird objects
	
	item.set_surface_override_material(0, material)
	
	# Position it
	tile.add_child(item)
	item.global_position = position
	item.position.y = 0.5  # Float above ground
	
	# Store item data
	item.set_meta("item_id", item_id)
	item.set_meta("is_collectible", true)
	item.set_meta("tile_position", tile.get_meta("world_map_pos", Vector2i()))
	
	# Add collision for pickup
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	
	item.add_child(area)
	area.add_child(collision)
	
	# Set collision layers
	area.collision_layer = 0
	area.collision_mask = 1  # Detect player
	
	# Connect pickup signal
	area.body_entered.connect(_on_item_pickup.bind(item))
	
	print("  ✓ Item spawned: ", item_id)

func _on_item_pickup(body: Node3D, item: Node3D):
	"""Handle item pickup"""
	if not body.is_in_group("player"):
		return
	
	var item_id = item.get_meta("item_id", "")
	var tile_pos = item.get_meta("tile_position", Vector2i())
	
	print("Player picked up item: ", item_id)
	
	# Notify EventManager
	if event_manager:
		event_manager.on_item_collected(item_id, tile_pos)
	
	# Remove the item
	item.queue_free()

func _register_permanent_tile(tile: Node3D, position: Vector2i):
	"""Register a permanent tile and its puzzle if it has one"""
	permanent_tiles[position] = tile
	permanent_tile_positions.append(position)
	
	print("Registered PERMANENT tile at ", position)
	
	# Check if tile has a puzzle
	if tile.has_method("get_puzzle_id"):
		var puzzle_id = tile.get_puzzle_id()
		if puzzle_id != "":
			permanent_puzzle_tiles[position] = puzzle_id
			
			# Register with EventManager
			if event_manager:
				event_manager.register_permanent_tile_puzzle(position, puzzle_id)
			
			print("  Tile has puzzle: ", puzzle_id)

func remove_permanent_tile(position: Vector2i):
	"""Remove a tile from permanent status (called when puzzle is completed)"""
	if permanent_tiles.has(position):
		permanent_tiles.erase(position)
		permanent_tile_positions.erase(position)
		permanent_puzzle_tiles.erase(position)
		print("Removed permanent tile at ", position, " - puzzle completed!")

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
	
	# Ensure the tile has detected its doors first
	if not target_tile.has_method("detect_doors"):
		print("    ERROR: Target tile has no detect_doors method")
		return
		
	# Force door detection if not already done
	target_tile.detect_doors()
	
	# Get the original doors before rotation
	var original_doors = []
	for original_dir in target_tile.door_markers.keys():
		original_doors.append(original_dir)
	
	if original_doors.is_empty():
		print("    Target tile has no available doors")
		return
	
	# Pick a random door from the original doors
	var chosen_original_door = original_doors[randi() % original_doors.size()]
	print("    Chose original door ", _get_direction_name(chosen_original_door), " to connect")
	
	# Calculate rotation needed to make this door face the opposite of source_door_direction
	var required_global_direction = _get_opposite_direction(source_door_direction)
	var rotation_needed = _calculate_rotation_to_global_direction(chosen_original_door, required_global_direction)
	
	# Apply rotation - this will automatically update the global door assignments
	if target_tile.has_method("set_tile_rotation"):
		target_tile.set_tile_rotation(rotation_needed)
		print("    Applied ", rotation_needed * 90, "° rotation (counter-clockwise)")
	else:
		# Fallback direct rotation
		target_tile.rotation.y = rotation_needed * PI / 2
		if target_tile.has_method("_update_global_door_assignments"):
			target_tile._update_global_door_assignments(rotation_needed)
		print("    Applied direct rotation: ", rotation_needed * 90, "° (counter-clockwise)")

func _get_opposite_direction(direction: int) -> int:
	"""Get the opposite direction"""
	match direction:
		DoorDirection.NORTH: return DoorDirection.SOUTH
		DoorDirection.EAST: return DoorDirection.WEST
		DoorDirection.SOUTH: return DoorDirection.NORTH
		DoorDirection.WEST: return DoorDirection.EAST
		_: return DoorDirection.NORTH

func _calculate_rotation_to_global_direction(original_door: int, target_global_direction: int) -> int:
	"""Calculate rotation steps to make original_door point toward target_global_direction"""
	var original_index = _door_enum_to_index(original_door)
	var target_index = _door_enum_to_index(target_global_direction)
	
	# For counter-clockwise rotation (positive Y rotation in Godot)
	# We need to rotate FROM original TO target
	var rotation = (original_index - target_index + 4) % 4
	
	print("    Original door ", _get_direction_name(original_door), " (index ", original_index, ")")
	print("    Target direction ", _get_direction_name(target_global_direction), " (index ", target_index, ")")
	print("    Rotation steps needed: ", rotation, " (", rotation * 90, "° counter-clockwise)")
	
	return rotation

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
	
	# Notify EventManager of tile entry
	if event_manager:
		var tile_id = active_tiles[tile_position].get_meta("scene_path", "").get_file().get_basename()
		event_manager.on_tile_enter(tile_id, tile_position)
	
	# FIRST: Clean up any stray past tiles to ensure only one past tile exists
	_cleanup_all_past_tiles_except_current()
	
	# Handle past tile logic - clear any existing past tile first
	if past_tile_node and is_instance_valid(past_tile_node):
		# Clean up connections to the OLD past tile before replacing it
		print("TILMGR: Cleaning up connections to old past tile at ", past_tile_position)
		_cleanup_tile_connections(past_tile_position, tile_position, old_tile_pos)
		
		# Notify EventManager of tile cleanup for item removal
		if event_manager:
			event_manager.on_tile_cleanup(past_tile_position)
		
		# Clear the past tile state (it becomes a regular connecting tile or gets cleaned up)
		if past_tile_node.has_method("set_as_connecting_tile"):
			past_tile_node.set_as_connecting_tile()
		print("TILMGR: Cleared previous past tile at ", past_tile_position)
	
	# Set the previous active tile as the new past tile (if it exists and isn't permanent)
	if active_tiles.has(old_tile_pos) and is_instance_valid(active_tiles[old_tile_pos]):
		var old_tile_node = active_tiles[old_tile_pos]
		if old_tile_node.has_method("is_tile_permanent") and not old_tile_node.is_tile_permanent():
			past_tile_position = old_tile_pos
			past_tile_node = old_tile_node
			if old_tile_node.has_method("set_as_past_tile"):
				old_tile_node.set_as_past_tile()
			print("TILMGR: Set past tile at ", old_tile_pos)
		else:
			print("TILMGR: Old tile is permanent, not setting as past tile")
	
	# Set new active tile
	active_tile_node = active_tiles[tile_position]
	
	# Mark new tile as active
	if active_tile_node.has_method("set_as_active_tile"):
		active_tile_node.set_as_active_tile()
	
	# Check if this tile should become permanent (first 5 visited tiles)
	_check_for_permanent_tile_registration(tile_position)
	
	# IMPORTANT: Clean up previous tile connections (except the one player came from and past tile)
	if old_tile_pos != tile_position:
		_cleanup_tile_connections(old_tile_pos, tile_position, past_tile_position)
	
	# Wait for tile to be ready, then spawn new connections
	await get_tree().process_frame
	print("TILMGR: About to run door detection and spawn for tile at ", tile_position)
	_run_door_detection_and_spawn(active_tile_node, tile_position)
	print("TILMGR: Door detection and spawn completed for tile at ", tile_position)
	
	emit_signal("player_entered_tile", tile_position)

func _cleanup_all_past_tiles_except_current():
	"""Clean up any stray past tiles that might exist from previous moves - ensure only one past tile exists"""
	print("TILMGR: Cleaning up all stray past tiles...")
	var past_tiles_found = 0
	var tiles_to_remove = []
	
	for pos in active_tiles.keys():
		var tile = active_tiles[pos]
		if is_instance_valid(tile) and tile.is_past_tile:
			# This is a past tile - if it's not the current tracked past tile, mark for removal
			if pos != past_tile_position or tile != past_tile_node:
				print("TILMGR: Found stray past tile at ", pos, " - marking for cleanup")
				tiles_to_remove.append(pos)
			past_tiles_found += 1
	
	# Remove stray past tiles
	for pos in tiles_to_remove:
		if active_tiles.has(pos):
			var tile = active_tiles[pos]
			active_tiles.erase(pos)
			tile.queue_free()
			print("TILMGR: Removed stray past tile at ", pos)
	
	print("TILMGR: Found ", past_tiles_found, " past tiles, removed ", tiles_to_remove.size(), " strays")

func _cleanup_tile_connections(cleanup_pos: Vector2i, current_player_pos: Vector2i, exclude_past_pos: Vector2i = Vector2i(-1000, -1000)):
	"""Clean up tiles connected to a specific tile (except protected tiles)"""
	print("=== CLEANUP: Cleaning connections from tile ", cleanup_pos, " ===")
	print("  Current player at: ", current_player_pos)
	print("  Exclude past tile at: ", exclude_past_pos)
	print("  Active tiles before cleanup: ", active_tiles.keys())
	
	if not active_tiles.has(cleanup_pos):
		print("  ERROR: Cleanup tile not found in active_tiles")
		return
	
	var cleanup_tile = active_tiles[cleanup_pos]
	if not cleanup_tile or not cleanup_tile.has_method("get_available_doors"):
		print("  ERROR: Cleanup tile has no get_available_doors method")
		return
	
	var cleanup_doors = cleanup_tile.get_available_doors()
	print("  Cleanup tile has ", cleanup_doors.size(), " doors")
	
	var destroyed_count = 0
	for door_direction in cleanup_doors:
		var connecting_pos = _get_connecting_position(cleanup_pos, door_direction)
		print("  Checking connection at ", connecting_pos, " (", _get_direction_name(door_direction), " door)")
		
		# Don't destroy the tile the player is currently on
		if connecting_pos == current_player_pos:
			print("    SKIP: This is current player tile")
			continue
		
		# Don't destroy the past tile (if specified)
		if connecting_pos == exclude_past_pos:
			print("    SKIP: This is the excluded past tile")
			continue
		
		# Don't destroy permanent tiles (including those with is_permanent attribute)
		if _has_permanent_tile_at_position(connecting_pos):
			print("    SKIP: This is a permanent tile")
			continue
		
		# Destroy connecting tile (including any other past tiles - only 1 past allowed)
		if active_tiles.has(connecting_pos):
			var tile_to_destroy = active_tiles[connecting_pos]
			
			# Notify EventManager of cleanup for item removal
			if event_manager:
				event_manager.on_tile_cleanup(connecting_pos)
			
			# Special handling for past tiles - there can only be one
			if tile_to_destroy.is_past_tile:
				print("    DESTROYING OLD PAST TILE: Only one past tile allowed")
			
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
	"""Check if this tile should be registered as permanent (based on tile's permanent property)"""
	if not permanent_tiles.has(tile_pos) and active_tiles.has(tile_pos):
		var tile = active_tiles[tile_pos]
		if tile.has_method("is_tile_permanent") and tile.is_tile_permanent():
			add_permanent_tile(tile_pos)

# Permanent tile system
func add_permanent_tile(pos: Vector2i):
	"""Add a tile to the permanent tile system"""
	if active_tiles.has(pos):
		permanent_tiles[pos] = active_tiles[pos]
		permanent_tile_positions.append(pos)
		active_tiles[pos].set_meta("is_permanent", true)
		print("Added PERMANENT tile at ", pos, " (total permanent tiles: ", permanent_tile_positions.size(), ")")

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

func _has_permanent_tile_at_position(pos: Vector2i) -> bool:
	"""Check if there's a permanent tile at the given position"""
	# Check the old permanent tiles system
	if permanent_tiles.has(pos):
		return true
	
	# Check for tiles with is_permanent attribute
	if active_tiles.has(pos) and is_instance_valid(active_tiles[pos]):
		var tile = active_tiles[pos]
		if tile.has_method("is_tile_permanent"):
			return tile.is_tile_permanent()
	
	return false

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

# EventManager integration
func _on_event_maze_shift():
	"""Handle maze shift requests from EventManager"""
	print("TileManager: Maze shift requested via EventManager")
	shift_maze_section()

func shift_maze_section():
	"""Trigger a maze section shift"""
	# For now, just shift permanent tiles
	# TODO: Implement more complex maze shifting
	shift_permanent_tiles()
	print("TileManager: Maze section shifted")
