extends Node
## Effigy Manager - Handles effigy creation and management based on death locations
## Implements GAMELOOP.md step 12: Effigy spawning at death locations

var _message_bus: Node
var _state_manager: Node
var _harvest_logger: Node

# Effigy tracking
var _active_effigies: Dictionary = {}  # Vector2i -> effigy_node
var _effigy_data: Dictionary = {}  # Vector2i -> effigy_metadata
var _next_effigy_id: int = 0

# Effigy scenes and stages
var _effigy_scene_path: String = "res://scenes/entities/effigy.tscn"
var _effigy_stages: Array[String] = [
	"res://assets/models/effigy_stage1.tscn",
	"res://assets/models/effigy_stage2.tscn", 
	"res://assets/models/effigy_stage3.tscn",
	"res://assets/models/effigy_stage4.tscn"
]

func _ready() -> void:
	name = "EffigyManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_harvest_logger = get_node_or_null("/root/HarvestLogger")
	
	if not _message_bus or not _state_manager:
		push_error("EffigyManager: Required core systems not found")
		return
	
	_connect_to_events()
	_load_existing_effigies()

func spawn_effigy_at_death_location(death_data: Dictionary) -> Node3D:
	"""
	Spawn an effigy at a death location from previous run
	Implements GAMELOOP.md step 12: Effigy spawning when backpack is dropped
	
	@param death_data: Death location data from GameStateManager
	@return: Spawned effigy node or null if failed
	"""
	if death_data.is_empty():
		return null
	
	var position: Vector2i = death_data.get("position", Vector2i.ZERO)
	var cause: String = death_data.get("cause", "Unknown")
	var inventory: Array = death_data.get("inventory", [])
	
	# Don't spawn multiple effigies at same location
	if _active_effigies.has(position):
		print("EffigyManager: Effigy already exists at ", position)
		return _active_effigies[position]
	
	# Create effigy
	var effigy = _create_effigy_node(position, cause, inventory)
	if not effigy:
		return null
	
	# Position the effigy in world space
	var world_pos = Vector3(position.x * 20.0, 0, position.y * 20.0)  # TILE_SIZE = 20.0
	effigy.global_position = world_pos
	
	# Add to scene
	get_tree().current_scene.add_child(effigy)
	
	# Track the effigy
	_active_effigies[position] = effigy
	_effigy_data[position] = {
		"cause": cause,
		"inventory": inventory,
		"spawn_time": Time.get_unix_time_from_system(),
		"run_id": death_data.get("run_id", "unknown"),
		"entity_id": _generate_effigy_id()
	}
	
	# Set initial stage based on current sanity
	var current_sanity = _state_manager.get_state("sanity")
	_update_effigy_stage(effigy, position, current_sanity)
	
	# Emit spawn event
	_message_bus.emit_event("entity_spawned", ["effigy", effigy, world_pos])
	
	print("EffigyManager: Spawned effigy at %s (cause: %s)" % [position, cause])
	return effigy

func _create_effigy_node(position: Vector2i, cause: String, inventory: Array) -> Node3D:
	"""
	Create effigy node instance
	
	@param position: Grid position
	@param cause: Death cause
	@param inventory: Items from death
	@return: Effigy node or null
	"""
	var effigy: Node3D = null
	
	# Try to load effigy scene
	if FileAccess.file_exists(_effigy_scene_path):
		var effigy_scene = load(_effigy_scene_path) as PackedScene
		if effigy_scene:
			effigy = effigy_scene.instantiate()
		else:
			push_warning("EffigyManager: Failed to load effigy scene")
	
	# Create placeholder if scene doesn't exist
	if not effigy:
		effigy = _create_placeholder_effigy()
	
	# Set effigy metadata
	effigy.set_meta("effigy_position", position)
	effigy.set_meta("death_cause", cause)
	effigy.set_meta("death_inventory", inventory)
	effigy.set_meta("entity_id", _generate_effigy_id())
	effigy.name = "Effigy_%d_%d" % [position.x, position.y]
	
	return effigy

