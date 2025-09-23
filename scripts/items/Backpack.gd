extends Node3D
## BackpackRestore
## Loads previous-run items from SaveManager into this backpack.
## The backpack scene should expose either:
##   - load_items_from_ids(ids: PackedStringArray) -> void
##   - add_item_by_id(id: StringName) -> void

@export var clear_after_load: bool = true
@export var announce_bus_event: StringName = &"backpack_restored"

var _save: Node = null
var _bus: Node = null

func _resolve() -> void:
	"""Cache autoloads."""
	if has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")
	if has_node("/root/MessageBus"):
		_bus = get_node("/root/MessageBus")

func _load_into_backpack(ids: PackedStringArray) -> void:
	"""Load item ids into the backpack via preferred API."""
	if ids.is_empty():
		return
	if has_method("load_items_from_ids"):
		call("load_items_from_ids", ids)
		return
	if has_method("add_item_by_id"):
		for s in ids:
			call("add_item_by_id", StringName(s))

func _announce(ids: PackedStringArray) -> void:
	"""Tell the world we restored items, if a bus exists."""
	if _bus == null:
		return
	if _bus.has_method("emit_event"):
		_bus.call("emit_event", announce_bus_event, [ids])

func _ready() -> void:
	"""Perform the restoration."""
	_resolve()
	if _save == null:
		return
	if not _save.has_method("get_previous_run_items"):
		return
	
	var ids_var: Variant = _save.call("get_previous_run_items")
	if typeof(ids_var) != TYPE_ARRAY:
		return
	
	var ids: PackedStringArray = PackedStringArray()
	for v in (ids_var as Array):
		if typeof(v) == TYPE_STRING:
			ids.append(String(v))
	
	_load_into_backpack(ids)
	_announce(ids)
	
	if clear_after_load and _save.has_method("clear_previous_run_items"):
		_save.call_deferred("clear_previous_run_items")
