extends Node
## Input Manager - Handles input mapping and custom controls
## Centralized input handling for Project Harvest
signal control_scheme_changed(control_scheme: String)
signal input_source_changed(input_source: String)
signal prompt_style_changed(prompt_style: String)
const INPUT_SOURCE_KEYBOARD: String = "keyboard"
const INPUT_SOURCE_CONTROLLER: String = "controller"
const PROMPT_STYLE_AUTO: String = "auto"
const PROMPT_STYLE_KEYBOARD: String = "keyboard"
const PROMPT_STYLE_XBOX: String = "xbox"
const PROMPT_STYLE_PLAYSTATION: String = "playstation"
const LOOK_DEADZONE: float = 0.2
const INPUT_ACTIONS := {
	"move_forward": true,
	"move_back": true,
	"move_left": true,
	"move_right": true,
	"toggle_flashlight": true,
	"interact": true,
	"inventory": true,
	"journal": true,
	"pause": true,
	"sprint": true,
	"look_left": true,
	"look_right": true,
	"look_up": true,
	"look_down": true
}
const UI_NAVIGATION_ACTIONS := {
	"ui_accept": {
		"deadzone": 0.5,
		"buttons": [0]
	},
	"ui_cancel": {
		"deadzone": 0.5,
		"buttons": [1]
	},
	"ui_up": {
		"deadzone": 0.2,
		"buttons": [11],
		"axes": [{"axis": 1, "value": -1.0}]
	},
	"ui_down": {
		"deadzone": 0.2,
		"buttons": [12],
		"axes": [{"axis": 1, "value": 1.0}]
	},
	"ui_left": {
		"deadzone": 0.2,
		"buttons": [13],
		"axes": [{"axis": 0, "value": -1.0}]
	},
	"ui_right": {
		"deadzone": 0.2,
		"buttons": [14],
		"axes": [{"axis": 0, "value": 1.0}]
	}
}
const KEYBOARD_PROMPTS := {
	"move": "WASD",
	"move_forward": "W",
	"move_back": "S",
	"move_left": "A",
	"move_right": "D",
	"look": "Mouse",
	"continue": "Space or E",
	"toggle_flashlight": "F",
	"interact": "E",
	"inventory": "I",
	"journal": "J",
	"ui_accept": "Enter",
	"ui_cancel": "Esc",
	"pause": "Esc",
	"sprint": "Space"
}
const XBOX_PROMPTS := {
	"move": "Left Stick",
	"move_forward": "Left Stick",
	"move_back": "Left Stick",
	"move_left": "Left Stick",
	"move_right": "Left Stick",
	"look": "Right Stick",
	"continue": "A",
	"toggle_flashlight": "X",
	"interact": "A",
	"inventory": "Y",
	"journal": "View",
	"ui_accept": "A",
	"ui_cancel": "B",
	"pause": "Menu",
	"sprint": "R3"
}
const PLAYSTATION_PROMPTS := {
	"move": "Left Stick",
	"move_forward": "Left Stick",
	"move_back": "Left Stick",
	"move_left": "Left Stick",
	"move_right": "Left Stick",
	"look": "Right Stick",
	"continue": "Cross",
	"toggle_flashlight": "Square",
	"interact": "Cross",
	"inventory": "Triangle",
	"journal": "Touch Pad",
	"ui_accept": "Cross",
	"ui_cancel": "Circle",
	"pause": "Options",
	"sprint": "R3"
}
var control_scheme: String = INPUT_SOURCE_KEYBOARD
var input_buffer: Dictionary = {}
var last_input_time: Dictionary = {}
var _last_input_source: String = INPUT_SOURCE_KEYBOARD
func _ready() -> void:
	name = "InputManager"
	add_to_group("core_systems")
	_setup_input_actions()

func _setup_input_actions() -> void:
	"""Set up custom input actions if not already defined"""
	for action in INPUT_ACTIONS.keys():
		if not InputMap.has_action(action):
			push_warning("Input action '%s' not found in InputMap" % action)
	_ensure_ui_navigation_actions()

func _ensure_ui_navigation_actions() -> void:
	for action_name in UI_NAVIGATION_ACTIONS.keys():
		var config: Dictionary = UI_NAVIGATION_ACTIONS[action_name]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, config.get("deadzone", 0.5))
		for button_index in config.get("buttons", []):
			if not _action_has_button(action_name, int(button_index)):
				var button_event := InputEventJoypadButton.new()
				button_event.button_index = int(button_index)
				InputMap.action_add_event(action_name, button_event)
		for axis_config in config.get("axes", []):
			var axis: int = int(axis_config.get("axis", 0))
			var axis_value: float = float(axis_config.get("value", 0.0))
			if not _action_has_axis(action_name, axis, axis_value):
				var motion_event := InputEventJoypadMotion.new()
				motion_event.axis = axis
				motion_event.axis_value = axis_value
				InputMap.action_add_event(action_name, motion_event)

