extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	_assert_set_puzzle_state_preserves_completed_flag()
	_assert_used_items_repair_missing_completion_flags()

	if _failed:
		printerr("test_save_manager_puzzle_repair: FAIL")
		quit(1)
		return

	print("test_save_manager_puzzle_repair: PASS")
	quit(0)

func _assert_set_puzzle_state_preserves_completed_flag() -> void:
	var save_manager: Node = load("res://scripts/autoloads/system/SaveManager.gd").new()
	save_manager.save_data = {
		"puzzles": {
			"watching_stones": {
				"completed": true,
				"completion_time": 12345,
				"altar_count": 2,
			}
		},
		"puzzle_items_used": [],
	}

	save_manager._merge_puzzle_state("watching_stones", {
		"altar_items": ["phone"],
		"brazier_items": ["flag"],
	})

	var state: Dictionary = save_manager.save_data["puzzles"]["watching_stones"]
	if not state.get("completed", false):
		_fail("set_puzzle_state should preserve an existing completed flag")
	elif int(state.get("completion_time", 0)) != 12345:
		_fail("set_puzzle_state should preserve completion_time when updating puzzle state")

	save_manager.free()

func _assert_used_items_repair_missing_completion_flags() -> void:
	var save_manager: Node = load("res://scripts/autoloads/system/SaveManager.gd").new()
	save_manager.save_data = {
		"puzzles": {
			"whispering_hollow": {
				"wrong_attempts": [],
			}
		},
		"puzzle_items_used": [
			"symbol_watch",
			"symbol_coin",
			"symbol_ticket",
			"phone",
			"holy_book",
			"flag",
			"broken_glass_1",
			"broken_glass_2",
			"broken_glass_3",
		],
	}

	save_manager._repair_puzzle_completion_flags()

	for puzzle_id: String in ["whispering_hollow", "watching_stones", "crows_parliament"]:
		var state: Dictionary = save_manager.save_data["puzzles"].get(puzzle_id, {})
		if not state.get("completed", false):
			_fail("Expected repair to restore completed flag for %s from used puzzle items" % puzzle_id)
			break

	save_manager.free()

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
