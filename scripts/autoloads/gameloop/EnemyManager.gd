extends BaseManager
## Enemy Manager - Centralized management of enemy entities
## Handles enemy spawning, behavior coordination, and lifecycle

var _sanity_manager: Node

# Enemy tracking
var _active_enemies: Dictionary = {} # entity_id -> entity_node
var _enemy_spawn_cooldowns: Dictionary = {} # enemy_type -> cooldown_time
var _next_enemy_id: int = 0

@export var spawn_catalog: SpawnCatalog = preload("res://data/SpawnCatalog.tres")

# NEW: Map enemy_type to PackedScene
var _enemy_scene_map: Dictionary = {} # enemy_type -> PackedScene

# Enemy scene references
var _enemy_scenes: Dictionary = {
	"effigy": "res://scenes/entities/effigy.tscn"
}

func _ready() -> void:
	name = "EnemyManager"
	_resolve_catalog()
	add_to_group("game_systems")
	require_systems(["MessageBus", "GameStateManager"])
	super._ready()

func _initialize_manager() -> void:
	"""Initialize connections to core systems"""
	_sanity_manager = get_system_node("SanityManager")
	_build_enemy_scene_map() # NEW: Build the scene map
	_connect_to_events()
	
func _resolve_catalog() -> void:
	if spawn_catalog == null:
		push_error("EnemyManager: spawn_catalog is null. Assign SpawnCatalog.tres in Inspector.")
		return
	if spawn_catalog.enemy_scenes.is_empty():
		push_warning("EnemyManager: catalog has zero enemy scenes.")

# NEW: Build a map of enemy_type -> PackedScene
func _build_enemy_scene_map() -> void:
	"""Build a mapping of enemy types to their PackedScenes for efficient spawning"""
	_enemy_scene_map.clear()
	
	if not spawn_catalog or spawn_catalog.enemy_scenes.is_empty():
		push_warning("EnemyManager: No enemy scenes in catalog")
		return
	
	for entry in spawn_catalog.get_enemy_catalog_entries():
		var enemy_type: String = entry.id
		var scene: PackedScene = entry.scene
		if scene != null and not enemy_type.is_empty():
			_enemy_scene_map[enemy_type] = scene

func get_all_enemy_scenes() -> Array[PackedScene]:
	if not spawn_catalog:
		return []
	return spawn_catalog.enemy_scenes.duplicate()

func _process(delta: float) -> void:
	"""Update enemy spawn cooldowns"""
	for enemy_type in _enemy_spawn_cooldowns.keys():
		_enemy_spawn_cooldowns[enemy_type] = max(0.0, _enemy_spawn_cooldowns[enemy_type] - delta)

func spawn_enemy(enemy_type: String, position: Vector3 = Vector3.ZERO, force_spawn: bool = false) -> Node3D:
	"""
	Spawn an enemy at the specified position
	
	@param enemy_type: Type of enemy to spawn (effigy)
	@param position: World position to spawn at (Vector3.ZERO for auto-placement)
	@param force_spawn: Ignore cooldowns and limits
	@return: Spawned enemy node or null if failed
	"""
	if not _can_spawn_enemy(enemy_type) and not force_spawn:
		return null
	
	var enemy_scene: PackedScene = _enemy_scene_map.get(enemy_type, null)
	if not enemy_scene and _enemy_scenes.has(enemy_type):
		var scene_path = _enemy_scenes[enemy_type]
		if FileAccess.file_exists(scene_path):
			enemy_scene = load(scene_path) as PackedScene

	if not enemy_scene:
		push_warning("EnemyManager: No scene found for enemy_type: ", enemy_type)
		return null
	
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		push_error("EnemyManager: Failed to instantiate enemy: %s" % enemy_type)
		return null
	
	# Add to scene
	get_tree().current_scene.add_child(enemy_instance)
	
	# Set position
	if position == Vector3.ZERO:
		position = _find_spawn_position(enemy_type)
	enemy_instance.global_position = position
	
	# Ensure proper orientation for effigies - face positive Z direction
	if enemy_type == "effigy":
		enemy_instance.rotation.y = 0.0
	
	# Register enemy
	var entity_id = _generate_enemy_id(enemy_type)
	_active_enemies[entity_id] = enemy_instance
	enemy_instance.set_meta("entity_id", entity_id)
	enemy_instance.set_meta("enemy_type", enemy_type)
	
	# Set cooldown
	_enemy_spawn_cooldowns[enemy_type] = _get_spawn_cooldown(enemy_type)
	
	# Emit spawn event
	emit_event("entity_spawned", [enemy_type, enemy_instance, position])
	
	return enemy_instance

