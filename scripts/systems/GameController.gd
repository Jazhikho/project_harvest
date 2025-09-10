extends Node3D

@onready var pause_menu = $UI/PauseMenu
@onready var inventory_ui = $UI/InventoryUI
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var animation_player = $TransitionLayer/AnimationPlayer

var game_paused = false
var inventory_open = false

func _ready():
	# Start with fade in
	fade_in()
	
	# Connect signals
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	
	if inventory_ui:
		inventory_ui.closed.connect(_on_inventory_closed)
	
	# IMPORTANT: Trigger initial tile generation after scene is fully loaded
	call_deferred("_initialize_game")

func _initialize_game():
	
	var tile_manager = get_node_or_null("/root/TileManager")
	if tile_manager and tile_manager.has_method("initialize_game_tiles"):
		print("GameController: Telling TileManager to initialize game tiles")
		tile_manager.initialize_game_tiles()
	# Make sure MessageBus knows game started
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus:
		message_bus.emit_event("game_started", [])
	
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
	
	# Only allow pause if inventory isn't open
	if event.is_action_pressed("ui_cancel") and not inventory_open and not game_paused:
		toggle_pause()

func toggle_pause():
	game_paused = !game_paused
	pause_menu.visible = game_paused
	get_tree().paused = game_paused
	get_node("/root/TileManager").debug_check_start_tile()
	
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

func _on_inventory_closed():
	inventory_open = false
	get_tree().paused = false

func _on_main_menu_requested():
	print("GameController: Main menu requested, terminating subject")
	# Record death before leaving
	_terminate_subject("Abandoned")
	
	fade_out()
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false
	SceneManager.load_main_menu()

func _on_quit_requested():
	print("GameController: Quit requested, terminating subject")
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

func trigger_death(death_type: String):
	print("GameController: Triggering death screen for: ", death_type)
	
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
