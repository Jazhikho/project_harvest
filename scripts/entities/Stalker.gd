extends CharacterBody3D
## The Stalker - Apex predator entity that hunts the player
## Activated when too many Weird Things are collected, represents inevitable harvest

@export var movement_speed: float = 3.0
@export var hunt_speed: float = 6.0
@export var patrol_radius: float = 20.0
@export var detection_range: float = 15.0
@export var lose_target_range: float = 30.0
@export var sanity_drain_range: float = 12.0
@export var sanity_drain_rate: int = 25  # Per proximity event

var is_activated: bool = false
var player_reference: Node3D
var last_known_player_position: Vector3
var patrol_center: Vector3
var current_target_position: Vector3

# Stalker states
enum StalkerState {
	DORMANT,      # Not yet activated
	PATROLLING,   # Searching for player
	HUNTING,      # Actively pursuing player
	CLOSING_IN    # Very close to player
}

var current_state: StalkerState = StalkerState.DORMANT

# Navigation and AI
var navigation_timer: float = 0.0
var navigation_update_interval: float = 0.5
var patrol_change_timer: float = 0.0
var patrol_change_interval: float = 3.0

# Audio and effects
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var detection_area: Area3D = $DetectionArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Grid-based movement (for maze navigation)
var grid_position: Vector2i
var target_grid_position: Vector2i
var grid_size: float = 4.0

func _ready():
	add_to_group("stalker")
	
	# Initially dormant and invisible
	visible = false
	set_physics_process(false)
	
	# Connect detection area
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	
	# Set initial position
	patrol_center = global_position
	current_target_position = global_position

func _physics_process(delta):
	if current_state == StalkerState.DORMANT:
		return
	
	_update_ai_logic(delta)
	_update_movement(delta)
	_update_effects(delta)

func _update_ai_logic(delta):
	"""Update AI decision making"""
	navigation_timer += delta
	
	if navigation_timer >= navigation_update_interval:
		navigation_timer = 0.0
		_update_navigation()
	
	_check_state_transitions()

func _update_navigation():
	"""Update navigation target based on current state"""
	var player = _get_player()
	if not player:
		return
	
	var player_distance = global_position.distance_to(player.global_position)
	
	match current_state:
		StalkerState.PATROLLING:
			_update_patrol_navigation()
		
		StalkerState.HUNTING:
			_update_hunt_navigation(player)
		
		StalkerState.CLOSING_IN:
			_update_closing_navigation(player)

func _update_patrol_navigation():
	"""Update navigation during patrol state"""
	patrol_change_timer += navigation_update_interval
	
	if patrol_change_timer >= patrol_change_interval:
		patrol_change_timer = 0.0
		
		# Pick new patrol point
		var angle = randf() * 2 * PI
		var distance = randf_range(5.0, patrol_radius)
		current_target_position = patrol_center + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		_convert_to_grid_target(current_target_position)

func _update_hunt_navigation(player: Node3D):
	"""Update navigation during hunting state"""
	last_known_player_position = player.global_position
	
	# Move towards player's last known position
	current_target_position = last_known_player_position
	_convert_to_grid_target(current_target_position)

func _update_closing_navigation(player: Node3D):
	"""Update navigation when closing in on player"""
	# Direct path to player
	current_target_position = player.global_position
	_convert_to_grid_target(current_target_position)

func _convert_to_grid_target(world_pos: Vector3):
	"""Convert world position to grid-based target"""
	target_grid_position = Vector2i(
		int(world_pos.x / grid_size),
		int(world_pos.z / grid_size)
	)

func _update_movement(delta):
	"""Handle actual movement towards target"""
	if target_grid_position == grid_position:
		return
	
	var maze_manager = get_node("/root/MazeManager")
	if not maze_manager:
		return
	
	# Calculate next grid step
	var next_step = _calculate_next_pathfinding_step(maze_manager)
	if next_step != Vector2i(-1, -1):
		_move_to_grid_position(next_step, delta)

func _calculate_next_pathfinding_step(maze_manager: Node) -> Vector2i:
	"""Calculate next step towards target using simple pathfinding"""
	var dx = target_grid_position.x - grid_position.x
	var dy = target_grid_position.y - grid_position.y
	
	# Try to move in the direction of largest distance first
	var next_pos = grid_position
	
	if abs(dx) > abs(dy):
		next_pos.x += 1 if dx > 0 else -1
	else:
		next_pos.y += 1 if dy > 0 else -1
	
	# Check if movement is valid
	if maze_manager.can_move(grid_position.x, grid_position.y, next_pos.x, next_pos.y):
		return next_pos
	
	# Try alternative direction if primary is blocked
	if abs(dx) > abs(dy):
		next_pos = grid_position
		next_pos.y += 1 if dy > 0 else -1
	else:
		next_pos = grid_position
		next_pos.x += 1 if dx > 0 else -1
	
	if maze_manager.can_move(grid_position.x, grid_position.y, next_pos.x, next_pos.y):
		return next_pos
	
	return Vector2i(-1, -1)  # No valid move

