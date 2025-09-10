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

# Enemy scene references
var _enemy_scenes: Dictionary = {
	"stalker": "res://scenes/entities/stalker.tscn",
	"watcher": "res://scenes/entities/watcher.tscn",
	"effigy": "res://scenes/entities/effigy.tscn"
}

func _ready() -> void:
	name = "EnemyManager"
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
	print("EnemyManager: === ENEMY SPAWN REQUEST ===")
	print("  Type: %s" % enemy_type)
	print("  Position: %s" % position)
	print("  Force spawn: %s" % force_spawn)
	
	if not _can_spawn_enemy(enemy_type) and not force_spawn:
		print("  ✗ Spawn blocked by conditions")
		print("=====================================")
		return null
	
	if not _enemy_scenes.has(enemy_type):
		push_error("EnemyManager: Unknown enemy type '%s'" % enemy_type)
		return null
	
	var scene_path = _enemy_scenes[enemy_type]
	print("  Scene path: %s" % scene_path)
	
	if not FileAccess.file_exists(scene_path):
		print("  Scene file not found - creating placeholder")
		var placeholder = _spawn_placeholder_enemy(enemy_type, position)
		print("  ✓ Placeholder enemy created")
		print("=====================================")
		return placeholder
	
	print("  Loading enemy scene...")
	var enemy_scene = load(scene_path) as PackedScene
	if not enemy_scene:
		push_error("EnemyManager: Failed to load enemy scene: %s" % scene_path)
		print("  ✗ Scene load failed")
		print("=====================================")
		return null
	
	print("  Instantiating enemy...")
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		push_error("EnemyManager: Failed to instantiate enemy: %s" % enemy_type)
		print("  ✗ Instantiation failed")
		print("=====================================")
		return null
	
	# Add to scene
	print("  Adding to scene tree...")
	get_tree().current_scene.add_child(enemy_instance)
	
	# Set position
	if position == Vector3.ZERO:
		position = _find_spawn_position(enemy_type)
		print("  Auto-selected position: %s" % position)
	enemy_instance.global_position = position
	
	# Register enemy
	var entity_id = _generate_enemy_id(enemy_type)
	_active_enemies[entity_id] = enemy_instance
	enemy_instance.set_meta("entity_id", entity_id)
	enemy_instance.set_meta("enemy_type", enemy_type)
	
	# Set cooldown
	_enemy_spawn_cooldowns[enemy_type] = _get_spawn_cooldown(enemy_type)
	print("  Set cooldown: %.1fs" % _get_spawn_cooldown(enemy_type))
	
	# Emit spawn event
	_message_bus.emit_event("entity_spawned", [enemy_type, enemy_instance, position])
	
	print("  ✓ Enemy spawned successfully (ID: %s)" % entity_id)
	print("=====================================")
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
	
	print("EnemyManager: Created placeholder %s" % enemy_type)
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
	
	print("EnemyManager: Despawned %s (ID: %s)" % [enemy_type, entity_id])
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
		print("EnemyManager: Cleaned up invalid enemy ID: %s" % entity_id)

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
		print("EnemyManager: Watcher spawn blocked - MVP disabled")
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
	if weird_things_manager and weird_things_manager.has_method("get_collected_count"):
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

func debug_print_enemies() -> void:
	"""Print debug info about all active enemies"""
	print("=== ENEMY MANAGER DEBUG ===")
	print("Active enemies: %d" % _active_enemies.size())
	for entity_id in _active_enemies.keys():
		var enemy = _active_enemies[entity_id]
		if is_instance_valid(enemy):
			var enemy_type = enemy.get_meta("enemy_type", "unknown")
			print("  %s (%s): %s" % [entity_id, enemy_type, enemy.global_position])
		else:
			print("  %s: INVALID" % entity_id)
	print("Spawn cooldowns:")
	for enemy_type in _enemy_spawn_cooldowns.keys():
		print("  %s: %.1fs" % [enemy_type, _enemy_spawn_cooldowns[enemy_type]])
	print("===========================")

func get_enemy_count() -> int:
	"""Get total number of active enemies"""
	cleanup_invalid_enemies()
	return _active_enemies.size()

func get_enemy_count_by_type(enemy_type: String) -> int:
	"""Get number of active enemies of specific type"""
	return get_enemies_by_type(enemy_type).size()
