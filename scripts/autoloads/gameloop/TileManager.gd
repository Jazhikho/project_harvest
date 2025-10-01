extends Node
## TileManager - Handles tile generation, connections, and cleanup
## State management delegated to TileStateManager
@export var tile_database: TileDatabase = preload("res://data/TileDatabase.tres")

var _message_bus: Node
var _state_manager: Node
var _spawn_manager: Node
var _tile_state_manager: Node

# Tile tracking
var _active_tiles: Dictionary = {} # Vector2i -> Node3D
var _permanent_tiles: Dictionary = {} # Vector2i -> Node3D
var _puzzle_tiles: Dictionary = {} # Vector2i -> puzzle_id

# Connection tracking - prevents respawning
var _established_connections: Dictionary = {} # "pos1_pos2" -> true

# Tile scenes
var _normal_tiles: Array[PackedScene] = [] # Changed from Array[String]
var _permanent_tiles_scenes: Array[PackedScene] = [] # Changed from Array[String]
var _start_tile_scene: PackedScene = preload("res://scenes/tiles/start_tile.tscn")


# Initialization flag
var _start_tile_initialized: bool = false
var _permanent_tile_assignments: Dictionary = {}

# Forbidden zone for permanent tiles (1,1) to (-1,-1)
const FORBIDDEN_MIN: Vector2i = Vector2i(-1, -1)
const FORBIDDEN_MAX: Vector2i = Vector2i(1, 1)

# Door constants
enum DoorDirection {NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8}

const TILE_SIZE: float = 20.0

func _ready() -> void:
	name = "TileManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections and load tile scenes"""
	
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_spawn_manager = get_node_or_null("/root/SpawnManager")
	_tile_state_manager = get_node_or_null("/root/TileStateManager")
	
	if not _message_bus or not _state_manager or not _spawn_manager or not _tile_state_manager:
		push_error("TileManager: Required core systems not found")
		return
	
	_load_available_tiles()
	
	_connect_to_events()
	
	# DON'T spawn start tile here - wait for game scene

func _load_available_tiles() -> void:
	"""Load and categorize tile scenes from database"""
	_normal_tiles.clear()
	_permanent_tiles_scenes.clear()
	
	if not tile_database:
		push_error("TileManager: No tile database assigned!")
		return
	
	# Process normal tiles
	for tile_scene in tile_database.normal_tile_scenes:
		if tile_scene:
			_normal_tiles.append(tile_scene)
	
	# Process permanent tiles - check which puzzles are completed
	for tile_scene in tile_database.permanent_tile_scenes:
		if not tile_scene:
			continue
			
		# Check if this permanent tile's puzzle is already completed
		var temp_instance: Node3D = tile_scene.instantiate() as Node3D
		if temp_instance:
			var is_completed = false
			
			if temp_instance.has_method("get_puzzle_id"):
				var puzzle_id = temp_instance.get_puzzle_id()
				if not puzzle_id.is_empty() and SaveManager.has_method("is_puzzle_completed"):
					is_completed = SaveManager.is_puzzle_completed(puzzle_id)
					print("TileManager: Checking puzzle '%s' - completed: %s" % [puzzle_id, is_completed])
				else:
					print("TileManager: Warning - puzzle ID empty or SaveManager method missing for tile: %s" % tile_scene.resource_path)
			
			temp_instance.queue_free()
			
			if not is_completed:
				_permanent_tiles_scenes.append(tile_scene)
	
	print("TileManager: Loaded ", _normal_tiles.size(), " normal tiles and ",
		  _permanent_tiles_scenes.size(), " permanent tiles")
	
	# Pre-assign permanent tiles to positions
	_assign_permanent_tile_positions()
	
func _assign_permanent_tile_positions() -> void:
	"""Pre-assign permanent tiles to specific grid positions"""
	_permanent_tile_assignments.clear()
	
	if _permanent_tiles_scenes.is_empty():
		return
	
	# Filter out permanent tiles whose puzzles are completed
	var available_permanent_tiles: Array[PackedScene] = []
	for tile_scene in _permanent_tiles_scenes:
		if tile_scene:
			available_permanent_tiles.append(tile_scene)
	
	if available_permanent_tiles.is_empty():
		print("TileManager: No permanent tiles to assign")
		return
	
	# Generate valid spawn positions (outside forbidden zone)
	var valid_positions: Array[Vector2i] = []
	
	for x in range(-3, 4):
		for y in range(-3, 4):
			var pos: Vector2i = Vector2i(x, y)
			if _can_permanent_tile_spawn_at(pos):
				valid_positions.append(pos)
	
	# Shuffle positions for randomness
	valid_positions.shuffle()
	
	# Assign each permanent tile to a position (storing PackedScene)
	var assignment_count: int = min(available_permanent_tiles.size(), valid_positions.size())
	for i in range(assignment_count):
		var pos: Vector2i = valid_positions[i]
		var tile_scene: PackedScene = available_permanent_tiles[i]
		_permanent_tile_assignments[pos] = tile_scene
		print("TileManager: Assigned permanent tile to position ", pos)

