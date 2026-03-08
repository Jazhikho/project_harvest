extends Control

signal resume_requested
signal main_menu_requested
signal quit_requested

@onready var menu_panel = $MenuPanel
@onready var settings_panel = $SettingsPanel
@onready var resume_button: Button = $MenuPanel/VBoxContainer/ResumeButton
@onready var back_button: Button = $SettingsPanel/SettingsContainer/BackButton
@onready var master_slider = $SettingsPanel/SettingsContainer/MasterVolume/Slider
@onready var music_slider = $SettingsPanel/SettingsContainer/MusicVolume/Slider
@onready var sfx_slider = $SettingsPanel/SettingsContainer/SFXVolume/Slider
@onready var master_value_label = $SettingsPanel/SettingsContainer/MasterVolume/Value
@onready var music_value_label = $SettingsPanel/SettingsContainer/MusicVolume/Value
@onready var sfx_value_label = $SettingsPanel/SettingsContainer/SFXVolume/Value
@onready var settings_container: VBoxContainer = $SettingsPanel/SettingsContainer

var invert_look_checkbox: CheckBox
var hold_sprint_checkbox: CheckBox
var prompt_style_row: HBoxContainer
var prompt_style_option: OptionButton
var quit_dialog: ConfirmationDialog = null
var main_menu_dialog: ConfirmationDialog = null
const PROMPT_STYLE_OPTIONS := [
	{"label": "Auto", "value": "auto"},
	{"label": "Keyboard", "value": "keyboard"},
	{"label": "Xbox", "value": "xbox"},
	{"label": "PlayStation", "value": "playstation"}
]

func _ready() -> void:
	_ensure_control_toggles()
	_create_dialogs()
	call_deferred("_load_settings")

func _ensure_control_toggles() -> void:
	if not (invert_look_checkbox and is_instance_valid(invert_look_checkbox)):
		invert_look_checkbox = CheckBox.new()
		invert_look_checkbox.name = "InvertLookY"
		invert_look_checkbox.text = "Invert Look Y"
		invert_look_checkbox.focus_mode = Control.FOCUS_ALL as Control.FocusMode
		invert_look_checkbox.toggled.connect(_on_invert_look_toggled)
		_insert_settings_control(invert_look_checkbox)
	if not (hold_sprint_checkbox and is_instance_valid(hold_sprint_checkbox)):
		hold_sprint_checkbox = CheckBox.new()
		hold_sprint_checkbox.name = "HoldToSprint"
		hold_sprint_checkbox.text = "Hold To Sprint"
		hold_sprint_checkbox.focus_mode = Control.FOCUS_ALL as Control.FocusMode
		hold_sprint_checkbox.toggled.connect(_on_hold_sprint_toggled)
		_insert_settings_control(hold_sprint_checkbox)
	if prompt_style_row and is_instance_valid(prompt_style_row):
		return
	prompt_style_row = HBoxContainer.new()
	prompt_style_row.name = "PromptStyleRow"
	prompt_style_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prompt_style_label := Label.new()
	prompt_style_label.text = "Prompt Style"
	prompt_style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_style_row.add_child(prompt_style_label)
	prompt_style_option = OptionButton.new()
	prompt_style_option.name = "PromptStyle"
	prompt_style_option.focus_mode = Control.FOCUS_ALL as Control.FocusMode
	for prompt_style in PROMPT_STYLE_OPTIONS:
		prompt_style_option.add_item(prompt_style["label"])
	prompt_style_option.item_selected.connect(_on_prompt_style_selected)
	prompt_style_row.add_child(prompt_style_option)
	_insert_settings_control(prompt_style_row)

func _insert_settings_control(control: Control) -> void:
	var spacer := settings_container.get_node_or_null("Spacer")
	if spacer:
		settings_container.add_child(control)
		settings_container.move_child(control, spacer.get_index())
	else:
		settings_container.add_child(control)

func _on_invert_look_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("controls", "invert_look_y", toggled_on)

func _on_hold_sprint_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("controls", "hold_to_sprint", toggled_on)

func _on_prompt_style_selected(index: int) -> void:
	if index < 0 or index >= PROMPT_STYLE_OPTIONS.size():
		return
	SettingsManager.set_setting("controls", "prompt_style", PROMPT_STYLE_OPTIONS[index]["value"])

