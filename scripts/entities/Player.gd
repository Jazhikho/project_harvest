extends CharacterBody3D
## Player Controller - Simplified movement and interaction
## State tracking delegated to appropriate systems

@export var movement_speed: float = 4.5
@export var sprint_mult: float = 1.6
@export var mouse_sensitivity: float = 0.003
@export var controller_look_sensitivity: float = 2.5
@export var flashlight_battery_max: float = GameConstants.FLASHLIGHT_BATTERY_MAX
@export var flashlight_drain_rate: float = 1.0
@export var sfx_lib: SFX

# Flashlight system
var flashlight_battery: float
var flashlight_enabled: bool = false
var flashlight_battery_died: bool = false # Track if battery died (for one-time sanity loss)
var darkness_timer: float = 0.0 # Timer for darkness sanity drain
var game_timer: float = 0.0 # Total game time elapsed

# Audio state tracking
var walking_player: AudioStreamPlayer3D
var sprinting_player: AudioStreamPlayer3D
var heartbeat_player: AudioStreamPlayer3D
var whisper_players: Array[AudioStreamPlayer3D] = []
var scream_players: Array[AudioStreamPlayer3D] = []
var _whisper_timer: Timer
var _whispers_active: bool = false

# Audio state tracking
var is_moving: bool = false
var is_sprinting: bool = false

# Component references
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight

# System references
var _message_bus: Node
var _state_manager: Node
var _save_manager: Node
var _game_controller: Node

# Input handling
var mouse_captured: bool = false
var debug_mode: bool = false
var _nearby_interactables: Dictionary = {}
var _sprint_toggled: bool = true

# Health system
var last_sanity_state: String = "normal"

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
	call_deferred("_setup_audio_players")
	
	# Initialize flashlight
	flashlight_battery = randf_range(GameConstants.FLASHLIGHT_BATTERY_MIN, GameConstants.FLASHLIGHT_BATTERY_MAX)
	flashlight_battery_max = flashlight_battery
	_update_flashlight_state()

func _initialize_systems() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_save_manager = get_node_or_null("/root/SaveManager")
	_game_controller = get_node_or_null("/root/Game/GameController")
	
	if not _message_bus:
		push_error("Player: MessageBus not found")
		return
	
	_connect_to_events()
	
	# Notify systems of player spawn
	_message_bus.emit_event("player_spawned", [self])

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.game_ended.connect(_on_game_ended)
	_message_bus.game_started.connect(_on_game_started)
	
func _make_player3d(name_str: String) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.name = name_str
	p.bus = "SFX"
	p.attenuation_filter_cutoff_hz = 20500.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	return p

func _enable_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream.has_method("set_loop"):
		stream.call("set_loop", true)
	elif "loop" in stream:
		stream.loop = true

## _setup_audio_players
## Purpose: Create and configure movement/heartbeat/whisper/scream audio players.
## @return void.
func _setup_audio_players() -> void:
	# Ensure SFX bus exists just in case
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("_ensure_core_buses"):
		audio_manager._ensure_core_buses()

	# Create core players if missing
	if walking_player == null or not is_instance_valid(walking_player):
		walking_player = _make_player3d("WalkingPlayer")
	if sprinting_player == null or not is_instance_valid(sprinting_player):
		sprinting_player = _make_player3d("SprintingPlayer")
	if heartbeat_player == null or not is_instance_valid(heartbeat_player):
		heartbeat_player = _make_player3d("HeartbeatPlayer")

	# Assign streams from SFX library
	if sfx_lib:
		if sfx_lib.walking is AudioStream:
			walking_player.stream = sfx_lib.walking
		if sfx_lib.sprinting is AudioStream:
			sprinting_player.stream = sfx_lib.sprinting
		if "heartbeat" in sfx_lib and sfx_lib.heartbeat is AudioStream:
			heartbeat_player.stream = sfx_lib.heartbeat

	_enable_loop(walking_player.stream)
	_enable_loop(sprinting_player.stream)
	_enable_loop(heartbeat_player.stream)

	# Prepare whispers: up to 4 players, each with a different whisper
	var whisper_count: int = 0
	if sfx_lib:
		whisper_count = sfx_lib.whispers.size()
	var max_whispers: int = min(4, whisper_count)
	# Create missing players
	while whisper_players.size() < max_whispers:
		var wp: AudioStreamPlayer3D = _make_player3d("WhisperPlayer_%d" % whisper_players.size())
		whisper_players.append(wp)
	# Assign streams
	for i in range(max_whispers):
		whisper_players[i].stream = sfx_lib.whispers[i]
		_enable_loop(whisper_players[i].stream)

	# Prepare screams similarly
	var scream_count: int = 0
	if sfx_lib:
		scream_count = sfx_lib.screams.size()
	var max_screams: int = min(4, scream_count)
	while scream_players.size() < max_screams:
		var sp: AudioStreamPlayer3D = _make_player3d("ScreamPlayer_%d" % scream_players.size())
		scream_players.append(sp)
	for i in range(max_screams):
		scream_players[i].stream = sfx_lib.screams[i]
		# Screams are usually one-shots; do not loop.

	# Timer for whispers
	if _whisper_timer == null or not is_instance_valid(_whisper_timer):
		_whisper_timer = Timer.new()
		_whisper_timer.name = "WhisperTimer"
		_whisper_timer.one_shot = true
		add_child(_whisper_timer)
		_whisper_timer.timeout.connect(_play_random_whisper)

