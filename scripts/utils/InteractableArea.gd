extends Area3D
class_name InteractableArea
## InteractableArea
## General-purpose interaction Area for items AND scene objects.
## - Tracks player proximity.
## - Registers with the player (if they support it).
## - Shows/hides a UI toast via MessageBus.
## - Forwards interact(by) to the "owner" node using a standard method contract.

signal became_available(player: Node)
signal became_unavailable(player: Node)

## What kind of thing this is (affects default prompt text)
enum InteractableKind { GENERIC = 0, ITEM = 1, OBJECT = 2, NOTE = 3 }

# --- Configuration ---
@export var kind: InteractableKind = InteractableKind.GENERIC
@export var require_player_in_area: bool = true
@export var auto_hide_toast_on_exit: bool = true

@export var prompt_default: String = "Interact"
@export var prompt_item_format: String = "Pick up {name}"
@export var prompt_object_format: String = "Use {name}"

@export_node_path("Node") var owner_path: NodePath = NodePath("..")

# Optional: names for owner methods (kept explicit to avoid reflection games)
@export var owner_interact_method: StringName = &"interact"             # preferred
@export var owner_pickup_method: StringName = &"on_item_picked_up"      # legacy items
@export var owner_try_interact_method: StringName = &"try_interact"     # compatibility

# Optional: UI bus event names
@export var bus_event_toast_show: StringName = &"ui_toast_show"
@export var bus_event_toast_hide: StringName = &"ui_toast_hide"

# --- Cached refs ---
var _player_inside: bool = false
var _message_bus: Node = null
var _owner: Node = null

# ===========================
# Internal helpers (first)
# ===========================

func _resolve_message_bus() -> void:
	"""Cache the MessageBus autoload if present."""
	if has_node("/root/MessageBus"):
		_message_bus = get_node("/root/MessageBus")

func _resolve_owner() -> void:
	"""Cache the owner node."""
	if owner_path == NodePath(".."):
		_owner = get_parent()
	else:
		_owner = get_node_or_null(owner_path)

func _get_display_name() -> String:
	"""Best-effort friendly name (owner.get_display_name, owner.display_name, meta, or node name)."""
	if _owner == null:
		return ""
	if _owner.has_method("get_display_name"):
		var v: Variant = _owner.call("get_display_name")
		if typeof(v) == TYPE_STRING:
			return String(v)
	if "display_name" in _owner and typeof(_owner.display_name) == TYPE_STRING:
		return String(_owner.display_name)
	if _owner.has_meta("display_name"):
		return String(_owner.get_meta("display_name"))
	return _owner.name

func _build_prompt() -> String:
	"""Compute prompt text based on kind and name."""
	var name_str: String = _get_display_name()
	if kind == InteractableKind.ITEM and name_str != "":
		return prompt_item_format.replace("{name}", name_str)
	if kind == InteractableKind.OBJECT and name_str != "":
		return prompt_object_format.replace("{name}", name_str)
	return prompt_default

func _show_toast() -> void:
	"""Ask UI to show an interaction toast via MessageBus."""
	if _message_bus == null:
		return
	if _message_bus.has_method("emit_event"):
		_message_bus.call("emit_event", bus_event_toast_show, [_build_prompt()])

func _hide_toast() -> void:
	"""Ask UI to hide the interaction toast via MessageBus."""
	if _message_bus == null:
		return
	if _message_bus.has_method("emit_event"):
		_message_bus.call("emit_event", bus_event_toast_hide, [])

func _forward_to_owner(by: Node) -> bool:
	"""
	Forward the interaction to the owner using the standard contract:
	1) owner.interact(by) -> bool (preferred)
	2) if kind == ITEM and owner.on_item_picked_up(by) exists, call it (legacy)
	3) owner.try_interact("player") (compat for older objects like FinalGateDoor)
	Always returns true if we attempted something.
	"""
	if _owner == null:
		return false
	
	# Preferred: interact(by)
	if _owner.has_method(owner_interact_method):
		_owner.call(owner_interact_method, by)
		return true
	
	# Legacy item pickup
	if kind == InteractableKind.ITEM and _owner.has_method(owner_pickup_method):
		_owner.call(owner_pickup_method, by)
		return true
	
	# Compatibility fallback: try_interact("player")
	if _owner.has_method(owner_try_interact_method):
		_owner.call(owner_try_interact_method, "player")
		return true
	
	# Nothing to call
	return false

# ===============
# Lifecycle / API
# ===============

func _ready() -> void:
	"""Initialize caching and wire area callbacks."""
	add_to_group("interactable")
	monitoring = true
	monitorable = true
	_resolve_message_bus()
	_resolve_owner()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func interact(by: Node) -> bool:
	"""
	Called by the player's Interaction Controller.
	Respects require_player_in_area and forwards to the owner.
	"""
	if require_player_in_area and not _player_inside:
		return false
	return _forward_to_owner(by)

func get_prompt() -> String:
	"""Public helper for UI widgets that like to pre-fetch the prompt."""
	return _build_prompt()

func _on_body_entered(body: Node) -> void:
	"""Player entered the area; show prompt and register with the player, if supported."""
	if not body.is_in_group("player"):
		return
	_player_inside = true
	emit_signal("became_available", body)
	_show_toast()
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)

func _on_body_exited(body: Node) -> void:
	"""Player left the area; hide prompt and unregister if supported."""
	if not body.is_in_group("player"):
		return
	_player_inside = false
	emit_signal("became_unavailable", body)
	if auto_hide_toast_on_exit:
		_hide_toast()
	if body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)
