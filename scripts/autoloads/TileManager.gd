extends Node
## Tile Manager - Dynamic tile-streaming maze system
## Core innovation of Project Harvest: infinite maze with minimal memory footprint

signal tile_spawned(position: Vector2i, tile_type: String)
signal tile_culled(position: Vector2i)
signal player_tile_changed(old_tile: Vector2i, new_tile: Vector2i)

@export var tile_size: float = 20.0  # Size of each tile in world units (matches cross tiles)
@export var active_radius: int = 1   # Keep tiles within this radius (1 = 3x3 grid)
@export var max_tiles: int = 9       # Maximum tiles in memory

# Door system constants
enum Door { N=0, E=1, S=2, W=3 }
const DOOR_BIT = {Door.N: 1, Door.E: 2, Door.S: 4, Door.W: 8}
const DOOR_OFFSET = {
	Door.N: Vector2i(0, -1),
	Door.E: Vector2i(1, 0), 
	Door.S: Vector2i(0, 1),
	Door.W: Vector2i(-1, 0)
}

# Tile types and library
enum TileType {
	DEAD_END,    # 1 exit
	STRAIGHT,    # 2 opposite exits  
	CORNER,      # 2 adjacent exits
	T_JUNCTION,  # 3 exits
	CROSS        # 4 exits
}

# Available tile scene paths (dynamically loaded)
var available_tile_scenes: Array[String] = []
var start_tile_scene: String = "res://scenes/tiles/start_tile.tscn"
var start_tile_used: bool = false

# Active tiles and state
var active_tiles: Dictionary = {}  # Vector2i -> Node3D
var tile_queue: Array[Vector2i] = []  # Order of tile creation for culling
var current_player_tile: Vector2i = Vector2i(0, 0)
var tiles_traversed: int = 0
var tension_level: float = 0.0

# Tile pooling for performance
var tile_pools: Dictionary = {}  # TileType -> Array[Node3D]
var navigation_links: Array[NavigationLink3D] = []
var link_pool: Array[NavigationLink3D] = []

func _ready():
	_load_available_tiles()
	_initialize_tile_pools()
	_spawn_initial_tile()

func _initialize_tile_pools():
	"""Initialize tile pools for each type"""
	for tile_type in TileType.values():
		tile_pools[tile_type] = []

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
				print("Loaded tile: ", file_name)
			file_name = tiles_dir.get_next()
	
	print("Available tiles: ", available_tile_scenes.size())

func _spawn_initial_tile():
	"""Spawn the starting tile for the player"""
	var start_tile = _create_start_tile(Vector2i(0, 0))
	_register_tile(Vector2i(0, 0), start_tile)
	
	# Position player at start marker
	_position_player_at_start(start_tile)
	
	# Spawn initial exit tiles
	call_deferred("_spawn_initial_exit_tiles")

func on_player_transition(from_tile: Vector2i, to_tile: Vector2i, direction: Door):
	"""Handle player transitioning from one tile to another"""
	print("Player transitioning from ", from_tile, " to ", to_tile, " via ", _door_to_string(direction))
	
	current_player_tile = to_tile
	tiles_traversed += 1
	_update_tension_level()
	
	# Mark start tile as used if leaving it
	if from_tile == Vector2i(0, 0) and not start_tile_used:
		start_tile_used = true
		print("Start tile marked as used - no longer available for spawning")
	
	# Ensure target tile exists
	if not active_tiles.has(to_tile):
		var required_entrance = _get_opposite_door(direction)
		var new_tile = _spawn_random_tile_with_entrance(to_tile, required_entrance)
		_register_tile(to_tile, new_tile)
	
	# Set entrance on the tile the player just entered
	var entered_tile = active_tiles[to_tile]
	if entered_tile.has_method("set_entrance"):
		var entrance_direction = _get_opposite_door(direction)
		entered_tile.set_entrance(entrance_direction)
	
	# Cull unused exits from previous tile and spawn new exits for current tile
	_update_tile_connections(from_tile, to_tile, direction)
	
	emit_signal("player_tile_changed", from_tile, to_tile)

