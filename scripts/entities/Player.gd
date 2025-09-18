extends CharacterBody3D
## Player Controller - Simplified movement and interaction
## State tracking delegated to appropriate systems

@export var movement_speed: float = 4.5
@export var sprint_mult: float = 1.6
@export var mouse_sensitivity: float = 0.003
@export var flashlight_battery_max: float = 300.0
@export var flashlight_drain_rate: float = 1.0

# Flashlight system
var flashlight_battery: float
var flashlight_enabled: bool = true
var flashlight_battery_died: bool = false  # Track if battery died (for one-time sanity loss)
var darkness_timer: float = 0.0  # Timer for darkness sanity drain

# Component references
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var flashlight_mesh: MeshInstance3D = $Camera3D/FlashlightMesh

# System references
var _message_bus: Node

# Input handling
var mouse_captured: bool = false
var debug_mode: bool = false

# Health system
var health: int = 100

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	
	# Set collision properties using CollisionHelper
	CollisionHelper.setup_player_collision(self)
	
	# Initialize mouse capture
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	
	# Initialize systems after scene is ready
	call_deferred("_initialize_systems")
	
	# Initialize flashlight
	flashlight_battery = randf_range(60.0, 300.0)
	flashlight_battery_max = flashlight_battery
	_update_flashlight_state()

func _initialize_systems() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	
	if not _message_bus:
		push_error("Player: MessageBus not found")
		return
	
	_connect_to_events()
	
	# Notify systems of player spawn
	_message_bus.emit_event("player_spawned", [self])

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.game_ended.connect(_on_game_ended)

func _notification(what: int) -> void:
	"""Handle window focus notifications and quit requests"""
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Recapture mouse when window regains focus
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Release mouse when window loses focus to prevent it getting stuck
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Handle force quit scenarios - record as death
		_handle_force_quit()

func _input(event: InputEvent) -> void:
	# Handle mouse recapture on click when mouse is visible
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	
	# Debug mode toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		debug_mode = !debug_mode
		# Debug messages removed - not referencing gameloop steps
		return
	
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	
	if event.is_action_pressed("toggle_flashlight"):
		_toggle_flashlight()
	
	if event.is_action_pressed("interact"):
		_try_interact()
	
	# Debug sanity controls
	if debug_mode and event is InputEventKey and event.pressed:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var digit = event.keycode - KEY_0
			var new_sanity = digit * 10  # 0 = 0%, 1 = 10%, etc.
			var state_manager = get_node_or_null("/root/GameStateManager")
			if state_manager:
				var current_sanity = state_manager.get_state("sanity")
				var delta = new_sanity - current_sanity
				state_manager.modify_sanity(delta)
				# Debug message removed - not referencing gameloop steps
	
	if event.is_action_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

func _handle_mouse_look(relative_motion: Vector2) -> void:
	"""
	Handle mouse look for camera rotation
	
	@param relative_motion: Mouse movement delta
	"""
	camera.rotation.x = clamp(camera.rotation.x - relative_motion.y * mouse_sensitivity, -PI/2, PI/2)
	rotation.y -= relative_motion.x * mouse_sensitivity

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_flashlight(delta)
	_check_interactions()

func _handle_movement(delta: float) -> void:
	"""
	Handle player movement input and physics
	
	@param delta: Frame time delta
	"""
	var input_dir: Vector3 = Vector3.ZERO
	
	if debug_mode:
		# Flight mode
		if Input.is_action_pressed("move_forward"):
			input_dir -= transform.basis.z
		if Input.is_action_pressed("move_back"):
			input_dir += transform.basis.z
		if Input.is_action_pressed("move_left"):
			input_dir -= transform.basis.x
		if Input.is_action_pressed("move_right"):
			input_dir += transform.basis.x
		# Z to go up, C to go down
		if Input.is_key_pressed(KEY_Z):
			input_dir += Vector3.UP
		if Input.is_key_pressed(KEY_C):
			input_dir += Vector3.DOWN
		
		if input_dir.length() > 0:
			global_position += input_dir.normalized() * movement_speed * delta * 3.0
		
		velocity = Vector3.ZERO
	else:
		# Normal movement with collision
		if Input.is_action_pressed("move_forward"):
			input_dir -= transform.basis.z
		if Input.is_action_pressed("move_back"):
			input_dir += transform.basis.z
		if Input.is_action_pressed("move_left"):
			input_dir -= transform.basis.x
		if Input.is_action_pressed("move_right"):
			input_dir += transform.basis.x
		
		if input_dir.length() > 0:
			var speed: float = movement_speed
			if Input.is_action_pressed("sprint"):
				speed *= sprint_mult
			
			velocity = input_dir.normalized() * speed
			move_and_slide()

