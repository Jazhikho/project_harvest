extends SceneTree

var _failed: bool = false

class FakeSceneManager:
	extends Node

	var load_count: int = 0

	func load_ending_credits() -> void:
		load_count += 1

func _initialize() -> void:
	_assert_transition_uses_cached_scene_manager()

	if _failed:
		printerr("test_final_gate_transition: FAIL")
		quit(1)
		return

	print("test_final_gate_transition: PASS")
	quit(0)

func _assert_transition_uses_cached_scene_manager() -> void:
	var gate: Node = load("res://scripts/puzzles/FinalGatePuzzle.gd").new()
	var scene_manager := FakeSceneManager.new()

	gate._transition_to_ending(scene_manager)

	if scene_manager.load_count != 1:
		_fail("Expected final gate transition to use the cached SceneManager")

	gate.free()
	scene_manager.free()

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