func initialize_game_tiles() -> void:
	"""Called when the game scene is actually loaded"""
	if _start_tile_initialized:
		return
	
	_spawn_start_tile()
	_start_tile_initialized = true

func _spawn_start_tile() -> void:
	"""Register the existing start tile from the game scene"""
	
	# The StartTile should be in the current scene
	var start_tile: Node3D = null
	
	# Check various possible locations
	var possible_paths = [
		"StartTile",
		"MazeContainer/StartTile",
		"Maze/StartTile",
		"./StartTile"
	]
	
	for path in possible_paths:
		start_tile = get_tree().current_scene.get_node_or_null(path) as Node3D
		if start_tile:
			break
	
	if not start_tile:
		push_error("TileManager: StartTile not found in scene! Check scene structure.")
		return
	
	# Configure the start tile
	start_tile.position = Vector3.ZERO
	
	# Make sure it's not permanent
	if start_tile.has_method("set") and start_tile.get("is_permanent") != null:
		start_tile.set("is_permanent", false)
	
	# Set required metadata
	start_tile.set_meta("grid_position", Vector2i(0, 0))
	start_tile.set_meta("scene_path", "res://scenes/tiles/start_tile.tscn")
	start_tile.set_meta("world_map_pos", Vector2i(0, 0))
	
	
	# CRITICAL: Register with TileManager
	_register_tile(start_tile, Vector2i(0, 0))
	
	# Register with TileStateManager
	if _tile_state_manager:
		_tile_state_manager.register_tile(start_tile, Vector2i(0, 0), _tile_state_manager.TileState.ACTIVE)
		_tile_state_manager.set_initial_player_position(Vector2i(0, 0))
	
	# Position player
	call_deferred("_position_player_at_start", start_tile)
	
	# Wait for everything to settle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Spawn connections
	_spawn_tile_connections(start_tile, Vector2i(0, 0))
	_message_bus.emit_event("tile_generated", [start_tile, Vector2i(0, 0), {}])
	

func _create_tile_from_scene(scene: Variant, grid_pos: Vector2i) -> Node3D:
	"""
	Create tile instance from scene file or PackedScene
	
	@param scene: PackedScene or path to tile scene file
	@param grid_pos: Grid position for the tile
	@return: Created tile node or null if failed
	"""
	var tile_scene: PackedScene
	
	# Handle both PackedScene and String path
	if scene is PackedScene:
		tile_scene = scene
	elif scene is String:
		tile_scene = load(scene) as PackedScene
		if not tile_scene:
			push_error("TileManager: Failed to load scene: " + scene)
			return null
	else:
		push_error("TileManager: Invalid scene type")
		return null
	
	var tile_instance: Node3D = tile_scene.instantiate() as Node3D
	if not tile_instance:
		push_error("TileManager: Failed to instantiate scene")
		return null
	
	tile_instance.set_meta("grid_position", grid_pos)
	tile_instance.set_meta("scene_resource", tile_scene) # Store the PackedScene reference
	tile_instance.set_meta("world_map_pos", grid_pos)
	
	# For start tile, explicitly ensure it's not permanent
	if tile_scene == _start_tile_scene:
		if tile_instance.has_method("set") and tile_instance.get("is_permanent") != null:
			tile_instance.set("is_permanent", false)
	
	var maze_container: Node = get_tree().current_scene.get_node("MazeContainer")
	if maze_container:
		maze_container.add_child(tile_instance)
	else:
		push_error("TileManager: MazeContainer not found")
		tile_instance.queue_free()
		return null
	
	return tile_instance

func _register_tile(tile: Node3D, position: Vector2i) -> void:
	"""
	Register a tile in the active tiles system
	
	@param tile: Tile node to register
	@param position: Grid position of the tile
	"""
	_active_tiles[position] = tile
	
	# Only register as permanent if the tile is actually marked as permanent
	if tile.has_method("is_tile_permanent") and tile.is_tile_permanent():
		_permanent_tiles[position] = tile
		
		if tile.has_method("get_puzzle_id"):
			var puzzle_id: String = tile.get_puzzle_id()
			if not puzzle_id.is_empty():
				_puzzle_tiles[position] = puzzle_id

