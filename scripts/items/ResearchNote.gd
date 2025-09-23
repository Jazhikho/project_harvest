extends BaseItem
class_name NoteItem
## NoteItem
## Journal-only pickup. Does NOT touch Inventory. Matches BaseItem's interact signature.

@export var note_id: StringName = &"note_001"
@export var journal_autoload_path: NodePath = NodePath("/root/Journal")
@export var message_bus_path: NodePath = NodePath("/root/MessageBus")

@export var show_toast_on_pickup: bool = true
@export var toast_seconds: float = 2.0

var _save: Node = null
var _journal: Node = null
var _pickup_sfx: AudioStreamPlayer3D = null

# ----------------------------
# Internal helpers (first)
# ----------------------------

func _resolve_refs() -> void:
	if has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")
	if journal_autoload_path != NodePath(""):
		_journal = get_node_or_null(journal_autoload_path)
	if message_bus_path != NodePath(""):
		_bus = get_node_or_null(message_bus_path)

	# These NodePaths are expected to exist in BaseItem (area_path, pickup_sfx_path, body_path)
	_area = get_node_or_null(area_path) as Area3D
	_pickup_sfx = get_node_or_null(pickup_sfx_path) as AudioStreamPlayer3D
	_body = get_node_or_null(body_path) as RigidBody3D

func _already_collected() -> bool:
	if _save == null:
		return false
	if not _save.has_method("has_note_collected"):
		return false
	var v: bool = _save.call("has_note_collected", note_id)
	return v

func _mark_collected() -> void:
	if _save == null:
		return
	if _save.has_method("add_note_collected"):
		_save.call("add_note_collected", note_id)

func _add_to_journal() -> void:
	if _journal == null:
		return
	if _journal.has_method("add_note"):
		_journal.call("add_note", note_id)
	elif _journal.has_method("add_entry"):
		_journal.call("add_entry", note_id)

func _emit_bus_event() -> void:
	if _bus == null:
		return
	if _bus.has_method("emit_event"):
		_bus.call("emit_event", &"note_collected", [{"note_id": String(note_id), "item_id": String(item_id)}])
	elif _bus.has_signal("note_collected"):
		_bus.emit_signal("note_collected", {"note_id": String(note_id), "item_id": String(item_id)})

func _play_pickup() -> void:
	if _pickup_sfx != null:
		_pickup_sfx.play()

func _sleep_body() -> void:
	if _body == null:
		return
	_body.can_sleep = true
	_body.sleeping = true

# ----------------------------
# Lifecycle / API
# ----------------------------

func _ready() -> void:
	_resolve_refs()
	# If the note was already collected on a previous run, delete the shell.
	if _already_collected():
		queue_free()

func interact(by: Node) -> void:
	# Must match parent: interact(Node) -> void
	# If already collected or about to be collected, bail early after cleanup.
	if _already_collected():
		return

	_disable_interaction()  # from BaseItem
	_play_pickup()
	_sleep_body()

	_add_to_journal()
	_mark_collected()
	_emit_bus_event()

	if show_toast_on_pickup and has_node("/root/NarrativeSystem"):
		var ns: Node = get_node("/root/NarrativeSystem")
		if ns.has_method("trigger_custom_narration"):
			var title: String = display_name if display_name != "" else String(note_id)
			ns.call("trigger_custom_narration", "Journal updated: " + title, toast_seconds, "hint")

	var sm := get_node_or_null("/root/SanityManager")
	if sm != null and sm.has_method("apply_sanity_loss"):
		sm.call("apply_sanity_loss", "note_read", 1, global_transform.origin)
	else:
		var sv := get_node_or_null("/root/SaveManager")
		if sv != null and sv.has_method("modify_sanity"):
			sv.call("modify_sanity", -1)

	queue_free()