func _move_to_grid_position(new_grid_pos: Vector2i, delta: float):
	"""Smoothly move to new grid position"""
	grid_position = new_grid_pos
	var target_world_pos = Vector3(
		grid_position.x * grid_size,
		global_position.y,
		grid_position.y * grid_size
	)
	
	# Smooth movement
	var speed = hunt_speed if current_state == StalkerState.HUNTING else movement_speed
	global_position = global_position.move_toward(target_world_pos, speed * delta)

func _check_state_transitions():
	"""Check for state transitions based on player proximity"""
	var player = _get_player()
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		StalkerState.PATROLLING:
			if distance_to_player <= detection_range:
				_transition_to_hunting()
		
		StalkerState.HUNTING:
			if distance_to_player <= 8.0:
				_transition_to_closing_in()
			elif distance_to_player >= lose_target_range:
				_transition_to_patrolling()
		
		StalkerState.CLOSING_IN:
			if distance_to_player >= 12.0:
				_transition_to_hunting()
			elif distance_to_player <= 3.0:
				_trigger_player_caught()

func _transition_to_patrolling():
	"""Transition to patrolling state"""
	current_state = StalkerState.PATROLLING
	patrol_center = global_position
	_play_state_audio("patrol")
	print("STALKER: Lost target, returning to patrol")

func _transition_to_hunting():
	"""Transition to hunting state"""
	current_state = StalkerState.HUNTING
	_play_state_audio("hunt")
	
	# Trigger sanity loss when hunt begins
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.apply_sanity_loss_event("stalker_proximity", 20)
	
	print("STALKER: Target acquired, beginning hunt")

func _transition_to_closing_in():
	"""Transition to closing in state"""
	current_state = StalkerState.CLOSING_IN
	_play_state_audio("closing")
	
	# Heavy sanity loss when stalker gets close
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.apply_sanity_loss_event("stalker_proximity", 40)
	
	print("STALKER: Closing in for the harvest...")

func _trigger_player_caught():
	"""Handle player being caught by stalker"""
	print("STALKER: Subject captured for harvest")
	
	# End game with consumed status
	var game_director = get_node("/root/GameDirector")
	if game_director:
		var player = _get_player()
		var player_pos = Vector2.ZERO
		if player and player.has_method("get_grid_position"):
			var grid_pos = player.get_grid_position()
			player_pos = Vector2(grid_pos.x, grid_pos.y)
		
		game_director.end_game("Consumed", player_pos)

func _update_effects(delta):
	"""Update visual and audio effects"""
	var player = _get_player()
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Proximity sanity drain
	if distance_to_player <= sanity_drain_range:
		_apply_proximity_sanity_drain(delta)
	
	# Look towards player when hunting
	if current_state != StalkerState.PATROLLING:
		look_at(player.global_position, Vector3.UP)

func _apply_proximity_sanity_drain(delta):
	"""Apply gradual sanity drain when Stalker is nearby"""
	# Occasional sanity drain instead of constant
	if randf() < 0.05:  # 5% chance per frame when close
		var sanity_manager = get_node("/root/SanityManager")
		if sanity_manager:
			sanity_manager.apply_sanity_loss_event("stalker_proximity", 5)

func _play_state_audio(state_type: String):
	"""Play audio appropriate for current state"""
	# TODO: Load and play appropriate audio clips
	match state_type:
		"patrol":
			pass  # Subtle movement sounds
		"hunt":
			pass  # Aggressive pursuit sounds  
		"closing":
			pass  # Terrifying approach sounds

func _on_player_detected(body):
	"""Handle player entering detection range"""
	if body.is_in_group("player") and current_state == StalkerState.PATROLLING:
		_transition_to_hunting()

func _on_player_lost(body):
	"""Handle player leaving detection range"""
	if body.is_in_group("player") and current_state == StalkerState.HUNTING:
		# Don't immediately lose target, use timer
		pass

func _get_player() -> Node3D:
	"""Get reference to player"""
	if not player_reference:
		player_reference = get_tree().get_first_node_in_group("player")
	return player_reference

# Public API
func activate():
	"""Activate the Stalker (called when enough weird things collected)"""
	if is_activated:
		return
	
	is_activated = true
	visible = true
	set_physics_process(true)
	current_state = StalkerState.PATROLLING
	
	# Position near player but not too close
	var player = _get_player()
	if player:
		var spawn_distance = randf_range(25.0, 35.0)
		var spawn_angle = randf() * 2 * PI
		global_position = player.global_position + Vector3(
			cos(spawn_angle) * spawn_distance,
			0,
			sin(spawn_angle) * spawn_distance
		)
		
		patrol_center = global_position
		
		# Update grid position
		grid_position = Vector2i(
			int(global_position.x / grid_size),
			int(global_position.z / grid_size)
		)
	
	print("STALKER: Activated - The harvest begins...")

func is_stalker_active() -> bool:
	return is_activated

func get_stalker_state() -> StalkerState:
	return current_state
