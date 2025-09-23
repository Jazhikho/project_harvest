extends Node

# Minimal TileManager for Project Harvest
# Responsibilities:
# - Track tiles on a 7x7 grid from (-3,-3) to (3,3)
# - Register the existing StartTile (do not spawn it)
# - Assign permanent puzzle tiles to random positions on the grid
# - When player "enters" a tile, spawn tiles at each door position
#   • If the position is reserved for a permanent tile and not solved, spawn that permanent tile
#   • Otherwise spawn a random regular tile
#   • Pick a random door on the spawned tile and rotate it so that it connects to the source door
# - Skip the door that leads back to the previous tile
# - Clean up tiles that are not the current tile and not directly connected to it

# Grid settings
const GRID_MIN_X: int = -3
const GRID_MAX_X: int = 3
const GRID_MIN_Y: int = -3
const GRID_MAX_Y: int = 3

# Scenes
const START_TILE_SCENE: String = "res://scenes/tiles/start_tile.tscn"
const TILES_DIR: String = "res://scenes/tiles/"

# Permanent puzzle tiles (scenes)
const PERMANENT_SCENES: Array[String] = [
	"res://scenes/tiles/the_watching_stones.tscn",
	"res://scenes/tiles/whispering_hollow.tscn",
	"res://scenes/tiles/crows_parliament.tscn",
	"res://scenes/tiles/Final_Gate.tscn"
]

# Door constants, must match scripts/tiles/tile.gd
enum DoorDirection {NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8}

# Runtime state
var _maze_container: Node3D = null
var _active_tiles: Dictionary = {} # Vector2i -> Node3D
var _established_connections: Dictionary = {} # String "x1,y1:x2,y2" -> bool
var _permanent_positions: Dictionary = {} # Vector2i -> String (scene path)
var _solved_permanent: Dictionary = {} # String (scene path) -> bool

var _current_pos: Vector2i = Vector2i(0, 0)
var _previous_pos: Vector2i = Vector2i(9999, 9999)
var _regular_tile_scenes: Array[String] = []

func _ready() -> void:
	# Expect to live under GameControllers
	pass

# Called by GameController after the Game scene is loaded
func initialize_game_tiles() -> void:
	_reset_state()
	_maze_container = _find_maze_container()
	_load_regular_tiles()
	_assign_permanent_positions()
	var start_tile: Node3D = _find_existing_start_tile()
	if start_tile == null:
		push_warning("TileManager (slim): StartTile not found under MazeContainer. Using scene to create one.")
		start_tile = _spawn_specific_tile(START_TILE_SCENE, Vector2i(0, 0))
	if start_tile == null:
		push_error("TileManager (slim): Cannot initialize without a start tile.")
		return
	_register_tile(start_tile, Vector2i(0, 0))
	_current_pos = Vector2i(0, 0)
	_previous_pos = Vector2i(9999, 9999)
	
	# Emit tile_generated signal for the start tile
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus and message_bus.has_method("emit_event"):
		var tile_data = {
			"scene_path": START_TILE_SCENE,
			"is_permanent": false,
			"is_start_tile": true
		}
		message_bus.emit_event("tile_generated", [start_tile, Vector2i(0, 0), tile_data])
		print("TileManager: Emitted tile_generated signal for start tile")
	
	# Treat as if the player just entered the start tile
	on_player_entered_tile(_current_pos)

# External hook used by PlayerPositionTracker when player enters a new tile
func on_player_entered_tile(tile_position: Vector2i) -> void:
	print("TileManager: on_player_entered_tile called for position %s" % tile_position)
	if not _active_tiles.has(tile_position):
		push_error("TileManager (slim): on_player_entered_tile called for unknown tile " + str(tile_position))
		print("TileManager: Available tiles: %s" % _active_tiles.keys())
		return
	_previous_pos = _current_pos
	_current_pos = tile_position
	print("TileManager: Updated current position from %s to %s" % [_previous_pos, _current_pos])
	_cleanup_around(_current_pos)
	var src_tile: Node3D = _active_tiles[_current_pos]
	print("TileManager: Source tile found: %s" % src_tile.name if src_tile else "null")
	_spawn_connections_from(src_tile, _current_pos)
	
	# Emit tile_entered signal for other systems
	var message_bus = get_node_or_null("/root/MessageBus")
	var player = get_tree().get_first_node_in_group("player")
	if message_bus and message_bus.has_method("emit_event") and player:
		message_bus.emit_event("tile_entered", [src_tile, tile_position, player])
		print("TileManager: Emitted tile_entered signal for tile %s" % tile_position)

# Mark puzzle at position as solved so it stops spawning
func mark_permanent_solved_at(pos: Vector2i) -> void:
	if _permanent_positions.has(pos):
		var scene_path: String = _permanent_positions[pos]
		_solved_permanent[scene_path] = true

