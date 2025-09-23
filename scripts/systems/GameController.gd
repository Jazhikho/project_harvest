extends Node3D

@onready var pause_menu = $UI/PauseMenu
@onready var inventory_ui = $UI/InventoryUI
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var animation_player = $TransitionLayer/AnimationPlayer

@onready var message_bus: Node = get_node_or_null("/root/MessageBus")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")

var enemy_manager: Node
var sanity_manager: Node
var tile_state_manager: Node
var tile_manager: Node
var spawn_manager: Node
var item_manager: Node
var journal_manager: Node
var narrative_system: Node
var player_position_tracker: Node

var game_paused = false
var inventory_open = false

func _ready():
	var controllers_root: Node = get_node("GameControllers")

	enemy_manager = controllers_root.get_node_or_null("EnemyManager")
	sanity_manager = controllers_root.get_node_or_null("SanityManager")
	tile_state_manager = controllers_root.get_node_or_null("TileStateManager")
	tile_manager = controllers_root.get_node_or_null("TileManager")
	spawn_manager = controllers_root.get_node_or_null("SpawnManager")
	item_manager = controllers_root.get_node_or_null("ItemManager")
	journal_manager = controllers_root.get_node_or_null("JournalManager")
	narrative_system = controllers_root.get_node_or_null("NarrativeSystem")
	player_position_tracker = controllers_root.get_node_or_null("PlayerPositionTracker")

	# Connect signals
	pause_menu.resume_requested.connect(_on_resume_requested)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)

	inventory_ui.closed.connect(_on_inventory_closed)

	call_deferred("_setup_manager_access")
	call_deferred("_initialize_game")
	call_deferred("_connect_journal_signals")

	get_tree().get_root().focus_entered.connect(_on_window_focus_entered)
	get_tree().get_root().focus_exited.connect(_on_window_focus_exited)

	await get_tree().process_frame
	fade_in()

func _setup_manager_access():
	"""Set up manager access for other scripts by storing references in MessageBus"""
	if not message_bus:
		push_error("GameController: MessageBus not found during manager setup!")
		return
	
	message_bus.set_meta("tile_manager", tile_manager)
	message_bus.set_meta("journal_manager", journal_manager)
	message_bus.set_meta("item_manager", item_manager)
	message_bus.set_meta("spawn_manager", spawn_manager)
	message_bus.set_meta("sanity_manager", sanity_manager)
	message_bus.set_meta("enemy_manager", enemy_manager)
	message_bus.set_meta("tile_state_manager", tile_state_manager)
	message_bus.set_meta("narrative_system", narrative_system)
	message_bus.set_meta("player_position_tracker", player_position_tracker)

func _connect_journal_signals():
	"""Connect to journal-related signals after initialization"""
	if journal_manager and journal_manager.has_signal("journal_closed"):
		journal_manager.journal_closed.connect(_on_journal_closed)

	
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
		_terminate_subject("Force Quit")
		get_tree().quit()

func _initialize_game():
	if tile_manager and tile_manager.has_method("initialize_game_tiles"):
		tile_manager.initialize_game_tiles()
	
	# Initialize player position tracker after tiles are set up
	if player_position_tracker and player_position_tracker.has_method("set_current_tile_position"):
		player_position_tracker.set_current_tile_position(Vector2i(0, 0))
	
	var result = message_bus.emit_event("game_started", [])
	message_bus.player_died.connect(_on_player_died)
	
	await get_tree().create_timer(0.1).timeout

func _verify_mouse_capture():
	"""Verify mouse is actually captured, force it if not"""
	if not game_paused and not inventory_open:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event.is_action_pressed("inventory"):
		if not game_paused:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		return

	# Journal toggle
	if event.is_action_pressed("journal"):
		if not game_paused:
			if journal_manager and journal_manager.has_method("toggle_open"):
				# Pause state should mirror inventory while journal is open
				if journal_manager.is_open():
					journal_manager.hide_journal()
					get_tree().paused = false
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					journal_manager.show_journal()
					get_tree().paused = true
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				get_viewport().set_input_as_handled()
			return
	
	# Handle ESC - check journal first, then inventory, then pause
	if event.is_action_pressed("ui_cancel"):
		if journal_manager and journal_manager.has_method("is_open") and journal_manager.is_open():
			# Close journal
			journal_manager.hide_journal()
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()
			return
		elif inventory_open:
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
		await get_tree().process_frame # Wait 2 frames to be sure
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
func _force_mouse_capture():
	"""Force mouse capture with multiple attempts"""
	if not game_paused and not inventory_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Reset first
		await get_tree().process_frame # Wait a frame
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Then capture
		
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

func _on_journal_closed():
	"""Handle journal being closed - unpause game and recapture mouse"""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Force mouse capture after a brief delay
	call_deferred("_ensure_mouse_captured")

func _on_main_menu_requested():
	# Record death before leaving
	_terminate_subject("Abandoned")
	
	fade_out()
	await get_tree().create_timer(0.5).timeout
	#get_tree().paused = false
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
	if message_bus and save_manager:
		var current_pos = save_manager.get_state("current_tile_position")
		var death_data = {
			"voluntary": true,
			"cause": cause
		}
		message_bus.emit_event("player_died", [cause, current_pos, death_data])
		
		# Also save/record the death
		if cause == "Terminated":
			SaveManager.record_death(cause, current_pos)

func fade_in():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_rect.color.a = 1.0
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func fade_out():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _on_player_died(cause: String, death_position: Vector2i, death_data: Dictionary):
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

func _set_narrative_pause(paused: bool):
	"""Set the game_paused flag for narrative sequences"""
	game_paused = paused
