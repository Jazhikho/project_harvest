extends CharacterBody3D
## Player Controller - First-person movement with grid-based logic
## Ported from JavaScript player.js with 3D enhancements

@export var movement_speed: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var flashlight_battery_max: float = 300.0  # 5 minutes
@export var flashlight_drain_rate: float = 1.0     # per second

# Grid-based positioning for maze logic
var grid_position: Vector2i = Vector2i(1, 1)
var grid_size: float = 4.0  # Size of each maze cell in world units

# Movement state
var last_move_time: float = 0.0
var move_cooldown: float = 0.2  # Prevent too-rapid grid movement

# Flashlight system
var flashlight_battery: float = 300.0
var flashlight_enabled: bool = true

# References
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var flashlight_mesh: MeshInstance3D = $Camera3D/FlashlightMesh

# Input handling
var mouse_captured: bool = false

func _ready():
	# Capture mouse for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	
	# Set initial world position based on grid position
	_update_world_position()
	
	# Initialize flashlight
	_update_flashlight_state()

func _input(event):
	if not mouse_captured:
		return
		
	# Mouse look
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	
	# Toggle flashlight
	if event.is_action_pressed("toggle_flashlight"):
		_toggle_flashlight()
	
	# Escape to release mouse (for debugging)
	if event.is_action_pressed("ui_cancel"):
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true

func _handle_mouse_look(relative_motion: Vector2):
	"""Handle mouse look for camera rotation"""
	# Rotate camera up/down
	camera.rotation.x = clamp(camera.rotation.x - relative_motion.y * mouse_sensitivity, -PI/2, PI/2)
	
	# Rotate body left/right
	rotation.y -= relative_motion.x * mouse_sensitivity

func _physics_process(delta):
	_handle_movement(delta)
	_update_flashlight(delta)
	_check_maze_interactions()

func _handle_movement(delta):
	"""Handle player movement with grid constraints"""
	var input_vector = Vector2.ZERO
	
	# Get input direction
	if Input.is_action_pressed("move_forward"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_back"):
		input_vector.y += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	# Apply movement cooldown
	if Time.get_time_from_start() - last_move_time < move_cooldown:
		return
	
	if input_vector.length() > 0:
		_attempt_grid_movement(input_vector.normalized())

func _attempt_grid_movement(direction: Vector2):
	"""Attempt to move to adjacent grid cell"""
	var new_grid_pos = grid_position
	
	# Determine grid movement direction
	if abs(direction.x) > abs(direction.y):
		new_grid_pos.x += 1 if direction.x > 0 else -1
	else:
		new_grid_pos.y += 1 if direction.y > 0 else -1
	
	# Check if movement is valid with maze
	var maze_manager = get_node("/root/MazeManager")
	if maze_manager and maze_manager.can_move(grid_position.x, grid_position.y, new_grid_pos.x, new_grid_pos.y):
		grid_position = new_grid_pos
		_update_world_position()
		last_move_time = Time.get_time_from_start()
		
		# Check for weird things at new position
		_check_weird_things_collection()

func _update_world_position():
	"""Update 3D world position based on grid position"""
	var world_pos = Vector3(
		grid_position.x * grid_size,
		global_position.y,  # Keep current Y
		grid_position.y * grid_size
	)
	global_position = world_pos

func _check_weird_things_collection():
	"""Check if player stepped on a weird thing"""
	var weird_things_manager = get_node("/root/WeirdThingsManager")
	if weird_things_manager:
		var weird_thing = weird_things_manager.check_collection_at_position(grid_position)
		if not weird_thing.is_empty():
			weird_things_manager.collect_weird_thing(weird_thing)

func _update_flashlight(delta):
	"""Update flashlight battery and effects"""
	if flashlight_enabled and flashlight.visible:
		flashlight_battery = max(0.0, flashlight_battery - flashlight_drain_rate * delta)
		
		if flashlight_battery <= 0.0:
			_toggle_flashlight()
			_show_message("Flashlight battery died!")
	
	_update_flashlight_state()

func _update_flashlight_state():
	"""Update flashlight visual state based on battery"""
	if flashlight_enabled and flashlight_battery > 0.0:
		flashlight.visible = true
		
		# Dim light as battery drains
		var battery_ratio = flashlight_battery / flashlight_battery_max
		flashlight.light_energy = battery_ratio * 2.0
		
		# Flicker when battery is low
		if battery_ratio < 0.2:
			if randf() < 0.1:  # 10% chance to flicker
				flashlight.visible = false
				await get_tree().create_timer(0.1).timeout
				flashlight.visible = true
	else:
		flashlight.visible = false

func _toggle_flashlight():
	"""Toggle flashlight on/off"""
	if flashlight_battery > 0.0:
		flashlight_enabled = !flashlight_enabled
		_update_flashlight_state()

func _check_maze_interactions():
	"""Check for interactions with maze elements"""
	# Check exit trigger
	var game_director = get_node("/root/GameDirector")
	if game_director:
		# TODO: Check if at exit position
		pass
	
	# Update visibility for fog of war
	_update_visibility()

func _update_visibility():
	"""Update what the player can see (fog of war)"""
	var maze_manager = get_node("/root/MazeManager")
	if not maze_manager:
		return
	
	# TODO: Implement fog of war system
	# This would involve revealing nearby cells and hiding distant ones

func _show_message(text: String):
	"""Show a message to the player"""
	print("PLAYER: ", text)
	# TODO: Connect to UI system

func take_damage(amount: int, source: String):
	"""Handle player taking damage (sanity loss)"""
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.apply_sanity_loss_event(source, amount)

func get_world_position() -> Vector3:
	"""Get current world position"""
	return global_position

func get_grid_position() -> Vector2i:
	"""Get current grid position"""
	return grid_position

func set_grid_position(new_pos: Vector2i):
	"""Set grid position and update world position"""
	grid_position = new_pos
	_update_world_position()

# Flashlight API
func get_flashlight_battery_ratio() -> float:
	return flashlight_battery / flashlight_battery_max

func is_flashlight_enabled() -> bool:
	return flashlight_enabled and flashlight_battery > 0.0

func add_battery(amount: float):
	"""Add battery charge (from pickup items)"""
	flashlight_battery = min(flashlight_battery_max, flashlight_battery + amount)
	_show_message("Flashlight battery recharged!")

# For other entities to reference player position
func _on_area_entered(area):
	"""Handle area triggers (for exit detection, etc.)"""
	if area.is_in_group("exit_trigger"):
		var game_director = get_node("/root/GameDirector")
		if game_director:
			game_director.end_game("Harvested", Vector2(grid_position.x, grid_position.y))