func _spawn_tile_connections(source_tile: Node3D, source_pos: Vector2i) -> void:
	"""
	Spawn connecting tiles for all doors (only if connection doesn't exist)
	Implements GAMELOOP.md step 5: Check for permanent tiles with 7x7 grid wrapping
	
	@param source_tile: Source tile to connect from
	@param source_pos: Grid position of source tile
	"""
	
	if not source_tile.has_method("get_available_doors"):
		push_error("TileManager: Tile missing get_available_doors method")
		return
	
	var available_doors: Dictionary = source_tile.get_available_doors()
	
	for door_direction in available_doors:
		var raw_connecting_pos: Vector2i = _get_connecting_position(source_pos, door_direction)
		var wrapped_connecting_pos: Vector2i = _apply_world_wrapping(raw_connecting_pos)
		var did_wrap: bool = (raw_connecting_pos != wrapped_connecting_pos)
		
		print("TileManager: Checking connection from ", source_pos, " ", _get_direction_name(door_direction),
			  " to raw: ", raw_connecting_pos, " wrapped: ", wrapped_connecting_pos)
		
		# Skip if connection already established
		if _is_connection_established(source_pos, wrapped_connecting_pos):
			continue
		
		# Check if tile already exists at wrapped position
		if _active_tiles.has(wrapped_connecting_pos) and is_instance_valid(_active_tiles[wrapped_connecting_pos]):
			var existing_tile: Node3D = _active_tiles[wrapped_connecting_pos]
			
			# If it's a permanent tile, rotate it to connect
			if existing_tile.has_method("is_tile_permanent") and existing_tile.is_tile_permanent():
				_rotate_permanent_tile_to_connect(existing_tile, door_direction)
			
			_establish_connection(source_pos, wrapped_connecting_pos)
			_tile_state_manager.set_tile_state(wrapped_connecting_pos, _tile_state_manager.TileState.CONNECTING)
			continue
		elif _active_tiles.has(wrapped_connecting_pos):
			_active_tiles.erase(wrapped_connecting_pos)
		
		# Check for pre-assigned permanent tile at this position
		var permanent_scene_at_pos: PackedScene = _get_permanent_tile_at_position(wrapped_connecting_pos)
		if permanent_scene_at_pos != null:
			var permanent_tile: Node3D = _spawn_permanent_tile(permanent_scene_at_pos, wrapped_connecting_pos, source_tile, door_direction)
			if permanent_tile:
				_establish_connection(source_pos, wrapped_connecting_pos)
			continue
		
		# Allow normal tiles at (0,0) if start tile is gone
		if wrapped_connecting_pos == Vector2i(0, 0):
			if _active_tiles.has(Vector2i(0, 0)) and is_instance_valid(_active_tiles[Vector2i(0, 0)]):
				var tile_at_origin: Node3D = _active_tiles[Vector2i(0, 0)]
				var scene_path: String = tile_at_origin.get_meta("scene_path", "")
				# if scene_path == _start_tile_scene or tile_at_origin.name == "StartTile":
				# 	_establish_connection(source_pos, wrapped_connecting_pos)
				# 	_tile_state_manager.set_tile_state(wrapped_connecting_pos, _tile_state_manager.TileState.CONNECTING)
				# 	continue
		
		# Create random normal tile
		var new_tile: Node3D = _create_random_tile(wrapped_connecting_pos)
		if not new_tile:
			continue
		
		# Setup tile orientation and position
		_align_tiles(source_tile, new_tile, door_direction, wrapped_connecting_pos, did_wrap)
		_register_tile(new_tile, wrapped_connecting_pos)
		
		# Register with TileStateManager as connecting
		_tile_state_manager.register_tile(new_tile, wrapped_connecting_pos, _tile_state_manager.TileState.CONNECTING)
		
		# Establish the connection
		_establish_connection(source_pos, wrapped_connecting_pos)
		
		# Emit tile generated event
		_message_bus.emit_event("tile_generated", [new_tile, wrapped_connecting_pos, {}])
		
