extends Node
## TileManager - Handles tile generation, connections, and cleanup
## State management delegated to TileStateManager

var _message_bus: Node
var _state_manager: Node
var _spawn_manager: Node
var _tile_state_manager: Node

# Tile tracking
var _active_tiles: Dictionary = {}  # Vector2i -> Node3D
var _permanent_tiles: Dictionary = {}  # Vector2i -> Node3D
var _puzzle_tiles: Dictionary = {}  # Vector2i -> puzzle_id

# Connection tracking - prevents respawning
var _established_connections: Dictionary = {}  # "pos1_pos2" -> true

# Tile scenes
var _available_tile_scenes: Array[String] = []
var _start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"
var _final_tile_scene: String = "res://scenes/tiles/final_event_tile.tscn"

# Initialization flag
var _start_tile_initialized: bool = false

# Door constants
enum DoorDirection { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

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
	"""Load all available tile scenes"""
	_available_tile_scenes.clear()
	
	var tiles_dir: DirAccess = DirAccess.open("res://scenes/tiles/")
	if not tiles_dir:
		push_error("TileManager: Could not open tiles directory")
		return
	
	tiles_dir.list_dir_begin()
	var file_name: String = tiles_dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn") and file_name != "start_tile.tscn" and file_name != "final_event_tile.tscn":
			_available_tile_scenes.append("res://scenes/tiles/" + file_name)
		file_name = tiles_dir.get_next()
	
	tiles_dir.list_dir_end()

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
	

func _create_tile_from_scene(scene_path: String, grid_pos: Vector2i) -> Node3D:
	"""
	Create tile instance from scene file
	
	@param scene_path: Path to tile scene file
	@param grid_pos: Grid position for the tile
	@return: Created tile node or null if failed
	"""
	var tile_scene: PackedScene = load(scene_path) as PackedScene
	if not tile_scene:
		push_error("TileManager: Failed to load scene: " + scene_path)
		return null
	
	var tile_instance: Node3D = tile_scene.instantiate() as Node3D
	if not tile_instance:
		push_error("TileManager: Failed to instantiate scene: " + scene_path)
		return null
	
	tile_instance.set_meta("grid_position", grid_pos)
	tile_instance.set_meta("scene_path", scene_path)
	tile_instance.set_meta("world_map_pos", grid_pos)
	
	# For start tile, explicitly ensure it's not permanent
	if scene_path == _start_tile_scene:
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
		var connecting_pos: Vector2i = _apply_world_wrapping(raw_connecting_pos)
		
		
		# Skip if connection already established
		if _is_connection_established(source_pos, connecting_pos):
			continue
		
		# Step 5a: Check for permanent tile at wrapped position first
		if _has_permanent_tile_at(connecting_pos):
			_establish_connection(source_pos, connecting_pos)
			continue
		
		# Skip if tile already exists
		if _active_tiles.has(connecting_pos) and is_instance_valid(_active_tiles[connecting_pos]):
			_establish_connection(source_pos, connecting_pos)
			# Make sure existing tile is set to connecting state
			_tile_state_manager.set_tile_state(connecting_pos, _tile_state_manager.TileState.CONNECTING)
			continue
		elif _active_tiles.has(connecting_pos):
			# Clean up invalid reference
			_active_tiles.erase(connecting_pos)
		
		# IMPORTANT: Don't create a new tile at (0, 0) if we already have the start tile there
		if connecting_pos == Vector2i(0, 0):
			# The start tile should already be registered if it exists
			if _active_tiles.has(Vector2i(0, 0)):
				_establish_connection(source_pos, connecting_pos)
				_tile_state_manager.set_tile_state(connecting_pos, _tile_state_manager.TileState.CONNECTING)
				continue
		
		# Step 5b: Create random tile if no permanent tile exists
		var new_tile: Node3D = _create_random_tile(connecting_pos)
		if not new_tile:
			continue
		
		# Setup tile orientation and position
		_align_tiles(source_tile, new_tile, door_direction)
		_register_tile(new_tile, connecting_pos)
		
		# Register with TileStateManager as connecting
		_tile_state_manager.register_tile(new_tile, connecting_pos, _tile_state_manager.TileState.CONNECTING)
		
		# Establish the connection
		_establish_connection(source_pos, connecting_pos)
		
		# Emit tile generated event for spawn processing
		_message_bus.emit_event("tile_generated", [new_tile, connecting_pos, {}])
		

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
	"""
	Create a random tile at position
	
	@param grid_pos: Grid position for tile
	@return: Created tile or null
	"""
	if _available_tile_scenes.is_empty():
		push_error("TileManager: No available tile scenes")
		return null
	
	# Check if should spawn final tile
	if _state_manager.has_flag("final_event_available") and randf() < 0.5:
		return _create_tile_from_scene(_final_tile_scene, grid_pos)
	
	var random_scene: String = _available_tile_scenes[randi() % _available_tile_scenes.size()]
	return _create_tile_from_scene(random_scene, grid_pos)

func _align_tiles(source_tile: Node3D, target_tile: Node3D, door_direction: int) -> void:
	"""
	Align target tile to connect with source tile door
	
	@param source_tile: Source tile with door
	@param target_tile: Target tile to align
	@param door_direction: Direction of connecting door
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
	
	# Position target tile
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
	var wrapped_pos = position
	
	# Wrap X coordinate: -3 to 3
	if wrapped_pos.x > 3:
		wrapped_pos.x = -3 + (wrapped_pos.x - 4)
	elif wrapped_pos.x < -3:
		wrapped_pos.x = 3 + (wrapped_pos.x + 4)
	
	# Wrap Y coordinate: -3 to 3  
	if wrapped_pos.y > 3:
		wrapped_pos.y = -3 + (wrapped_pos.y - 4)
	elif wrapped_pos.y < -3:
		wrapped_pos.y = 3 + (wrapped_pos.y + 4)
	
	if wrapped_pos != position:
		pass
	
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
	var tile_name = "UNKNOWN"
	if is_instance_valid(tile):
		tile_name = tile.name
	
	# Count and remove items/entities
	var items_removed: Array = []
	var entities_removed: Array = []
	
	if is_instance_valid(tile):
		# Find and log items being removed
		for child in tile.get_children():
			if child.has_meta("is_collectible"):
				var item_id = child.get_meta("item_id", "unknown")
				items_removed.append(item_id)
			elif child.has_meta("is_backpack"):
				items_removed.append("backpack")
			elif child.is_in_group("enemies") or child.is_in_group("effigies"):
				entities_removed.append(child.name)
	
	# Log what's being cleaned up
	if items_removed.size() > 0:
		pass
	if entities_removed.size() > 0:
		pass
	
	if pos == Vector2i(0, 0):
		pass
	
	# Emit cleanup event
	_message_bus.emit_event("tile_cleaned_up", [pos, items_removed])
	
	# Remove from tracking
	_active_tiles.erase(pos)
	_remove_connections_for_position(pos)
	_tile_state_manager.cleanup_tile(pos)
	
	# Free the tile safely
	if is_instance_valid(tile):
		# Ensure tile is removed from parent before freeing
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

func _on_game_started() -> void:
	"""Handle game start - initialize tiles when game actually starts"""
	initialize_game_tiles()

func _on_maze_shift(center: Vector2i, radius: int, affected_tiles: Array) -> void:
	"""Handle maze shift request"""
	shift_maze_section(center)

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion"""
	remove_permanent_tile(tile_pos)

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
