extends Node
## Enemy Manager - Centralized management of enemy entities
## Handles enemy spawning, tracking, and lifecycle (behavior handled by individual enemies)

var _message_bus: Node
var _state_manager: Node
# Removed: _sanity_manager - No longer needed since behavior control moved to individual enemies

# Enemy tracking
var _active_enemies: Dictionary = {} # entity_id -> entity_node
var _enemy_spawn_cooldowns: Dictionary = {} # enemy_type -> cooldown_time
var _next_enemy_id: int = 0

# Enemy scene references
var _enemy_scenes: Dictionary = {
	# "stalker": "res://scenes/entities/stalker.tscn",  # STALKER REMOVED
	# "watcher": "res://scenes/entities/watcher.tscn",
	"effigy": "res://scenes/entities/effigy.tscn"
}

func _ready() -> void:
	name = "EnemyManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus or not _state_manager:
		push_error("EnemyManager: Required core systems not found")
		return
	
	_connect_to_events()

func _process(delta: float) -> void:
	"""Update enemy spawn cooldowns"""
	for enemy_type in _enemy_spawn_cooldowns.keys():
		_enemy_spawn_cooldowns[enemy_type] = max(0.0, _enemy_spawn_cooldowns[enemy_type] - delta)

func spawn_enemy(enemy_type: String, position: Vector3 = Vector3.ZERO, force_spawn: bool = false) -> Node3D:
	"""
	Spawn an enemy at the specified position
	
	@param enemy_type: Type of enemy to spawn (stalker, watcher, effigy)
	@param position: World position to spawn at (Vector3.ZERO for auto-placement)
	@param force_spawn: Ignore cooldowns and limits
	@return: Spawned enemy node or null if failed
	"""
	if not _can_spawn_enemy(enemy_type) and not force_spawn:
		return null
	
	if not _enemy_scenes.has(enemy_type):
		push_error("EnemyManager: Unknown enemy type '%s'" % enemy_type)
		return null
	
	var scene_path = _enemy_scenes[enemy_type]
	
	if not FileAccess.file_exists(scene_path):
		push_error("EnemyManager: Enemy scene not found: %s" % scene_path)
		return null
	
	var enemy_scene = load(scene_path) as PackedScene
	if not enemy_scene:
		push_error("EnemyManager: Failed to load enemy scene: %s" % scene_path)
		return null
	
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		push_error("EnemyManager: Failed to instantiate enemy: %s" % enemy_type)
		return null
	
	# Add to scene
	get_tree().current_scene.add_child(enemy_instance)
	
	enemy_instance.global_position = position
	
	# Register enemy
	var entity_id = _generate_enemy_id(enemy_type)
	_active_enemies[entity_id] = enemy_instance
	enemy_instance.set_meta("entity_id", entity_id)
	enemy_instance.set_meta("enemy_type", enemy_type)
	
	# Set cooldown
	# _enemy_spawn_cooldowns[enemy_type] = _get_spawn_cooldown(enemy_type)
	
	# Emit spawn event
	_message_bus.emit_event("entity_spawned", [enemy_type, enemy_instance, position])
	
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
	var enemy_type = enemy.get_meta("enemy_type", "unknown")
	
	_active_enemies.erase(entity_id)
	
	if is_instance_valid(enemy):
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

# Removed: set_enemy_aggression_level() - Behavior control moved to individual enemies

func cleanup_invalid_enemies() -> void:
	"""Remove invalid enemy references"""
	var invalid_ids: Array[String] = []
	
	for entity_id in _active_enemies.keys():
		var enemy = _active_enemies[entity_id]
		if not is_instance_valid(enemy):
			invalid_ids.append(entity_id)
	
	for entity_id in invalid_ids:
		_active_enemies.erase(entity_id)
		pass

func _can_spawn_enemy(enemy_type: String) -> bool:
	"""
	Check if an enemy type can be spawned based on conditions
	
	@param enemy_type: Type of enemy to check
	@return: True if enemy can be spawned
	"""
	# Check cooldown
	if _enemy_spawn_cooldowns.get(enemy_type, 0.0) > 0.0:
		return false
	
	# Check type-specific conditions
	match enemy_type:
		# "stalker":  # STALKER REMOVED
		# 	return _can_spawn_stalker()
		# "watcher":
			# return _can_spawn_watcher()
		"effigy":
			return true # Effigies can always spawn
		_:
			return true