func _create_placeholder_effigy() -> Node3D:
	"""
	Create placeholder effigy when scene files are missing
	
	@return: Placeholder effigy node
	"""
	var effigy = StaticBody3D.new()
	effigy.name = "PlaceholderEffigy"
	
	# Add mesh - scarecrow-like appearance
	var mesh_instance = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.height = 2.0
	mesh.radius = 0.3
	mesh_instance.mesh = mesh
	
	# Dark material to look ominous
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.1, 0.1)  # Dark reddish
	material.roughness = 0.8
	mesh_instance.set_surface_override_material(0, material)
	
	effigy.add_child(mesh_instance)
	
	# Add collision for interaction
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = 2.0
	shape.radius = 0.3
	collision.shape = shape
	effigy.add_child(collision)
	
	# Position slightly above ground
	mesh_instance.position.y = 1.0
	
	print("EffigyManager: Created placeholder effigy")
	return effigy

func update_effigy_stages_for_sanity(sanity: int) -> void:
	"""
	Update all effigy stages based on current sanity level
	Implements sanity-dependent effigy appearance changes
	
	@param sanity: Current player sanity (0-100)
	"""
	for position in _active_effigies.keys():
		var effigy = _active_effigies[position]
		if is_instance_valid(effigy):
			_update_effigy_stage(effigy, position, sanity)

func _update_effigy_stage(effigy: Node3D, position: Vector2i, sanity: int) -> void:
	"""
	Update individual effigy's stage based on sanity
	
	@param effigy: Effigy node to update
	@param position: Effigy position
	@param sanity: Current sanity level
	"""
	var stage = _calculate_stage_for_sanity(sanity)
	var current_stage = effigy.get_meta("current_stage", 1)
	
	if stage != current_stage:
		effigy.set_meta("current_stage", stage)
		
		# If effigy has stage management methods, use them
		if effigy.has_method("set_stage"):
			effigy.set_stage(stage)
		elif effigy.has_method("_change_stage"):
			effigy._change_stage(stage)
		else:
			# Fallback: modify appearance directly
			_apply_stage_appearance(effigy, stage)
		
		print("EffigyManager: Updated effigy at %s to stage %d (sanity: %d)" % [position, stage, sanity])

func _calculate_stage_for_sanity(sanity: int) -> int:
	"""
	Calculate which stage effigy should be at for given sanity level
	Matches Effigy.gd stage calculation
	
	@param sanity: Current sanity level
	@return: Stage number (1-4)
	"""
	if sanity >= 70:
		return 1  # Normal scarecrow
	elif sanity >= 50:
		return 2  # Slightly unsettling
	elif sanity >= 40:
		return 3  # Clearly wrong
	else:
		return 4  # Nightmare fuel

func _apply_stage_appearance(effigy: Node3D, stage: int) -> void:
	"""
	Apply visual changes for effigy stage (placeholder implementation)
	
	@param effigy: Effigy to modify
	@param stage: Stage to apply
	"""
	var mesh_instance = effigy.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	
	var material = mesh_instance.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	
	# Change appearance based on stage
	match stage:
		1:  # Normal
			material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown
		2:  # Unsettling
			material.albedo_color = Color(0.4, 0.3, 0.2)  # Darker brown
		3:  # Wrong
			material.albedo_color = Color(0.3, 0.2, 0.2)  # Dark red-brown
		4:  # Nightmare
			material.albedo_color = Color(0.1, 0.0, 0.0)  # Nearly black
			material.emission = Color(0.2, 0.0, 0.0)  # Slight red glow

func cleanup_old_effigies(max_age_seconds: float = 300.0) -> void:
	"""
	Remove effigies that are too old
	
	@param max_age_seconds: Maximum age before cleanup (default 5 minutes)
	"""
	var current_time = Time.get_unix_time_from_system()
	var positions_to_remove: Array[Vector2i] = []
	
	for position in _effigy_data.keys():
		var data = _effigy_data[position]
		var age = current_time - data.get("spawn_time", current_time)
		
		if age > max_age_seconds:
			positions_to_remove.append(position)
	
	for position in positions_to_remove:
		remove_effigy(position)
		print("EffigyManager: Cleaned up old effigy at ", position)

