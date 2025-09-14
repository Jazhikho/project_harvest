extends Node
## Test script to verify that quitting the game properly records deaths

func _ready():
	# Wait a moment for systems to initialize
	await get_tree().create_timer(1.0).timeout
	
	test_quit_scenarios()

func test_quit_scenarios():
	"""Test different quit scenarios"""
	test_save_data_flow()
	test_menu_quit()
	test_main_menu_return()
	test_force_quit_simulation()

func test_menu_quit():
	"""Test the pause menu quit functionality"""
	var game_controller = get_node_or_null("/root/Game/GameController")
	if game_controller:
		game_controller._terminate_subject("Test Quit")

func test_main_menu_return():
	"""Test the main menu return functionality"""
	var game_controller = get_node_or_null("/root/Game/GameController")
	if game_controller:
		game_controller._terminate_subject("Test Abandon")

func test_force_quit_simulation():
	"""Simulate force quit detection"""
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player._handle_force_quit()
	
	# GameDirector force quit handling
	var game_director = get_node_or_null("/root/GameDirector")
	if game_director:
		# Simulate active game state
		var state_manager = get_node_or_null("/root/GameStateManager")
		if state_manager:
			state_manager.set_state("game_active", true)
			# Simulate the notification
			game_director._notification(NOTIFICATION_WM_CLOSE_REQUEST)

func test_save_data_flow():
	"""Test the save data and continue button logic"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		# Simulate game start
		save_manager._on_game_started()
		# Simulate death
		save_manager.record_death()

func _input(event):
	"""Allow manual testing with key presses"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_menu_quit()
			KEY_2:
				test_main_menu_return()
			KEY_3:
				test_force_quit_simulation()
			KEY_Q:
				get_tree().quit()
