extends Node3D
## Spawns and manages multiple crows at precise positions
## Each crow can have individual animation speeds and behaviors

class_name CrowFlock

# ----------------------------
# Exports
# ----------------------------

## Crow scene to instantiate
@export var crow_scene: PackedScene

## Array of precise positions for crows (relative to this node)
@export var crow_positions: Array[Vector3] = []

## Array of Y-axis rotations for crows in degrees (matches crow_positions indices)
## If empty or shorter than positions, defaults to 0 degrees
@export var crow_rotations: Array[float] = []

## Randomize rotation if not specified
@export var randomize_rotation: bool = false

## Randomize animation speed for each crow
@export var randomize_speed: bool = true

## Min animation speed multiplier
@export var min_animation_speed: float = 0.5

## Max animation speed multiplier
@export var max_animation_speed: float = 1.5

## Randomize behaviors
@export var randomize_behaviors: bool = true

## Randomize starting animation time offset
@export var randomize_time_offset: bool = true

## Auto-generate crows on ready
@export var auto_generate: bool = true

# ----------------------------
# Internal state
# ----------------------------

var _crow_instances: Array[Crow] = []

# ----------------------------
# Internal helpers
# ----------------------------

## _create_crow_at_position
## Purpose: Instantiate and configure a crow at a specific position.
## @param pos: Position relative to this node.
## @param rotation_y: Y-axis rotation in degrees.
## Returns: Crow instance or null on error.
func _create_crow_at_position(pos: Vector3, rotation_y: float) -> Crow:
	if not crow_scene:
		push_error("CrowFlock: crow_scene not set in %s" % name)
		return null
	
	var crow_instance: Node3D = crow_scene.instantiate()
	if not crow_instance:
		push_error("CrowFlock: Failed to instantiate crow_scene in %s" % name)
		return null
	
	add_child(crow_instance)
	crow_instance.position = pos
	crow_instance.rotation_degrees.y = rotation_y
	
	# Check if it's a Crow type
	var crow: Crow = crow_instance as Crow
	if not crow:
		# Try to find Crow script if scene isn't directly a Crow
		crow = crow_instance.get_node_or_null(".") as Crow
	
	if crow:
		# Apply randomization
		if randomize_speed:
			crow.set_random_animation_speed(min_animation_speed, max_animation_speed)
		
		if randomize_behaviors:
			crow.set_random_behavior()
		
		if randomize_time_offset:
			crow.set_time_offset_random()
	else:
		push_error("CrowFlock: Instantiated scene is not a Crow type in %s" % name)
	
	return crow

# ----------------------------
# Public API
# ----------------------------

## generate_flock
## Purpose: Spawn all crows at defined positions.
## Returns: void.
func generate_flock() -> void:
	# Clear existing crows
	clear_flock()
	
	if not crow_scene:
		push_error("CrowFlock: crow_scene not assigned in %s" % name)
		return
	
	if crow_positions.is_empty():
		push_error("CrowFlock: No crow_positions defined in %s" % name)
		return
	
	# Create crows at each position
	for i: int in crow_positions.size():
		var pos: Vector3 = crow_positions[i]
		var rotation_y: float = 0.0
		
		# Get rotation from array if available
		if i < crow_rotations.size():
			rotation_y = crow_rotations[i]
		elif randomize_rotation:
			rotation_y = randf_range(0.0, 360.0)
		
		var crow: Crow = _create_crow_at_position(pos, rotation_y)
		if crow:
			_crow_instances.append(crow)

## clear_flock
## Purpose: Remove all spawned crows.
## Returns: void.
func clear_flock() -> void:
	for crow: Crow in _crow_instances:
		if is_instance_valid(crow):
			crow.queue_free()
	_crow_instances.clear()

## add_crow_at
## Purpose: Add a single crow at a specific position.
## @param pos: Position relative to this node.
## @param rotation_y: Y-axis rotation in degrees (default: 0.0).
## Returns: The created Crow instance or null.
func add_crow_at(pos: Vector3, rotation_y: float = 0.0) -> Crow:
	var crow: Crow = _create_crow_at_position(pos, rotation_y)
	if crow:
		_crow_instances.append(crow)
		crow_positions.append(pos)
		crow_rotations.append(rotation_y)
	return crow

## get_crow_count
## Purpose: Get the number of active crows in the flock.
## Returns: int count of crows.
func get_crow_count() -> int:
	return _crow_instances.size()

# ----------------------------
# Lifecycle
# ----------------------------

## _ready
## Purpose: Auto-generate flock if enabled.
## Returns: void.
func _ready() -> void:
	if auto_generate:
		generate_flock()