func _spawn_initial_exit_tiles():
	"""Spawn tiles at all exits of the start tile"""
	var start_tile = active_tiles[Vector2i(0, 0)]
	if not start_tile:
		return
	
	_spawn_exit_tiles(Vector2i(0, 0), -1)  # -1 means no entrance direction to skip

func _determine_required_entrance(pos: Vector2i) -> int:
	"""Determine what entrance a tile needs based on neighboring tiles"""
	for door in Door.values():
		var neighbor_pos = pos + DOOR_OFFSET[door]
		if active_tiles.has(neighbor_pos):
			var neighbor_tile = active_tiles[neighbor_pos]
			var opposite_door = _get_opposite_door(door)
			
			# Check if neighbor has an exit facing this position
			if _tile_has_door(neighbor_tile, opposite_door):
				return door  # This tile needs this entrance
	
	return -1  # No required entrance

func _spawn_random_tile_with_entrance(pos: Vector2i, required_entrance: int) -> Node3D:
	"""Spawn a random tile that has the specified entrance door"""
	if available_tile_scenes.is_empty():
		push_error("No available tile scenes loaded!")
		return null
	
	# For now, just pick a random tile and rotate it to match the entrance
	var random_scene_path = available_tile_scenes[randi() % available_tile_scenes.size()]
	return _create_tile_from_scene(random_scene_path, pos, required_entrance)

func _create_start_tile(pos: Vector2i) -> Node3D:
	"""Create the special start tile"""
	return _create_tile_from_scene(start_tile_scene, pos, -1)  # -1 means no required entrance

func _create_tile_from_scene(scene_path: String, grid_pos: Vector2i, required_entrance: int = -1) -> Node3D:
	"""Create a tile instance from a scene file"""
	var tile_scene: PackedScene = load(scene_path)
	if not tile_scene:
		push_error("Failed to load tile scene: " + scene_path)
		return null
	
	var tile_instance: Node3D = tile_scene.instantiate()
	if not tile_instance:
		push_error("Failed to instantiate tile scene: " + scene_path)
		return null
	
	# Position tile
	tile_instance.position = _grid_to_world(grid_pos)
	
	# Rotate tile to align entrance door if needed
	if required_entrance != -1:
		var rotation_needed = _calculate_tile_rotation(tile_instance, required_entrance)
		tile_instance.rotation.y = deg_to_rad(rotation_needed * 90)
		print("Rotated tile ", rotation_needed * 90, " degrees to align entrance ", _door_to_string(required_entrance))
	
	# Store metadata
	tile_instance.set_meta("scene_path", scene_path)
	tile_instance.set_meta("grid_position", grid_pos)
	tile_instance.set_meta("required_entrance", required_entrance)
	tile_instance.set_meta("rotation", _calculate_tile_rotation(tile_instance, required_entrance) if required_entrance != -1 else 0)
	
	# Add to maze container
	var maze_container = get_tree().current_scene.get_node("MazeContainer")
	if maze_container:
		maze_container.add_child(tile_instance)
	else:
		push_error("MazeContainer not found in current scene!")
		tile_instance.queue_free()
		return null
	
	print("Created tile: ", scene_path.get_file(), " at ", grid_pos)
	return tile_instance

func _calculate_tile_rotation(tile: Node3D, required_entrance_door: int) -> int:
	"""Calculate how many 90-degree rotations needed to align entrance door"""
	# Find which door the tile naturally has that we want to use as entrance
	var available_doors = _get_tile_available_doors(tile)
	
	if available_doors.is_empty():
		print("Warning: Tile has no doors!")
		return 0
	
	# For now, use the first available door as the "natural" entrance
	var natural_entrance = available_doors[0]
	
	# Calculate rotation needed to move natural entrance to required position
	# Door enum: N=0, E=1, S=2, W=3
	var rotation_steps = (required_entrance_door - natural_entrance) % 4
	
	print("Tile natural entrance: ", _door_to_string(natural_entrance), 
		  " -> Required: ", _door_to_string(required_entrance_door), 
		  " -> Rotation: ", rotation_steps * 90, " degrees")
	
	return rotation_steps

