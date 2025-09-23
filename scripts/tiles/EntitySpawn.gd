extends Node3D
## EntitySpawnController
## Manages spawn points for tile entities (enemies, NPCs, ambience).
## Provides a clean API for the TileManager (or whoever) to request spawns.

@export var max_active: int = 1
@export var group_for_spawned: StringName = &"tile_entity"

var _points: Array[Node3D] = []
var _spawned: Array[Node3D] = []

func _collect_points() -> void:
	"""Cache children named like EntityPoint* as spawn anchors."""
	_points.clear()
	for child in get_children():
		if child is Node3D and child.name.begins_with("EntityPoint"):
			_points.append(child as Node3D)

func _validate_index(index: int) -> bool:
	"""Bounds-check helper."""
	if index < 0:
		return false
	if index >= _points.size():
		return false
	return true

func _ready() -> void:
	"""Collect points on ready."""
	_collect_points()

func get_points() -> Array[Node3D]:
	"""Return the list of spawn point nodes."""
	return _points.duplicate()

func get_free_point_count() -> int:
	"""Return how many spawn points exist (not about availability)."""
	return _points.size()

func clear_spawned() -> void:
	"""Free all spawned children created by this controller."""
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()

func spawn_at(index: int, scene: PackedScene) -> Node3D:
	"""
	Instantiate 'scene' at point[index] and return the instance.
	Caller is responsible for AI hookup and lifetime beyond this controller.
	"""
	if scene == null:
		push_error("EntitySpawnController: scene is null")
		return null
	if not _validate_index(index):
		push_error("EntitySpawnController: invalid index %d" % index)
		return null
	if _spawned.size() >= max_active:
		return null
	
	var p: Node3D = _points[index]
	var inst: Node3D = scene.instantiate() as Node3D
	add_child(inst)
	inst.global_transform = p.global_transform
	if String(group_for_spawned) != "":
		inst.add_to_group(group_for_spawned)
	_spawned.append(inst)
	return inst