func _rotate_permanent_tile_to_connect(permanent_tile: Node3D, approaching_from_direction: int) -> void:
	"""
	Rotate an existing permanent tile to connect with the approaching tile
	
	@param permanent_tile: The permanent tile to rotate
	@param approaching_from_direction: The direction we're approaching FROM (need opposite door)
	"""
	# Calculate the opposite direction (where permanent tile needs a door)
	var required_door_direction: int = _get_opposite_direction(approaching_from_direction)
	
	print("TileManager: Need to rotate permanent tile ", permanent_tile.name,
		  " to have door facing ", _get_direction_name(required_door_direction))
	
	# Get the permanent tile's available doors in their ORIGINAL orientations
	if not permanent_tile.has_method("door_markers"):
		# Try to detect doors if not already done
		if permanent_tile.has_method("detect_doors"):
			permanent_tile.detect_doors()
	
	# Find which original door can be rotated to face the required direction
	var best_rotation: int = -1
	
	# Check all possible doors on the permanent tile
	var door_found: bool = false
	for check_direction in [DoorDirection.NORTH, DoorDirection.EAST, DoorDirection.SOUTH, DoorDirection.WEST]:
		if permanent_tile.has_method("has_door") and permanent_tile.has_door(check_direction):
			# This door exists, check how many rotations needed
			for rotation_steps in range(4):
				var rotated_direction: int = _get_door_after_rotation(check_direction, rotation_steps)
				if rotated_direction == required_door_direction:
					best_rotation = rotation_steps
					door_found = true
					print("TileManager: Found door at ", _get_direction_name(check_direction),
						  " that needs ", rotation_steps, " rotations")
					break
		
		if door_found:
			break
	
	# Apply the rotation if we found a valid orientation
	if best_rotation != -1:
		var current_rotation: int = 0
		if permanent_tile.has_method("get_current_rotation"):
			current_rotation = permanent_tile.get_current_rotation()
		
		if current_rotation != best_rotation:
			print("TileManager: Rotating permanent tile from rotation ", current_rotation,
				  " to ", best_rotation)
			
			if permanent_tile.has_method("set_tile_rotation"):
				permanent_tile.set_tile_rotation(best_rotation)
			else:
				permanent_tile.rotation.y = best_rotation * PI / 2
	else:
		push_warning("TileManager: Could not find valid rotation for permanent tile ",
					 permanent_tile.name, " to connect from ", _get_direction_name(approaching_from_direction))

func _is_connection_established(pos1: Vector2i, pos2: Vector2i) -> bool:
	"""
	Check if connection between two positions is already established
	
	@param pos1: First position
	@param pos2: Second position
	@return: True if connection exists
	"""
	var key1: String = str(pos1) + "_" + str(pos2)
	var key2: String = str(pos2) + "_" + str(pos1)
	
	return _established_connections.has(key1) or _established_connections.has(key2)

func _establish_connection(pos1: Vector2i, pos2: Vector2i) -> void:
	"""
	Mark connection as established between two positions
	
	@param pos1: First position
	@param pos2: Second position
	"""
	var key: String = str(pos1) + "_" + str(pos2)
	_established_connections[key] = true

func _create_random_tile(grid_pos: Vector2i) -> Node3D:
	"""Create a random normal (non-permanent) tile at position"""
	if _normal_tiles.is_empty():
		push_error("TileManager: No normal tile scenes available")
		return null
	
	# Select random normal tile
	var random_scene: PackedScene = _normal_tiles[randi() % _normal_tiles.size()]
	return _create_tile_from_scene(random_scene, grid_pos)

func _align_tiles(source_tile: Node3D, target_tile: Node3D, door_direction: int, target_grid_pos: Vector2i, did_wrap: bool) -> void:
	"""
	Align target tile to connect with source tile door
	Physical positions are always adjacent, grid positions wrap for tracking
	
	@param source_tile: Source tile with door
	@param target_tile: Target tile to align
	@param door_direction: Direction of connecting door
	@param target_grid_pos: Grid position of target tile (wrapped for tracking)
	@param did_wrap: Whether world wrapping occurred (for tracking only)
	"""
	# Rotate target tile
	if target_tile.has_method("get_available_doors"):
		var target_doors: Array = target_tile.get_available_doors().keys()
		if not target_doors.is_empty():
			var chosen_door: int = target_doors[randi() % target_doors.size()]
			var rotation_needed: int = _calculate_rotation_needed(chosen_door, door_direction)
			
			if target_tile.has_method("set_tile_rotation"):
				target_tile.set_tile_rotation(rotation_needed)
			else:
				target_tile.rotation.y = rotation_needed * PI / 2
	
	# FIXED: Always position tiles adjacent to each other in world space
	# Grid wrapping is ONLY for tracking, not for physical position
	var source_center: Vector3 = source_tile.position
	var offset: float = TILE_SIZE
	
	match door_direction:
		DoorDirection.NORTH:
			target_tile.position = Vector3(source_center.x + offset, source_center.y, source_center.z)
		DoorDirection.EAST:
			target_tile.position = Vector3(source_center.x, source_center.y, source_center.z + offset)
		DoorDirection.SOUTH:
			target_tile.position = Vector3(source_center.x - offset, source_center.y, source_center.z)
		DoorDirection.WEST:
			target_tile.position = Vector3(source_center.x, source_center.y, source_center.z - offset)
	
	if did_wrap:
		print("TileManager: Tile at wrapped grid ", target_grid_pos, " positioned at world ", target_tile.position,
			  " (adjacent to source at ", source_center, ")")