func _notification(what: int) -> void:
	"""Handle window focus notifications and quit requests"""
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Recapture mouse when window regains focus
		# Small delay to ensure window is fully active
		await get_tree().create_timer(0.1).timeout
		# Only recapture if we should have mouse captured and game isn't paused
		if mouse_captured and get_tree().paused == false and not _is_ui_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Release mouse when window loses focus to prevent it getting stuck
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Handle force quit scenarios - record as death
		_handle_force_quit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and mouse_captured:
			if not get_tree().paused and not _is_ui_open():
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		debug_mode = !debug_mode
		return
	if event is InputEventMouseMotion and mouse_captured and not _is_ui_open():
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("toggle_flashlight"):
		_toggle_flashlight()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("sprint"):
		_handle_sprint_input()
	if debug_mode and event is InputEventKey and event.pressed:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var digit = event.keycode - KEY_0
			var new_sanity = digit * 10
			if _state_manager:
				var current_sanity = _state_manager.get_state("sanity")
				var delta = new_sanity - current_sanity
				_state_manager.modify_sanity(delta)
	if event is InputEventKey and event.pressed and event.is_action_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		if mouse_captured and not _is_ui_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _handle_mouse_look(relative_motion: Vector2) -> void:
	camera.rotation.x = clamp(camera.rotation.x - relative_motion.y * mouse_sensitivity, -PI / 2, PI / 2)
	rotation.y -= relative_motion.x * mouse_sensitivity

func _handle_controller_look(delta: float) -> void:
	if not mouse_captured or _is_ui_open():
		return
	var look_vector: Vector2 = InputManager.get_look_vector()
	if look_vector == Vector2.ZERO:
		return
	camera.rotation.x = clamp(camera.rotation.x + look_vector.y * controller_look_sensitivity * delta, -PI / 2, PI / 2)
	rotation.y -= look_vector.x * controller_look_sensitivity * delta

func _handle_sprint_input() -> void:
	if _is_hold_to_sprint_enabled():
		return
	_sprint_toggled = not _sprint_toggled

func _is_hold_to_sprint_enabled() -> bool:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	return settings_manager != null and bool(settings_manager.get_setting("controls", "hold_to_sprint"))

func _is_sprint_requested() -> bool:
	if _is_hold_to_sprint_enabled():
		return InputManager.is_action_pressed("sprint")
	return _sprint_toggled

func register_nearby_interactable(node: Node) -> void:
	if node == null:
		return
	_nearby_interactables[node.get_instance_id()] = node

func unregister_nearby_interactable(node: Node) -> void:
	if node == null:
		return
	_nearby_interactables.erase(node.get_instance_id())

func _get_best_nearby_interactable() -> Node:
	var closest_node: Node = null
	var closest_distance: float = INF
	var stale_ids: Array[int] = []
	for interactable_id in _nearby_interactables.keys():
		var candidate: Node = _nearby_interactables[interactable_id]
		if not is_instance_valid(candidate):
			stale_ids.append(interactable_id)
			continue
		if not (candidate is Node3D):
			continue
		var candidate_3d := candidate as Node3D
		var distance: float = global_position.distance_to(candidate_3d.global_position)
		if distance <= 2.5 and distance < closest_distance:
			closest_distance = distance
			closest_node = candidate
	for stale_id in stale_ids:
		_nearby_interactables.erase(stale_id)
	return closest_node

