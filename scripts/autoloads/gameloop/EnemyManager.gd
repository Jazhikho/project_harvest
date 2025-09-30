extends Node
## Enemy Manager - Centralized management of enemy entities
## Handles enemy spawning, behavior coordination, and lifecycle

var _message_bus: Node
var _state_manager: Node
var _sanity_manager: Node

# Enemy tracking
var _active_enemies: Dictionary = {}  # entity_id -> entity_node
var _enemy_spawn_cooldowns: Dictionary = {}  # enemy_type -> cooldown_time
var _next_enemy_id: int = 0

@export var spawn_catalog: SpawnCatalog = preload("res://data/SpawnCatalog.tres")

# NEW: Map enemy_type to PackedScene
var _enemy_scene_map: Dictionary = {}  # enemy_type -> PackedScene

# Enemy spawn settings
var _stalker_spawn_conditions: Dictionary = {
	"min_weird_things": 3,
	"max_active": 1,
	"cooldown": 30.0
}

var _watcher_spawn_conditions: Dictionary = {
	"sanity_threshold": 80,
	"max_active": 3,
	"cooldown": 10.0,
	"mvp_disabled": true  # Disable Watchers for MVP release
}

# Enemy scene references (FALLBACK - catalog is preferred)
var _enemy_scenes: Dictionary = {
	"stalker": "res://scenes/entities/stalker.tscn",
	"watcher": "res://scenes/entities/watcher.tscn",
	"effigy": "res://scenes/entities/effigy.tscn"
}

