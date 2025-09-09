extends Node
## Manages tile generation, connections, and lifecycle
## Fixed to prevent respawning of tiles player moves between

var _message_bus: Node
var _state_manager: Node
var _spawn_manager: Node

# Tile tracking
var _active_tiles: Dictionary = {}  # Vector2i -> Node3D
var _current_player_tile: Vector2i = Vector2i(0, 0)
var _previous_player_tile: Vector2i = Vector2i(-1000, -1000)
var _permanent_tiles: Dictionary = {}  # Vector2i -> Node3D
var _puzzle_tiles: Dictionary = {}  # Vector2i -> puzzle_id

# Connection tracking - prevents respawning
var _established_connections: Dictionary = {}  # "pos1_pos2" -> true

# Tile scenes
var _available_tile_scenes: Array[String] = []
var _start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"
var _final_tile_scene: String = "res://scenes/tiles/final_event_tile.tscn"

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
	
	if not _message_bus or not _state_manager or not _spawn_manager:
		push_error("TileManager: Required core systems not found")
		return
	
	_load_available_tiles()
	_connect_to_events()
	_spawn_start_tile()

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
	print("TileManager: Loaded ", _available_tile_scenes.size(), " tile scenes")

func _spawn_start_tile() -> void:
	"""Spawn the initial start tile"""
	var maze_container: Node = get_tree().current_scene.get_node_or_null("MazeContainer")
	if not maze_container:
		push_error("TileManager: MazeContainer not found in scene")
		return
	
	var start_tile: Node3D = null
	var existing_start: Node = maze_container.get_node_or_null("StartTile")
	
	if existing_start:
		start_tile = existing_start as Node3D
		start_tile.position = Vector3.ZERO
	else:
		start_tile = _create_tile_from_scene(_start_tile_scene, Vector2i(0, 0))
		if start_tile:
			start_tile.name = "StartTile"
			start_tile.position = Vector3.ZERO
	
	if not start_tile:
		push_error("TileManager: Failed to create start tile")
		return
	
	_register_tile(start_tile, Vector2i(0, 0))
	_current_player_tile = Vector2i(0, 0)
	
	if start_tile.has_method("set_as_active_tile"):
		start_tile.set_as_active_tile()
	
	call_deferred("_position_player_at_start", start_tile)
	await get_tree().process_frame
	await get_tree().process_frame
	
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
	
	if tile.has_method("is_tile_permanent") and tile.is_tile_permanent():
		_permanent_tiles[position] = tile
		
		if tile.has_method("get_puzzle_id"):
			var puzzle_id: String = tile.get_puzzle_id()
			if not puzzle_id.is_empty():
				_puzzle_tiles[position] = puzzle_id

func _spawn_tile_connections(source_tile: Node3D, source_pos: Vector2i) -> void:
	"""
	Spawn connecting tiles for all doors (only if connection doesn't exist)
	
	@param source_tile: Source tile to connect from
	@param source_pos: Grid position of source tile
	"""
	print("TileManager: Spawning connections for tile at ", source_pos)
	
	if not source_tile.has_method("get_available_doors"):
		push_error("TileManager: Tile missing get_available_doors method")
		return
	
	var available_doors: Dictionary = source_tile.get_available_doors()
	print("  Found ", available_doors.size(), " doors")
	
	for door_direction in available_doors:
		var connecting_pos: Vector2i = _get_connecting_position(source_pos, door_direction)
		
		print("  Checking connection to ", connecting_pos, " via ", _get_direction_name(door_direction))
		
		# Skip if connection already established (THIS IS THE KEY FIX)
		if _is_connection_established(source_pos, connecting_pos):
			print("    Connection already established - skipping")
			continue
		
		# Skip if tile already exists
		if _active_tiles.has(connecting_pos) and is_instance_valid(_active_tiles[connecting_pos]):
			print("    Tile already exists - establishing connection")
			_establish_connection(source_pos, connecting_pos)
			continue
		elif _active_tiles.has(connecting_pos):
			_active_tiles.erase(connecting_pos)
		
		# Skip if permanent tile exists
		if _has_permanent_tile_at(connecting_pos):
			print("    Permanent tile exists - establishing connection")
			_establish_connection(source_pos, connecting_pos)
			continue
		
		# Create new connecting tile
		print("    Creating new tile")
		var new_tile: Node3D = _create_random_tile(connecting_pos)
		if not new_tile:
			continue
		
		# Setup tile orientation and position
		_align_tiles(source_tile, new_tile, door_direction)
		_register_tile(new_tile, connecting_pos)
		
		# Establish the connection
		_establish_connection(source_pos, connecting_pos)
		
		# Mark as connecting tile
		if new_tile.has_method("set_as_connecting_tile"):
			new_tile.set_as_connecting_tile()
		
		# Emit tile generated event for spawn processing
		_message_bus.emit_event("tile_generated", [new_tile, connecting_pos, {}])
		
		print("    ✓ Created and connected tile at ", connecting_pos)

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
	print("  ✓ Connection established: ", pos1, " <-> ", pos2)

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