func _resolve_parent_puzzle(node: Node) -> Node:
	if node == null:
		return null
	if node.has_meta("parent_puzzle"):
		var parent_puzzle: Variant = node.get_meta("parent_puzzle")
		if parent_puzzle is Node and is_instance_valid(parent_puzzle):
			return parent_puzzle
	return null

func _resolve_interaction_target(collider: Node) -> Node:
	var current: Node = collider
	while current:
		var parent_puzzle: Node = _resolve_parent_puzzle(current)
		if parent_puzzle:
			return current
		if current.has_method("interact") or current.has_method("get_pickup_prompt_text"):
			return current
		if current.has_meta("is_collectible") or current.has_meta("is_backpack") or current.has_meta("is_puzzle") or current.has_meta("is_puzzle_part") or current.has_meta("is_interactable"):
			return current
		current = current.get_parent()
	return collider

func _is_ui_open() -> bool:
	"""
	Check if any UI menu is currently open
	
	@return bool: True if any UI is open
	"""
	# If game is paused, assume UI is open
	if get_tree().paused:
		return true
	
	var game_controller = get_node_or_null("/root/Game/GameController")
	if not game_controller:
		return false
	
	# Check pause menu
	if _game_controller.get("game_paused") and _game_controller.pause_menu and _game_controller.pause_menu.visible:
		return true
	
	# Check inventory
	if game_controller.get("inventory_open") and game_controller.inventory_ui and game_controller.inventory_ui.visible:
		return true
	
	# Check journal
	if _game_controller.get("journal_open") and _game_controller.journal_ui and _game_controller.journal_ui.visible:
		return true
	
	# Check narrative UI
	if game_controller.narrative_ui and game_controller.narrative_ui.visible:
		return true
	
	return false

func ensure_mouse_capture_state() -> void:
	"""
	Ensure mouse capture state is correct based on current game state
	Should be called when game state changes
	"""
	# If game is paused, always use visible mouse
	if get_tree().paused:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	# When resuming from pause, restore mouse capture state
	if not _is_ui_open():
		mouse_captured = true
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# UI is open, keep mouse visible
		mouse_captured = false
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	game_timer += delta
	_handle_controller_look(delta)
	_handle_movement(delta)
	_update_flashlight(delta)
	_check_interactions()
	_update_sanity_audio()
	
func _handle_movement(delta: float) -> void:
	var movement_input: Vector2 = InputManager.get_movement_vector()
	var input_dir: Vector3 = (transform.basis.x * movement_input.x) + (transform.basis.z * movement_input.y)
	var was_moving = is_moving
	var was_sprinting = is_sprinting
	is_moving = movement_input.length() > 0.0
	is_sprinting = is_moving and _is_sprint_requested()
	if is_moving:
		var speed: float = movement_speed
		if is_sprinting:
			speed *= sprint_mult
		velocity = input_dir.normalized() * speed
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	_update_movement_audio(was_moving, was_sprinting)

func _update_movement_audio(was_moving: bool, was_sprinting: bool) -> void:
	"""Update movement audio based on current state"""
	if not walking_player or not sprinting_player:
		return
	
	# Handle sprinting audio
	if is_sprinting and not was_sprinting:
		walking_player.stop()
		if not sprinting_player.playing:
			sprinting_player.play()
	elif not is_sprinting and was_sprinting:
		sprinting_player.stop()
	
	# Handle walking audio  
	if is_moving and not is_sprinting and not was_moving:
		sprinting_player.stop()
		if not walking_player.playing:
			walking_player.play()
	elif not is_moving and was_moving:
		walking_player.stop()
		sprinting_player.stop()

func _check_interactions() -> void:
	var interaction_target: Node = _get_raycast_interaction_target()
	if interaction_target:
		_show_interaction_prompt(interaction_target)
		return
	interaction_target = _get_best_nearby_interactable()
	if interaction_target:
		_show_interaction_prompt(interaction_target)