func _get_tile_available_doors(tile: Node3D) -> Array[int]:
	"""Get list of doors available in this tile"""
	var doors: Array[int] = []
	
	for door in Door.values():
		if _tile_has_door(tile, door):
			doors.append(door)
	
	return doors

# Old tile library functions removed - now using actual scene files

func _position_player_at_start(start_tile: Node3D):
	"""Position the player at the start marker in the start tile"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Player not found in scene!")
		return
	
	var start_marker = start_tile.get_node_or_null("PlayerStart")
	if start_marker:
		player.global_position = start_marker.global_position
		print("Player positioned at start marker: ", start_marker.global_position)
	else:
		push_warning("PlayerStart marker not found in start tile!")

func _update_tile_connections(from_tile_pos: Vector2i, to_tile_pos: Vector2i, used_direction: Door):
	"""Update tile connections when player moves"""
	# Cull tiles at unused exits of the previous tile
	_cull_unused_exits(from_tile_pos, used_direction)
	
	# Spawn tiles at all exits of the current tile (except the entrance)
	_spawn_exit_tiles(to_tile_pos, _get_opposite_door(used_direction))

func _cull_unused_exits(tile_pos: Vector2i, used_direction: Door):
	"""Remove tiles at exits that weren't used"""
	if not active_tiles.has(tile_pos):
		return
	
	var tile = active_tiles[tile_pos]
	
	# Check all possible directions
	for door in Door.values():
		if door == used_direction:
			continue  # Skip the direction the player used
		
		var exit_pos = tile_pos + DOOR_OFFSET[door]
		
		# If there's a tile at this unused exit, remove it
		if active_tiles.has(exit_pos):
			print("Culling unused exit tile at: ", exit_pos)
			_cull_tile(exit_pos)

func _spawn_exit_tiles(tile_pos: Vector2i, entrance_direction: int):
	"""Spawn tiles at all exits of the current tile (except entrance)"""
	if not active_tiles.has(tile_pos):
		print("No tile found at position: ", tile_pos)
		return
	
	var tile = active_tiles[tile_pos]
	print("Spawning exit tiles for tile at: ", tile_pos, " (skipping entrance: ", _door_to_string(entrance_direction) if entrance_direction != -1 else "none", ")")
	
	# Check all possible directions
	for door in Door.values():
		if door == entrance_direction:
			print("  Skipping door ", _door_to_string(door), " (entrance)")
			continue  # Skip the entrance direction
		
		var exit_pos = tile_pos + DOOR_OFFSET[door]
		var has_door = _tile_has_door(tile, door)
		var tile_exists = active_tiles.has(exit_pos)
		
		print("  Checking door ", _door_to_string(door), ": has_door=", has_door, ", tile_exists=", tile_exists, ", exit_pos=", exit_pos)
		
		# Only spawn if the current tile has this door and no tile exists there yet
		if has_door and not tile_exists:
			var required_entrance = _get_opposite_door(door)
			var new_tile = _spawn_random_tile_with_entrance(exit_pos, required_entrance)
			if new_tile:
				_register_tile(exit_pos, new_tile)
				print("  ✓ Spawned exit tile at: ", exit_pos, " with entrance: ", _door_to_string(required_entrance))
			else:
				print("  ✗ Failed to spawn tile at: ", exit_pos)

func _spawn_tile_content(tile: Node3D, tile_type: TileType, grid_pos: Vector2i):
	"""Spawn appropriate content for this tile based on progression tier"""
	var tier = _get_current_tier()
	var distance_from_start = grid_pos.length()
	
	# Weird Things spawning
	var weird_things_manager = get_node("/root/WeirdThingsManager")
	if weird_things_manager and randf() < _get_weird_thing_spawn_chance(tier):
		weird_things_manager.spawn_weird_thing_in_tile(tile, tier)
	
	# Entity spawning
	_spawn_entities_in_tile(tile, tier, distance_from_start)
	
	# Echo spawning from previous runs
	var harvest_logger = get_node("/root/HarvestLogger")
	if harvest_logger and randf() < 0.3:  # 30% chance
		harvest_logger.try_spawn_echo_in_tile(tile, grid_pos)

