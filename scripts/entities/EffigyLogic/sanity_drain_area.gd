extends Area3D
class_name SanityDrainArea

@export var player_group: String = "player"
@export var base_drain_per_stage: float = 1.0           # sanity per second per stage
@export var effigy_path: NodePath = NodePath("")         # leave empty to auto-use parent Effigy

var _save_manager: Node = null
var _effigy: Node = null
var _player_inside: bool = false
var _stage_cached: int = 1
var _pending_fractional: float = 0.0

func _ready() -> void:
	# Autoload SaveManager
	_save_manager = get_node_or_null("/root/SaveManager")
	if _save_manager == null:
		push_error("SanityDrainArea: Autoload '/root/SaveManager' not found.")
		set_physics_process(false)
		return

	# Resolve effigy node
	if effigy_path != NodePath(""):
		_effigy = get_node_or_null(effigy_path)
	else:
		_effigy = get_parent()
	if _effigy == null:
		push_error("SanityDrainArea: Effigy node not found. Set 'effigy_path' or make this Area a child of the Effigy.")
		set_physics_process(false)
		return

	# Connect to effigy's stage signal if present
	if _effigy.has_signal("stage_changed"):
		_effigy.connect("stage_changed", Callable(self, "_on_effigy_stage_changed"))
	# Prime stage cache once, in case the signal hasn’t fired yet
	if _effigy.has_method("get_stage"):
		var s: Variant = _effigy.call("get_stage")
		if typeof(s) == TYPE_INT:
			_stage_cached = int(s)
			if _stage_cached < 1:
				_stage_cached = 1

	# Body enter/exit
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _physics_process(delta: float) -> void:
	if not _player_inside:
		return

	var rate: float = base_drain_per_stage * float(_stage_cached)  # points per second
	var amount: float = rate * delta
	_pending_fractional += amount

	var whole: int = int(floor(_pending_fractional))
	if whole >= 1:
		_pending_fractional -= float(whole)
		_apply_sanity_delta(-whole)  # SaveManager.modify_sanity(int)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group(player_group):
		_player_inside = false
		_pending_fractional = 0.0

func _on_effigy_stage_changed(stage: int) -> void:
	if stage < 1:
		stage = 1
	_stage_cached = stage

func _apply_sanity_delta(delta_points: int) -> void:
	if _save_manager.has_method("modify_sanity"):
		_save_manager.call("modify_sanity", delta_points)
		return
	push_error("SanityDrainArea: SaveManager.modify_sanity(int) not found on autoload.")