func _ready() -> void:
	name = "EnemyManager"
	_resolve_catalog()
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_sanity_manager = get_node_or_null("/root/SanityManager")
	
	if not _message_bus or not _state_manager:
		push_error("EnemyManager: Required core systems not found")
		return
	
	_build_enemy_scene_map()  # NEW: Build the scene map
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
	
	for scene in spawn_catalog.enemy_scenes:
		if not scene:
			continue
		
		# Instantiate temporarily to get the enemy_type
		var temp_instance = scene.instantiate()
		var enemy_type: String = ""
		
		if temp_instance.has_method("get_enemy_type"):
			enemy_type = temp_instance.get_enemy_type()
		elif "enemy_type" in temp_instance:
			enemy_type = temp_instance.enemy_type
		elif temp_instance.has_meta("enemy_type"):
			enemy_type = temp_instance.get_meta("enemy_type")
		else:
			# Fallback: use node name
			enemy_type = temp_instance.name.to_lower()
		
		temp_instance.queue_free()
		
		if not enemy_type.is_empty():
			_enemy_scene_map[enemy_type] = scene
			print("EnemyManager: Mapped enemy_type '", enemy_type, "' to scene")
		else:
			push_warning("EnemyManager: Enemy scene has no enemy_type: ", scene.resource_path)
	
	print("EnemyManager: Built scene map with ", _enemy_scene_map.size(), " enemies")

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
	
	@param enemy_type: Type of enemy to spawn (stalker, watcher, effigy)
	@param position: World position to spawn at (Vector3.ZERO for auto-placement)
	@param force_spawn: Ignore cooldowns and limits
	@return: Spawned enemy node or null if failed
	"""
	if not _can_spawn_enemy(enemy_type) and not force_spawn:
		return null
	
	# NEW: Try to get scene from catalog map first
	var enemy_scene: PackedScene = _enemy_scene_map.get(enemy_type, null)
	
	# FALLBACK: Try loading from hardcoded paths
	if not enemy_scene and _enemy_scenes.has(enemy_type):
		var scene_path = _enemy_scenes[enemy_type]
		if FileAccess.file_exists(scene_path):
			enemy_scene = load(scene_path) as PackedScene
	
	# If still no scene, create placeholder
	if not enemy_scene:
		push_warning("EnemyManager: No scene found for enemy_type: ", enemy_type, " - using placeholder")
		return _spawn_placeholder_enemy(enemy_type, position)
	
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
	
	# Register enemy
	var entity_id = _generate_enemy_id(enemy_type)
	_active_enemies[entity_id] = enemy_instance
	enemy_instance.set_meta("entity_id", entity_id)
	enemy_instance.set_meta("enemy_type", enemy_type)
	
	# Set cooldown
	_enemy_spawn_cooldowns[enemy_type] = _get_spawn_cooldown(enemy_type)
	
	# Emit spawn event
	_message_bus.emit_event("entity_spawned", [enemy_type, enemy_instance, position])
	
	print("EnemyManager: Spawned ", enemy_type, " at ", position)
	
	return enemy_instance

func _spawn_placeholder_enemy(enemy_type: String, position: Vector3) -> Node3D:
	"""
	Spawn a placeholder enemy when scene files are missing
	
	@param enemy_type: Type of enemy
	@param position: Spawn position
	@return: Placeholder enemy node
	"""
	var placeholder = CharacterBody3D.new()
	placeholder.name = enemy_type.capitalize()
	
	# Add basic mesh
	var mesh_instance = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.height = 2.0
	mesh_instance.mesh = mesh
	
	# Add material based on enemy type
	var material = StandardMaterial3D.new()
	match enemy_type:
		"stalker":
			material.albedo_color = Color.BLACK
		"watcher":
			material.albedo_color = Color.DARK_RED
		"effigy":
			material.albedo_color = Color.DARK_GRAY
		_:
			material.albedo_color = Color.PURPLE
	
	mesh_instance.set_surface_override_material(0, material)
	placeholder.add_child(mesh_instance)
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = 2.0
	collision.shape = shape
	placeholder.add_child(collision)
	
	# Add to scene and register
	get_tree().current_scene.add_child(placeholder)
	placeholder.global_position = position
	
	var entity_id = _generate_enemy_id(enemy_type)
	_active_enemies[entity_id] = placeholder
	placeholder.set_meta("entity_id", entity_id)
	placeholder.set_meta("enemy_type", enemy_type)
	
	print("EnemyManager: Spawned placeholder ", enemy_type, " at ", position)
	
	return placeholder

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
	
	# Check type-specific conditions
	match enemy_type:
		"stalker":
			return _can_spawn_stalker()
		"watcher":
			return _can_spawn_watcher()
		"effigy":
			return true  # Effigies are spawned by EffigyManager based on death locations
		_:
			return true

func _can_spawn_stalker() -> bool:
	"""Check if stalker can be spawned"""
	# Check if max active stalkers reached
	var active_stalkers = get_enemies_by_type("stalker").size()
	if active_stalkers >= _stalker_spawn_conditions.max_active:
		return false
	
	# Check weird things collected (would need to check with WeirdThingsManager)
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("get_collected_count"):
		var weird_count = weird_things_manager.get_collected_count()
		if weird_count < _stalker_spawn_conditions.min_weird_things:
			return false
	
	return true

func _can_spawn_watcher() -> bool:
	"""Check if watcher can be spawned"""
	# MVP: Watchers are disabled for initial release
	if _watcher_spawn_conditions.get("mvp_disabled", false):
		return false
	
	# Check if max active watchers reached
	var active_watchers = get_enemies_by_type("watcher").size()
	if active_watchers >= _watcher_spawn_conditions.max_active:
		return false
	
	# Check sanity threshold
	if _state_manager:
		var current_sanity = _state_manager.get_state("sanity")
		if current_sanity > _watcher_spawn_conditions.sanity_threshold:
			return false
	
	return true

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
	
	match enemy_type:
		"stalker":
			# Spawn stalker far from player
			var angle = randf() * 2 * PI
			var distance = randf_range(25.0, 35.0)
			return player_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		"watcher":
			# Spawn watcher at medium distance
			var angle = randf() * 2 * PI
			var distance = randf_range(15.0, 25.0)
			return player_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		_:
			return player_pos + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))

func _get_spawn_cooldown(enemy_type: String) -> float:
	"""Get spawn cooldown for enemy type"""
	match enemy_type:
		"stalker":
			return _stalker_spawn_conditions.cooldown
		"watcher":
			return _watcher_spawn_conditions.cooldown
		_:
			return 5.0

func _generate_enemy_id(enemy_type: String) -> String:
	"""Generate unique enemy ID"""
	_next_enemy_id += 1
	return "%s_%d" % [enemy_type, _next_enemy_id]

# Event handlers

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.weird_thing_collected.connect(_on_weird_thing_collected)
	_message_bus.sanity_threshold_crossed.connect(_on_sanity_threshold_crossed)
	_message_bus.player_died.connect(_on_player_died)
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.game_ended.connect(_on_game_ended)

func _on_weird_thing_collected(thing_id: String, position: Vector2i, effects: Dictionary) -> void:
	"""Handle weird thing collection - may trigger stalker spawn"""
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("get_collecte d_count"):
		var weird_count = weird_things_manager.get_collected_count()
		if weird_count >= _stalker_spawn_conditions.min_weird_things:
			if randf() < 0.3:  # 30% chance to spawn stalker
				spawn_enemy("stalker")

func _on_sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool) -> void:
	"""Handle sanity threshold changes"""
	if not crossed_down:
		return
	
	match threshold_name:
		"low":  # Below 40%
			if randf() < 0.4:
				spawn_enemy("watcher")
		"critical":  # Below 20%
			if randf() < 0.6:
				spawn_enemy("watcher")

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
	_on_game_started()  # Same cleanup

# Debug functions

func get_enemy_count() -> int:
	"""Get total number of active enemies"""
	cleanup_invalid_enemies()
	return _active_enemies.size()

func get_enemy_count_by_type(enemy_type: String) -> int:
	"""Get number of active enemies of specific type"""
	return get_enemies_by_type(enemy_type).size()
