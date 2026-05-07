extends SceneTree

var _failed: bool = false

class FakeStateManager:
	extends Node

	func get_state(key: String = "") -> Variant:
		if key == "collected_items":
			return []
		return null

class FakeSaveManager:
	extends Node

	var completed_puzzles: Dictionary = {}
	var used_items: Array[String] = []

	func is_puzzle_completed(puzzle_id: String) -> bool:
		return bool(completed_puzzles.get(puzzle_id, false))

	func is_puzzle_item_used(item_id: String) -> bool:
		return item_id in used_items

func _initialize() -> void:
	var save_manager := FakeSaveManager.new()

	var item_manager: Node = load("res://scripts/autoloads/gameloop/ItemManager.gd").new()
	item_manager.set_meta("save_manager_override", save_manager)
	item_manager.set("_state_manager", FakeStateManager.new())
	item_manager.set("_item_definitions", {
		"hollow_key": {
			"id": "hollow_key",
			"category": "special",
			"puzzle_id": "final_gate",
		},
		"broken_glass_1": {
			"id": "broken_glass_1",
			"category": "items",
		},
		"note_1": {
			"id": "note_1",
			"category": "notes",
		},
	})
	item_manager.set("_item_categories", {
		"notes": ["note_1"],
		"items": ["broken_glass_1", "hollow_key"],
	})
	item_manager.set("_item_scene_map", {
		"hollow_key": true,
		"broken_glass_1": true,
	})

	_assert_missing_key_before_prerequisites(item_manager)
	_assert_key_is_forced_once_prerequisites_complete(item_manager, save_manager)
	_assert_duplicate_filter_blocks_repeat_key(item_manager, save_manager)

	item_manager.free()
	save_manager.free()

	if _failed:
		printerr("test_gate_key_spawn: FAIL")
		quit(1)
		return

	print("test_gate_key_spawn: PASS")
	quit(0)

func _assert_missing_key_before_prerequisites(item_manager: Node) -> void:
	var spawnable: Array[Dictionary] = item_manager.get_spawnable_items({}, [])
	for entry: Dictionary in spawnable:
		if String(entry.get("item_id", "")) == "hollow_key":
			_fail("hollow_key should not spawn before prerequisite puzzles are complete")
			return

func _assert_key_is_forced_once_prerequisites_complete(item_manager: Node, save_manager: FakeSaveManager) -> void:
	save_manager.completed_puzzles = {
		"whispering_hollow": true,
		"watching_stones": true,
		"crows_parliament": true,
	}

	var spawnable: Array[Dictionary] = item_manager.get_spawnable_items({}, [])
	if spawnable.size() != 1:
		_fail("Expected hollow_key to be the only spawnable item once prerequisites are complete")
		return
	if String(spawnable[0].get("item_id", "")) != "hollow_key":
		_fail("Expected hollow_key to be forced into the next eligible item spawn")
		return

func _assert_duplicate_filter_blocks_repeat_key(item_manager: Node, save_manager: FakeSaveManager) -> void:
	save_manager.completed_puzzles = {
		"whispering_hollow": true,
		"watching_stones": true,
		"crows_parliament": true,
	}

	var spawnable: Array[Dictionary] = item_manager.get_spawnable_items({}, ["hollow_key"])
	for entry: Dictionary in spawnable:
		if String(entry.get("item_id", "")) == "hollow_key":
			_fail("hollow_key should not be listed twice during a single tile spawn pass")
			return

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
