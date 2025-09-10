extends Control

signal resume_requested
signal main_menu_requested
signal quit_requested

@onready var menu_panel = $MenuPanel
@onready var settings_panel = $SettingsPanel

var quit_dialog: ConfirmationDialog = null
var main_menu_dialog: ConfirmationDialog = null

func _ready():
	# Create confirmation dialogs
	_create_dialogs()

func show_menu():
	var tween = create_tween()
	menu_panel.scale = Vector2.ZERO
	tween.tween_property(menu_panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _create_dialogs():
	# Create quit confirmation dialog
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.name = "QuitConfirmDialog"
	quit_dialog.title = "QUIT GAME"
	quit_dialog.dialog_text = "This will quit the game and end your current run.\n\nYour death will be recorded at your current position.\n\nAre you certain?"
	quit_dialog.ok_button_text = "QUIT"
	quit_dialog.cancel_button_text = "CONTINUE EXPERIMENT"
	quit_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	quit_dialog.size = Vector2i(500, 200)
	add_child(quit_dialog)
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	
	# Create main menu confirmation dialog
	main_menu_dialog = ConfirmationDialog.new()
	main_menu_dialog.name = "MainMenuConfirmDialog"
	main_menu_dialog.title = "ABANDON EXPERIMENT"
	main_menu_dialog.dialog_text = "Returning to the main menu will terminate the current subject.\n\nAll progress for this run will be lost.\n\nProceed?"
	main_menu_dialog.ok_button_text = "ABANDON"
	main_menu_dialog.cancel_button_text = "CONTINUE"
	main_menu_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	main_menu_dialog.size = Vector2i(450, 180)
	add_child(main_menu_dialog)
	main_menu_dialog.confirmed.connect(_on_main_menu_confirmed)

func _on_resume_pressed():
	emit_signal("resume_requested")

func _on_settings_pressed():
	menu_panel.visible = false
	settings_panel.visible = true

func _on_main_menu_pressed():
	# Show confirmation dialog
	print("PauseMenu: Main menu button pressed")
	if main_menu_dialog:
		print("PauseMenu: Showing main menu dialog")
		main_menu_dialog.popup_centered()
	else:
		print("PauseMenu: ERROR - main_menu_dialog is null!")

func _on_quit_pressed():
	# Show confirmation dialog
	if quit_dialog:
		quit_dialog.popup_centered()

func _on_quit_confirmed():
	print("PauseMenu: Quit confirmed, terminating subject")
	
	# Record death at current position before quitting
	var game_director = get_node_or_null("/root/GameDirector")
	if game_director and game_director.has_method("end_game"):
		var state_manager = get_node_or_null("/root/GameStateManager")
		var current_pos = Vector2i.ZERO
		if state_manager:
			current_pos = state_manager.get_state("current_tile_position")
		
		game_director.end_game("Quit", {"reason": "player_quit", "position": current_pos})
		
		# Wait a frame for death recording, then quit
		await get_tree().process_frame
		get_tree().quit()
	else:
		# Fallback: just quit
		get_tree().quit()

func _on_main_menu_confirmed():
	print("PauseMenu: Main menu confirmed, emitting signal")
	# The GameController will handle the actual scene transition and death recording
	emit_signal("main_menu_requested")

func _on_reset_data_pressed():
	SaveManager.delete_save()
	emit_signal("main_menu_requested")

func _on_back_pressed():
	settings_panel.visible = false
	menu_panel.visible = true
