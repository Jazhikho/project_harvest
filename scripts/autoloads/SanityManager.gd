extends Node
## Sanity Manager - Handles player psychological state
## Manages sanity decay, visual effects, and entity spawn rates

signal sanity_changed(new_sanity: int)
signal sanity_critical  # When sanity drops below 20
signal sanity_break     # When sanity reaches 0

@export var max_sanity: int = 100
@export var passive_decay_rate: float = 1.0  # Points per 30 seconds
@export var critical_threshold: int = 20
@export var visual_distortion_threshold: int = 50

var current_sanity: int = 100
var decay_timer: float = 0.0
var is_critical: bool = false

# Visual effect references
var environment: Environment
var camera_effects: Node

func _ready():
	current_sanity = max_sanity
	_initialize_visual_systems()

func _initialize_visual_systems():
	"""Initialize visual effect systems for sanity feedback"""
	# TODO: Get references to visual systems
	# environment = get_viewport().get_camera_3d().environment
	pass

func _process(delta):
	_update_passive_decay(delta)
	_update_visual_effects()

func _update_passive_decay(delta):
	"""Handle gradual sanity decay over time"""
	decay_timer += delta
	
	if decay_timer >= 30.0:  # Every 30 seconds
		decay_timer = 0.0
		modify_sanity(-passive_decay_rate)

func modify_sanity(amount: int):
	"""Modify sanity by a specific amount"""
	var old_sanity = current_sanity
	current_sanity = clamp(current_sanity + amount, 0, max_sanity)
	
	if current_sanity != old_sanity:
		emit_signal("sanity_changed", current_sanity)
		_check_sanity_thresholds(old_sanity)

func _check_sanity_thresholds(old_sanity: int):
	"""Check for sanity threshold changes and trigger events"""
	# Critical threshold
	if current_sanity <= critical_threshold and old_sanity > critical_threshold:
		is_critical = true
		emit_signal("sanity_critical")
		_on_sanity_critical()
	
	# Sanity break (death)
	if current_sanity <= 0 and old_sanity > 0:
		emit_signal("sanity_break")
		_on_sanity_break()

func _on_sanity_critical():
	"""Handle entering critical sanity state"""
	print("SANITY CRITICAL: Entering critical psychological state")
	
	# Increase entity spawn rates
	var watcher = get_tree().get_first_node_in_group("watcher")
	if watcher and watcher.has_method("set_spawn_rate"):
		watcher.set_spawn_rate(0.6)
	
	# Activate the choir whispers
	var choir = get_tree().get_first_node_in_group("choir") 
	if choir and choir.has_method("activate"):
		choir.activate()

func _on_sanity_break():
	"""Handle complete sanity breakdown (game over)"""
	print("SANITY BREAK: Complete psychological breakdown")
	
	# Trigger fragmented ending
	var game_director = get_node("/root/GameDirector")
	if game_director:
		var player_pos = _get_player_position()
		game_director.end_game("Fragmented", player_pos)

func _update_visual_effects():
	"""Update visual distortion effects based on sanity level"""
	var distortion_intensity = 1.0 - (float(current_sanity) / float(max_sanity))
	
	# Color grading effects
	if environment:
		# Desaturate and darken as sanity decreases
		var color_correction = environment.adjustment_enabled
		if current_sanity < visual_distortion_threshold:
			environment.adjustment_enabled = true
			environment.adjustment_saturation = 1.0 - (distortion_intensity * 0.5)
			environment.adjustment_brightness = 1.0 - (distortion_intensity * 0.3)
		else:
			environment.adjustment_enabled = false
	
	# Screen distortion effects for very low sanity
	if current_sanity <= critical_threshold:
		_apply_critical_visual_effects(distortion_intensity)

func _apply_critical_visual_effects(intensity: float):
	"""Apply intense visual effects for critical sanity levels"""
	# TODO: Implement screen shake, chromatic aberration, etc.
	# This would connect to post-processing shaders
	pass

func apply_sanity_loss_event(event_type: String, base_amount: int = 10):
	"""Apply sanity loss from specific events with contextual messages"""
	var amount = base_amount
	var message = ""
	
	match event_type:
		"weird_thing":
			amount = randi_range(5, 15)
			message = "Your mind reels as you touch the cursed object..."
		
		"watcher_encounter":
			amount = randi_range(10, 25)
			message = "Something watches you from the shadows..."
		
		"stalker_proximity":
			amount = randi_range(20, 40)
			message = "Terror grips your heart as death approaches..."
		
		"maze_shift":
			amount = 5
			message = "Reality bends unnaturally around you..."
		
		"choir_whispers":
			amount = randi_range(3, 8)
			message = "The voices of the harvested call out to you..."
		
		"overseer_scan":
			amount = randi_range(8, 15)
			message = "You feel exposed, analyzed, catalogued..."
	
	modify_sanity(-amount)
	_show_sanity_message(message)

func _show_sanity_message(message: String):
	"""Display a sanity-related message to the player"""
	if message != "":
		print("SANITY: ", message)
		
		# TODO: Connect to UI message system
		var ui_manager = get_tree().get_first_node_in_group("ui_manager")
		if ui_manager and ui_manager.has_method("show_sanity_message"):
			ui_manager.show_sanity_message(message, 2.0)

func get_sanity_spawn_rate(entity_type: String) -> float:
	"""Get entity spawn rate based on current sanity level"""
	var sanity_ratio = float(current_sanity) / float(max_sanity)
	
	match entity_type:
		"watcher":
			if current_sanity >= 80:
				return 0.1
			elif current_sanity >= 50:
				return 0.25
			elif current_sanity >= 20:
				return 0.4
			else:
				return 0.6
		
		"choir":
			if current_sanity < 50:
				return 0.3
			else:
				return 0.0
		
		"residual_subjects":
			if current_sanity < 30:
				return 0.2
			else:
				return 0.0
	
	return 0.0

func _get_player_position() -> Vector2:
	"""Get current player world position for events"""
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return Vector2(player.global_position.x, player.global_position.z)
	return Vector2.ZERO

# Public API
func get_current_sanity() -> int:
	return current_sanity

func get_sanity_ratio() -> float:
	return float(current_sanity) / float(max_sanity)

func is_sanity_critical() -> bool:
	return is_critical

func restore_sanity(amount: int):
	"""Restore sanity (for safe zones or special items)"""
	modify_sanity(amount)

func reset_sanity():
	"""Reset sanity to maximum (for new game)"""
	current_sanity = max_sanity
	is_critical = false
	decay_timer = 0.0
	emit_signal("sanity_changed", current_sanity)

# EventManager integration
func _on_event_sanity_changed(new_sanity: int):
	"""Handle sanity change events from EventManager"""
	var old_sanity = current_sanity
	current_sanity = new_sanity
	emit_signal("sanity_changed", current_sanity)
	_check_sanity_thresholds(old_sanity)
