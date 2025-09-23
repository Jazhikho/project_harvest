extends Node
## PuzzleProgress
## Centralizes puzzle progress and completion for a single puzzle tile.
## Talks to SaveManager and informs the MessageBus.

@export var puzzle_id: StringName = &"watching_stones"

var _bus: Node = null
var _save: Node = null
var _completed: bool = false

func _resolve() -> void:
	"""Cache SaveManager and MessageBus."""
	if has_node("/root/MessageBus"):
		_bus = get_node("/root/MessageBus")
	if has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")

func _ready() -> void:
	"""Resolve services and query initial completion."""
	_resolve()
	if _save != null and _save.has_method("is_puzzle_completed"):
		var done: bool = _save.call("is_puzzle_completed", puzzle_id)
		_completed = done

func report_progress(step: StringName, amount: int = 1) -> void:
	"""
	Record progress with the SaveManager, if supported.
	Use this from your object scripts when the player advances the puzzle.
	"""
	if _completed:
		return
	if _save != null and _save.has_method("update_puzzle_progress"):
		_save.call("update_puzzle_progress", puzzle_id, step, amount)

func mark_completed(extra: Dictionary = {}) -> void:
	"""
	Mark the puzzle complete in SaveManager and notify via MessageBus.
	Call this once when the puzzle is definitively solved.
	"""
	if _completed:
		return
	_completed = true
	if _save != null and _save.has_method("mark_puzzle_completed"):
		_save.call("mark_puzzle_completed", puzzle_id)
	
	var payload: Dictionary = {"puzzle_id": String(puzzle_id), "extra": extra}
	if _bus != null and _bus.has_method("emit_event"):
		_bus.call("emit_event", &"puzzle_completed", payload)
