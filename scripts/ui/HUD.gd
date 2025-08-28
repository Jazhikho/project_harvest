extends Control
## HUD - Main heads-up display for Project Harvest
## Shows sanity, weird findings counter, flashlight battery, and messages

@onready var sanity_bar: ProgressBar = $VBoxContainer/SanityContainer/SanityBar
@onready var sanity_label: Label = $VBoxContainer/SanityContainer/SanityLabel
@onready var weird_counter: Label = $VBoxContainer/CounterContainer/WeirdCounter
@onready var flashlight_battery: ProgressBar = $VBoxContainer/FlashlightContainer/BatteryBar
@onready var message_overlay: Panel = $MessageOverlay
@onready var message_text: Label = $MessageOverlay/MessageText
@onready var message_timer: Timer = $MessageTimer

# Visual effects
var sanity_color_normal: Color = Color.GREEN
var sanity_color_warning: Color = Color.YELLOW
var sanity_color_critical: Color = Color.RED

# Message system
var message_queue: Array[Dictionary] = []
var current_message_duration: float = 3.0

func _ready():
	add_to_group("ui_manager")
	
	# Connect to game systems
	_connect_to_systems()
	
	# Initialize UI state
	_initialize_hud()
	
	# Set up message timer
	message_timer.timeout.connect(_on_message_timer_timeout)
	
	# Initially hide message overlay
	message_overlay.visible = false

func _connect_to_systems():
	"""Connect to autoload systems for data updates"""
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.sanity_changed.connect(_on_sanity_changed)
		sanity_manager.sanity_critical.connect(_on_sanity_critical)
	
	var game_director = get_node("/root/GameDirector")
	if game_director:
		game_director.weird_thing_collected.connect(_on_weird_thing_collected)
	
	var weird_things_manager = get_node("/root/WeirdThingsManager")
	if weird_things_manager:
		weird_things_manager.weird_thing_collected.connect(_on_weird_collected_update)

func _initialize_hud():
	"""Initialize HUD with starting values"""
	_update_sanity_display(100)
	_update_weird_counter(0)
	_update_flashlight_battery(1.0)

func _process(delta):
	_update_flashlight_display()
	_process_message_queue()

func _update_flashlight_display():
	"""Update flashlight battery display"""
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_flashlight_battery_ratio"):
		var battery_ratio = player.get_flashlight_battery_ratio()
		_update_flashlight_battery(battery_ratio)

func _on_sanity_changed(new_sanity: int):
	"""Handle sanity changes"""
	_update_sanity_display(new_sanity)

func _on_sanity_critical():
	"""Handle critical sanity state"""
	_add_screen_effects_critical()
	show_message("Your mind fragments as reality breaks apart...", 4.0)

func _on_weird_thing_collected(type: String):
	"""Handle weird thing collection"""
	var game_director = get_node("/root/GameDirector")
	if game_director:
		_update_weird_counter(game_director.get_weird_findings_count())

func _on_weird_collected_update(type: String, position: Vector2i):
	"""Handle weird things manager update"""
	var weird_things_manager = get_node("/root/WeirdThingsManager")
	if weird_things_manager:
		_update_weird_counter(weird_things_manager.get_collected_count())

func _update_sanity_display(sanity: int):
	"""Update sanity bar and color"""
	sanity_bar.value = sanity
	sanity_label.text = str(sanity) + "%"
	
	# Update color based on sanity level
	if sanity > 50:
		sanity_bar.modulate = sanity_color_normal
	elif sanity > 20:
		sanity_bar.modulate = sanity_color_warning
	else:
		sanity_bar.modulate = sanity_color_critical
		_add_screen_effects_critical()

func _update_weird_counter(count: int):
	"""Update weird findings counter"""
	weird_counter.text = "Weird Findings: " + str(count)

func _update_flashlight_battery(ratio: float):
	"""Update flashlight battery display"""
	flashlight_battery.value = ratio * 100
	
	# Change color based on battery level
	if ratio > 0.5:
		flashlight_battery.modulate = Color.GREEN
	elif ratio > 0.2:
		flashlight_battery.modulate = Color.YELLOW
	else:
		flashlight_battery.modulate = Color.RED

func _add_screen_effects_critical():
	"""Add visual effects for critical states"""
	# Screen edge darkening/reddening for low sanity
	# TODO: Implement post-processing effects
	pass

func show_message(text: String, duration: float = 3.0):
	"""Show a message to the player"""
	var message_data = {
		"text": text,
		"duration": duration,
		"priority": 1  # Normal priority
	}
	
	message_queue.append(message_data)

func show_weird_message(text: String, duration: float = 4.0):
	"""Show a weird thing related message with special styling"""
	var message_data = {
		"text": text,
		"duration": duration,
		"priority": 2,  # High priority
		"style": "weird"
	}
	
	message_queue.append(message_data)

func show_sanity_message(text: String, duration: float = 2.0):
	"""Show a sanity-related message"""
	var message_data = {
		"text": text,
		"duration": duration,
		"priority": 1,
		"style": "sanity"
	}
	
	message_queue.append(message_data)

func _process_message_queue():
	"""Process the message queue and display messages"""
	if message_queue.is_empty() or message_overlay.visible:
		return
	
	var next_message = message_queue.pop_front()
	_display_message(next_message)

func _display_message(message_data: Dictionary):
	"""Display a specific message"""
	message_text.text = message_data["text"]
	current_message_duration = message_data["duration"]
	
	# Apply styling based on message type
	match message_data.get("style", "normal"):
		"weird":
			message_text.modulate = Color.ORANGE_RED
			_add_message_effects("weird")
		"sanity":
			message_text.modulate = Color.CYAN
			_add_message_effects("sanity")
		_:
			message_text.modulate = Color.WHITE
	
	# Show overlay
	message_overlay.visible = true
	message_overlay.modulate.a = 0.0
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(message_overlay, "modulate:a", 1.0, 0.3)
	
	# Start timer
	message_timer.wait_time = current_message_duration
	message_timer.start()

func _add_message_effects(effect_type: String):
	"""Add special effects for different message types"""
	match effect_type:
		"weird":
			# TODO: Add flickering effect, distortion
			pass
		"sanity":
			# TODO: Add screen shake, color shift
			pass

func _on_message_timer_timeout():
	"""Handle message timeout"""
	_hide_current_message()

func _hide_current_message():
	"""Hide the current message"""
	if not message_overlay.visible:
		return
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(message_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): message_overlay.visible = false)

# Public API for other systems
func show_game_over_screen():
	"""Show game over overlay"""
	# TODO: Implement game over screen
	pass

func show_pause_menu():
	"""Show pause menu"""
	# TODO: Implement pause menu
	pass

func hide_hud():
	"""Hide the entire HUD"""
	visible = false

func show_hud():
	"""Show the HUD"""
	visible = true
