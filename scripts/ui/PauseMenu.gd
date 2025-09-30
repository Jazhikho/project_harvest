extends Control

signal resume_requested
signal main_menu_requested
signal quit_requested

@onready var menu_panel = $MenuPanel
@onready var settings_panel = $SettingsPanel

# Audio sliders
@onready var master_slider = $SettingsPanel/SettingsContainer/MasterVolume/Slider
@onready var music_slider = $SettingsPanel/SettingsContainer/MusicVolume/Slider
@onready var sfx_slider = $SettingsPanel/SettingsContainer/SFXVolume/Slider

@onready var master_value_label = $SettingsPanel/SettingsContainer/MasterVolume/Value
@onready var music_value_label = $SettingsPanel/SettingsContainer/MusicVolume/Value
@onready var sfx_value_label = $SettingsPanel/SettingsContainer/SFXVolume/Value

var quit_dialog: ConfirmationDialog = null
var main_menu_dialog: ConfirmationDialog = null

## _ready
## Purpose: Initialize pause menu and load settings
## @return void
func _ready():
	# Create confirmation dialogs
	_create_dialogs()
	# Load settings when ready
	call_deferred("_load_settings")

## show_menu
## Purpose: Display pause menu with animation
## @return void
func show_menu():
	var tween: Tween = create_tween()
	menu_panel.scale = Vector2.ZERO
	tween.tween_property(menu_panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## _create_dialogs
## Purpose: Create confirmation dialogs for quit and main menu
## @return void
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

## _on_resume_pressed
## Purpose: Handle resume button press
## @return void
func _on_resume_pressed():
	emit_signal("resume_requested")

## _on_settings_pressed
## Purpose: Handle settings button press and show settings panel
## @return void
func _on_settings_pressed():
	menu_panel.visible = false
	settings_panel.visible = true
	_load_settings()
	if master_slider:
		master_slider.grab_focus()

## _on_main_menu_pressed
## Purpose: Handle main menu button press and show confirmation dialog
## @return void
func _on_main_menu_pressed():
	# Show confirmation dialog
	if main_menu_dialog:
		main_menu_dialog.popup_centered()

## _on_quit_pressed
## Purpose: Handle quit button press and show confirmation dialog
## @return void
func _on_quit_pressed():
	# Show confirmation dialog
	if quit_dialog:
		quit_dialog.popup_centered()

## _on_quit_confirmed
## Purpose: Handle quit confirmation and record death before exiting
## @return void (awaitable)
func _on_quit_confirmed():
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

## _on_main_menu_confirmed
## Purpose: Handle main menu confirmation and emit signal
## @return void
func _on_main_menu_confirmed():
	# The GameController will handle the actual scene transition and death recording
	emit_signal("main_menu_requested")

## _on_reset_data_pressed
## Purpose: Handle reset data button press and delete save
## @return void
func _on_reset_data_pressed():
	SaveManager.delete_save()
	emit_signal("main_menu_requested")

## _load_settings
## Purpose: Load current audio settings from AudioManager and update sliders
## @return void (awaitable)
func _load_settings():
	# Wait for AudioManager to initialize buses
	await get_tree().process_frame
	
	# Load volume settings with fallbacks
	var master_vol: float = 1.0
	var music_vol: float = 0.8
	var sfx_vol: float = 1.0
	
	if AudioManager:
		master_vol = AudioManager.get_bus_volume("Master")
		music_vol = AudioManager.get_bus_volume("Music")
		sfx_vol = AudioManager.get_bus_volume("SFX")
	
	# Set slider values
	if master_slider:
		master_slider.value = master_vol
	if music_slider:
		music_slider.value = music_vol
	if sfx_slider:
		sfx_slider.value = sfx_vol
	
	_update_volume_labels()

## _update_volume_labels
## Purpose: Update the volume percentage labels based on slider values
## @return void
func _update_volume_labels():
	if master_value_label and master_slider:
		master_value_label.text = str(int(master_slider.value * 100)) + "%"
	if music_value_label and music_slider:
		music_value_label.text = str(int(music_slider.value * 100)) + "%"
	if sfx_value_label and sfx_slider:
		sfx_value_label.text = str(int(sfx_slider.value * 100)) + "%"

## _on_master_volume_changed
## Purpose: Handle master volume slider change and update AudioManager
## @param value: Volume level from 0.0 to 1.0
## @return void
func _on_master_volume_changed(value: float):
	AudioManager.set_bus_volume("Master", value)
	if master_value_label:
		master_value_label.text = str(int(value * 100)) + "%"

## _on_music_volume_changed
## Purpose: Handle music volume slider change and update AudioManager
## @param value: Volume level from 0.0 to 1.0
## @return void
func _on_music_volume_changed(value: float):
	AudioManager.set_bus_volume("Music", value)
	if music_value_label:
		music_value_label.text = str(int(value * 100)) + "%"

## _on_sfx_volume_changed
## Purpose: Handle SFX volume slider change and update AudioManager
## @param value: Volume level from 0.0 to 1.0
## @return void
func _on_sfx_volume_changed(value: float):
	AudioManager.set_bus_volume("SFX", value)
	if sfx_value_label:
		sfx_value_label.text = str(int(value * 100)) + "%"

## _on_back_pressed
## Purpose: Handle back button press and return to main pause menu
## @return void
func _on_back_pressed():
	settings_panel.visible = false
	menu_panel.visible = true
