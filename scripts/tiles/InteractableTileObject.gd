extends Node3D
## Interactable Tile Object - For non-collectible objects that show toasts when examined
## Examples: gargoyles, statues, decorative elements on tiles

class_name InteractableTileObject

## Unique identifier that matches object_interactions.json key
@export var object_id: String = ""

## Action word shown in interaction prompt (e.g., "Examine", "Read", "Inspect")
@export var interaction_prompt: String = "examine"

## Interaction mode: "single" shows same message every time, "multiple" cycles through messages
@export var interaction_mode: String = "single"

## Detection radius for player interaction
@export var interaction_radius: float = 2.5

# Internal state
var _interaction_count: int = 0
var _message_bus: Node
var _interaction_area: Area3D
var _player_in_range: bool = false

func _ready() -> void:
	"""Initialize the interactable object"""
	# Validate configuration
	if object_id.is_empty():
		push_error("InteractableTileObject: object_id not set for %s" % name)
		return
	
	# Set metadata for detection
	set_meta("is_interactable", true)
	set_meta("object_id", object_id)
	
	# Add to groups for easier detection
	add_to_group("interactables")
	add_to_group("collectibles") # Player fallback checks this group
	
	# Setup interaction area
	call_deferred("_setup_interaction_area")
	
	# Connect to MessageBus
	call_deferred("_initialize_systems")

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	if not _message_bus:
		push_error("InteractableTileObject: MessageBus not found for %s" % name)

func _setup_interaction_area() -> void:
	"""Create and configure interaction detection area"""
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	add_child(_interaction_area)
	
	# Create collision shape
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = interaction_radius
	collision.shape = shape
	_interaction_area.add_child(collision)
	
	# Set collision layers - use interaction layer (8)
	_interaction_area.collision_layer = 8
	_interaction_area.collision_mask = 1
	
	# Connect signals
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	"""Handle player entering interaction range"""
	if not body.is_in_group("player"):
		return
	
	_player_in_range = true
	_show_interaction_prompt()

func _on_body_exited(body: Node3D) -> void:
	"""Handle player leaving interaction range"""
	if not body.is_in_group("player"):
		return
	
	_player_in_range = false
	_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	"""Show interaction prompt to player via MessageBus"""
	if not _message_bus:
		return
	
	var prompt_text: String = interaction_prompt + " " + name
	_message_bus.emit_event("show_interaction_prompt", [prompt_text, self])

func _hide_interaction_prompt() -> void:
	"""Hide interaction prompt via MessageBus"""
	if not _message_bus:
		return
	
	_message_bus.emit_event("hide_interaction_prompt", [self])

func interact() -> bool:
	"""
	Called when player interacts with this object
	Emits event that ObjectToastHandler will respond to
	
	@return: True if interaction was successful
	"""
	
	if not _message_bus:
		push_error("InteractableTileObject: MessageBus not available for %s" % name)
		return false
	
	# Emit interaction event with current count
	_message_bus.emit_event("object_interacted", [object_id, _interaction_count, self])
	
	# Increment count for multiple mode
	if interaction_mode == "multiple":
		_interaction_count += 1
	
	return true

# Public API

func get_object_id() -> String:
	"""Get the object identifier"""
	return object_id

func get_interaction_count() -> int:
	"""Get how many times this object has been interacted with"""
	return _interaction_count

func reset_interaction_count() -> void:
	"""Reset the interaction counter (useful for testing)"""
	_interaction_count = 0
