extends Node
## Game Director - Main game coordination and high-level flow
## Now works through EventManager for unified event system

signal game_over
signal maze_shifted

@export var maze_size: Vector2i = Vector2i(100, 100)
@export var maze_shift_interval: float = 30.0
@export var maze_shift_interval_stressed: float = 15.0

var game_active: bool = false
var maze_shift_timer: float = 0.0
var is_stressed_mode: bool = false
var run_start_time: String

# References to systems
var event_manager: Node
var tile_manager: Node

func _ready():
	# Wait for other autoloads to initialize
	await get_tree().process_frame
	_initialize_game_systems()

func _initialize_game_systems():
	event_manager = get_node("/root/EventManager")
	tile_manager = get_node("/root/TileManager")
	
	# Connect to EventManager signals
	if event_manager:
		event_manager.sanity_changed.connect(_on_sanity_changed)
		event_manager.weird_thing_collected.connect(_on_weird_thing_collected)
		event_manager.run_ended.connect(_on_run_ended)
		event_manager.maze_shift_requested.connect(_trigger_maze_shift)

func _process(delta):
	if not game_active:
		return
		
	_update_maze_shift_timer(delta)

func start_new_game():
	"""Initialize a new game session"""
	game_active = true
	maze_shift_timer = 0.0
	is_stressed_mode = false
	run_start_time = Time.get_datetime_string_from_system()
	
	# Initialize EventManager state for new run
	if event_manager:
		event_manager.reset_run_state()
		event_manager.set_timestamp(run_start_time)
		event_manager.set_sanity(100)  # Reset to full sanity
	
	# Initialize maze through tile manager
	if tile_manager:
		if tile_manager.has_method("generate_new_maze"):
			tile_manager.generate_new_maze()
	
	# Spawn initial content through event system
	_spawn_initial_content()

func end_game(cause: String, _location: Vector2):
	"""End the current game and log the results"""
	game_active = false
	
	# Log run through event system
	if event_manager:
		var state = event_manager.get_state()
		state.run.death_type = cause
		# Trigger run logging through event system
		event_manager._log_harvest(cause)
	
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
	if tile_manager and tile_manager.has_method("shift_maze_section"):
		tile_manager.shift_maze_section()
	
	emit_signal("maze_shifted")
	
	# Show narrative message through event system
	if event_manager:
		event_manager.show_speech("maze_shift_message")

func _spawn_initial_content():
	"""Spawn initial game content through event system"""
	# This will trigger placement of weird things, echoes, etc. through event system
	# For now, manually trigger WeirdThingsManager until migration is complete
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("place_weird_things"):
		weird_things_manager.place_weird_things()
	
	# Spawn harvest echoes from previous runs
	var harvest_logger = get_node_or_null("/root/HarvestLogger")
	if harvest_logger and harvest_logger.has_method("spawn_echoes_from_previous_runs"):
		harvest_logger.spawn_echoes_from_previous_runs()

func _on_sanity_changed(new_sanity: int):
	"""React to sanity changes - now just for local state"""
	# Sanity events are now handled by EventManager through events.json
	# Just update local state for stressed mode timing
	if new_sanity <= 50 and not is_stressed_mode:
		is_stressed_mode = true

func _on_weird_thing_collected(type: String, _position: Vector2i):
	"""React to weird thing collection through EventManager"""
	# Collections are now fully handled by EventManager
	# This is just for any GameDirector-specific reactions
	print("GameDirector: Weird thing collected - ", type)

func _on_run_ended(mode: String):
	"""Handle run end signal from EventManager"""
	end_game(mode, Vector2.ZERO)

# Public API for other systems
func get_current_sanity() -> int:
	if event_manager:
		return event_manager.get_sanity()
	return 100

func is_game_active() -> bool:
	return game_active

func get_run_start_time() -> String:
	return run_start_time

# Tile interaction bridge to EventManager
func on_tile_entered(tile_id: String):
	"""Bridge tile entry to EventManager"""
	if event_manager:
		event_manager.on_tile_enter(tile_id)

func on_player_interact(tile_id: String, target_id: String = ""):
	"""Bridge player interaction to EventManager"""
	if event_manager:
		event_manager.on_interact(tile_id, target_id)
