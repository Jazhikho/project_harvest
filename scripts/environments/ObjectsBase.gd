extends Node3D
class_name SceneObjectBase
## SceneObjectBase
## Base behavior for interactable SCENE OBJECTS (not pickups, not notes).
## - Shows optional toasts via MessageBus.
## - Supports using inventory items on the object (via SaveManager).
## - Emits signals for success/failure; leaves visuals/FX to child scripts or an Audio node.
##
## Contract with InteractableArea:
##   InteractableArea will call interact(by: Node) -> void when the player presses Interact.
##   Your player controller can call use_item_on_object(item_id) -> bool to apply a specific item.
##
## Overridable hooks for child scripts:
##   _on_plain_interact(by: Node) -> void
##   _on_item_used(by: Node, item_id: StringName) -> bool   (return true if it worked)
##   _get_custom_prompt() -> String                          (optional prompt override)

signal object_interacted(by: Node)
signal object_item_used(by: Node, item_id: StringName)
signal object_item_failed(by: Node, item_id: StringName, reason: String)
signal sfx_request(kind: String)   # "use_ok", "use_fail", "interact"

# ---------- Config: identity / UX ----------

@export var display_name: String = ""
@export var toast_on_interact: bool = true
@export var interact_toast_text: String = "Use {name}"
@export var toast_seconds: float = 1.6

# UI bus event names (kept explicit so we don't hard-couple)
@export var bus_event_toast_show: StringName = &"ui_toast_show"
@export var bus_event_toast_hide: StringName = &"ui_toast_hide"

# ---------- Config: item use ----------

@export var accepts_items: PackedStringArray = []   # list of item IDs this object can accept
@export var consume_item_on_success: bool = true
@export var show_toast_on_success: bool = true
@export var success_toast_text: String = "{name}: applied"
@export var show_toast_on_fail: bool = true
@export var fail_toast_text: String = "{name}: doesn't fit"

# ---------- Services / NodePaths ----------

@export_node_path("Node") var message_bus_path: NodePath = NodePath("/root/MessageBus")
@export_node_path("Node") var save_manager_path: NodePath = NodePath("/root/SaveManager")

# ---------- Cached refs ----------

var _bus: Node = null
var _save: Node = null

# ==============================
# Internal helpers (first)
# ==============================

func _resolve_services() -> void:
	"""Cache optional autoloads."""
	_bus = null
	_save = null
	if message_bus_path != NodePath(""):
		_bus = get_node_or_null(message_bus_path)
	if _bus == null and has_node("/root/MessageBus"):
		_bus = get_node("/root/MessageBus")
	if save_manager_path != NodePath(""):
		_save = get_node_or_null(save_manager_path)
	if _save == null and has_node("/root/SaveManager"):
		_save = get_node("/root/SaveManager")

func _toast_show(text: String) -> void:
	"""Ask UI to show a toast via MessageBus."""
	if _bus == null:
		return
	if _bus.has_method("emit_event"):
		_bus.call("emit_event", bus_event_toast_show, [text])

func _toast_hide() -> void:
	"""Ask UI to hide the toast via MessageBus."""
	if _bus == null:
		return
	if _bus.has_method("emit_event"):
		_bus.call("emit_event", bus_event_toast_hide, [])

func _name_for_prompt() -> String:
	"""Best-effort display name for prompts."""
	if display_name != "":
		return display_name
	if has_meta("display_name"):
		return String(get_meta("display_name"))
	return name

func _format_prompt(src: String) -> String:
	"""Insert {name} into prompt templates."""
	return src.replace("{name}", _name_for_prompt())

func _has_item(id: StringName) -> bool:
	"""Check inventory in SaveManager."""
	if _save == null:
		return false
	if not _save.has_method("has_item"):
		return false
	var v: bool = _save.call("has_item", id)
	return v

func _remove_item(id: StringName) -> void:
	"""Remove item from SaveManager."""
	if _save == null:
		return
	if _save.has_method("remove_item"):
		_save.call_deferred("remove_item", id)

func _default_prompt() -> String:
	"""Compute a default toast prompt, overridable by child hook."""
	var custom: String = _get_custom_prompt()
	if custom != "":
		return custom
	return _format_prompt(interact_toast_text)

# ==============================
# Lifecycle
# ==============================

func _ready() -> void:
	"""Resolve services. Child scripts can override and call super()."""
	_resolve_services()

# ==============================
# Public API
# ==============================

func interact(by: Node) -> void:
	"""
	Called by InteractableArea when the player presses the Interact button.
	Shows an optional toast and triggers the plain-interact hook.
	"""
	if toast_on_interact:
		_toast_show(_default_prompt())
	emit_signal("sfx_request", "interact")
	emit_signal("object_interacted", by)
	_on_plain_interact(by)

func supports_item(id: StringName) -> bool:
	"""Return true if this object is configured to accept the provided item id."""
	for s in accepts_items:
		if StringName(s) == id:
			return true
	return false

func use_item_on_object(by: Node, item_id: StringName) -> bool:
	"""
	Player attempts to use a specific inventory item on this object.
	Returns true if the attempt was handled (success or failure).
	Success path will optionally consume the item.
	"""
	# Validate eligibility
	if not supports_item(item_id):
		if show_toast_on_fail:
			_toast_show(_format_prompt(fail_toast_text))
		emit_signal("sfx_request", "use_fail")
		emit_signal("object_item_failed", by, item_id, "unsupported_item")
		return true
	
	# Ensure the player actually has it (SaveManager = source of truth)
	if not _has_item(item_id):
		if show_toast_on_fail:
			_toast_show(_format_prompt(fail_toast_text))
		emit_signal("sfx_request", "use_fail")
		emit_signal("object_item_failed", by, item_id, "item_missing")
		return true
	
	# Let child behavior decide whether the item works right now
	var ok: bool = _on_item_used(by, item_id)
	if ok:
		if consume_item_on_success:
			_remove_item(item_id)
		if show_toast_on_success:
			_toast_show(_format_prompt(success_toast_text))
		emit_signal("sfx_request", "use_ok")
		emit_signal("object_item_used", by, item_id)
	else:
		if show_toast_on_fail:
			_toast_show(_format_prompt(fail_toast_text))
		emit_signal("sfx_request", "use_fail")
		emit_signal("object_item_failed", by, item_id, "rejected_by_object")
	return true

# ==============================
# Overridables for child scripts
# ==============================

func _on_plain_interact(by: Node) -> void:
	"""
	Override in derived scripts for default interact behavior,
	e.g., toggling a lever with no item, inspecting text, etc.
	"""
	pass

func _on_item_used(by: Node, item_id: StringName) -> bool:
	"""
	Override in derived scripts to evaluate and apply item usage.
	Return true if the item was accepted and applied; false to reject.
	"""
	return false

func _get_custom_prompt() -> String:
	"""
	Optional: override to customize the toast prompt per object state.
	Return empty string to use the default prompt.
	"""
	return ""
