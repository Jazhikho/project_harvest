extends Node3D
## Individual crow with animation control and behavior variation
## Limits animation to first 6.5 seconds and supports variable playback speed

class_name Crow

# ----------------------------
# Exports
# ----------------------------

## Animation playback speed multiplier (0.5 = half speed, 2.0 = double speed)
@export var animation_speed: float = 1.0

## Maximum animation time in seconds (loops back to start after this)
@export var max_animation_time: float = 6.5

## Random time offset to start animation (adds variety to flock)
@export var time_offset: float = 0.0

## Behavior type for this crow
@export_enum("idle", "pecking", "looking_around", "preening") var behavior: String = "idle"

# ----------------------------
# Internal state
# ----------------------------

var _animation_player: AnimationPlayer
var _current_time: float = 0.0
var _behavior_timer: float = 0.0
var _next_behavior_change: float = 0.0

# ----------------------------
# Internal helpers
# ----------------------------

## _find_animation_player
## Purpose: Locate AnimationPlayer node in the crow model hierarchy.
## Returns: AnimationPlayer node or null if not found.
func _find_animation_player() -> AnimationPlayer:
	# Search in Sketchfab_Scene children
	var sketchfab_scene: Node = get_node_or_null("Sketchfab_Scene")
	if not sketchfab_scene:
		push_error("Crow: Could not find Sketchfab_Scene node in %s" % name)
		return null
	
	# Recursively search for AnimationPlayer
	return _find_node_by_type(sketchfab_scene, AnimationPlayer) as AnimationPlayer

## _find_node_by_type
## Purpose: Recursively search for a node of specific type.
## @param node: Starting node for search.
## @param type: Type to search for.
## Returns: Node of specified type or null.
func _find_node_by_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child: Node in node.get_children():
		var result: Node = _find_node_by_type(child, type)
		if result:
			return result
	
	return null

## _pick_random_behavior
## Purpose: Select a random behavior type for variety.
## Returns: String behavior name.
func _pick_random_behavior() -> String:
	var behaviors: Array[String] = ["idle", "pecking", "looking_around", "preening"]
	return behaviors[randi() % behaviors.size()]

## _apply_behavior
## Purpose: Apply current behavior to crow's animation or state.
## Returns: void.
func _apply_behavior() -> void:
	# Behaviors could modify animation speed or other properties
	match behavior:
		"pecking":
			# Pecking might be faster
			animation_speed = randf_range(1.2, 1.5)
		"looking_around":
			# Looking around might be normal speed
			animation_speed = randf_range(0.8, 1.2)
		"preening":
			# Preening might be slower
			animation_speed = randf_range(0.6, 0.9)
		"idle":
			# Idle is slowest
			animation_speed = randf_range(0.5, 0.8)

# ----------------------------
# Lifecycle
# ----------------------------

## _ready
## Purpose: Initialize crow and setup animation control.
## Returns: void.
func _ready() -> void:
	# Find animation player
	_animation_player = _find_animation_player()
	if not _animation_player:
		push_error("Crow: No AnimationPlayer found in %s" % name)
		return
	
	# Start animation
	var anim_list: PackedStringArray = _animation_player.get_animation_list()
	if anim_list.size() > 0:
		_animation_player.play(anim_list[0])
		_animation_player.pause()
		
		# Apply initial speed
		_animation_player.speed_scale = animation_speed
		
		# Apply time offset
		_current_time = time_offset
		_animation_player.seek(_current_time, true)
	else:
		push_error("Crow: No animations found in AnimationPlayer for %s" % name)
	
	# Setup behavior timer
	_next_behavior_change = randf_range(5.0, 15.0)

## _process
## Purpose: Update animation time and behavior.
## @param delta: Frame time.
## Returns: void.
func _process(delta: float) -> void:
	if not _animation_player:
		return
	
	# Update animation time manually to control loop point
	_current_time += delta * animation_speed
	
	# Loop back to 0 when we hit max time
	if _current_time >= max_animation_time:
		_current_time = fmod(_current_time, max_animation_time)
	
	# Seek to current time
	_animation_player.seek(_current_time, true)
	
	# Update behavior timer
	_behavior_timer += delta
	if _behavior_timer >= _next_behavior_change:
		behavior = _pick_random_behavior()
		_apply_behavior()
		_behavior_timer = 0.0
		_next_behavior_change = randf_range(5.0, 15.0)

# ----------------------------
# Public API
# ----------------------------

## set_random_animation_speed
## Purpose: Randomize animation speed within a range.
## @param min_speed: Minimum speed multiplier.
## @param max_speed: Maximum speed multiplier.
## Returns: void.
func set_random_animation_speed(min_speed: float, max_speed: float) -> void:
	animation_speed = randf_range(min_speed, max_speed)
	if _animation_player:
		_animation_player.speed_scale = animation_speed

## set_random_behavior
## Purpose: Assign a random behavior to this crow.
## Returns: void.
func set_random_behavior() -> void:
	behavior = _pick_random_behavior()
	_apply_behavior()

## set_time_offset_random
## Purpose: Set a random starting time in the animation for variety.
## Returns: void.
func set_time_offset_random() -> void:
	time_offset = randf_range(0.0, max_animation_time)
	_current_time = time_offset
	if _animation_player:
		_animation_player.seek(_current_time, true)
