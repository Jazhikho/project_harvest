extends Node3D

@onready var pause_menu = $UI/PauseMenu
@onready var inventory_ui = $UI/InventoryUI
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var animation_player = $TransitionLayer/AnimationPlayer

var game_paused = false
var inventory_open = false

func _ready():
	
	# Connect signals
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	
	if inventory_ui:
		inventory_ui.closed.connect(_on_inventory_closed)
	
	# IMPORTANT: Trigger initial tile generation after scene is fully loaded
	call_deferred("_initialize_game")
	
	get_tree().get_root().focus_entered.connect(_on_window_focus_entered)
	get_tree().get_root().focus_exited.connect(_on_window_focus_exited)

	# Start with fade in
	fade_in()
	
func _on_window_focus_entered():
	"""Recapture mouse when window regains focus"""
	if not game_paused and not inventory_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_window_focus_exited():
	"""Release mouse when window loses focus"""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(what: int) -> void:
	"""Handle window close requests as death events"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Record death before quitting
		_terminate_subject("Force Quit")
		# Allow the quit to proceed after recording death
		get_tree().quit()

func _initialize_game():
	
	var tile_manager = get_node_or_null("/root/TileManager")
	if tile_manager and tile_manager.has_method("initialize_game_tiles"):
		tile_manager.initialize_game_tiles()
	# Make sure MessageBus knows game started
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus:
		message_bus.emit_event("game_started", [])
		
		# Connect to player death events
		if message_bus.has_signal("player_died"):
			message_bus.player_died.connect(_on_player_died)
	
	# Give TileManager a moment to finish initialization
	await get_tree().create_timer(0.1).timeout
	
	# Force initial tile connections
	if tile_manager:
		# Get the start tile
		var start_tile = $MazeContainer/StartTile
		if start_tile:
			# Force spawn connections from start tile
			tile_manager._spawn_tile_connections(start_tile, Vector2i(0, 0))
		else:
			push_error("GameController: Start tile not found!")
			
func _verify_mouse_capture():
	"""Verify mouse is actually captured, force it if not"""
	if not game_paused and not inventory_open:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			print("Mouse not captured, forcing capture...")
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Debug: Test narration system with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		var narrative_system = get_node_or_null("/root/NarrativeSystem")
		if narrative_system and narrative_system.has_method("test_narration"):
			narrative_system.test_narration()
		get_viewport().set_input_as_handled()
		return
	
	# Inventory takes priority over pause
	if event.is_action_pressed("inventory"):
		if not game_paused:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		return
	
	# Handle ESC - if inventory is open, let it handle it first
	if event.is_action_pressed("ui_cancel"):
		if inventory_open:
			# Let the inventory handle it, don't do anything here
			get_viewport().set_input_as_handled()
			return
		elif not game_paused:
			toggle_pause()
			get_viewport().set_input_as_handled()
	
func toggle_pause():
	game_paused = !game_paused
	pause_menu.visible = game_paused
	get_tree().paused = game_paused
	
	if game_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_menu.show_menu()
	else:
		# Wait for pause state to fully clear before capturing mouse
		await get_tree().process_frame
		await get_tree().process_frame  # Wait 2 frames to be sure
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
func _force_mouse_capture():
	"""Force mouse capture with multiple attempts"""
	if not game_paused and not inventory_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # Reset first
		await get_tree().process_frame  # Wait a frame
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Then capture
		
		# Double-check after another frame
		await get_tree().process_frame
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_inventory():
	inventory_open = !inventory_open
	get_tree().paused = inventory_open
	
	if inventory_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		inventory_ui.show_inventory()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		inventory_ui.hide_inventory()
		# Force mouse capture after a brief delay
		call_deferred("_ensure_mouse_captured")

func _on_resume_requested():
	toggle_pause()
	# Ensure mouse is captured after resume
	call_deferred("_ensure_mouse_captured")

func _on_inventory_closed():
	inventory_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Force mouse capture after a brief delay
	call_deferred("_ensure_mouse_captured")

func _on_main_menu_requested():
	# Record death before leaving
	_terminate_subject("Abandoned")
	
	fade_out()
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false
	SceneManager.load_main_menu()

func _on_quit_requested():
	# Record death and show death screen
	_terminate_subject("Terminated")
	
	fade_out()
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false
	SceneManager.load_death_screen("Terminated")

func _terminate_subject(cause: String):
	"""Handle subject termination for quit/main menu"""
	var message_bus = get_node_or_null("/root/MessageBus")
	var state_manager = get_node_or_null("/root/GameStateManager")
	
	if message_bus and state_manager:
		var current_pos = state_manager.get_state("current_tile_position")
		var death_data = {
			"voluntary": true,
			"cause": cause
		}
		message_bus.emit_event("player_died", [cause, current_pos, death_data])
		
		# Also save/record the death
		if cause == "Terminated":
			SaveManager.record_death()

func fade_in():
	var tween = create_tween()
	fade_rect.color.a = 1.0
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _on_player_died(cause: String, death_position: Vector2i, death_data: Dictionary):
	"""Handle player death event from MessageBus"""
	trigger_death(cause)

func trigger_death(death_type: String):
	
	# Make sure game isn't paused
	get_tree().paused = false
	
	# Hide UI elements
	if pause_menu:
		pause_menu.visible = false
	if inventory_ui:
		inventory_ui.visible = false
	
	# Fade out and load death screen
	fade_out()
	await get_tree().create_timer(0.5).timeout
	SceneManager.load_death_screen(death_type)

func _ensure_mouse_captured():
	"""Ensure mouse is captured for gameplay"""
	if not game_paused and not inventory_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
