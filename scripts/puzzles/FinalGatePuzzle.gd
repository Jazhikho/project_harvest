extends Node3D
## Final Gate Puzzle - Unlocks when all other puzzles are complete

class_name FinalGatePuzzle

## Unique puzzle identifier for save/events
@export var puzzle_id: String = "final_gate"
## Item ID required to open gate
@export var required_item: String = "hollow_key"
## SFX library for gate open sounds
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
const PREREQUISITE_PUZZLES: Array[String] = [
	"whispering_hollow",
	"watching_stones",
	"crows_parliament",
]
const KEY_SPAWN_OFFSET: Vector3 = Vector3(0.0, 1.25, 2.0)

@onready var gate_area: Area3D = $gate/Area3D

func _ready() -> void:
	set_meta("is_puzzle", true)
	set_meta("puzzle_id", puzzle_id)
	
	call_deferred("_initialize_systems")
	_setup_interaction_area()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = _resolve_system_node("message_bus_override", "/root/MessageBus")
	_player_inventory = _resolve_system_node("player_inventory_override", "/root/PlayerInventory")
	_save_manager = _resolve_system_node("save_manager_override", "/root/SaveManager")
	_item_manager = _resolve_system_node("item_manager_override", "/root/ItemManager")
	_audio_manager = _resolve_system_node("audio_manager_override", "/root/AudioManager")
	
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
		var gate_node: Node3D = get_node_or_null("gate")
		if not gate_node:
			gate_node = get_node_or_null("Gate")
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
	
	gate_area.collision_layer = 1 << (CollisionHelper.LAYER_PUZZLE_OBJECTS - 1)
	gate_area.collision_mask = 1 << (CollisionHelper.LAYER_PLAYER - 1)
	if not gate_area.body_entered.is_connected(_on_interaction_body_entered):
		gate_area.body_entered.connect(_on_interaction_body_entered)
	if not gate_area.body_exited.is_connected(_on_interaction_body_exited):
		gate_area.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node3D) -> void:
	if body and body.is_in_group("player") and body.has_method("register_nearby_interactable"):
		body.register_nearby_interactable(self)

func _on_interaction_body_exited(body: Node3D) -> void:
	if body and body.is_in_group("player") and body.has_method("unregister_nearby_interactable"):
		body.unregister_nearby_interactable(self)

func _check_key_spawn() -> void:
	"""Spawn the key at the gate once all prerequisite puzzles are complete."""
	if _key_spawned or _gate_unlocked:
		return

	if not _are_prerequisite_puzzles_complete():
		return

	if _player_has_gate_key() or _is_key_in_backpack() or _is_key_in_world():
		_key_spawned = true
		return

	var key_instance: Node3D = _spawn_gate_key()
	if key_instance:
		_key_spawned = true
		_show_message("An ornate key now hangs before the gate.")
	else:
		push_error("FinalGatePuzzle: Failed to spawn hollow_key at the gate")

func interact() -> bool:
	"""Called when player interacts with the gate"""
	if _gate_unlocked:
		return true
	
	# Check if player has the key
	if _player_inventory.has_item("hollow_key"):
		_unlock_gate()
		return true
	else:
		# Emit object interaction event for toast system
		if _message_bus:
			_message_bus.emit_event("object_interacted", ["final_gate", _interaction_count, self])
		
		_interaction_count += 1
		_save_puzzle_state()
		
		# Old message system (keeping for backwards compatibility)
		if _interaction_count == 1:
			_play_sfx_stream(sfx_library.stilllocked)
			# Message now comes from object_interactions.json via toast
		elif _interaction_count == 2:
			_play_sfx_stream(sfx_library.kick)
			# Message now comes from object_interactions.json via toast
		else:
			# Message now comes from object_interactions.json via toast
			pass
		
		return false

func _unlock_gate() -> void:
	"""Unlock the gate with the key"""
	_player_inventory.remove_item("hollow_key")
	_gate_unlocked = true
	_save_puzzle_state()
	
	# Start the ending sequence with fade and sounds
	_play_ending_sequence()