func _action_has_button(action: String, button_index: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return true
	return false

func _action_has_axis(action: String, axis: int, axis_value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return true
	return false
func _input(event: InputEvent) -> void:
	"""Handle global input events"""
	_track_input_source(event)
	for action in INPUT_ACTIONS.keys():
		if event.is_action_pressed(action):
			last_input_time[action] = Time.get_ticks_msec()
			input_buffer[action] = true
		elif event.is_action_released(action):
			input_buffer[action] = false
func _track_input_source(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			_set_input_source(INPUT_SOURCE_CONTROLLER)
		return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) >= LOOK_DEADZONE:
			_set_input_source(INPUT_SOURCE_CONTROLLER)
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_set_input_source(INPUT_SOURCE_KEYBOARD)
		return
	if event is InputEventMouseButton:
		if event.pressed:
			_set_input_source(INPUT_SOURCE_KEYBOARD)
		return
	if event is InputEventMouseMotion and event.relative.length_squared() > 0.0:
		_set_input_source(INPUT_SOURCE_KEYBOARD)
func _set_input_source(source: String) -> void:
	if source != INPUT_SOURCE_KEYBOARD and source != INPUT_SOURCE_CONTROLLER:
		return
	if _last_input_source == source and control_scheme == source:
		return
	var source_changed: bool = _last_input_source != source
	_last_input_source = source
	if source_changed:
		emit_signal("input_source_changed", source)
	if control_scheme != source:
		control_scheme = source
		emit_signal("control_scheme_changed", control_scheme)
		emit_signal("prompt_style_changed", get_prompt_style())
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("set_runtime_control_scheme"):
		settings_manager.set_runtime_control_scheme(source)
func set_control_scheme(scheme: String, update_input_source: bool = true) -> void:
	if scheme != INPUT_SOURCE_KEYBOARD and scheme != INPUT_SOURCE_CONTROLLER:
		push_warning("InputManager: Unknown control scheme '%s'" % scheme)
		return
	var source_changed: bool = update_input_source and _last_input_source != scheme
	var scheme_changed: bool = control_scheme != scheme
	control_scheme = scheme
	if update_input_source:
		_last_input_source = scheme
	if source_changed:
		emit_signal("input_source_changed", _last_input_source)
	if scheme_changed:
		emit_signal("control_scheme_changed", control_scheme)
		emit_signal("prompt_style_changed", get_prompt_style())
func get_last_input_source() -> String:
	return _last_input_source
func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)
func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)
func get_movement_vector() -> Vector2:
	"""Get normalized movement input vector"""
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
func get_look_vector() -> Vector2:
	"""Get analog look input from controller right stick"""
	var look_vector: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down", LOOK_DEADZONE)
	if look_vector.length() < LOOK_DEADZONE:
		return Vector2.ZERO
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.get_setting("controls", "invert_look_y"):
		look_vector.y *= -1.0
	return look_vector
func get_input_strength(action: String) -> float:
	"""Get input strength for analog controls"""
	return Input.get_action_strength(action)

func get_prompt_style() -> String:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	var preferred_style: String = PROMPT_STYLE_AUTO
	if settings_manager:
		var setting_value: Variant = settings_manager.get_setting("controls", "prompt_style")
		if setting_value is String:
			preferred_style = setting_value
	match preferred_style:
		PROMPT_STYLE_KEYBOARD, PROMPT_STYLE_XBOX, PROMPT_STYLE_PLAYSTATION:
			return preferred_style
	if control_scheme == INPUT_SOURCE_CONTROLLER:
		return PROMPT_STYLE_XBOX
	return PROMPT_STYLE_KEYBOARD

func refresh_prompt_style() -> void:
	emit_signal("prompt_style_changed", get_prompt_style())

func get_action_prompt(action: String) -> String:
	var prompts: Dictionary = KEYBOARD_PROMPTS
	match get_prompt_style():
		PROMPT_STYLE_XBOX:
			prompts = XBOX_PROMPTS
		PROMPT_STYLE_PLAYSTATION:
			prompts = PLAYSTATION_PROMPTS
	return prompts.get(action, action.capitalize())
