extends Node3D
## Final Gate Puzzle - Unlocks when all other puzzles are complete

class_name FinalGatePuzzle

@export var puzzle_id: String = "final_gate"
@export var required_item: String = "hollow_key"
@export var sfx_library: SFX

var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var _item_manager: Node
var _audio_manager: Node

var _key_spawned: bool = false
var _gate_unlocked: bool = false
var _first_tile_visit: bool = false
var _interaction_count: int = 0

@onready var gate_area: Area3D = $gate/Area3D
@onready var altar_node: Node3D = $altar

func _ready() -> void:
	set_meta("is_puzzle", true)
	set_meta("puzzle_id", puzzle_id)
	
	call_deferred("_initialize_systems")
	_setup_interaction_area()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")
	_save_manager = get_node_or_null("/root/SaveManager")
	_item_manager = get_node_or_null("/root/ItemManager")
	_audio_manager = get_node_or_null("/root/AudioManager")
	
	if not _message_bus or not _player_inventory or not _save_manager or not _item_manager:
		push_error("FinalGatePuzzle: Required systems not found")
		return
	
	if _message_bus:
		_message_bus.connect_event("tile_entered", _on_tile_entered)
		_message_bus.connect_event("puzzle_completed", _on_puzzle_completed)
		_message_bus.connect_event("game_started", _on_game_started)
	
	_load_puzzle_state()
	_check_key_spawn()

func _on_game_started() -> void:
	"""Reset puzzle state for new run - gate should always start locked"""
	_gate_unlocked = false
	_check_key_spawn()

func _setup_interaction_area() -> void:
	"""Setup interaction area for gate"""
	if not gate_area:
		var gate_node: Node3D = get_node_or_null("Gate")
		if not gate_node:
			push_error("FinalGatePuzzle: Gate node not found")
			return
		
		gate_area = Area3D.new()
		gate_area.name = "Area3D"
		gate_node.add_child(gate_area)
		
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(3, 4, 0.5)
		collision.shape = shape
		gate_area.add_child(collision)
	
	gate_area.collision_layer = 8
	gate_area.collision_mask = 1

func _check_key_spawn() -> void:
	"""Check if key should spawn on altar"""
	if _key_spawned or _gate_unlocked:
		return
	
	# Check if all other puzzles are completed
	var all_complete: bool = true
	var puzzles_to_check: Array[String] = ["whispering_hollow", "watching_stones", "crows_parliament"]
	
	for puzzle in puzzles_to_check:
		if not _save_manager.is_puzzle_completed(puzzle):
			all_complete = false
			break
	
	if all_complete and not _key_spawned:
		_spawn_key()

func _spawn_key() -> void:
	"""Spawn the key on the altar using ItemManager"""
	if not altar_node:
		push_error("FinalGatePuzzle: Altar node not found")
		return
	
	print("FinalGatePuzzle: Spawning key on altar")
	
	var spawn_position: Vector3 = altar_node.global_position + Vector3(0, 1.5, 0)
	var key_instance: Node3D = _item_manager.spawn_item_instance("hollow_key", spawn_position, get_tree().current_scene)
	
	if not key_instance:
		push_error("FinalGatePuzzle: Failed to spawn hollow_key")
		return
	
	_key_spawned = true
	_save_puzzle_state()

func interact() -> bool:
	"""Called when player interacts with the gate"""
	if _gate_unlocked:
		return true
	
	# Check if player has the key
	if _player_inventory.has_item("hollow_key"):
		_unlock_gate()
		return true
	else:
		_interaction_count += 1
		_save_puzzle_state()
		
		if _interaction_count == 1:
			_play_sfx_stream(sfx_library.stilllocked)
			_show_message("It's locked. Figures. I wonder if there is a key around here?")
		elif _interaction_count == 2:
			_play_sfx_stream(sfx_library.kick)
			_show_message("Oww... Ok, yeah, this gate is pretty solid.")
		else:
			_show_message("Still locked... I need to find the key...")
		
		return false

func _unlock_gate() -> void:
	"""Unlock the gate with the key"""
	_player_inventory.remove_item("hollow_key")
	_gate_unlocked = true
	_save_puzzle_state()
	
	# Start the ending sequence with fade and sounds
	await _play_ending_sequence()

