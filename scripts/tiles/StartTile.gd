extends Node
## StartTileController
## Controls special-cased objects on the Start tile for new vs continued runs.

@export_node_path("Node3D") var effigy_path: NodePath
@export_node_path("Node3D") var backpack_path: NodePath

var _save: Node = null
var _effigy: Node3D = null
var _backpack: Node3D = null

func _resolve() -> void:
	"""Cache references."""
	if has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")
	_effigy = get_node_or_null(effigy_path) as Node3D
	_backpack = get_node_or_null(backpack_path) as Node3D

func _is_continued_run() -> bool:
	"""Ask SaveManager whether this is a continued run."""
	if _save == null:
		return false
	if _save.has_method("is_continued_run"):
		var v: bool = _save.call("is_continued_run")
		return v
	# Fallback: presence of previous run items
	if _save.has_method("get_previous_run_items"):
		var items: Variant = _save.call("get_previous_run_items")
		if typeof(items) == TYPE_ARRAY:
			return (items as Array).size() > 0
	return false

func _set_visible_safe(n: Node3D, vis: bool) -> void:
	"""Toggle visibility safely."""
	if n == null:
		return
	if "visible" in n:
		n.visible = vis

func _ready() -> void:
	"""Resolve and toggle objects for startup state."""
	_resolve()
	var cont: bool = _is_continued_run()
	_set_visible_safe(_effigy, cont)
	_set_visible_safe(_backpack, cont)
