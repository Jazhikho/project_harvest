extends Node
## Maze Manager - Handles algorithmic maze generation patterns
## Provides maze generation utilities for TileManager

var _message_bus: Node
var _maze_data: Dictionary = {}

# Maze generation parameters
var _grid_width: int = 100
var _grid_height: int = 100
var _generation_seed: int = 0

func _ready() -> void:
	name = "MazeManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections"""
	_message_bus = get_node_or_null("/root/MessageBus")
	
	if not _message_bus:
		push_error("MazeManager: MessageBus not found")
		return
	
	_connect_to_events()

func generate_maze_pattern(size: Vector2i, seed_value: int = -1) -> Dictionary:
	"""
	Generate maze pattern data for tile placement
	
	@param size: Maze grid size
	@param seed_value: Random seed (-1 for random)
	@return: Maze pattern dictionary
	"""
	if seed_value == -1:
		seed_value = randi()
	
	_generation_seed = seed_value
	_grid_width = size.x
	_grid_height = size.y
	
	var pattern: Dictionary = {
		"size": size,
		"seed": seed_value,
		"connections": _generate_connection_map(),
		"special_areas": _generate_special_areas(),
		"distortion_zones": _generate_distortion_zones()
	}
	
	_maze_data = pattern
	_message_bus.emit_event("maze_generated", [size, seed_value])
	
	return pattern

func _generate_connection_map() -> Dictionary:
	"""
	Generate basic connection patterns between tiles
	
	@return: Dictionary of position -> allowed_connections
	"""
	var connections: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _generation_seed
	
	# Simple connection generation - each tile can connect in 1-4 directions
	for y in range(_grid_height):
		for x in range(_grid_width):
			var pos: Vector2i = Vector2i(x, y)
			var allowed_dirs: Array[int] = []
			
			# Randomly allow connections
			if rng.randf() < 0.7:  # 70% chance for each direction
				allowed_dirs.append(1)  # North
			if rng.randf() < 0.7:
				allowed_dirs.append(2)  # East
			if rng.randf() < 0.7:
				allowed_dirs.append(4)  # South
			if rng.randf() < 0.7:
				allowed_dirs.append(8)  # West
			
			# Ensure at least one connection
			if allowed_dirs.is_empty():
				allowed_dirs.append([1, 2, 4, 8][rng.randi() % 4])
			
			connections[pos] = allowed_dirs
	
	return connections

func _generate_special_areas() -> Array[Dictionary]:
	"""
	Generate special area data
	
	@return: Array of special area definitions
	"""
	var areas: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _generation_seed + 1
	
	# Generate 3-5 special areas
	var area_count: int = rng.randi_range(3, 5)
	
	for i in range(area_count):
		var center: Vector2i = Vector2i(
			rng.randi_range(10, _grid_width - 10),
			rng.randi_range(10, _grid_height - 10)
		)
		
		var area: Dictionary = {
			"center": center,
			"radius": rng.randi_range(3, 7),
			"type": ["puzzle", "safe", "danger", "weird"][rng.randi() % 4]
		}
		
		areas.append(area)
	
	return areas

func _generate_distortion_zones() -> Array[Dictionary]:
	"""
	Generate distortion zone data
	
	@return: Array of distortion zone definitions
	"""
	var zones: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _generation_seed + 2
	
	# Generate 2-4 distortion zones
	var zone_count: int = rng.randi_range(2, 4)
	
	for i in range(zone_count):
		var center: Vector2i = Vector2i(
			rng.randi_range(15, _grid_width - 15),
			rng.randi_range(15, _grid_height - 15)
		)
		
		var zone: Dictionary = {
			"center": center,
			"radius": rng.randi_range(5, 10),
			"intensity": rng.randf_range(0.3, 1.0),
			"effects": ["reality_bend", "time_skip", "echo_spawn"][rng.randi() % 3]
		}
		
		zones.append(zone)
	
	return zones

func shift_maze_section(center: Vector2i, radius: int) -> Dictionary:
	"""
	Generate shift pattern for maze section
	
	@param center: Center of shift
	@param radius: Shift radius
	@return: Shift data dictionary
	"""
	var shift_data: Dictionary = {
		"center": center,
		"radius": radius,
		"affected_positions": [],
		"new_connections": {}
	}
	
	# Calculate affected positions
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var pos: Vector2i = Vector2i(x, y)
			var distance: float = center.distance_to(pos)
			
			if distance <= radius:
				shift_data.affected_positions.append(pos)
	
	# Generate new connection patterns for affected area
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_system()
	
	for pos in shift_data.affected_positions:
		var new_connections: Array[int] = []
		
		# Randomly reassign connections
		for dir in [1, 2, 4, 8]:
			if rng.randf() < 0.6:
				new_connections.append(dir)
		
		if new_connections.is_empty():
			new_connections.append([1, 2, 4, 8][rng.randi() % 4])
		
		shift_data.new_connections[pos] = new_connections
	
	return shift_data

func get_allowed_connections(position: Vector2i) -> Array[int]:
	"""
	Get allowed connections for a position
	
	@param position: Grid position to check
	@return: Array of allowed direction flags
	"""
	if not _maze_data.has("connections"):
		return [1, 2, 4, 8]  # Allow all directions by default
	
	var connections: Dictionary = _maze_data.connections
	return connections.get(position, [1, 2, 4, 8])

func is_in_special_area(position: Vector2i) -> Dictionary:
	"""
	Check if position is in a special area
	
	@param position: Grid position to check
	@return: Special area data or empty dictionary
	"""
	if not _maze_data.has("special_areas"):
		return {}
	
	for area in _maze_data.special_areas:
		var center: Vector2i = area.center
		var radius: int = area.radius
		
		if center.distance_to(position) <= radius:
			return area
	
	return {}

func is_in_distortion_zone(position: Vector2i) -> Dictionary:
	"""
	Check if position is in a distortion zone
	
	@param position: Grid position to check
	@return: Distortion zone data or empty dictionary
	"""
	if not _maze_data.has("distortion_zones"):
		return {}
	
	for zone in _maze_data.distortion_zones:
		var center: Vector2i = zone.center
		var radius: int = zone.radius
		
		if center.distance_to(position) <= radius:
			return zone
	
	return {}

func get_maze_data() -> Dictionary:
	"""Get current maze data"""
	return _maze_data.duplicate()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.maze_shift_triggered.connect(_on_maze_shift_triggered)
	_message_bus.game_started.connect(_on_game_started)

func _on_maze_shift_triggered(center: Vector2i, radius: int, affected_tiles: Array) -> void:
	"""Handle maze shift events"""
	var shift_data: Dictionary = shift_maze_section(center, radius)
	print("MazeManager: Generated shift pattern for ", shift_data.affected_positions.size(), " positions")

func _on_game_started() -> void:
	"""Handle game start"""
	generate_maze_pattern(Vector2i(100, 100))