func _calculate_rotation_needed(original_door: int, target_door: int) -> int:
	"""
	Calculate rotation steps needed to align doors
	
	@param original_door: Original door direction
	@param target_door: Target door direction
	@return: Rotation steps (0-3)
	"""
	var original_index: int = _door_to_index(original_door)
	var target_index: int = _door_to_index(target_door)
	var opposite_target: int = (target_index + 2) % 4
	
	return (original_index - opposite_target + 4) % 4

func _door_to_index(door: int) -> int:
	"""
	Convert door enum to index
	
	@param door: Door direction enum
	@return: Index (0-3)
	"""
	match door:
		DoorDirection.NORTH: return 0
		DoorDirection.EAST: return 1
		DoorDirection.SOUTH: return 2
		DoorDirection.WEST: return 3
		_: return 0

func _get_direction_name(direction: int) -> String:
	"""Get direction name for logging"""
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East"
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

func _get_connecting_position(tile_pos: Vector2i, door_direction: int) -> Vector2i:
	"""
	Get grid position for connecting tile
	
	@param tile_pos: Current tile position
	@param door_direction: Direction of door
	@return: Connecting tile position
	"""
	match door_direction:
		DoorDirection.NORTH: return tile_pos + Vector2i(1, 0)
		DoorDirection.EAST: return tile_pos + Vector2i(0, 1)
		DoorDirection.SOUTH: return tile_pos + Vector2i(-1, 0)
		DoorDirection.WEST: return tile_pos + Vector2i(0, -1)
		_: return tile_pos

func _apply_world_wrapping(position: Vector2i) -> Vector2i:
	"""
	Apply 7x7 world grid wrapping as described in GAMELOOP.md step 5a
	Grid covers square area with corners at (3,3) and (-3,-3)
	
	@param position: Raw grid position
	@return: Wrapped position within 7x7 grid
	"""
	var wrapped_pos: Vector2i = position
	
	# Wrap X coordinate: -3 to 3 (7 total positions)
	while wrapped_pos.x > 3:
		wrapped_pos.x -= 7
	while wrapped_pos.x < -3:
		wrapped_pos.x += 7
	
	# Wrap Y coordinate: -3 to 3 (7 total positions)
	while wrapped_pos.y > 3:
		wrapped_pos.y -= 7
	while wrapped_pos.y < -3:
		wrapped_pos.y += 7
	
	if wrapped_pos != position:
		print("TileManager: World wrapped position from ", position, " to ", wrapped_pos)
	
	return wrapped_pos

func _has_permanent_tile_at(position: Vector2i) -> bool:
	"""
	Check if permanent tile exists at position
	
	@param position: Grid position to check
	@return: True if permanent tile exists
	"""
	# First check our permanent tiles registry
	if _permanent_tiles.has(position):
		return true
	
	# Then check if there's an active tile that's marked permanent
	if _active_tiles.has(position) and is_instance_valid(_active_tiles[position]):
		var tile: Node3D = _active_tiles[position]
		if tile.has_method("is_tile_permanent") and tile.is_tile_permanent():
			return true
	
	return false

func on_player_entered_tile(tile_position: Vector2i) -> void:
	"""
	Handle player entering a new tile (called by TileStateManager)
	
	@param tile_position: Grid position of entered tile
	"""
	
	if not _active_tiles.has(tile_position):
		push_error("TileManager: Player entered non-existent tile at " + str(tile_position))
		return
	
	var entered_tile: Node3D = _active_tiles[tile_position]
	
	# First perform cleanup of distant tiles
	_cleanup_tiles_for_position(tile_position)
	
	
	# Then spawn new connections from current tile
	await get_tree().process_frame
	_spawn_tile_connections(entered_tile, tile_position)