func show_menu() -> void:
	menu_panel.scale = Vector2.ZERO
	create_tween().tween_property(menu_panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	resume_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_back_pressed()
		else:
			emit_signal("resume_requested")
		get_viewport().set_input_as_handled()

func _create_dialogs() -> void:
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "QUIT GAME"
	quit_dialog.dialog_text = "This will quit the game and end your current run.\n\nYour death will be recorded at your current position.\n\nAre you certain?"
	quit_dialog.ok_button_text = "QUIT"
	quit_dialog.cancel_button_text = "CONTINUE EXPERIMENT"
	add_child(quit_dialog)
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	quit_dialog.about_to_popup.connect(_focus_quit_dialog)
	main_menu_dialog = ConfirmationDialog.new()
	main_menu_dialog.title = "ABANDON EXPERIMENT"
	main_menu_dialog.dialog_text = "Returning to the main menu will terminate the current subject.\n\nAll progress for this run will be lost.\n\nProceed?"
	main_menu_dialog.ok_button_text = "ABANDON"
	main_menu_dialog.cancel_button_text = "CONTINUE"
	add_child(main_menu_dialog)
	main_menu_dialog.confirmed.connect(_on_main_menu_confirmed)
	main_menu_dialog.about_to_popup.connect(_focus_main_menu_dialog)

func _focus_quit_dialog() -> void:
	call_deferred("_grab_quit_dialog_focus")

func _grab_quit_dialog_focus() -> void:
	var ok_button: Button = quit_dialog.get_ok_button()
	if ok_button:
		ok_button.grab_focus()

func _focus_main_menu_dialog() -> void:
	call_deferred("_grab_main_menu_dialog_focus")

func _grab_main_menu_dialog_focus() -> void:
	var ok_button: Button = main_menu_dialog.get_ok_button()
	if ok_button:
		ok_button.grab_focus()

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_panel.visible = true
	_load_settings()
	master_slider.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_main_menu_pressed() -> void:
	main_menu_dialog.popup_centered()

func _on_quit_pressed() -> void:
	quit_dialog.popup_centered()

func _on_quit_confirmed() -> void:
	var game_director = get_node_or_null("/root/GameDirector")
	if game_director and game_director.has_method("end_game"):
		var state_manager = get_node_or_null("/root/GameStateManager")
		var current_pos = Vector2i.ZERO
		if state_manager:
			current_pos = state_manager.get_state("current_tile_position")
		game_director.end_game("Quit", {"reason": "player_quit", "position": current_pos})
		await get_tree().process_frame
		get_tree().quit()
	else:
		get_tree().quit()

func _on_main_menu_confirmed() -> void:
	emit_signal("main_menu_requested")

func _load_settings() -> void:
	await get_tree().process_frame
	master_slider.value = AudioManager.get_bus_volume("Master")
	music_slider.value = AudioManager.get_bus_volume("Music")
	sfx_slider.value = AudioManager.get_bus_volume("SFX")
	_update_volume_labels()
	if invert_look_checkbox:
		invert_look_checkbox.button_pressed = SettingsManager.get_setting("controls", "invert_look_y")
	if hold_sprint_checkbox:
		hold_sprint_checkbox.button_pressed = SettingsManager.get_setting("controls", "hold_to_sprint")
	if prompt_style_option:
		var prompt_style: String = str(SettingsManager.get_setting("controls", "prompt_style"))
		for index in range(PROMPT_STYLE_OPTIONS.size()):
			if PROMPT_STYLE_OPTIONS[index]["value"] == prompt_style:
				prompt_style_option.select(index)
				break

func _update_volume_labels() -> void:
	master_value_label.text = str(int(master_slider.value * 100)) + "%"
	music_value_label.text = str(int(music_slider.value * 100)) + "%"
	sfx_value_label.text = str(int(sfx_slider.value * 100)) + "%"

func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume("Master", value)
	master_value_label.text = str(int(value * 100)) + "%"

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume("Music", value)
	music_value_label.text = str(int(value * 100)) + "%"

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume("SFX", value)
	sfx_value_label.text = str(int(value * 100)) + "%"

func _on_back_pressed() -> void:
	settings_panel.visible = false
	menu_panel.visible = true
	resume_button.grab_focus()

func _on_reset_data_pressed() -> void:
	SaveManager.delete_save()
	emit_signal("main_menu_requested")