func despawn_enemy(entity_id: String) -> bool:
	"""
	Remove an enemy from the game
	
	@param entity_id: ID of enemy to remove
	@return: True if enemy was removed
	"""
	if not _active_enemies.has(entity_id):
		return false
	
	var enemy = _active_enemies[entity_id]
	
	# Check if enemy is valid before trying to get metadata
	if not is_instance_valid(enemy):
		_active_enemies.erase(entity_id)
		return false
	
	var enemy_type = enemy.get_meta("enemy_type", "unknown")
	
	_active_enemies.erase(entity_id)
	enemy.queue_free()
	
	return true

func get_enemies_in_range(position: Vector3, radius: float) -> Array[Node3D]:
	"""
	Get all enemies within a certain range of a position
	
	@param position: Center position
	@param radius: Search radius
	@return: Array of enemy nodes within range
	"""
	var enemies_in_range: Array[Node3D] = []
	
	for enemy in _active_enemies.values():
		if is_instance_valid(enemy):
			var distance = enemy.global_position.distance_to(position)
			if distance <= radius:
				enemies_in_range.append(enemy)
	
	return enemies_in_range

func get_enemies_by_type(enemy_type: String) -> Array[Node3D]:
	"""
	Get all active enemies of a specific type
	
	@param enemy_type: Type of enemy to find
	@return: Array of enemy nodes of that type
	"""
	var enemies: Array[Node3D] = []
	
	for enemy in _active_enemies.values():
		if is_instance_valid(enemy) and enemy.get_meta("enemy_type", "") == enemy_type:
			enemies.append(enemy)
	
	return enemies

func set_enemy_aggression_level(level: float) -> void:
	"""
	Set global aggression level for all enemies
	
	@param level: Aggression level (0.0 to 1.0)
	"""
	level = clampf(level, 0.0, 1.0)
	
	for enemy in _active_enemies.values():
		if is_instance_valid(enemy) and enemy.has_method("set_aggression_level"):
			enemy.set_aggression_level(level)

func cleanup_invalid_enemies() -> void:
	"""Remove invalid enemy references"""
	var invalid_ids: Array[String] = []
	
	for entity_id in _active_enemies.keys():
		var enemy = _active_enemies[entity_id]
		if not is_instance_valid(enemy):
			invalid_ids.append(entity_id)
	
	for entity_id in invalid_ids:
		_active_enemies.erase(entity_id)

func _can_spawn_enemy(enemy_type: String) -> bool:
	"""
	Check if an enemy type can be spawned based on conditions
	
	@param enemy_type: Type of enemy to check
	@return: True if enemy can be spawned
	"""
	# Check cooldown
	if _enemy_spawn_cooldowns.get(enemy_type, 0.0) > 0.0:
		return false
	
	if enemy_type == "effigy":
		return true
	return false

func _find_spawn_position(enemy_type: String) -> Vector3:
	"""
	Find appropriate spawn position for enemy type
	
	@param enemy_type: Type of enemy
	@return: Spawn position
	"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return Vector3.ZERO
	
	var player_pos = player.global_position
	
	return player_pos + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))

func _get_spawn_cooldown(enemy_type: String) -> float:
	"""Get spawn cooldown for enemy type"""
	return 5.0

func _generate_enemy_id(enemy_type: String) -> String:
	"""Generate unique enemy ID"""
	_next_enemy_id += 1
	return "%s_%d" % [enemy_type, _next_enemy_id]

# Event handlers

func _connect_to_events() -> void:
	"""Connect to MessageBus events (game_started/game_ended from BaseManager)"""
	_message_bus.player_died.connect(_on_player_died)

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	"""Handle player death - despawn all enemies"""
	var enemy_ids = _active_enemies.keys()
	for entity_id in enemy_ids:
		despawn_enemy(entity_id)

func _on_game_started() -> void:
	"""Handle game start - clear all enemies"""
	var enemy_ids = _active_enemies.keys()
	for entity_id in enemy_ids:
		despawn_enemy(entity_id)
	_enemy_spawn_cooldowns.clear()
	_next_enemy_id = 0

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end - cleanup all enemies"""
	_on_game_started() # Same cleanup

# Debug functions

func get_enemy_count() -> int:
	"""Get total number of active enemies"""
	cleanup_invalid_enemies()
	return _active_enemies.size()

func get_enemy_count_by_type(enemy_type: String) -> int:
	"""Get number of active enemies of specific type"""
	return get_enemies_by_type(enemy_type).size()