func _check_interactions() -> void:
	"""Check for nearby interactive objects"""
	# Cast ray to check for interactables
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 2.0
	)
	CollisionHelper.setup_interaction_raycast(query)
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var collider: Node = result.collider
		_show_interaction_prompt(collider)

func _try_interact() -> void:
	"""Attempt to interact with object in front of player"""
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 2.0
	)
	CollisionHelper.setup_interaction_raycast(query)
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var collider: Node = result.collider
		_interact_with_object(collider)

func _interact_with_object(obj: Node) -> void:
	"""
	Interact with a specific object
	
	@param obj: Object to interact with
	"""
	var state_manager = get_node_or_null("/root/GameStateManager")
	var current_tile = Vector2i.ZERO
	if state_manager:
		current_tile = state_manager.get_state("current_tile_position")
	
	# Handle item collection
	if obj.has_meta("is_collectible"):
		var item_id: String = obj.get_meta("item_id", "")
		if not item_id.is_empty():
			_message_bus.emit_event("item_collected", [item_id, self, current_tile])
			return
	
	# Handle backpack interaction
	if obj.has_meta("is_backpack"):
		var inventory: Array = obj.get_meta("inventory", [])
		_collect_backpack_contents(inventory)
		obj.queue_free()
		return
	
	# Handle puzzle interaction
	if obj.has_meta("is_puzzle"):
		var puzzle_id: String = obj.get_meta("puzzle_id", "")
		_message_bus.emit_event("puzzle_started", [puzzle_id, current_tile])
		return
	
	# Generic interaction
	_message_bus.emit_event("player_interacted", [obj, "use"])

func _collect_backpack_contents(inventory: Array) -> void:
	"""
	Collect items from backpack
	
	@param inventory: Array of item IDs in backpack
	"""
	var state_manager = get_node_or_null("/root/GameStateManager")
	var current_tile = Vector2i.ZERO
	if state_manager:
		current_tile = state_manager.get_state("current_tile_position")
	
	for item_id in inventory:
		_message_bus.emit_event("item_collected", [item_id, self, current_tile])
	
	if inventory.size() > 0:
		_show_message("Found %d items from a previous explorer..." % inventory.size())

func _show_interaction_prompt(obj: Node) -> void:
	"""
	Show interaction prompt for object
	
	@param obj: Object that can be interacted with
	"""
	if obj.has_meta("is_collectible"):
		# Show collect prompt
		pass
	elif obj.has_meta("is_backpack"):
		# Show backpack prompt
		pass
	elif obj.has_meta("is_puzzle"):
		# Show puzzle prompt
		pass

func _update_flashlight(delta: float) -> void:
	"""
	Update flashlight battery and effects
	
	@param delta: Frame time delta
	"""
	if flashlight_enabled and flashlight.visible:
		flashlight_battery = max(0.0, flashlight_battery - flashlight_drain_rate * delta)
		
		if flashlight_battery <= 0.0:
			# One-time sanity loss when battery dies
			if not flashlight_battery_died:
				flashlight_battery_died = true
				var state_manager = get_node_or_null("/root/GameStateManager")
				if state_manager:
					state_manager.modify_sanity(-10)
					_show_message("Flashlight battery died! The darkness feels oppressive...")
				else:
					_show_message("Flashlight battery died!")
			
			_toggle_flashlight()
	
	# Handle darkness sanity drain (1 sanity per 15 seconds when flashlight is off)
	if not flashlight_enabled or flashlight_battery <= 0.0:
		darkness_timer += delta
		if darkness_timer >= 15.0:  # 15 seconds
			darkness_timer = 0.0
			var state_manager = get_node_or_null("/root/GameStateManager")
			if state_manager:
				state_manager.modify_sanity(-1)
	else:
		# Reset timer when flashlight is on
		darkness_timer = 0.0
	
	_update_flashlight_state()

func _update_flashlight_state() -> void:
	"""Update flashlight visual state based on battery"""
	if flashlight_enabled and flashlight_battery > 0.0:
		flashlight.visible = true
		flashlight.light_energy = 2.0
		
		# Flicker when battery is low
		var battery_ratio: float = flashlight_battery / flashlight_battery_max
		if battery_ratio < 0.2 and randf() < 0.1:
			flashlight.visible = false
			await get_tree().create_timer(0.1).timeout
			if flashlight_enabled:
				flashlight.visible = true
	else:
		flashlight.visible = false

