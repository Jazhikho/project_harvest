extends Node
## Tile Manager - Simple maze generation system
## Spawns tiles connected by doors, manages active/passive states

signal player_entered_tile(tile_position: Vector2i)

# Door system constants
enum Door { NORTH=0, EAST=1, SOUTH=2, WEST=3 }

# Available tile scene paths
var available_tile_scenes: Array[String] = []
var start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"

# Active tiles
var active_tiles: Dictionary = {}  # Vector2i -> Node3D
var current_player_tile: Vector2i = Vector2i(0, 0)
var active_tile_node: Node3D = null

func _ready():
	_load_available_tiles()
	_spawn_start_tile()

func _load_available_tiles():
	"""Load all available tile scenes from the tiles folder"""
	available_tile_scenes.clear()
	
	# Load all tile scenes except start_tile
	var tiles_dir = DirAccess.open("res://scenes/tiles/")
	if tiles_dir:
		tiles_dir.list_dir_begin()
		var file_name = tiles_dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tscn") and file_name != "start_tile.tscn":
				available_tile_scenes.append("res://scenes/tiles/" + file_name)
			file_name = tiles_dir.get_next()
	
	print("Loaded ", available_tile_scenes.size(), " tile scenes")

func _spawn_start_tile():
	"""Spawn the starting tile and connect tiles to its doors"""
	print("Spawning start tile...")
	
	# Check if there's already a start tile in the scene
	var maze_container = get_tree().current_scene.get_node_or_null("MazeContainer")
	var existing_start_tile = null
	
	if maze_container:
		existing_start_tile = maze_container.get_node_or_null("StartTile")
	
	var start_tile: Node3D
	
	if existing_start_tile:
		start_tile = existing_start_tile
		start_tile.position = Vector3.ZERO
	else:
		start_tile = _create_tile_from_scene(start_tile_scene, Vector2i(0, 0))
		# Ensure start tile is at origin
		if start_tile:
			start_tile.position = Vector3.ZERO
	
	# Register start tile
	active_tiles[Vector2i(0, 0)] = start_tile
	current_player_tile = Vector2i(0, 0)
	active_tile_node = start_tile
	
	# Position player at start marker (defer until player is ready)
	call_deferred("_position_player_at_start", start_tile)
	
	# Wait for tile to be fully initialized before spawning connecting tiles
	await get_tree().process_frame
	await get_tree().process_frame  # Wait extra frame for tile's _ready() to complete
	
	# Spawn connecting tiles for all doors on start tile
	_spawn_connecting_tiles(start_tile, Vector2i(0, 0))
	
	print("Start tile spawned and connected")

func on_player_entered_tile(tile_position: Vector2i):
	"""Handle player entering a new tile"""
	print("Player entered tile at: ", tile_position)
	
	var old_tile_pos = current_player_tile
	current_player_tile = tile_position
	
	# Create tile if it doesn't exist (this should normally not happen if spawning works correctly)
	if not active_tiles.has(tile_position):
		print("Creating missing tile at: ", tile_position)
		var new_tile = _create_random_tile(tile_position)
		if new_tile:
			active_tiles[tile_position] = new_tile
		else:
			print("ERROR: Failed to create tile at ", tile_position)
			return
	
	# Set new active tile
	active_tile_node = active_tiles[tile_position]
	
	# Mark old tile as passive and destroy its connected tiles (except the one player is on)
	if old_tile_pos != tile_position and active_tiles.has(old_tile_pos):
		_cleanup_passive_tile(old_tile_pos, tile_position)
	
	# Wait a frame for tile to be ready, then spawn connecting tiles
	await get_tree().process_frame
	_spawn_connecting_tiles(active_tile_node, tile_position)
	
	emit_signal("player_entered_tile", tile_position)