func _cleanup_tiles_for_position(player_pos: Vector2i) -> void:
	"""
	Clean up tiles based on STRICT game loop rules:
	According to step 13: "the previous tile's connecting tiles are 'cleaned up'"
	Only keep: Active tile, Previous tile, and tiles connecting to the ACTIVE tile
	
	@param player_pos: Current player position
	"""
	
	var previous_pos = _tile_state_manager.get_previous_player_tile()
	
	# According to game loop: Keep only Active, Previous, and 0-3 connecting tiles to Active
	var tiles_to_keep: Array[Vector2i] = []
	
	# 1. Always keep current (ACTIVE) tile
	tiles_to_keep.append(player_pos)
	
	# 2. Keep previous tile if valid (allows player to go back)
	if previous_pos != Vector2i(-1000, -1000):
		tiles_to_keep.append(previous_pos)
	
	# 3. Keep only tiles that are DIRECTLY connected to the ACTIVE tile
	# These are the "connecting tiles" mentioned in the game loop
	for dir in [DoorDirection.NORTH, DoorDirection.EAST, DoorDirection.SOUTH, DoorDirection.WEST]:
		var adjacent_pos = _get_connecting_position(player_pos, dir)
		if _active_tiles.has(adjacent_pos):
			tiles_to_keep.append(adjacent_pos)
	
	
	# 4. Build removal list - everything NOT in the keep list
	var tiles_to_remove: Array[Vector2i] = []
	for pos in _active_tiles.keys():
		if pos not in tiles_to_keep:
			# Check if it's permanent (puzzle tiles should be preserved)
			if _has_permanent_tile_at(pos):
				pass
			else:
				tiles_to_remove.append(pos)
	
	if tiles_to_remove.size() > 0:
		for pos in tiles_to_remove:
			_cleanup_single_tile(pos)

func _cleanup_single_tile(pos: Vector2i) -> void:
	"""
	Clean up a single tile and its resources
	
	@param pos: Position of tile to clean up
	"""
	if not _active_tiles.has(pos):
		return
	
	var tile: Node3D = _active_tiles[pos]
	
	# Check if tile reference is valid first, before doing anything
	if not is_instance_valid(tile):
		print("TileManager: Tile at ", pos, " was already freed, cleaning up reference")
		_active_tiles.erase(pos)
		_remove_connections_for_position(pos)
		_tile_state_manager.cleanup_tile(pos)
		return
	
	var tile_name = tile.name
	
	# Count and remove items/entities
	var items_removed: Array = []
	var entities_removed: Array = []
	
	# Find and log items being removed
	for child in tile.get_children():
		if not is_instance_valid(child):
			continue
			
		if child.has_meta("is_collectible"):
			var item_id = child.get_meta("item_id", "unknown")
			items_removed.append(item_id)
		elif child.has_meta("is_backpack"):
			items_removed.append("backpack")
		elif child.is_in_group("enemies") or child.is_in_group("effigies"):
			entities_removed.append(child.name)
	
	# Emit cleanup event
	_message_bus.emit_event("tile_cleaned_up", [pos, items_removed])
	
	# Remove from tracking
	_active_tiles.erase(pos)
	_remove_connections_for_position(pos)
	_tile_state_manager.cleanup_tile(pos)
	
	# Free the tile safely
	if tile.get_parent():
		tile.get_parent().remove_child(tile)
	tile.queue_free()

func _remove_connections_for_position(pos: Vector2i) -> void:
	"""
	Remove all connection entries for a position
	
	@param pos: Position to remove connections for
	"""
	var keys_to_remove: Array[String] = []
	
	for key in _established_connections.keys():
		if str(pos) in key:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_established_connections.erase(key)

func shift_maze_section(center: Vector2i = Vector2i.ZERO) -> void:
	"""
	Trigger a maze section shift
	
	@param center: Center position for shift
	"""
	_message_bus.emit_event("maze_shift_triggered", [center, 3, []])

func remove_permanent_tile(position: Vector2i) -> void:
	"""
	Remove a tile from permanent status (when puzzle completed)
	
	@param position: Position of tile to remove from permanent
	"""
	if _permanent_tiles.has(position):
		_permanent_tiles.erase(position)
	
	if _puzzle_tiles.has(position):
		_puzzle_tiles.erase(position)

func _position_player_at_start(start_tile: Node3D) -> void:
	"""
	Position player at start marker
	
	@param start_tile: Start tile with player spawn point
	"""
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		push_warning("TileManager: Player not found")
		return
	
	var start_marker: Node3D = start_tile.get_node_or_null("PlayerStart") as Node3D
	if start_marker:
		player.global_position = start_marker.global_position
	else:
		player.global_position = start_tile.global_position + Vector3(0, 1, 0)