func _has_permanent_tile_at(position: Vector2i) -> bool:
	"""
	Check if permanent tile exists at position
	
	@param position: Grid position to check
	@return: True if permanent tile exists
	"""
	if _permanent_tiles.has(position):
		return true
	
	if _active_tiles.has(position) and is_instance_valid(_active_tiles[position]):
		var tile: Node3D = _active_tiles[position]
		if tile.has_method("is_tile_permanent"):
			return tile.is_tile_permanent()
	
	return false

func on_player_entered_tile(tile_position: Vector2i) -> void:
	"""
	Handle player entering a new tile
	
	@param tile_position: Grid position of entered tile
	"""
	print("TileManager: Player entered tile at ", tile_position, " (was at ", _current_player_tile, ")")
	
	# Check if this is actually a new tile or just a false transition
	if tile_position == _current_player_tile:
		print("TileManager: Player is already on this tile, ignoring transition")
		return
	
	_previous_player_tile = _current_player_tile
	_current_player_tile = tile_position
	
	if not _active_tiles.has(tile_position):
		push_error("TileManager: Player entered non-existent tile at " + str(tile_position))
		return
	
	var entered_tile: Node3D = _active_tiles[tile_position]
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	
	# Emit tile entry event
	_message_bus.emit_event("tile_entered", [entered_tile, tile_position, player])
	
	# Update tile states
	_update_tile_states(_previous_player_tile, tile_position)
	
	# Clean up distant tiles (but keep connected ones)
	_cleanup_distant_tiles(tile_position)
	
	# Spawn new connections from current tile
	await get_tree().process_frame
	_spawn_tile_connections(entered_tile, tile_position)

func _update_tile_states(old_pos: Vector2i, new_pos: Vector2i) -> void:
	"""
	Update tile active/past states
	
	@param old_pos: Previous tile position
	@param new_pos: Current tile position
	"""
	# Set new tile as active
	if _active_tiles.has(new_pos):
		var new_tile: Node3D = _active_tiles[new_pos]
		if new_tile.has_method("set_as_active_tile"):
			new_tile.set_as_active_tile()
	
	# Set old tile as connecting (so player can return)
	if _active_tiles.has(old_pos) and is_instance_valid(_active_tiles[old_pos]):
		var old_tile: Node3D = _active_tiles[old_pos]
		if old_tile.has_method("set_as_connecting_tile"):
			old_tile.set_as_connecting_tile()

func _cleanup_distant_tiles(player_pos: Vector2i) -> void:
	"""
	Clean up tiles that are too far from player (but preserve connections)
	
	@param player_pos: Current player position
	"""
	var tiles_to_remove: Array[Vector2i] = []
	var max_distance: int = 3  # Keep tiles within 3 positions
	
	for pos in _active_tiles.keys():
		var distance: float = player_pos.distance_to(pos)
		
		# Skip cleanup for:
		# - Current player tile
		# - Previous player tile (allow return)
		# - Permanent tiles
		# - Recently connected tiles
		if pos == player_pos:
			continue
		if pos == _previous_player_tile:
			continue
		if _has_permanent_tile_at(pos):
			continue
		if distance <= max_distance:
			continue
		
		tiles_to_remove.append(pos)
	
	# Remove distant tiles and their connections
	for pos in tiles_to_remove:
		if _active_tiles.has(pos):
			var tile: Node3D = _active_tiles[pos]
			_active_tiles.erase(pos)
			_remove_connections_for_position(pos)
			tile.queue_free()
			print("TileManager: Cleaned up distant tile at ", pos)

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
	print("TileManager: Maze section shift triggered")
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
	return _current_player_tile

func get_active_tile_count() -> int:
	"""Get number of active tiles"""
	return _active_tiles.size()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.maze_shift_triggered.connect(_on_maze_shift)
	_message_bus.puzzle_completed.connect(_on_puzzle_completed)

func _on_game_started() -> void:
	"""Handle game start"""
	print("TileManager: Game started")

func _on_maze_shift(center: Vector2i, radius: int, affected_tiles: Array) -> void:
	"""Handle maze shift request"""
	shift_maze_section(center)

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion"""
	remove_permanent_tile(tile_pos)