func _get_raycast_interaction_target() -> Node:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 3.0
	)
	CollisionHelper.setup_interaction_raycast(query)
	var result: Dictionary = space_state.intersect_ray(query)
	if result and result.has("collider"):
		return _resolve_interaction_target(result.collider)
	return null

func _try_interact() -> void:
	var interaction_target: Node = _get_raycast_interaction_target()
	if interaction_target == null:
		interaction_target = _get_best_nearby_interactable()
	if interaction_target == null:
		return
	if interaction_target.has_method("interact"):
		interaction_target.interact()
		return
	_interact_with_object(interaction_target)

func _interact_with_object(obj: Node) -> void:
	"""
	Interact with a specific object
	
	@param obj: Object to interact with
	"""
	var current_tile: Vector2i = Vector2i.ZERO
	if _state_manager:
		current_tile = _state_manager.get_state("current_tile_position")
	
	# Check the parent node first if this is a collision body
	var check_node: Node = obj
	if obj is CollisionObject3D:
		var parent_node = obj.get_parent()
		if parent_node and parent_node.has_meta("is_collectible"):
			check_node = parent_node

	var parent_puzzle: Node = _resolve_parent_puzzle(check_node)
	if parent_puzzle:
		var interaction_type: String = str(check_node.get_meta("interaction_type", ""))
		if interaction_type == "altar" and parent_puzzle.has_method("interact_with_altar"):
			parent_puzzle.interact_with_altar()
			return
		if interaction_type == "brazier" and parent_puzzle.has_method("interact_with_brazier"):
			parent_puzzle.interact_with_brazier()
			return
		if parent_puzzle.has_method("interact"):
			parent_puzzle.interact()
			return
	
	# Handle item collection
	if check_node.has_meta("is_collectible"):
		# Try to call interact method if available
		if check_node.has_method("interact"):
			check_node.interact()
		else:
			# Fallback to event system
			var item_id: String = check_node.get_meta("item_id", "")
			if not item_id.is_empty():
				_message_bus.emit_event("item_collected", [item_id, self, current_tile])
		return
	
	# Handle backpack interaction
	if check_node.has_meta("is_backpack"):
		var inventory: Array = check_node.get_meta("inventory", [])
		_collect_backpack_contents(inventory)
		check_node.queue_free()
		return
	
	# Handle puzzle interaction
	if check_node.has_meta("is_puzzle"):
		var puzzle_id: String = check_node.get_meta("puzzle_id", "")
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
	if not _message_bus or obj == null:
		return
	var prompt_text: String = ""
	if obj.has_method("get_pickup_prompt_text"):
		prompt_text = obj.get_pickup_prompt_text()
	elif obj.has_meta("is_collectible"):
		prompt_text = "pick up"
	elif obj.has_meta("is_backpack"):
		prompt_text = "search backpack"
	elif obj.has_meta("is_puzzle"):
		prompt_text = "interact"
	elif obj.has_meta("is_puzzle_part"):
		prompt_text = "interact"
	elif obj.has_meta("is_interactable"):
		prompt_text = "interact"
	if not prompt_text.is_empty():
		_message_bus.emit_event("show_interaction_prompt", [prompt_text, obj])

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
				if _state_manager:
					# Delay next action for 2 seconds after flashlight battery dies
					await get_tree().create_timer(2.0).timeout
					_state_manager.modify_sanity(-100)
			
			_toggle_flashlight()
	
	# Handle darkness sanity drain (1 sanity per 5 seconds when flashlight is off)
	# Only start draining sanity after 4 minutes (240 seconds) of game time
	if game_timer >= GameConstants.DARKNESS_SANITY_GRACE_PERIOD and (not flashlight_enabled or flashlight_battery <= 0.0):
		darkness_timer += delta
		if darkness_timer >= 5.0: # 5 seconds
			darkness_timer = 0.0
			if _state_manager:
				_state_manager.modify_sanity(-1)
	else:
		# Reset timer when flashlight is on or before grace period
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
	if _save_manager and _save_manager.has_method("record_death"):
		_save_manager.record_death()