func get_current_player_tile() -> Vector2i:
	"""Get current player tile position"""
	return _tile_state_manager.get_current_player_tile()

func get_active_tile_count() -> int:
	"""Get number of active tiles"""
	return _active_tiles.size()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.maze_shift_triggered.connect(_on_maze_shift)
	_message_bus.puzzle_completed.connect(_on_puzzle_completed)
	
	# Connect to SaveManager signal for continue games
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_signal("save_data_loaded"):
		save_manager.save_data_loaded.connect(_on_save_data_loaded)

func _on_game_started() -> void:
	"""Handle game start - initialize tiles when game actually starts"""
	# Clear all previous run data
	_established_connections.clear()
	_start_tile_initialized = false
	cleanup_invalid_tile_references()
	initialize_game_tiles()

func _on_maze_shift(center: Vector2i, radius: int, affected_tiles: Array) -> void:
	"""Handle maze shift request"""
	shift_maze_section(center)

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion"""
	remove_permanent_tile(tile_pos)

func _on_save_data_loaded() -> void:
	"""Handle save data loaded signal - reload tiles to check puzzle completion status"""
	print("TileManager: Save data loaded, reloading available tiles")
	_load_available_tiles()

# Debug functions
func debug_print_active_tiles() -> void:
	"""Print all active tiles for debugging"""
	pass

func force_cleanup_debug() -> void:
	"""Force cleanup for debugging purposes"""
	var current_pos = _tile_state_manager.get_current_player_tile()
	_cleanup_tiles_for_position(current_pos)
	debug_print_active_tiles()

func debug_check_start_tile() -> void:
	"""Debug function to check start tile status"""
	pass

func _get_permanent_tile_at_position(position: Vector2i) -> PackedScene:
	"""
	Check if a permanent tile is pre-assigned to this position
	
	@param position: Grid position to check
	@return: PackedScene of permanent tile assigned here, or null
	"""
	if _permanent_tile_assignments.has(position):
		return _permanent_tile_assignments[position]
	
	return null

func _are_positions_equivalent_with_wrapping(pos1: Vector2i, pos2: Vector2i) -> bool:
	"""
	Check if two positions are equivalent considering world wrapping
	
	@param pos1: First position
	@param pos2: Second position  
	@return: True if positions are the same considering wrapping
	"""
	# Positions are equivalent if they differ by multiples of 7
	var diff_x: int = abs(pos1.x - pos2.x)
	var diff_y: int = abs(pos1.y - pos2.y)
	
	return (diff_x % 7 == 0) and (diff_y % 7 == 0)

func _can_permanent_tile_spawn_at(position: Vector2i) -> bool:
	"""
	Check if a permanent tile is allowed to spawn at this position
	Permanent tiles cannot spawn in the area from (1,1) to (-1,-1)
	
	@param position: Position to check
	@return: True if permanent tiles can spawn here
	"""
	# Check if position is in forbidden zone
	if position.x >= FORBIDDEN_MIN.x and position.x <= FORBIDDEN_MAX.x and \
	   position.y >= FORBIDDEN_MIN.y and position.y <= FORBIDDEN_MAX.y:
		return false
	
	return true

func _spawn_permanent_tile(tile_scene: PackedScene, grid_pos: Vector2i, source_tile: Node3D, door_direction: int) -> Node3D:
	"""
	Spawn a pre-assigned permanent tile at position
	
	@param tile_scene: PackedScene of the permanent tile
	@param grid_pos: Position to spawn at
	@param source_tile: Tile we're connecting from
	@param door_direction: Direction we're connecting from
	@return: Spawned tile or null
	"""
	print("TileManager: Spawning pre-assigned permanent tile at ", grid_pos)
	
	var permanent_tile: Node3D = _create_tile_from_scene(tile_scene, grid_pos)
	if not permanent_tile:
		return null
	
	# Permanent tiles must rotate to connect
	_align_tiles_with_rotation_requirement(source_tile, permanent_tile, door_direction, grid_pos)
	
	# Register the tile
	_register_tile(permanent_tile, grid_pos)
	
	# Register with TileStateManager as connecting
	_tile_state_manager.register_tile(permanent_tile, grid_pos, _tile_state_manager.TileState.CONNECTING)
	
	# Emit tile generated event
	_message_bus.emit_event("tile_generated", [permanent_tile, grid_pos, {}])
	
	return permanent_tile

func _align_tiles_with_rotation_requirement(source_tile: Node3D, target_tile: Node3D, door_direction: int, target_grid_pos: Vector2i) -> void:
	"""
	Align tiles ensuring the target (permanent) tile rotates to connect properly
	Physical positions are always adjacent, grid positions wrap for tracking
	
	@param source_tile: Source tile with door
	@param target_tile: Target tile to align (will be rotated)
	@param door_direction: Direction of connecting door from source
	@param target_grid_pos: Grid position of target tile (wrapped for tracking)
	"""
	# Calculate the opposite direction (where target needs a door)
	var required_door_direction: int = _get_opposite_direction(door_direction)
	
	# Find which door on the target tile should connect
	if target_tile.has_method("get_available_doors"):
		var target_doors: Dictionary = target_tile.get_available_doors()
		
		# Find a door that can be rotated to match the required direction
		var best_rotation: int = -1
		var best_door: int = -1
		
		for original_door_dir in target_doors:
			# Calculate how many rotations needed to align this door
			for rotation_steps in range(4):
				var rotated_dir: int = _get_door_after_rotation(original_door_dir, rotation_steps)
				if rotated_dir == required_door_direction:
					best_rotation = rotation_steps
					best_door = original_door_dir
					break
			
			if best_rotation != -1:
				break
		
		# Apply the rotation
		if best_rotation != -1:
			print("TileManager: Rotating permanent tile ", target_tile.name, " by ", best_rotation, " steps")
			if target_tile.has_method("set_tile_rotation"):
				target_tile.set_tile_rotation(best_rotation)
			else:
				target_tile.rotation.y = best_rotation * PI / 2
	
	# FIXED: Always position tiles adjacent in world space
	# Grid wrapping is ONLY for tracking, not physical positioning
	var source_center: Vector3 = source_tile.position
	var offset: float = TILE_SIZE
	
	match door_direction:
		DoorDirection.NORTH:
			target_tile.position = Vector3(source_center.x + offset, source_center.y, source_center.z)
		DoorDirection.EAST:
			target_tile.position = Vector3(source_center.x, source_center.y, source_center.z + offset)
		DoorDirection.SOUTH:
			target_tile.position = Vector3(source_center.x - offset, source_center.y, source_center.z)
		DoorDirection.WEST:
			target_tile.position = Vector3(source_center.x, source_center.y, source_center.z - offset)
	
	print("TileManager: Permanent tile at wrapped grid ", target_grid_pos, " positioned at world ", target_tile.position)

func _get_opposite_direction(direction: int) -> int:
	"""
	Get the opposite door direction
	
	@param direction: Original direction
	@return: Opposite direction
	"""
	match direction:
		DoorDirection.NORTH: return DoorDirection.SOUTH
		DoorDirection.EAST: return DoorDirection.WEST
		DoorDirection.SOUTH: return DoorDirection.NORTH
		DoorDirection.WEST: return DoorDirection.EAST
		_: return DoorDirection.NORTH

func _get_door_after_rotation(original_door: int, rotation_steps: int) -> int:
	"""
	Get what door direction becomes after rotation (counter-clockwise)
	
	@param original_door: Original door direction
	@param rotation_steps: Number of 90-degree rotations
	@return: New door direction
	"""
	var door_index: int = _door_to_index(original_door)
	var new_index: int = (door_index - rotation_steps + 4) % 4
	return _index_to_door_enum(new_index)

func _index_to_door_enum(index: int) -> int:
	"""
	Convert index back to door enum
	
	@param index: Index (0-3)
	@return: Door direction enum
	"""
	match index:
		0: return DoorDirection.NORTH
		1: return DoorDirection.EAST
		2: return DoorDirection.SOUTH
		3: return DoorDirection.WEST
		_: return DoorDirection.NORTH
		
func cleanup_invalid_tile_references() -> void:
	"""
	Clean up any invalid tile references in _active_tiles
	Should be called when starting a new run
	"""
	var invalid_positions: Array[Vector2i] = []
	
	for pos in _active_tiles.keys():
		var tile = _active_tiles[pos]
		if not is_instance_valid(tile):
			invalid_positions.append(pos)
	
	for pos in invalid_positions:
		print("TileManager: Removing invalid tile reference at ", pos)
		_active_tiles.erase(pos)
		_remove_connections_for_position(pos)
	
	if invalid_positions.size() > 0:
		print("TileManager: Cleaned up ", invalid_positions.size(), " invalid tile references")
