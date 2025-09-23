extends Node3D
## FinalGateDoor
## Owns lock state, verifies key via SaveManager, disables blocker collision,
## requests SFX from the Audio node, and emits message-bus event.
## No animation. Tile root keeps only tile.gd.

signal sfx_request(kind: String)                 # "unlock" (future: "thump","kick" if you ever want)
signal gate_unlocked(payload: Dictionary)

@export var locked: bool = true
@export var required_item_id: StringName = &"final_key"
@export var consume_item_on_unlock: bool = true
@export var single_fire: bool = true
@export_node_path("StaticBody3D") var blocker_body_path: NodePath
@export var bus_event_name: StringName = &"final_gate_unlocked"

# --- Cached refs (autoloads + nodes) ---
@onready var _save_manager: Node = (get_node_or_null("/root/SaveManager") as Node)
@onready var _message_bus: Node = (get_node_or_null("/root/MessageBus") as Node)
@onready var _blocker: StaticBody3D = (
	get_node_or_null(blocker_body_path) as StaticBody3D
	if blocker_body_path != NodePath()
	else get_node_or_null("StaticBody3D") as StaticBody3D
)

var _unlocked_once: bool = false

# ===========================
# Internal helpers (per style)
# ===========================

func _set_blocking_enabled(enabled: bool) -> void:
	"""Enable or disable all CollisionShape3D children under the blocker body."""
	if _blocker == null:
		return
	for child in _blocker.get_children():
		if child is CollisionShape3D:
			var cs: CollisionShape3D = child as CollisionShape3D
			cs.disabled = not enabled
	_blocker.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _has_required_key() -> bool:
	"""Query SaveManager for the key."""
	if _save_manager == null:
		return false
	if not _save_manager.has_method("has_item"):
		return false
	var has_key: bool = _save_manager.call("has_item", required_item_id)
	return has_key

func _consume_key_if_configured() -> void:
	"""Remove the key from SaveManager if configured."""
	if not consume_item_on_unlock:
		return
	if _save_manager == null:
		return
	if _save_manager.has_method("remove_item"):
		_save_manager.call_deferred("remove_item", required_item_id)

func _emit_bus_event(payload: Dictionary) -> void:
	"""Emit a single, named event on your MessageBus."""
	if _message_bus == null:
		return
	if _message_bus.has_method("emit_event"):
		_message_bus.call("emit_event", bus_event_name, payload)
	elif _message_bus.has_signal(String(bus_event_name)):
		_message_bus.emit_signal(String(bus_event_name), payload)

# ===============
# Lifecycle / API
# ===============

func _ready() -> void:
	"""Reflect initial lock state in collision."""
	_set_blocking_enabled(locked)

func try_interact(source: String = "player") -> bool:
	"""
	Forwarded by the Area3D when the player interacts.
	Returns true if handled.
	"""
	if not locked:
		return true
	
	if _has_required_key():
		force_unlock(source)
		return true
	
	# Locked and no key: defer to Audio node if you later want bumps/clicks.
	emit_signal("sfx_request", "locked")  # harmless if no listener cares
	return true

func force_unlock(source: String = "system") -> void:
	"""
	Unlock without animation. Disables collision, requests SFX, and notifies bus.
	Idempotent if single_fire is true.
	"""
	if single_fire and _unlocked_once:
		return
	
	locked = false
	_unlocked_once = true
	_set_blocking_enabled(false)
	_consume_key_if_configured()
	emit_signal("sfx_request", "unlock")
	
	var payload: Dictionary = {
		"source": source,
		"gate_path": String(get_path()),
		"time_unix": Time.get_unix_time_from_system()
	}
	emit_signal("gate_unlocked", payload)
	_emit_bus_event(payload)

func interact(by: Node) -> bool:
	# preserve your existing behavior under the new contract
	return try_interact("player")
