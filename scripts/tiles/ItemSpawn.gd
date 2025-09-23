extends Node3D
## ItemSpawnController
## Manages item spawn anchors on a tile. Keeps zero logic about uniqueness;
## items and SaveManager handle that. This only instantiates at defined points.

@export var max_active: int = 4
@export var group_for_spawned: StringName = &"tile_item"

var _points: Array[Node3D] = []
var _spawned: Array[Node3D] = []

func _collect_points() -> void:
	"""Cache children named like ItemPoint* as spawn anchors."""
	_points.clear()
	for child in get_children():
		if child is Node3D and child.name.begins_with("ItemPoint"):
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
	"""Return the list of item spawn points."""
	return _points.duplicate()

func clear_spawned() -> void:
	"""Free all items spawned by this controller."""
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()

func spawn_item_at(index: int, scene: PackedScene) -> Node3D:
	"""
	Instantiate an item scene at point[index] and return the instance.
	Items should carry their own InteractableArea + pickup script.
	"""
	if scene == null:
		push_error("ItemSpawnController: scene is null")
		return null
	if not _validate_index(index):
		push_error("ItemSpawnController: invalid index %d" % index)
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