func _get_spawn_cooldown(enemy_type: String) -> float:
	"""Get spawn cooldown for enemy type"""
	match enemy_type:
		#"stalker":
			#return _stalker_spawn_conditions.cooldown
		#"watcher":
			#return _watcher_spawn_conditions.cooldown
		_:
			return 5.0

func _generate_enemy_id(enemy_type: String) -> String:
	"""Generate unique enemy ID"""
	_next_enemy_id += 1
	return "%s_%d" % [enemy_type, _next_enemy_id]

# Event handlers

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	# Removed behavior control events - handled by individual enemies
	_message_bus.player_died.connect(_on_player_died)
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.game_ended.connect(_on_game_ended)

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

# === ENTITY SPAWN LOGIC FUNCTIONS ===
# Moved from SpawnManager for better organization

func calculate_entity_spawn_chance(current_sanity: int, tiles_explored: int, weird_things_collected: int) -> float:
	"""
	Calculate entity spawn chance - simplified sliding scale
	Moved from SpawnManager for better organization
	
	@param current_sanity: Current player sanity (0-100)
	@param tiles_explored: Number of tiles explored
	@param weird_things_collected: Number of weird things collected
	@return: Final spawn chance as decimal (0.0 to 1.0)
	"""
	# Base 10% chance
	var base_chance: float = 0.10
	
	# Sanity modifier: 0% at 100 sanity, +20% at 0 sanity
	var sanity_modifier: float = (100 - current_sanity) * 0.002 # 0.2 at 0 sanity
	
	# Exploration modifier: Start adding after 5 tiles, +1% per tile
	var exploration_modifier: float = max(0.0, (tiles_explored - 5) * 0.01)
	
	# Collection modifier: +2% per weird thing collected
	var collection_modifier: float = weird_things_collected * 0.02
	
	# Calculate final chance
	var final_chance: float = base_chance + sanity_modifier + exploration_modifier + collection_modifier
	
	# Clamp between 10% and 60%
	final_chance = clampf(final_chance, 0.10, 0.60)
	
	return final_chance

func spawn_entities_on_tile(tile_node: Node3D, context: Dictionary, spawn_points: Array[Vector3]) -> Array:
	"""
	Spawn entities on tile - only Effigy in MVP
	Moved from SpawnManager for better organization
	
	@param tile_node: Tile node to spawn entities on
	@param context: Spawning context
	@param spawn_points: Available entity spawn positions
	@return: Array of spawned entity types
	"""
	var spawned_entities := []
	
	if spawn_points.is_empty():
		return spawned_entities
	
	# Get current game state
	var current_sanity: int = _state_manager.get_state("sanity")
	var tiles_explored_value = _state_manager.get_state("tiles_explored")
	var tiles_explored: int = tiles_explored_value if tiles_explored_value != null else 0
	var weird_things_collected: int = 0
	
	# Check with WeirdThingsManager if available
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("get_collected_count"):
		weird_things_collected = weird_things_manager.get_collected_count()
	else:
		# WeirdThingsManager not available, use default value
		weird_things_collected = 0
	
	# Calculate spawn chance
	var spawn_chance: float = calculate_entity_spawn_chance(current_sanity, tiles_explored, weird_things_collected)
	
	# Determine which entity to spawn
	var entity_type: String = "effigy" # Always spawn effigy now
	
	# Try to spawn entity
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var roll = randf()
	
	print("    DEBUG EnemyManager: Spawn chance: %.2f, Roll: %.2f" % [spawn_chance, roll])
	
	if roll < spawn_chance:
		print("    DEBUG EnemyManager: Attempting to spawn %s at %s" % [entity_type, spawn_point])
		# Use our own spawn_enemy method
		var spawned_entity = spawn_enemy(entity_type, spawn_point, true) # Force spawn
		if spawned_entity:
			spawned_entities.append(entity_type)
			print("    DEBUG EnemyManager: Successfully spawned %s" % entity_type)
		else:
			print("    DEBUG EnemyManager: Failed to spawn %s" % entity_type)
	else:
		print("    DEBUG EnemyManager: Spawn roll failed (%.2f >= %.2f)" % [roll, spawn_chance])
	
	return spawned_entities