func _spawn_connecting_tiles(tile: Node3D, tile_pos: Vector2i):
	"""Spawn tiles connected to all available doors of the given tile"""
	print("=== Spawning connecting tiles for tile at ", tile_pos, " ===")
	
	if not tile.has_method("get_available_doors"):
		print("ERROR: Tile doesn't have get_available_doors method")
		return
	
	var available_doors = tile.get_available_doors()
	print("Tile has ", available_doors.size(), " available doors:")
	for door_dir in available_doors:
		print("  - Door ", door_dir, " at ", available_doors[door_dir]["world_position"])
	
	for door_direction in available_doors:
		var door_data = available_doors[door_direction]
		var connecting_pos = _get_connecting_position(tile_pos, door_direction)
		
		print("Processing door ", door_direction, " -> connecting position ", connecting_pos)
		
		# Skip if tile already exists at this position
		if active_tiles.has(connecting_pos):
			print("  Tile already exists at ", connecting_pos, " - skipping")
			continue
		
		# Don't spawn start tile again
		if connecting_pos == Vector2i(0, 0):
			print("  Would spawn at start position - skipping")
			continue
		
		# Create new tile
		print("  Creating new tile at ", connecting_pos)
		var new_tile = _create_random_tile(connecting_pos)
		if new_tile:
			# Rotate new tile to align doors
			_align_tile_doors(tile, new_tile, door_direction, door_data)
			
			# Register the new tile
			active_tiles[connecting_pos] = new_tile
			
			print("  ✓ Successfully spawned connecting tile at ", connecting_pos)
		else:
			print("  ✗ Failed to create tile at ", connecting_pos)
	
	print("=== Connecting tile spawning complete ===\n")

func _cleanup_passive_tile(passive_tile_pos: Vector2i, active_tile_pos: Vector2i):
	"""Clean up tiles connected to the passive tile (except the active one)"""
	var passive_tile = active_tiles[passive_tile_pos]
	if not passive_tile or not passive_tile.has_method("get_available_doors"):
		return
	
	var available_doors = passive_tile.get_available_doors()
	
	for door_direction in available_doors:
		var connecting_pos = _get_connecting_position(passive_tile_pos, door_direction)
		
		# Don't destroy the tile the player is currently on
		if connecting_pos == active_tile_pos:
			continue
		
		# Don't destroy the start tile
		if connecting_pos == Vector2i(0, 0):
			continue
		
		# Destroy tile if it exists
		if active_tiles.has(connecting_pos):
			var tile_to_destroy = active_tiles[connecting_pos]
			active_tiles.erase(connecting_pos)
			tile_to_destroy.queue_free()
			print("Destroyed tile at ", connecting_pos)

func _get_connecting_position(tile_pos: Vector2i, door_direction) -> Vector2i:
	"""Get the position where a connecting tile should be placed"""
	# Based on coordinate system where North = +X, East = +Z in world space
	# Grid coordinates: X = North/South, Y = East/West
	match door_direction:
		1: return tile_pos + Vector2i(1, 0)   # NORTH -> move +X in grid
		2: return tile_pos + Vector2i(0, 1)   # EAST -> move +Y in grid  
		4: return tile_pos + Vector2i(-1, 0)  # SOUTH -> move -X in grid
		8: return tile_pos + Vector2i(0, -1)  # WEST -> move -Y in grid
		_: return tile_pos

func _create_random_tile(pos: Vector2i) -> Node3D:
	"""Create a random tile at the given position"""
	if available_tile_scenes.is_empty():
		print("ERROR: No available tile scenes loaded!")
		return null
	
	# Pick a random tile scene
	var random_scene_path = available_tile_scenes[randi() % available_tile_scenes.size()]
	print("Creating tile: ", random_scene_path.get_file(), " at ", pos)
	return _create_tile_from_scene(random_scene_path, pos)

func _align_tile_doors(source_tile: Node3D, target_tile: Node3D, source_door_direction, source_door_data):
	"""Tiles are positioned by grid - no additional alignment needed"""
	
	print("Tile positioned at: ", target_tile.position)

