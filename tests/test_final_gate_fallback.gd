extends SceneTree

var _failed: bool = false

class FakeMessageBus:
	extends Node

	func connect_event(_event_name: String, _callable: Callable) -> void:
		pass

	func emit_event(_event_name: String, _args: Array = []) -> void:
		pass

class FakePlayerInventory:
	extends Node

	var items: Array[String] = []

	func has_item(item_id: String) -> bool:
		return item_id in items

class FakeSaveManager:
	extends Node

	var completed_puzzles: Dictionary = {}
	var backpack_inventory: Array[String] = []

	func is_puzzle_completed(puzzle_id: String) -> bool:
		return bool(completed_puzzles.get(puzzle_id, false))

	func get_puzzle_state(_puzzle_id: String) -> Dictionary:
		return {}

	func set_puzzle_state(_puzzle_id: String, _state: Dictionary) -> void:
		pass

	func get_backpack_inventory() -> Array[String]:
		return backpack_inventory.duplicate()

class FakeItemManager:
	extends Node

	var spawn_count: int = 0
	var last_item_id: String = ""

	func spawn_item_instance(item_id: String, position: Vector3, parent: Node = null) -> Node3D:
		spawn_count += 1
		last_item_id = item_id
		var spawned := Node3D.new()
		spawned.name = "SpawnedKey"
		spawned.position = position
		spawned.set_meta("item_id", item_id)
		spawned.add_to_group("collectibles")
		if parent != null:
			parent.add_child(spawned)
		return spawned

func _initialize() -> void:
	await _assert_gate_spawns_key_once_prerequisites_complete()
	await _assert_gate_does_not_spawn_duplicate_if_key_in_backpack()

	if _failed:
		printerr("test_final_gate_fallback: FAIL")
		quit(1)
		return

	print("test_final_gate_fallback: PASS")
	quit(0)

func _assert_gate_spawns_key_once_prerequisites_complete() -> void:
	var harness := _build_harness({
		"whispering_hollow": true,
		"watching_stones": true,
		"crows_parliament": true,
	}, [])
	await process_frame
	await process_frame

	var item_manager: FakeItemManager = harness["item_manager"]
	if item_manager.spawn_count != 1:
		_fail("Expected final gate fallback to spawn the key once prerequisites are complete")
	elif item_manager.last_item_id != "hollow_key":
		_fail("Expected final gate fallback to spawn hollow_key")

	_cleanup_harness(harness)

func _assert_gate_does_not_spawn_duplicate_if_key_in_backpack() -> void:
	var harness := _build_harness({
		"whispering_hollow": true,
		"watching_stones": true,
		"crows_parliament": true,
	}, ["hollow_key"])
	await process_frame
	await process_frame

	var item_manager: FakeItemManager = harness["item_manager"]
	if item_manager.spawn_count != 0:
		_fail("Expected final gate fallback not to spawn a duplicate key when backpack already has it")

	_cleanup_harness(harness)

func _build_harness(completed_puzzles: Dictionary, backpack_inventory: Array[String]) -> Dictionary:
	var message_bus := FakeMessageBus.new()

	var player_inventory := FakePlayerInventory.new()

	var save_manager := FakeSaveManager.new()
	save_manager.completed_puzzles = completed_puzzles.duplicate(true)
	save_manager.backpack_inventory = backpack_inventory.duplicate()

	var item_manager := FakeItemManager.new()

	var audio_manager := Node.new()

	var maze := Node3D.new()
	maze.name = "Maze"
	root.add_child(maze)

	var puzzle_node := Node3D.new()
	puzzle_node.name = "Objects"

	var gate := Node3D.new()
	gate.name = "gate"
	puzzle_node.add_child(gate)

	var gate_area := Area3D.new()
	gate_area.name = "Area3D"
	gate.add_child(gate_area)

	puzzle_node.set_script(load("res://scripts/puzzles/FinalGatePuzzle.gd"))
	puzzle_node.set_meta("message_bus_override", message_bus)
	puzzle_node.set_meta("player_inventory_override", player_inventory)
	puzzle_node.set_meta("save_manager_override", save_manager)
	puzzle_node.set_meta("item_manager_override", item_manager)
	puzzle_node.set_meta("audio_manager_override", audio_manager)
	maze.add_child(puzzle_node)

	return {
		"message_bus": message_bus,
		"player_inventory": player_inventory,
		"save_manager": save_manager,
		"item_manager": item_manager,
		"audio_manager": audio_manager,
		"maze": maze,
		"puzzle_node": puzzle_node,
	}

func _cleanup_harness(harness: Dictionary) -> void:
	for key in harness.keys():
		var node: Node = harness[key]
		if is_instance_valid(node):
			node.queue_free()

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