# Mark puzzle by scene path as solved
func mark_permanent_puzzle_solved(scene_path: String) -> void:
	_solved_permanent[scene_path] = true

# === Internals ===

func _reset_state() -> void:
	_active_tiles.clear()
	_established_connections.clear()
	_permanent_positions.clear()
	_solved_permanent.clear()
	_current_pos = Vector2i(0, 0)
	_previous_pos = Vector2i(9999, 9999)
	_regular_tile_scenes.clear()

func _find_maze_container() -> Node3D:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var n: Node = scene_root.get_node_or_null("MazeContainer")
	if n == null:
		return null
	return n as Node3D

func _find_existing_start_tile() -> Node3D:
	if _maze_container == null:
		return null
	for child in _maze_container.get_children():
		if child is Node3D:
			var node3d: Node3D = child
			# Prefer an instance of the StartTile scene
			if node3d.scene_file_path == START_TILE_SCENE:
				return node3d
			# Fallback: check for a script that looks like a tile
			if node3d.has_method("get_available_doors"):
				return node3d
	return null

func _load_regular_tiles() -> void:
	_regular_tile_scenes.clear()
	var d: DirAccess = DirAccess.open(TILES_DIR)
	if d == null:
		push_error("TileManager (slim): tiles directory missing: " + TILES_DIR)
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var is_tscn: bool = name.ends_with(".tscn")
		if is_tscn:
			var full: String = TILES_DIR + name
			var is_start: bool = full == START_TILE_SCENE
			var is_perm: bool = PERMANENT_SCENES.has(full)
			if not is_start and not is_perm:
				_regular_tile_scenes.append(full)
		name = d.get_next()
	d.list_dir_end()

func _assign_permanent_positions() -> void:
	# Random unique positions within bounds, excluding central area (1,1) to (-1,-1)
	var available: Array[Vector2i] = []
	var y: int = GRID_MIN_Y
	while y <= GRID_MAX_Y:
		var x: int = GRID_MIN_X
		while x <= GRID_MAX_X:
			var v: Vector2i = Vector2i(x, y)
			# Exclude central area: (1,1), (1,0), (1,-1), (0,1), (0,0), (0,-1), (-1,1), (-1,0), (-1,-1)
			var is_central_area: bool = (v.x >= -1 and v.x <= 1) and (v.y >= -1 and v.y <= 1)
			if not is_central_area:
				available.append(v)
			x += 1
		y += 1
	available.shuffle()
	var i: int = 0
	while i < PERMANENT_SCENES.size() and i < available.size():
		_permanent_positions[available[i]] = PERMANENT_SCENES[i]
		print("TileManager: Assigned permanent tile %s to position %s" % [PERMANENT_SCENES[i], available[i]])
		i += 1

func _register_tile(tile: Node3D, pos: Vector2i) -> void:
	_active_tiles[pos] = tile
	tile.set_meta("grid_position", pos)
	tile.set_meta("world_map_pos", pos)

func _connection_key(a: Vector2i, b: Vector2i) -> String:
	return str(a.x) + "," + str(a.y) + ":" + str(b.x) + "," + str(b.y)

func _is_connection_established(a: Vector2i, b: Vector2i) -> bool:
	var k1: String = _connection_key(a, b)
	var k2: String = _connection_key(b, a)
	if _established_connections.has(k1):
		return true
	if _established_connections.has(k2):
		return true
	return false

func _mark_connection(a: Vector2i, b: Vector2i) -> void:
	var k: String = _connection_key(a, b)
	_established_connections[k] = true

