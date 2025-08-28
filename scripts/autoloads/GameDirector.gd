extends Node
## Game Director - Main game state management and coordination
## Ported from JavaScript gameLogic.js

signal game_over
signal sanity_changed(new_sanity: int)
signal weird_thing_collected(type: String)
signal maze_shifted

@export var maze_size: Vector2i = Vector2i(100, 100)
@export var initial_sanity: int = 100
@export var maze_shift_interval: float = 30.0
@export var maze_shift_interval_stressed: float = 15.0

var current_sanity: int = 100
var weird_findings: int = 0
var game_active: bool = false
var story_progress: int = 0
var maze_shift_timer: float = 0.0
var is_stressed_mode: bool = false

# References to other systems
var maze_manager: Node
var sanity_manager: Node  
var harvest_logger: Node
var weird_things_manager: Node

func _ready():
	# Wait for other autoloads to initialize
	await get_tree().process_frame
	_initialize_game_systems()

func _initialize_game_systems():
	maze_manager = get_node("/root/MazeManager")
	sanity_manager = get_node("/root/SanityManager") 
	harvest_logger = get_node("/root/HarvestLogger")
	weird_things_manager = get_node("/root/WeirdThingsManager")
	
	# Connect to system signals
	if sanity_manager:
		sanity_manager.sanity_changed.connect(_on_sanity_changed)
	if weird_things_manager:
		weird_things_manager.weird_thing_collected.connect(_on_weird_thing_collected)

func _process(delta):
	if not game_active:
		return
		
	_update_maze_shift_timer(delta)
	_update_narrative_progression()

func start_new_game():
	"""Initialize a new game session"""
	game_active = true
	current_sanity = initial_sanity
	weird_findings = 0
	story_progress = 0
	maze_shift_timer = 0.0
	is_stressed_mode = false
	
	# Initialize maze
	if maze_manager:
		maze_manager.generate_new_maze()
	
	# Place weird things
	if weird_things_manager:
		weird_things_manager.place_weird_things()
	
	# Load harvest echoes from previous runs
	if harvest_logger:
		harvest_logger.spawn_echoes_from_previous_runs()

func end_game(cause: String, location: Vector2):
	"""End the current game and log the results"""
	game_active = false
	
	# Log this run for future echoes
	if harvest_logger:
		harvest_logger.log_run_completion(cause, location, current_sanity, weird_findings)
	
	emit_signal("game_over")

func _update_maze_shift_timer(delta):
	"""Handle periodic maze shifting"""
	maze_shift_timer += delta
	var current_interval = maze_shift_interval_stressed if is_stressed_mode else maze_shift_interval
	
	if maze_shift_timer >= current_interval:
		maze_shift_timer = 0.0
		_trigger_maze_shift()

func _trigger_maze_shift():
	"""Trigger a maze shift event"""
	if maze_manager:
		maze_manager.shift_maze_section()
	
	emit_signal("maze_shifted")
	
	# Show narrative message
	var messages = [
		"The maze shifts around you...",
		"The walls rearrange themselves...", 
		"Reality bends and twists...",
		"The corn whispers as paths change..."
	]
	_show_message(messages[randi() % messages.size()])

func _update_narrative_progression():
	"""Handle story progression based on collected items"""
	match story_progress:
		0:
			if weird_findings >= 3:
				_show_message("The objects seem connected somehow. Your head begins to ache as whispers grow louder...")
				story_progress = 1
		1:
			if weird_findings >= 5:
				_show_message("Something's following you. Don't look back. Find the exit BEFORE it finds you.")
				story_progress = 2
				is_stressed_mode = true
				
				# Activate the stalker
				var stalker = get_tree().get_first_node_in_group("stalker")
				if stalker and stalker.has_method("activate"):
					stalker.activate()

func _on_sanity_changed(new_sanity: int):
	"""React to sanity changes"""
	current_sanity = new_sanity
	emit_signal("sanity_changed", new_sanity)
	
	# Trigger events based on sanity thresholds
	if new_sanity <= 20:
		_trigger_low_sanity_events()
	elif new_sanity <= 50:
		_trigger_medium_sanity_events()

func _on_weird_thing_collected(type: String):
	"""React to weird thing collection"""
	weird_findings += 1
	emit_signal("weird_thing_collected", type)
	
	# Apply sanity loss
	if sanity_manager:
		sanity_manager.modify_sanity(-randi_range(5, 15))

func _trigger_low_sanity_events():
	"""Trigger events when sanity is critically low"""
	# Increase watcher spawn rate
	var watcher = get_tree().get_first_node_in_group("watcher")
	if watcher and watcher.has_method("set_spawn_rate"):
		watcher.set_spawn_rate(0.6)

func _trigger_medium_sanity_events():
	"""Trigger events when sanity is moderately low"""
	# Increase watcher spawn rate
	var watcher = get_tree().get_first_node_in_group("watcher")
	if watcher and watcher.has_method("set_spawn_rate"):
		watcher.set_spawn_rate(0.25)

func _show_message(text: String):
	"""Display a narrative message to the player"""
	# This will be connected to UI system
	print("NARRATIVE: ", text)
	
	# TODO: Connect to UI message system
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("show_message"):
		ui_manager.show_message(text, 3.0)

# Public API for other systems
func get_current_sanity() -> int:
	return current_sanity

func get_weird_findings_count() -> int:
	return weird_findings

func is_game_active() -> bool:
	return game_active