func _spawn_entities_in_tile(tile: Node3D, tier: int, distance: float):
	"""Spawn entities appropriate for this tier and distance"""
	match tier:
		1:  # Tier 1: Safe exploration
			pass  # No entities
		2:  # Tier 2: Building tension
			if randf() < 0.1:  # 10% chance for Caretaker
				_spawn_caretaker_in_tile(tile)
		3:  # Tier 3: Active threats
			if randf() < 0.2:  # 20% chance for Overseer Eye
				_spawn_overseer_in_tile(tile)

func _register_tile(pos: Vector2i, tile: Node3D):
	"""Register a tile in the active collection"""
	active_tiles[pos] = tile
	tile_queue.append(pos)
	
	# Link navigation with neighbors
	_create_navigation_links(pos, tile)
	
	emit_signal("tile_spawned", pos, str(tile.get_meta("tile_type")))

func _create_navigation_links(pos: Vector2i, tile: Node3D):
	"""Create navigation links between this tile and its neighbors"""
	for door in Door.values():
		var neighbor_pos = pos + DOOR_OFFSET[door]
		
		if active_tiles.has(neighbor_pos):
			var neighbor_tile = active_tiles[neighbor_pos]
			var opposite_door = _get_opposite_door(door)
			
			# Check if both tiles have the required doors
			if _tile_has_door(tile, door) and _tile_has_door(neighbor_tile, opposite_door):
				_create_nav_link(tile, neighbor_tile, door, opposite_door)

func _create_nav_link(tile_a: Node3D, tile_b: Node3D, door_a: int, door_b: int):
	"""Create a NavigationLink3D between two tiles"""
	var link = _get_pooled_nav_link()
	
	# Get door positions from the tiles directly
	var pos_a = _get_tile_door_position(tile_a, door_a)
	var pos_b = _get_tile_door_position(tile_b, door_b)
	
	if pos_a != Vector3.ZERO and pos_b != Vector3.ZERO:
		link.start_position = pos_a
		link.end_position = pos_b
		link.enabled = true
		
		get_tree().current_scene.add_child(link)
		navigation_links.append(link)
		print("Created nav link between tiles")
	else:
		# Return link to pool if we couldn't create it
		_return_nav_link_to_pool(link)

func _get_tile_door_position(tile: Node3D, door: int) -> Vector3:
	"""Get the world position of a door on a tile"""
	var door_name = _door_to_string(door) + "Door"
	var door_marker = tile.get_node_or_null("Maze/" + door_name)
	
	if door_marker:
		return door_marker.global_position
	else:
		# Fallback: calculate approximate door position
		var tile_pos = tile.global_position
		match door:
			Door.N: return tile_pos + Vector3(0, 0, -10)
			Door.E: return tile_pos + Vector3(10, 0, 0)
			Door.S: return tile_pos + Vector3(0, 0, 10)
			Door.W: return tile_pos + Vector3(-10, 0, 0)
			_: return Vector3.ZERO

func _cull_distant_tiles(center: Vector2i):
	"""Remove tiles that are too far from the center position"""
	var tiles_to_cull = []
	
	for pos in active_tiles.keys():
		var distance = pos.distance_to(center)
		if distance > active_radius:
			tiles_to_cull.append(pos)
	
	for pos in tiles_to_cull:
		_cull_tile(pos)

func _cull_tile(pos: Vector2i):
	"""Remove a tile and clean up its resources"""
	if not active_tiles.has(pos):
		return
	
	var tile = active_tiles[pos]
	
	# Remove navigation links
	_remove_navigation_links_for_tile(tile)
	
	# Return tile to pool or queue_free
	_return_tile_to_pool(tile)
	
	# Remove from tracking
	active_tiles.erase(pos)
	tile_queue.erase(pos)
	
	emit_signal("tile_culled", pos)

func _remove_navigation_links_for_tile(tile: Node3D):
	"""Remove all navigation links connected to this tile"""
	var links_to_remove = []
	
	for link in navigation_links:
		# Check if link is connected to this tile
		if _is_link_connected_to_tile(link, tile):
			links_to_remove.append(link)
	
	for link in links_to_remove:
		navigation_links.erase(link)
		_return_nav_link_to_pool(link)

