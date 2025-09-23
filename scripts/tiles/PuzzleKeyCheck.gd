extends Node3D
## PuzzleKeyCheck
## Listens for puzzle completion events. When the required set is complete,
## spawns the final key on 'altar' exactly once.

@export var required_puzzles: PackedStringArray = ["watching_stones", "crows_parliament", "whispering_hollow"]
@export var key_scene: PackedScene
@export var key_item_id: StringName = &"final_key"

var _bus: Node = null
var _save: Node = null
var _altar: Node3D = null
var _spawned: bool = false

func _resolve() -> void:
	"""Cache bus, save, and altar ref."""
	if has_node("/root/MessageBus"):
		_bus = get_node("/root/MessageBus")
	if has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")
	_altar = get_node_or_null("altar") as Node3D

func _wire_bus() -> void:
	"""Subscribe to puzzle_completed if bus supports it."""
	if _bus == null:
		return
	if _bus.has_method("on"):
		_bus.call("on", "puzzle_completed", self, "_on_puzzle_completed_payload")
	elif _bus.has_signal("puzzle_completed"):
		_bus.connect("puzzle_completed", _on_puzzle_completed_signal)

func _ready() -> void:
	"""Resolve, wire and check if we should already have spawned the key."""
	_resolve()
	_wire_bus()
	_check_and_spawn_if_ready()

func _on_puzzle_completed_signal(payload: Dictionary) -> void:
	"""Signal-style bus callback."""
	_on_puzzle_completed_payload(payload)

func _on_puzzle_completed_payload(payload: Dictionary) -> void:
	"""Unified handler for payload-based bus."""
	_check_and_spawn_if_ready()

func _all_required_completed() -> bool:
	"""Ask SaveManager whether all required puzzle ids are completed."""
	if _save == null:
		return false
	for pid in required_puzzles:
		if not _save.has_method("is_puzzle_completed"):
			return false
		var done: bool = _save.call("is_puzzle_completed", StringName(pid))
		if not done:
			return false
	return true

func _check_and_spawn_if_ready() -> void:
	"""Spawn the key once when all required puzzles are complete."""
	if _spawned:
		return
	if key_scene == null:
		return
	if _altar == null:
		push_error("PuzzleKeyCheck: altar node not found")
		return
	if not _all_required_completed():
		return
	
	var inst: Node3D = key_scene.instantiate() as Node3D
	inst.name = "FinalKey"
	inst.set_meta("item_id", key_item_id)
	inst.set_meta("is_collectible", true)
	_altar.add_child(inst)
	inst.global_transform = _altar.global_transform.translated_local(Vector3(0.0, 1.2, 0.0))
	_spawned = true