func remove_effigy(position: Vector2i) -> bool:
	"""
	Remove effigy at specific position
	
	@param position: Grid position of effigy to remove
	@return: True if effigy was removed
	"""
	if not _active_effigies.has(position):
		return false
	
	var effigy = _active_effigies[position]
	
	# Clean up tracking
	_active_effigies.erase(position)
	_effigy_data.erase(position)
	
	# Remove from scene
	if is_instance_valid(effigy):
		effigy.queue_free()
	
	print("EffigyManager: Removed effigy at ", position)
	return true

func get_effigy_at_position(position: Vector2i) -> Node3D:
	"""
	Get effigy at specific position
	
	@param position: Grid position to check
	@return: Effigy node or null if none exists
	"""
	return _active_effigies.get(position, null)

func get_all_effigies() -> Array[Node3D]:
	"""
	Get all active effigies
	
	@return: Array of effigy nodes
	"""
	var effigies: Array[Node3D] = []
	for effigy in _active_effigies.values():
		if is_instance_valid(effigy):
			effigies.append(effigy)
	return effigies

func get_effigy_count() -> int:
	"""Get number of active effigies"""
	return _active_effigies.size()

func _load_existing_effigies() -> void:
	"""Load effigies from previous runs on game start"""
	if not _harvest_logger:
		return
	
	var recent_runs = _harvest_logger.get_recent_runs(5)  # Last 5 runs
	
	for run_data in recent_runs:
		var final_pos = Vector2i(run_data.final_position.x, run_data.final_position.y)
		
		# Only spawn effigy if death location is unused
		var death_data = _state_manager.get_unused_death_at_position(final_pos)
		if not death_data.is_empty():
			# This will be handled by SpawnManager when backpack is spawned
			continue

func _generate_effigy_id() -> String:
	"""Generate unique effigy ID"""
	_next_effigy_id += 1
	return "effigy_%d" % _next_effigy_id

# Event handlers

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.sanity_changed.connect(_on_sanity_changed)
	_message_bus.player_died.connect(_on_player_died)
	_message_bus.entity_spawned.connect(_on_entity_spawned)
	_message_bus.game_started.connect(_on_game_started)
	_message_bus.game_ended.connect(_on_game_ended)

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity changes - update effigy stages"""
	update_effigy_stages_for_sanity(new_value)

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	"""Handle player death - record for future effigy spawning"""
	# The actual effigy will be spawned in the next run when SpawnManager
	# processes the death location and spawns a backpack
	print("EffigyManager: Player death recorded at %s (cause: %s)" % [position, cause])

func _on_entity_spawned(entity_type: String, entity_node: Node3D, position: Vector3) -> void:
	"""Handle entity spawning - check if it's a backpack spawn that needs an effigy"""
	if entity_type == "backpack":
		# When a backpack is spawned, spawn an effigy nearby
		var grid_pos = Vector2i(int(position.x / 20.0), int(position.z / 20.0))
		var death_data = _state_manager.get_unused_death_at_position(grid_pos)
		
		if not death_data.is_empty():
			var effigy_pos = position + Vector3(1.5, 0, 0)  # Offset from backpack
			var effigy = spawn_effigy_at_death_location(death_data)
			if effigy:
				effigy.global_position = effigy_pos

func _on_game_started() -> void:
	"""Handle game start - cleanup old effigies, prepare for new run"""
	cleanup_old_effigies(0.0)  # Remove all existing effigies
	_next_effigy_id = 0

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end - cleanup"""
	# Effigies persist between runs, so don't clean up here
	pass

# Debug functions

func debug_print_effigies() -> void:
	"""Print debug info about all active effigies"""
	print("=== EFFIGY MANAGER DEBUG ===")
	print("Active effigies: %d" % _active_effigies.size())
	for position in _active_effigies.keys():
		var effigy = _active_effigies[position]
		var data = _effigy_data.get(position, {})
		if is_instance_valid(effigy):
			var stage = effigy.get_meta("current_stage", 1)
			var cause = data.get("cause", "unknown")
			print("  %s: Stage %d, Cause: %s, Pos: %s" % [position, stage, cause, effigy.global_position])
		else:
			print("  %s: INVALID" % position)
	print("============================")

func force_update_all_stages() -> void:
	"""Force update all effigy stages (for debugging)"""
	var current_sanity = _state_manager.get_state("sanity")
	update_effigy_stages_for_sanity(current_sanity)
	print("EffigyManager: Force updated all effigy stages for sanity %d" % current_sanity)