func _play_ending_sequence() -> void:
	"""Play the ending sequence with fade and sounds"""
	# Play padlock sound immediately
	_play_sfx_stream(sfx_library.padlock)
	
	# Create timer for padlock sound
	var padlock_timer: SceneTreeTimer = get_tree().create_timer(1.0)
	await padlock_timer.timeout
	
	# Play gate open sound
	_play_sfx_stream(sfx_library.gate_open)
	
	# Request screen fade to black through MessageBus (2.5 second fade)
	_message_bus.emit_event("screen_effect_requested", ["fade_black", 2.5, 1.0])
	
	# Request audio fade out through MessageBus (runs in parallel)
	_message_bus.emit_event("audio_fade_requested", [2.5])
	
	# Wait for fades to complete and gate sound to finish
	var ending_timer: SceneTreeTimer = get_tree().create_timer(7.0)
	await ending_timer.timeout
	
	# Gather puzzle data before any cleanup happens
	var puzzle_data: Dictionary = _gather_puzzle_data()
	
	# Transition to ending scene FIRST (before cleanup removes us from tree)
	_transition_to_ending()
	
	# THEN trigger game end to cleanup (after scene transition has started)
	# Use call_deferred so it happens after the scene change begins
	var game_director: Node = get_node_or_null("/root/GameDirector")
	if game_director and game_director.has_method("end_game"):
		game_director.call_deferred("end_game", "Victory", puzzle_data)

func _gather_puzzle_data() -> Dictionary:
	"""Gather data from all completed puzzles"""
	var data: Dictionary = {}
	
	# Get Watching Stones altar count
	var watching_stones_state: Dictionary = _save_manager.get_puzzle_state("watching_stones")
	data["altar_count"] = watching_stones_state.get("altar_count", 0)
	
	# Get Crows Parliament completion order
	var crows_state: Dictionary = _save_manager.get_puzzle_state("crows_parliament")
	data["mirror_completion_order"] = crows_state.get("completion_order", -1)
	
	# Get Whispering Hollow wrong attempts
	var hollow_state: Dictionary = _save_manager.get_puzzle_state("whispering_hollow")
	data["well_wrong_attempts"] = hollow_state.get("wrong_attempts", []).size()
	
	return data

func _transition_to_ending() -> void:
	"""Transition to the ending credits scene"""
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_method("load_ending_credits"):
		scene_manager.load_ending_credits()
	else:
		push_error("FinalGatePuzzle: SceneManager not found or missing load_ending_credits method")
		# Check if we're still in the tree before trying to change scenes
		var tree: SceneTree = get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/ui/EndingCredits.tscn")
		else:
			push_error("FinalGatePuzzle: Node is no longer in tree, cannot transition to ending")

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle when any puzzle is completed - check if key should spawn"""
	_check_key_spawn()

func _on_tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D) -> void:
	"""Handle when player enters this tile for the first time"""
	if _first_tile_visit:
		return
	
	# Check if this is the final gate tile (we are under Maze/Objects, so parent is Maze, grandparent is FinalGate)
	var final_gate_tile: Node3D = get_parent().get_parent()
	if tile_node != final_gate_tile:
		return
	
	_first_tile_visit = true
	_save_puzzle_state()
	_show_message("A gate... this must be the way out!")
	
	# Check if key should spawn when entering tile
	_check_key_spawn()

func _load_puzzle_state() -> void:
	"""Load puzzle state from save - only load first visit flag"""
	var state: Dictionary = _save_manager.get_puzzle_state(puzzle_id)
	# Only persist the first tile visit message across sessions
	_first_tile_visit = state.get("first_tile_visit", false)
	# Reset these each run so the gate is always playable
	_gate_unlocked = false
	_interaction_count = 0

func _save_puzzle_state() -> void:
	"""Save current puzzle state - only save first visit to avoid duplicate message"""
	_save_manager.set_puzzle_state(puzzle_id, {
		"first_tile_visit": _first_tile_visit
	})

func _show_message(text: String) -> void:
	"""Show message to player"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", [text, 3.0, 1])

func _play_sfx_stream(stream: AudioStream) -> void:
	"""Play a sound effect from the SFX library"""
	if not stream:
		return
	
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
