extends Node3D
## Final Gate Puzzle - Unlocks when all other puzzles are complete

class_name FinalGatePuzzle

@export var puzzle_id: String = "final_gate"
@export var required_item: String = "hollow_key"

var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var _item_manager: Node

var _key_spawned: bool = false
var _gate_unlocked: bool = false

@onready var gate_area: Area3D = $Gate/Area3D
@onready var altar_node: Node3D = $Altar

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
	
	if not _message_bus or not _player_inventory or not _save_manager:
		push_error("FinalGatePuzzle: Required systems not found")
		return
	
	_load_puzzle_state()
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
	"""Spawn the key on the altar"""
	if not altar_node:
		push_error("FinalGatePuzzle: Altar node not found")
		return
	
	print("FinalGatePuzzle: Spawning key on altar")
	
	# Create key scene or placeholder
	var key_scene_path: String = "res://scenes/items/hollow_key.tscn"
	var key_instance: Node3D
	
	if ResourceLoader.exists(key_scene_path):
		var key_scene: PackedScene = load(key_scene_path)
		key_instance = key_scene.instantiate()
	else:
		# Create placeholder key
		key_instance = MeshInstance3D.new()
		key_instance.mesh = CylinderMesh.new()
		key_instance.mesh.height = 0.2
		key_instance.mesh.top_radius = 0.3
		key_instance.mesh.bottom_radius = 0.3
		
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color.GOLD
		material.metallic = 0.8
		key_instance.set_surface_override_material(0, material)
	
	key_instance.name = "HollowKey"
	key_instance.set_meta("item_id", "hollow_key")
	key_instance.set_meta("is_collectible", true)
	
	# Position key on altar
	altar_node.add_child(key_instance)
	key_instance.position = Vector3(0, 1, 0)
	
	_key_spawned = true
	_save_puzzle_state()
	
	_show_message("A golden key materializes on the altar!")

func interact() -> bool:
	"""Called when player interacts with the gate"""
	if _gate_unlocked:
		_trigger_game_end()
		return true
	
	# Check if player has the key
	if _player_inventory.has_item("hollow_key"):
		_unlock_gate()
		return true
	else:
		if _key_spawned:
			_show_message("The gate is locked. You need the key from the altar.")
		else:
			_show_message("The gate is sealed. Perhaps completing all puzzles will reveal the way.")
		return false

func _unlock_gate() -> void:
	"""Unlock the gate with the key"""
	_player_inventory.remove_item("hollow_key")
	_gate_unlocked = true
	_save_puzzle_state()
	
	_show_message("The key turns with a satisfying click. The gate swings open...")
	
	# Wait a moment then trigger ending
	await get_tree().create_timer(2.0).timeout
	_trigger_game_end()

func _trigger_game_end() -> void:
	"""Trigger the game ending"""
	print("FinalGatePuzzle: GAME COMPLETE!")
	
	if _message_bus:
		_message_bus.emit_event("game_completed", [{
			"puzzles_data": _gather_puzzle_data()
		}])
	
	# Show temporary game over screen
	_show_game_over()

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

func _show_game_over() -> void:
	"""Show temporary game over screen"""
	var game_over_label: Label = Label.new()
	game_over_label.text = "CONGRATULATIONS!\n\nYou have escaped the maze!\n\nPress ESC to return to menu"
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.add_child(game_over_label)
	
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	get_tree().current_scene.add_child(overlay)
	get_tree().current_scene.add_child(center_container)
	
	get_tree().paused = true

func _load_puzzle_state() -> void:
	"""Load puzzle state from save"""
	var state: Dictionary = _save_manager.get_puzzle_state(puzzle_id)
	_key_spawned = state.get("key_spawned", false)
	_gate_unlocked = state.get("gate_unlocked", false)

func _save_puzzle_state() -> void:
	"""Save current puzzle state"""
	_save_manager.set_puzzle_state(puzzle_id, {
		"key_spawned": _key_spawned,
		"gate_unlocked": _gate_unlocked
	})

func _show_message(text: String) -> void:
	"""Show message to player"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", [text, 3.0, 1])
