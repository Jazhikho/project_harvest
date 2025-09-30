extends Node
## Input Manager - Handles input mapping and custom controls
## Centralized input handling for Project Harvest

# Control scheme management
var control_scheme = "keyboard"

# Input action mappings
const INPUT_ACTIONS = {
	"move_forward": "W",
	"move_back": "S",
	"move_left": "A",
	"move_right": "D",
	"toggle_flashlight": "F",
	"interact": "E",
	"inventory": "I",
	"journal": "J",
	"pause": "Escape"
}

# Input state tracking
var input_buffer: Dictionary = {}
var last_input_time: Dictionary = {}

func _ready():
	name = "InputManager"
	add_to_group("core_systems")
	_setup_input_actions()

func _setup_input_actions():
	"""Set up custom input actions if not already defined"""
	# This would be handled in the input map, but we can validate here
	for action in INPUT_ACTIONS.keys():
		if not InputMap.has_action(action):
			push_warning("Input action '%s' not found in InputMap" % action)

func _input(event):
	"""Handle global input events"""
	# Track input timing for buffer/combo systems
	for action in INPUT_ACTIONS.keys():
		if event.is_action_pressed(action):
			last_input_time[action] = Time.get_time_string_from_system()
			input_buffer[action] = true
		elif event.is_action_released(action):
			input_buffer[action] = false

# Control scheme management
func set_control_scheme(scheme: String):
	control_scheme = scheme

func get_control_hint(action: String) -> String:
	"""Return appropriate control hint based on input device"""
	var hints = {
		"keyboard": {
			"move": "WASD",
			"sprint": "Shift",
			"interact": "E",
			"flashlight": "F",
			"inventory": "I",
			"journal": "J",
			"pause": "Escape"
		},
		"controller": {
			"move": "Left Stick",
			"sprint": "L3",
			"interact": "A",
			"flashlight": "X",
			"inventory": "Select",
			"journal": "Select",
			"pause": "Start"
		}
	}
	return hints[control_scheme].get(action, "")

# Public API for other systems to check input state
func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func get_movement_vector() -> Vector2:
	"""Get normalized movement input vector"""
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_back"):
		input_vector.y += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	return input_vector.normalized()

func get_input_strength(action: String) -> float:
	"""Get input strength for analog controls"""
	return Input.get_action_strength(action)