func _play_ending_sequence() -> void:
	"""Play the ending sequence with fade and sounds"""
	# Play padlock sound immediately
	if sfx_library:
		_play_sfx_stream(sfx_library.padlock)
	
	# Create timer for padlock sound
	var padlock_timer: SceneTreeTimer = get_tree().create_timer(1.0)
	await padlock_timer.timeout
	
	# Play gate open sound
	if sfx_library:
		_play_sfx_stream(sfx_library.gate_open)
	
	# Request screen fade to black through MessageBus (2.5 second fade)
	if _message_bus:
		_message_bus.emit_event("screen_effect_requested", ["fade_black", 2.5, 1.0])
	
	# Request audio fade out through MessageBus (runs in parallel)
	if _message_bus:
		_message_bus.emit_event("audio_fade_requested", [2.5])
	
	# Wait for fades to complete and gate sound to finish
	var ending_timer: SceneTreeTimer = get_tree().create_timer(7.0)
	await ending_timer.timeout
	
	# Gather puzzle data before any cleanup happens
	var puzzle_data: Dictionary = _gather_puzzle_data()

	var tree: SceneTree = get_tree()
	var root: Window = tree.root
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	var game_director: Node = root.get_node_or_null("GameDirector")

	# Trigger cleanup before changing scenes. The transition is handled by an autoload
	# afterwards so it does not depend on this gate node surviving cleanup.
	if game_director and game_director.has_method("end_game"):
		game_director.end_game("Victory", puzzle_data)
	
	_transition_to_ending(scene_manager, tree)

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

func _transition_to_ending(scene_manager: Node = null, tree: SceneTree = null) -> void:
	"""Transition to the ending credits scene"""
	if scene_manager and scene_manager.has_method("load_ending_credits"):
		scene_manager.load_ending_credits()
	else:
		push_error("FinalGatePuzzle: SceneManager not found or missing load_ending_credits method")
		# Check if we're still in the tree before trying to change scenes
		if tree == null and is_inside_tree():
			tree = get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/ui/EndingCredits.tscn")
		else:
			push_error("FinalGatePuzzle: Node is no longer in tree, cannot transition to ending")

func _on_puzzle_completed(completed_puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle when any puzzle is completed - check if key should spawn"""
	_check_key_spawn()

func _on_tile_entered(tile_node: Node3D, tile_position: Vector2i, player: Node3D) -> void:
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
	_key_spawned = _player_has_gate_key() or _is_key_in_backpack() or _is_key_in_world()

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

func _are_prerequisite_puzzles_complete() -> bool:
	for puzzle_id: String in PREREQUISITE_PUZZLES:
		if not _save_manager.is_puzzle_completed(puzzle_id):
			return false
	return true

func _player_has_gate_key() -> bool:
	return _player_inventory != null \
		and _player_inventory.has_method("has_item") \
		and _player_inventory.has_item(required_item)

func _is_key_in_backpack() -> bool:
	if _save_manager == null or not _save_manager.has_method("get_backpack_inventory"):
		return false
	return required_item in _save_manager.get_backpack_inventory()

func _is_key_in_world() -> bool:
	if not is_inside_tree():
		return false

	for collectible in get_tree().get_nodes_in_group("collectibles"):
		if not is_instance_valid(collectible):
			continue

		var collectible_item_id: String = ""
		if collectible.has_meta("item_id"):
			collectible_item_id = String(collectible.get_meta("item_id"))
		elif collectible.has_method("get_item_id"):
			collectible_item_id = String(collectible.get_item_id())
		elif "item_id" in collectible:
			collectible_item_id = String(collectible.item_id)

		if collectible_item_id == required_item:
			return true

	return false

func _spawn_gate_key() -> Node3D:
	if _item_manager == null or not _item_manager.has_method("spawn_item_instance"):
		return null

	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = self

	var gate_node: Node3D = get_node_or_null("gate")
	if gate_node == null:
		gate_node = get_node_or_null("Gate")
	if gate_node == null:
		return null

	var spawn_position: Vector3 = gate_node.global_position + gate_node.global_basis * KEY_SPAWN_OFFSET
	return _item_manager.spawn_item_instance(required_item, spawn_position, parent_node)

func _resolve_system_node(override_meta_key: String, fallback_path: String) -> Node:
	if has_meta(override_meta_key):
		return get_meta(override_meta_key) as Node
	if not is_inside_tree():
		return null
	return get_node_or_null(fallback_path)