# Utility functions
func _rotate_mask(mask: int, turns: int) -> int:
	"""Rotate door mask by specified 90-degree turns clockwise"""
	var m = mask
	for i in turns:
		m = ((m << 1) | (m >> 3)) & 0xF  # 4-bit circular shift
	return m

func _get_opposite_door(door: int) -> int:
	"""Get the opposite door direction"""
	return (door + 2) % 4

func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to world position"""
	return Vector3(grid_pos.x * tile_size, 0, grid_pos.y * tile_size)

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convert world position to grid position"""
	return Vector2i(int(world_pos.x / tile_size), int(world_pos.z / tile_size))

func _door_to_string(door: int) -> String:
	"""Convert door enum to string for node names"""
	match door:
		Door.N: return "North"
		Door.E: return "East" 
		Door.S: return "South"
		Door.W: return "West"
		_: return "North"

func _tile_has_door(tile: Node3D, door: int) -> bool:
	"""Check if a tile has a specific door"""
	# First try the tile's own door detection method (works after it's in scene)
	if tile.has_method("has_door") and tile.is_inside_tree():
		var door_direction = _door_to_direction_enum(door)
		return tile.has_door(door_direction)
	else:
		# Fallback: check for door marker nodes directly
		var door_name = _door_to_string(door) + "Door"
		var door_marker = tile.get_node_or_null("Maze/" + door_name)
		return door_marker != null

func _door_to_direction_enum(door: int):
	"""Convert Door enum to tile script's DoorDirection enum"""
	match door:
		Door.N: return 1  # DoorDirection.NORTH
		Door.E: return 2  # DoorDirection.EAST
		Door.S: return 4  # DoorDirection.SOUTH
		Door.W: return 8  # DoorDirection.WEST
		_: return 1

func _get_current_tier() -> int:
	"""Determine current content tier based on tiles traversed"""
	if tiles_traversed <= 4:
		return 1
	elif tiles_traversed <= 10:
		return 2
	else:
		return 3

# Tile weight function removed - using simple random selection now

func _get_weird_thing_spawn_chance(tier: int) -> float:
	"""Get spawn chance for weird things in current tier"""
	match tier:
		1: return 0.1  # 10% in early game
		2: return 0.3  # 30% in mid game
		3: return 0.5  # 50% in late game
		_: return 0.2

# Weighted choice function removed - using simple random selection now

func _update_tension_level():
	"""Update global tension level based on progression"""
	tension_level = min(1.0, float(tiles_traversed) / 20.0)

func _get_pooled_nav_link() -> NavigationLink3D:
	"""Get a navigation link from pool or create new one"""
	if link_pool.size() > 0:
		return link_pool.pop_back()
	else:
		return NavigationLink3D.new()

func _return_nav_link_to_pool(link: NavigationLink3D):
	"""Return navigation link to pool"""
	link.get_parent().remove_child(link)
	link.enabled = false
	link_pool.append(link)

func _return_tile_to_pool(tile: Node3D):
	"""Return tile to pool or free it"""
	tile.get_parent().remove_child(tile)
	# For now, just free it. Later implement pooling for performance
	tile.queue_free()

func _is_link_connected_to_tile(link: NavigationLink3D, tile: Node3D) -> bool:
	"""Check if navigation link is connected to specific tile"""
	# Implementation depends on how you track link connections
	# This is a placeholder
	return false

# Placeholder functions for entity spawning
func _spawn_caretaker_in_tile(tile: Node3D):
	pass

func _spawn_overseer_in_tile(tile: Node3D):
	pass

# Public API
func get_current_player_tile() -> Vector2i:
	return current_player_tile

func get_tiles_traversed() -> int:
	return tiles_traversed

func get_tension_level() -> float:
	return tension_level

func get_active_tile_count() -> int:
	return active_tiles.size()

func is_position_in_active_tile(world_pos: Vector3) -> bool:
	var grid_pos = _world_to_grid(world_pos)
	return active_tiles.has(grid_pos)
