extends Control

const BuildInfoData = preload("res://scripts/utils/BuildInfo.gd")

@onready var start_button: Button = $MenuContainer/ButtonContainer/StartButton
@onready var continue_button: Button = $MenuContainer/ButtonContainer/ContinueButton
@onready var settings_panel = $SettingsPanel
@onready var credits_panel = $CreditsPanel
@onready var confirm_dialog = $ConfirmDialog
@onready var menu_container = $MenuContainer
@onready var fade_rect = $FadeRect
@onready var master_slider = $SettingsPanel/SettingsContainer/MasterVolume/Slider
@onready var music_slider = $SettingsPanel/SettingsContainer/MusicVolume/Slider
@onready var sfx_slider = $SettingsPanel/SettingsContainer/SFXVolume/Slider
@onready var settings_back_button: Button = $SettingsPanel/SettingsContainer/BackButton
@onready var credits_back_button: Button = $CreditsPanel/CreditsContainer/CreditsBackButton
@onready var master_value_label = $SettingsPanel/SettingsContainer/MasterVolume/Value
@onready var music_value_label = $SettingsPanel/SettingsContainer/MusicVolume/Value
@onready var sfx_value_label = $SettingsPanel/SettingsContainer/SFXVolume/Value
@onready var settings_container: VBoxContainer = $SettingsPanel/SettingsContainer
@onready var version_label: Label = $VersionLabel
@onready var credits_text: RichTextLabel = $CreditsPanel/CreditsContainer/ScrollContainer/CreditsText
@export var music_playlist: Resource

var invert_look_checkbox: CheckBox
var hold_sprint_checkbox: CheckBox
var prompt_style_row: HBoxContainer
var prompt_style_option: OptionButton

const FALLBACK_THEME_PATH: String = "res://assets/audio/music/theme.ogg"
const PROMPT_STYLE_OPTIONS := [
	{"label": "Auto", "value": "auto"},
	{"label": "Keyboard", "value": "keyboard"},
	{"label": "Xbox", "value": "xbox"},
	{"label": "PlayStation", "value": "playstation"}
]

func _ready() -> void:
	_ensure_control_toggles()
	_apply_build_info()
	_check_save_data()
	_load_settings()
	_detect_input_device()
	if not confirm_dialog.about_to_popup.is_connected(_on_confirm_dialog_about_to_popup):
		confirm_dialog.about_to_popup.connect(_on_confirm_dialog_about_to_popup)
	start_button.grab_focus()
	call_deferred("_start_menu_audio")
	call_deferred("fade_in")

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

func _apply_build_info() -> void:
	if version_label:
		version_label.text = BuildInfoData.get_version_label()
	if credits_text:
		credits_text.bbcode_enabled = true
		credits_text.text = BuildInfoData.get_credits_text()

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

func _on_confirm_dialog_about_to_popup() -> void:
	call_deferred("_focus_confirm_dialog")

func _focus_confirm_dialog() -> void:
	var ok_button: Button = confirm_dialog.get_ok_button()
	if ok_button:
		ok_button.grab_focus()

func _check_save_data() -> void:
	continue_button.disabled = not SaveManager.has_save_data()
	start_button.text = "NEW GAME" if SaveManager.has_save_data() else "START"

func _detect_input_device() -> void:
	InputManager.set_control_scheme("controller" if Input.get_connected_joypads().size() > 0 else "keyboard")

func _start_menu_audio() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if music_playlist is MusicPlaylist and music_playlist.main_theme is AudioStream:
		am.play_theme_loop(music_playlist.main_theme, -8.0)
		return
	var theme_stream: AudioStream = load(FALLBACK_THEME_PATH) as AudioStream
	if theme_stream != null:
		am.play_theme_loop(theme_stream, -8.0)

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

func _prepare_confirm_dialog() -> void:
	if confirm_dialog.confirmed.is_connected(_start_new_game):
		confirm_dialog.confirmed.disconnect(_start_new_game)
	if confirm_dialog.confirmed.is_connected(_reset_all_data):
		confirm_dialog.confirmed.disconnect(_reset_all_data)

func _on_start_pressed() -> void:
	if SaveManager.has_save_data():
		_prepare_confirm_dialog()
		confirm_dialog.dialog_text = "Starting a new game will delete your current progress. Continue?"
		confirm_dialog.confirmed.connect(_start_new_game, CONNECT_ONE_SHOT)
		confirm_dialog.popup_centered()
	else:
		_start_new_game()

func _start_new_game() -> void:
	fade_out()
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		await am.stop_theme_fade(1.5)
	await get_tree().create_timer(0.5).timeout
	SaveManager.delete_save()
	SceneManager.load_game_scene()

func _on_continue_pressed() -> void:
	fade_out()
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		await am.stop_theme_fade(1.5)
	await get_tree().create_timer(0.5).timeout
	SaveManager.load_game()
	SceneManager.load_game_scene()

func _on_settings_pressed() -> void:
	menu_container.visible = false
	settings_panel.visible = true
	master_slider.grab_focus()

func _on_credits_pressed() -> void:
	menu_container.visible = false
	credits_panel.visible = true
	credits_back_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var am: Node = get_node_or_null("/root/AudioManager")
		if am != null:
			await am.stop_theme_fade(1.0)
		get_tree().quit()

func _on_master_volume_changed(value) -> void:
	AudioManager.set_bus_volume("Master", value)
	master_value_label.text = str(int(value * 100)) + "%"

func _on_music_volume_changed(value) -> void:
	AudioManager.set_bus_volume("Music", value)
	music_value_label.text = str(int(value * 100)) + "%"

func _on_sfx_volume_changed(value) -> void:
	AudioManager.set_bus_volume("SFX", value)
	sfx_value_label.text = str(int(value * 100)) + "%"

func _on_reset_data_pressed() -> void:
	_prepare_confirm_dialog()
	confirm_dialog.dialog_text = "Are you sure you want to reset all progress? This cannot be undone!"
	confirm_dialog.confirmed.connect(_reset_all_data, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _reset_all_data() -> void:
	SaveManager.delete_save()
	_check_save_data()
	_on_settings_back_pressed()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	menu_container.visible = true
	start_button.grab_focus()

func _on_credits_back_pressed() -> void:
	credits_panel.visible = false
	menu_container.visible = true
	start_button.grab_focus()

func _on_confirm_reset() -> void:
	pass

func fade_out() -> void:
	create_tween().tween_property(fade_rect, "color:a", 1.0, 0.5)

func fade_in() -> void:
	fade_rect.color.a = 1.0
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.5)

func _input(event) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_settings_back_pressed()
		elif credits_panel.visible:
			_on_credits_back_pressed()
