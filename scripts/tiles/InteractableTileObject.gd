extends Node3D
## Interactable Tile Object - For non-collectible objects that show toasts when examined
## Examples: gargoyles, statues, decorative elements on tiles

class_name InteractableTileObject

@export var object_id: String = ""
@export var interaction_prompt: String = "examine"
@export var interaction_mode: String = "single"
@export var interaction_radius: float = 2.5

var _interaction_count: int = 0
var _message_bus: Node
var _interaction_area: Area3D
var _player_in_range: bool = false

func _ready() -> void:
	if object_id.is_empty():
		object_id = name.to_lower().replace(" ", "_")
		push_warning("InteractableTileObject: object_id not set for %s, defaulting to '%s'" % [name, object_id])
	set_meta("is_interactable", true)
	set_meta("object_id", object_id)
	add_to_group("interactables")
	call_deferred("_setup_interaction_area")
	call_deferred("_initialize_systems")

func _initialize_systems() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	if not _message_bus:
		push_error("InteractableTileObject: MessageBus not found for %s" % name)

func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	add_child(_interaction_area)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = interaction_radius
	collision.shape = shape
	_interaction_area.add_child(collision)
	_interaction_area.collision_layer = 1 << (CollisionHelper.LAYER_OBJECTS - 1)
	_interaction_area.collision_mask = 1 << (CollisionHelper.LAYER_PLAYER - 1)
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	if body.has_method("register_nearby_interactable"):
		body.register_nearby_interactable(self)
	_show_interaction_prompt()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	if body.has_method("unregister_nearby_interactable"):
		body.unregister_nearby_interactable(self)
	_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	if not _message_bus:
		return
	_message_bus.emit_event("show_interaction_prompt", ["%s %s" % [interaction_prompt, name], self])

func _hide_interaction_prompt() -> void:
	if not _message_bus:
		return
	_message_bus.emit_event("hide_interaction_prompt", [self])

func interact() -> bool:
	if not _message_bus:
		push_error("InteractableTileObject: MessageBus not available for %s" % name)
		return false
	_message_bus.emit_event("object_interacted", [object_id, _interaction_count, self])
	if interaction_mode == "multiple":
		_interaction_count += 1
	return true

func get_object_id() -> String:
	return object_id

func get_interaction_count() -> int:
	return _interaction_count

func reset_interaction_count() -> void:
	_interaction_count = 0