func _spawn_connections_from(src_tile: Node3D, src_pos: Vector2i) -> void:
	if src_tile == null:
		print("TileManager: _spawn_connections_from called with null src_tile")
		return
	if not src_tile.has_method("get_available_doors"):
		print("TileManager: src_tile does not have get_available_doors method")
		return
	var doors: Dictionary = src_tile.get_available_doors()
	print("TileManager: Spawning connections from tile at %s, found %d doors" % [src_pos, doors.size()])
	for dir_key in doors.keys():
		var dir: int = int(dir_key)
		# Skip door that goes back to previous tile
		var back_pos: Vector2i = src_tile.get_connecting_position(src_pos, dir)
		back_pos = src_tile.apply_world_wrapping(back_pos)
		print("TileManager: Checking door direction %d, target position %s" % [dir, back_pos])
		if back_pos == _previous_pos:
			print("TileManager: Skipping door %d (goes back to previous tile %s)" % [dir, _previous_pos])
			continue
		# If already connected, skip
		if _is_connection_established(src_pos, back_pos):
			print("TileManager: Skipping door %d (connection already established)" % dir)
			continue
		# If tile already exists there, mark connection and skip
		if _active_tiles.has(back_pos):
			print("TileManager: Skipping door %d (tile already exists at %s)" % [dir, back_pos])
			_mark_connection(src_pos, back_pos)
			continue
		# Decide what to spawn
		var scene_path: String = ""
		if _permanent_positions.has(back_pos):
			var perm_scene: String = _permanent_positions[back_pos]
			var solved: bool = _solved_permanent.get(perm_scene, false)
			if not solved:
				scene_path = perm_scene
				print("TileManager: Spawning permanent tile %s at %s" % [perm_scene, back_pos])
		if scene_path == "":
			# Use a random regular tile
			if _regular_tile_scenes.size() == 0:
				print("TileManager: No regular tile scenes available")
				continue
			var idx: int = randi() % _regular_tile_scenes.size()
			scene_path = _regular_tile_scenes[idx]
			print("TileManager: Spawning regular tile %s at %s" % [scene_path, back_pos])
		# Spawn tile
		var new_tile: Node3D = _spawn_specific_tile(scene_path, back_pos)
		if new_tile == null:
			print("TileManager: Failed to spawn tile at %s" % back_pos)
			continue
		# Align to connect: pick random door on the target and rotate to match
		if new_tile.has_method("align_tile_to_connect"):
			new_tile.align_tile_to_connect(src_tile, new_tile, dir)
		_register_tile(new_tile, back_pos)
		_mark_connection(src_pos, back_pos)
		print("TileManager: Successfully spawned and registered tile at %s" % back_pos)
		
		# Emit tile_generated signal for spawning systems
		var message_bus = get_node_or_null("/root/MessageBus")
		if message_bus and message_bus.has_method("emit_event"):
			var tile_data = {
				"scene_path": scene_path,
				"is_permanent": _permanent_positions.has(back_pos),
				"connection_direction": dir
			}
			message_bus.emit_event("tile_generated", [new_tile, back_pos, tile_data])
			print("TileManager: Emitted tile_generated signal for tile %s" % back_pos)

func _spawn_specific_tile(scene_path: String, grid_pos: Vector2i) -> Node3D:
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		push_error("TileManager (slim): failed to load " + scene_path)
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		push_error("TileManager (slim): failed to instantiate " + scene_path)
		return null
	if _maze_container == null:
		push_error("TileManager (slim): MazeContainer not found; cannot add tiles.")
		return null
	_maze_container.add_child(inst)
	# Let the tile place itself relative to source tile via align function later
	inst.set_meta("grid_position", grid_pos)
	inst.name = "Tile_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	return inst

func _cleanup_around(center: Vector2i) -> void:
	# Keep current tile and tiles directly connected to it
	var keep: Array[Vector2i] = []
	keep.append(center)
	if _active_tiles.has(center):
		var t: Node3D = _active_tiles[center]
		var dirs: Array[int] = [DoorDirection.NORTH, DoorDirection.EAST, DoorDirection.SOUTH, DoorDirection.WEST]
		for d in dirs:
			var pos: Vector2i = t.get_connecting_position(center, d)
			pos = t.apply_world_wrapping(pos)
			if _active_tiles.has(pos):
				keep.append(pos)
	# Remove everything else that is not a permanent puzzle tile at its reserved position
	var to_remove: Array[Vector2i] = []
	for k in _active_tiles.keys():
		var p: Vector2i = k
		var should_keep: bool = false
		var i: int = 0
		while i < keep.size():
			if keep[i] == p:
				should_keep = true
				break
			i += 1
		if not should_keep:
			if _permanent_positions.has(p):
				# If it's a permanent position but the tile there is not solved, keep it
				var perm_scene_path: String = _permanent_positions[p]
				var solved: bool = _solved_permanent.get(perm_scene_path, false)
				if not solved:
					should_keep = true
		if not should_keep:
			to_remove.append(p)
	for rp in to_remove:
		var node: Node3D = _active_tiles[rp]
		_active_tiles.erase(rp)
		if is_instance_valid(node):
			node.queue_free()
	# Also prune established connection keys that reference removed tiles
	var keys: Array = _established_connections.keys()
	for key in keys:
		var parts: Array = key.split(":")
		if parts.size() != 2:
			continue
		var a_str: String = parts[0]
		var b_str: String = parts[1]
		var a_parts: Array = a_str.split(",")
		var b_parts: Array = b_str.split(",")
		if a_parts.size() != 2 or b_parts.size() != 2:
			continue
		var ax: int = int(a_parts[0])
		var ay: int = int(a_parts[1])
		var bx: int = int(b_parts[0])
		var by: int = int(b_parts[1])
		var a_pos: Vector2i = Vector2i(ax, ay)
		var b_pos: Vector2i = Vector2i(bx, by)
		var a_exists: bool = _active_tiles.has(a_pos)
		var b_exists: bool = _active_tiles.has(b_pos)
		if not a_exists or not b_exists:
			_established_connections.erase(key)
