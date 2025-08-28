extends Node
## Input Manager - Handles input mapping and custom controls
## Centralized input handling for Project Harvest

# Input action mappings
const INPUT_ACTIONS = {
	"move_forward": "W",
	"move_back": "S", 
	"move_left": "A",
	"move_right": "D",
	"toggle_flashlight": "F",
	"interact": "E",
	"inventory": "Tab",
	"pause": "Escape"
}

# Input state tracking
var input_buffer: Dictionary = {}
var last_input_time: Dictionary = {}

func _ready():
	_setup_input_actions()

func _setup_input_actions():
	"""Set up custom input actions if not already defined"""
	# This would be handled in the input map, but we can validate here
	for action in INPUT_ACTIONS.keys():
		if not InputMap.has_action(action):
			print("WARNING: Input action '", action, "' not found in InputMap")

func _input(event):
	"""Handle global input events"""
	# Track input timing for buffer/combo systems
	for action in INPUT_ACTIONS.keys():
		if event.is_action_pressed(action):
			last_input_time[action] = Time.get_time_from_start()
			input_buffer[action] = true
		elif event.is_action_released(action):
			input_buffer[action] = false

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