static func spawn_aggressive_effigies(count: int, puzzle_node: Node) -> Array:
	"""
	Spawn aggressive effigies at entity points and return array of spawned effigies
	
	@param count: Number of effigies to spawn
	@param puzzle_node: The puzzle node calling this (used to find the tile)
	@return: Array of spawned effigy nodes
	"""
	var spawned_effigies: Array = []
	
	if count <= 0:
		return spawned_effigies
	
	# Get EnemyManager instance
	var enemy_manager: Node = puzzle_node.get_node_or_null("/root/EnemyManager")
	if not enemy_manager:
		push_error("EnemyManager not found")
		return spawned_effigies
	
	# Find the tile by walking up from the puzzle node
	var current_tile: Node3D = _find_tile_from_puzzle(puzzle_node)
	if not current_tile:
		push_error("Current tile not found from puzzle node")
		return spawned_effigies
	
	# Try to find Maze/Objects, then fallback to just Objects
	var maze_objects: Node3D = current_tile.get_node_or_null("Maze/Objects")
	if not maze_objects:
		maze_objects = current_tile.get_node_or_null("Objects")
	
	var spawn_positions: Array[Vector3] = []
	var player: Node3D = puzzle_node.get_tree().get_first_node_in_group("player")
	
	# If we have maze_objects with EntityPoints, use those
	if maze_objects:
		for i in range(min(count, 3)):
			var spawn_point_name: String = "EntityPoint%d" % (i + 1)
			var spawn_point: Node3D = maze_objects.get_node_or_null(spawn_point_name)
			if spawn_point:
				spawn_positions.append(spawn_point.global_position)
	
	# If we didn't find any spawn points, create positions near player
	if spawn_positions.is_empty():
		if player:
			var player_pos: Vector3 = player.global_position
			for i in range(min(count, 3)):
				var angle: float = (i * TAU / 3.0) + randf_range(-0.3, 0.3)
				var distance: float = randf_range(8.0, 12.0)
				var offset: Vector3 = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
				spawn_positions.append(player_pos + offset)
		else:
			push_error("Cannot spawn effigies: no spawn points and no player found")
			return spawned_effigies
	
	# Spawn effigies using normal spawn_enemy method, then set aggression
	for spawn_pos in spawn_positions:
		# Use standard spawn_enemy which handles all registration and setup
		var effigy: Node3D = enemy_manager.spawn_enemy("effigy", spawn_pos, true)
		
		if effigy:
			effigy.set_meta("aggression_locked", true)
			effigy.set_meta("aggression_lock_reason", "puzzle_completion")
			effigy.set_meta("is_puzzle_effigy", true)

			# Calculate direction to player for initial facing
			if player:
				var dir: Vector3 = (player.global_position - effigy.global_position).normalized()
				var target_yaw: float = atan2(dir.x, dir.z)
				effigy.rotation.y = target_yaw
			
			if effigy.has_method("configure_aggression_lock"):
				effigy.configure_aggression_lock(true, &"puzzle_completion")
			else:
				effigy.call_deferred("set_aggression_mode", true, &"puzzle_completion")
			
			spawned_effigies.append(effigy)
		else:
			push_warning("Failed to spawn aggressive effigy at position: ", spawn_pos)
	
	return spawned_effigies

static func _find_tile_from_puzzle(puzzle_node: Node) -> Node3D:
	"""
	Find the tile node by walking up the scene tree from the puzzle
	
	@param puzzle_node: The puzzle node to start from
	@return: The tile node or null if not found
	"""
	var current: Node = puzzle_node
	
	# Walk up the tree until we find a node with the tile script or is_permanent property
	while current:
		# Check if this node has the tile script
		if current.get_script():
			var script_path: String = current.get_script().resource_path
			if script_path.ends_with("Tile.gd"):
				return current as Node3D
		
		# Check if this node has is_permanent (tiles have this)
		if "is_permanent" in current:
			return current as Node3D
		
		# Check if this looks like a tile by name
		var node_name: String = current.name
		if node_name.contains("Tile") or node_name.contains("Hollow") or node_name.contains("Parliament") or node_name.contains("Stones") or node_name.contains("Gate"):
			# Verify it has a Maze child (tiles should have this)
			if current.has_node("Maze"):
				return current as Node3D
		
		current = current.get_parent()
	
	return null

static func _find_current_tile(scene_root: Node) -> Node3D:
	"""
	Find the current tile that the player is on
	
	@param scene_root: Root scene node
	@return: Current tile node or null if not found
	"""
	# Get TileStateManager to find current player tile
	var tile_state_manager = scene_root.get_node_or_null("/root/TileStateManager")
	if not tile_state_manager:
		push_error("TileStateManager not found")
		return null
	
	# Get current player tile position
	var current_tile_pos: Vector2i = tile_state_manager.get_current_player_tile()
	
	# Get the tile node from TileStateManager
	return tile_state_manager.get_tile_node(current_tile_pos)
