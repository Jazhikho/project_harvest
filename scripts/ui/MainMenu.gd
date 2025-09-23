extends Control

# Autoloads are globally accessible, no need to store references

# References to UI elements
@onready var start_button = $MenuContainer/ButtonContainer/StartButton
@onready var continue_button = $MenuContainer/ButtonContainer/ContinueButton
@onready var settings_panel = $SettingsPanel
@onready var credits_panel = $CreditsPanel
@onready var confirm_dialog = $ConfirmDialog
@onready var menu_container = $MenuContainer
@onready var settings_button = $MenuContainer/ButtonContainer/SettingsButton
@onready var credits_button = $MenuContainer/ButtonContainer/CreditsButton
@onready var credits_back_button = $CreditsPanel/CreditsContainer/CreditsBackButton

# Audio sliders
@onready var master_slider = $SettingsPanel/SettingsContainer/MasterVolume/Slider
@onready var music_slider = $SettingsPanel/SettingsContainer/MusicVolume/Slider
@onready var sfx_slider = $SettingsPanel/SettingsContainer/SFXVolume/Slider

@onready var master_value_label = $SettingsPanel/SettingsContainer/MasterVolume/Value
@onready var music_value_label = $SettingsPanel/SettingsContainer/MusicVolume/Value
@onready var sfx_value_label = $SettingsPanel/SettingsContainer/SFXVolume/Value

func _ready():
	_check_save_data()
	_load_settings()
	_detect_input_device()
	start_button.grab_focus()

	call_deferred("_play_menu_music")

func _play_menu_music() -> void:
	AudioManager.play_music("res://assets/audio/Project_Harvest_Main_Theme.ogg", 0.0)

func _check_save_data():
	# Check if save file exists
	var has_save = SaveManager.has_save_data()
	continue_button.disabled = !has_save
	start_button.text = "NEW GAME" if has_save else "START"

func _detect_input_device():
	# Auto-detect input device for control hints
	var using_controller = Input.get_connected_joypads().size() > 0
	if using_controller:
		InputManager.set_control_scheme("controller")
	else:
		InputManager.set_control_scheme("keyboard")

func _load_settings():
	# Wait for AudioManager to initialize buses, then load volume settings
	await get_tree().process_frame
	
	# Load volume settings with fallbacks
	var master_vol = 1.0
	var music_vol = 0.8
	var sfx_vol = 1.0
	
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

func _update_volume_labels():
	if master_value_label and master_slider:
		master_value_label.text = str(int(master_slider.value * 100)) + "%"
	if music_value_label and music_slider:
		music_value_label.text = str(int(music_slider.value * 100)) + "%"
	if sfx_value_label and sfx_slider:
		sfx_value_label.text = str(int(sfx_slider.value * 100)) + "%"

# Button Signals
func _on_start_pressed():
	if SaveManager.has_save_data():
		# Show confirmation dialog
		var dialog = ConfirmationDialog.new()
		dialog.title = "New Game"
		dialog.dialog_text = "Starting a new game will delete existing save data. Are you sure?"
		dialog.get_ok_button().text = "Yes"
		dialog.add_cancel_button("No")
		dialog.confirmed.connect(_start_new_game)
		add_child(dialog)
		dialog.popup_centered()
	else:
		_start_new_game()

func _start_new_game():
	var music_fade_finished = AudioManager.fade_out_music(1.0)
	var ui_fade_finished = _fade_out_ui(1.0)
	await music_fade_finished
	await ui_fade_finished

	SaveManager.delete_save()
	SaveManager._reset_save_data()

	SceneManager.start_new_game()

func _on_continue_pressed():
	var music_fade_finished = AudioManager.fade_out_music(1.0)
	var ui_fade_finished = _fade_out_ui(1.0)
	await music_fade_finished
	await ui_fade_finished
	get_tree().set_meta("load_from_save", true)
	SceneManager.start_new_game()

func _on_settings_pressed():
	menu_container.visible = false
	settings_panel.visible = true
	master_slider.grab_focus()

func _on_credits_pressed():
	menu_container.visible = false
	credits_panel.visible = true
	credits_back_button.grab_focus()

func _on_quit_pressed():
	get_tree().quit()

func _notification(what: int) -> void:
	"""Handle window close requests"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

# Settings Panel Signals
func _on_master_volume_changed(value):
	AudioManager.set_bus_volume("Master", value)
	master_value_label.text = str(int(value * 100)) + "%"

func _on_music_volume_changed(value):
	AudioManager.set_bus_volume("Music", value)
	music_value_label.text = str(int(value * 100)) + "%"

func _on_sfx_volume_changed(value):
	AudioManager.set_bus_volume("SFX", value)
	sfx_value_label.text = str(int(value * 100)) + "%"

func _on_reset_data_pressed():
	confirm_dialog.dialog_text = "Are you sure you want to reset all progress? This cannot be undone!"
	confirm_dialog.confirmed.connect(_reset_all_data)
	confirm_dialog.popup_centered()

func _reset_all_data():
	SaveManager.delete_save()
	_check_save_data()
	_on_settings_back_pressed()

func _on_settings_back_pressed():
	settings_panel.visible = false
	menu_container.visible = true
	start_button.grab_focus()

func _on_credits_back_pressed():
	credits_panel.visible = false
	menu_container.visible = true
	start_button.grab_focus()

func _on_confirm_reset():
	# Dialog automatically disconnects after use
	pass

func _input(event):
	# Handle ESC key to go back
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_settings_back_pressed()
		elif credits_panel.visible:
			_on_credits_back_pressed()

func _fade_out_ui(duration: float) -> Signal:
	var tween = create_tween()
	tween.tween_method(
		func(value): menu_container.modulate.a = value,
		1.0,
		0.0,
		duration
	)
	tween.set_trans(Tween.TRANS_LINEAR)
	return tween.finished
