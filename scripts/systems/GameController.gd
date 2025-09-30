extends Node3D

@onready var pause_menu = $UI/PauseMenu
@onready var inventory_ui = $UI/InventoryUI
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var animation_player = $TransitionLayer/AnimationPlayer
@onready var journal_ui = $UI/JournalUI
@onready var control_hints = $UI/ControlsUI

var game_paused = false
var inventory_open = false
var journal_open = false

func _ready():
	# Connect signals
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	
	if inventory_ui:
		inventory_ui.closed.connect(_on_inventory_closed)

	if journal_ui:
		journal_ui.closed.connect(_on_journal_closed)
	
	# IMPORTANT: Trigger initial tile generation after scene is fully loaded
	call_deferred("_initialize_game")

	# Start with fade in
	fade_in()
	

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

func _input(event):
	# Inventory takes priority over pause
	if event.is_action_pressed("inventory") and not game_paused:
		toggle_inventory()
		return
	
	if event.is_action_pressed("journal") and not game_paused:
		toggle_journal()
		return
	
	# Only allow pause if inventory isn't open
	if event.is_action_pressed("ui_cancel") and not inventory_open and not journal_open and not game_paused:
		toggle_pause()

func toggle_pause():
	game_paused = !game_paused
	pause_menu.visible = game_paused
	get_tree().paused = game_paused
	pass
	
	if game_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_menu.show_menu()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_inventory():
	inventory_open = !inventory_open
	get_tree().paused = inventory_open
	
	if inventory_open:
		inventory_ui.show_inventory()
	else:
		inventory_ui.hide_inventory()

func _on_resume_requested():
	toggle_pause()
	
func toggle_journal():
	journal_open = !journal_open
	get_tree().paused = journal_open
	
	if journal_open:
		journal_ui.show_journal()
	else:
		journal_ui.hide_journal()

func _on_inventory_closed():
	inventory_open = false
	get_tree().paused = false

func _on_journal_closed():
	journal_open = false
	get_tree().paused = false

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