func _toggle_flashlight() -> void:
	"""Toggle flashlight on/off"""
	if flashlight_battery > 0.0:
		flashlight_enabled = !flashlight_enabled
		_update_flashlight_state()

func _show_message(text: String) -> void:
	"""
	Show message to player
	
	@param text: Message text to display
	"""
	_message_bus.emit_event("notification_requested", [text, 3.0, 1])

func _handle_force_quit() -> void:
	"""
	Handle force quit scenarios by recording death
	"""
	# Trigger death with force quit cause
	die("Force Quit")
	
	# Also record death in SaveManager for persistent tracking
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("record_death"):
		save_manager.record_death()

func take_damage(amount: int, source: String = "") -> void:
	"""
	Take damage and potentially die
	
	@param amount: Damage amount
	@param source: Damage source description
	"""
	health -= amount
	
	if health <= 0:
		die(source if not source.is_empty() else "Unknown")

func die(cause: String) -> void:
	"""
	Handle player death
	
	@param cause: Cause of death
	"""
	
	# Prevent multiple death triggers
	if health <= -100:  # Already dead
		return
	
	health = -100  # Mark as dead
	
	var state_manager = get_node_or_null("/root/GameStateManager")
	var current_tile = Vector2i.ZERO
	if state_manager:
		current_tile = state_manager.get_state("current_tile_position")
	
	var death_data: Dictionary = {
		"position": current_tile,
		"world_position": global_position,
		"cause": cause,
		"health": health,
		"battery": flashlight_battery
	}
	
	# Disable input
	mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Emit death event
	_message_bus.emit_event("player_died", [cause, current_tile, death_data])

func heal(amount: int) -> void:
	"""
	Heal player
	
	@param amount: Amount to heal
	"""
	health = min(100, health + amount)
	_show_message("Health restored: +%d" % amount)

func add_battery(amount: float) -> void:
	"""
	Add battery charge
	
	@param amount: Battery amount to add
	"""
	flashlight_battery = min(flashlight_battery_max, flashlight_battery + amount)
	_show_message("Flashlight battery recharged!")

func use_inventory_item(item_id: String) -> bool:
	"""
	Use an item from inventory
	
	@param item_id: ID of item to use
	@return: True if item was used successfully
	"""
	var state_manager = get_node_or_null("/root/GameStateManager")
	if state_manager and state_manager.has_item(item_id):
		_message_bus.emit_event("item_used", [item_id, null, self])
		return true
	return false

# Public API for other systems

func get_world_position() -> Vector3:
	"""Get current world position"""
	return global_position

func get_flashlight_battery_ratio() -> float:
	"""Get flashlight battery as ratio (0.0 to 1.0)"""
	return flashlight_battery / flashlight_battery_max

func is_flashlight_enabled() -> bool:
	"""Check if flashlight is enabled and has battery"""
	return flashlight_enabled and flashlight_battery > 0.0

func get_health() -> int:
	"""Get current health"""
	return health

func is_looking_at_position(target_position: Vector3, fov_degrees: float = 180.0) -> bool:
	"""
	Check if player is looking at a specific world position
	
	@param target_position: World position to check visibility of
	@param fov_degrees: Field of view angle in degrees (default 90)
	@return: True if player is looking at the position
	"""
	if not camera:
		return false
	
	var to_target = (target_position - camera.global_position).normalized()
	var camera_forward = -camera.global_transform.basis.z
	
	# Check if target is within field of view
	var dot_product = camera_forward.dot(to_target)
	var angle = acos(clamp(dot_product, -1.0, 1.0))
	var fov_radians = deg_to_rad(fov_degrees * 0.5)  # Half FOV for comparison
	
	if angle > fov_radians:
		return false
	
	# Raycast to check if there are obstacles
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		target_position
	)
	query.exclude = [self]
	CollisionHelper.setup_visibility_raycast(query)
	
	var result = space_state.intersect_ray(query)
	
	# If ray hits something before reaching target, not visible
	if not result.is_empty():
		var hit_distance = camera.global_position.distance_to(result.position)
		var target_distance = camera.global_position.distance_to(target_position)
		
		# Allow small margin for floating point precision
		return hit_distance >= (target_distance - 0.1)
	
	return true

# Event handlers

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end"""
	mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