func die(cause: String) -> void:
	"""
	Handle player death
	
	@param cause: Cause of death
	"""
	
	var current_tile: Vector2i = Vector2i.ZERO
	if _state_manager:
		current_tile = _state_manager.get_state("current_tile_position")
	
	var death_data: Dictionary = {
		"position": current_tile,
		"world_position": global_position,
		"cause": cause,
		"battery": flashlight_battery
	}
	
	# Disable input
	mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Emit death event
	_message_bus.emit_event("player_died", [cause, current_tile, death_data])
func use_inventory_item(item_id: String) -> bool:
	"""
	Use an item from inventory
	
	@param item_id: ID of item to use
	@return: True if item was used successfully
	"""
	if _state_manager and _state_manager.has_method("has_item") and _state_manager.has_item(item_id):
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

func reset_for_new_run() -> void:
	"""Reset player state for new game run"""
	# Reset flashlight state
	flashlight_battery = randf_range(GameConstants.FLASHLIGHT_BATTERY_MIN, GameConstants.FLASHLIGHT_BATTERY_MAX)
	flashlight_battery_max = flashlight_battery
	flashlight_battery_died = false
	flashlight_enabled = false
	darkness_timer = 0.0
	game_timer = 0.0
	_sprint_toggled = true
	
	# Reset audio state
	last_sanity_state = "normal"
	
	# Update flashlight visual state
	_update_flashlight_state()

func is_flashlight_enabled() -> bool:
	"""Check if flashlight is enabled and has battery"""
	return flashlight_enabled and flashlight_battery > 0.0

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
	var camera_forward = - camera.global_transform.basis.z
	
	# Check if target is within field of view
	var dot_product = camera_forward.dot(to_target)
	var angle = acos(clamp(dot_product, -1.0, 1.0))
	var fov_radians = deg_to_rad(fov_degrees * 0.5) # Half FOV for comparison
	
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

func _on_game_started() -> void:
	"""Handle game start - reset player state for new run"""
	reset_for_new_run()

func _update_sanity_audio() -> void:
	if heartbeat_player == null:
		return

	if _state_manager == null:
		return

	var current_sanity: int = _state_manager.get_state("sanity")
	var current_state: String = _get_sanity_state(current_sanity)

	# Heartbeat control
	if current_state == "critical":
		if not heartbeat_player.playing:
			heartbeat_player.play()
	else:
		if heartbeat_player.playing:
			heartbeat_player.stop()

	# Whispers: start timer when entering low/critical, stop when leaving
	if current_state != "high":
		if not _whispers_active:
			_whispers_active = true
			if current_state == "normal":
				_whisper_timer.start(randf_range(15.0, 45.0))
			elif current_state == "low":
				_whisper_timer.start(randf_range(5.0, 15.0))
			elif current_state == "critical":
				_whisper_timer.start(randf_range(1.0, 5.0))
	else:
		if _whispers_active:
			_whispers_active = false
			_whisper_timer.stop()
			for p in whisper_players:
				if p.playing:
					p.stop()

	# Scream at zero
	if current_sanity <= 0 and last_sanity_state != "zero":
		_play_scream()

	last_sanity_state = current_state
	
func _get_sanity_state(sanity: int) -> String:
	"""Get sanity state name based on value"""
	if sanity <= 0:
		return "zero"
	elif sanity <= GameConstants.SANITY_THRESHOLD_CRITICAL:
		return "critical"
	elif sanity <= GameConstants.SANITY_THRESHOLD_LOW:
		return "low"
	elif sanity <= GameConstants.SANITY_THRESHOLD_MEDIUM:
		return "normal"
	else:
		return "high"

func _play_random_whisper() -> void:
	if not _whispers_active:
		return
	if whisper_players.is_empty():
		return

	var idx: int = randi() % whisper_players.size()
	var player: AudioStreamPlayer3D = whisper_players[idx]

	# Stop others
	for p in whisper_players:
		if p != player and p.playing:
			p.stop()

	player.play()

	# Schedule next one
	_whisper_timer.start(randf_range(15.0, 45.0))

func _play_scream() -> void:
	"""Play a random scream once"""
	if scream_players.is_empty():
		return

	# Pick one at random
	var idx: int = randi() % scream_players.size()
	var player: AudioStreamPlayer3D = scream_players[idx]

	# Stop any currently running scream
	for p in scream_players:
		if p.playing:
			p.stop()

	player.play()