func _position_tile_basic(source_tile: Node3D, target_tile: Node3D, source_door_direction):
	"""Position tile using your simple formula: source_center + half_source + half_target"""
	
	var source_center = source_tile.position
	var source_size = source_tile.get_tile_size() if source_tile.has_method("get_tile_size") else Vector2(20, 20)
	var target_size = target_tile.get_tile_size() if target_tile.has_method("get_tile_size") else Vector2(20, 20)
	
	print("Source center: ", source_center, " size: ", source_size)
	print("Target size: ", target_size)
	
	var position = Vector3.ZERO
	
	match source_door_direction:
		1: # NORTH - now 20x20: (0,0,0) + 10 + 10 = (20,0,0)
			var offset = source_size.x * 0.5 + target_size.x * 0.5  # 10 + 10 = 20
			position = Vector3(source_center.x + offset, source_center.y, source_center.z)
		2: # EAST - now 20x20: (0,0,0) + 10 + 10 = (0,0,20)
			var offset = source_size.y * 0.5 + target_size.y * 0.5  # 10 + 10 = 20
			position = Vector3(source_center.x, source_center.y, source_center.z + offset)
		4: # SOUTH
			var offset = source_size.x * 0.5 + target_size.x * 0.5
			position = Vector3(source_center.x - offset, source_center.y, source_center.z)
		8: # WEST
			var offset = source_size.y * 0.5 + target_size.y * 0.5
			position = Vector3(source_center.x, source_center.y, source_center.z - offset)
	
	target_tile.position = position
	print("Basic positioning: door ", source_door_direction, " -> tile at ", position)

func _door_direction_to_name(door_direction) -> String:
	"""Convert door direction to node name"""
	match door_direction:
		1: return "N"  # NORTH -> NDoor
		2: return "E"  # EAST -> EDoor  
		4: return "S"  # SOUTH -> SDoor
		8: return "W"  # WEST -> WDoor
		_: return "N"

func _get_door_offset_direction(door_direction) -> Vector3:
	"""Get the direction vector for door offset (1 meter spacing)"""
	# The connecting door should be 1 meter away in the direction the source door faces
	# Based on coordinate system where North = +X, East = +Z
	match door_direction:
		1: return Vector3(1, 0, 0)   # NORTH door -> connecting door 1 meter north (positive X)
		2: return Vector3(0, 0, 1)   # EAST door -> connecting door 1 meter east (positive Z)  
		4: return Vector3(-1, 0, 0)  # SOUTH door -> connecting door 1 meter south (negative X)
		8: return Vector3(0, 0, -1)  # WEST door -> connecting door 1 meter west (negative Z)
		_: return Vector3.ZERO

# Removed complex rotation calculations - using simple 180° rotation

func _create_tile_from_scene(scene_path: String, grid_pos: Vector2i) -> Node3D:
	"""Create a tile instance from a scene file"""
	var tile_scene: PackedScene = load(scene_path)
	if not tile_scene:
		print("ERROR: Failed to load tile scene: " + scene_path)
		return null
	
	var tile_instance: Node3D = tile_scene.instantiate()
	if not tile_instance:
		print("ERROR: Failed to instantiate tile scene: " + scene_path)
		return null
	
	# Store grid position as metadata
	tile_instance.set_meta("grid_position", grid_pos)
	tile_instance.set_meta("scene_path", scene_path)
	
	# Position tile based on grid position (20x20 spacing)
	tile_instance.position = Vector3(grid_pos.x * 20.0, 0.0, grid_pos.y * 20.0)
	
	# Add to maze container
	var maze_container = get_tree().current_scene.get_node("MazeContainer")
	if maze_container:
		maze_container.add_child(tile_instance)
	else:
		print("ERROR: MazeContainer not found in current scene!")
		tile_instance.queue_free()
		return null
	
	print("Created tile at grid ", grid_pos, " - positioning will be handled by door alignment")
	return tile_instance

func _position_player_at_start(start_tile: Node3D):
	"""Position the player at the start marker in the start tile"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("WARNING: Player not found in scene!")
		return
	
	var start_marker = start_tile.get_node_or_null("PlayerStart")
	if start_marker:
		player.global_position = start_marker.global_position
		print("Player positioned at start marker: ", start_marker.global_position)
	else:
		print("WARNING: PlayerStart marker not found in start tile!")

# Public API functions
func get_current_player_tile() -> Vector2i:
	return current_player_tile

func get_active_tile_count() -> int:
	return active_tiles.size()
