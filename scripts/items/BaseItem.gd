# res://scripts/items/BaseItem.gd
extends Node3D
class_name BaseItem

@export var item_id: StringName = &"generic_item"
@export var display_name: String = ""
@export var pickup_sfx_path: NodePath = NodePath("")    # optional AudioStreamPlayer3D on this scene
@export var area_path: NodePath = NodePath("Area3D")    # your InteractableArea
@export var body_path: NodePath = NodePath("RigidBody3D") # optional, if you drop with physics
@export var sleep_after_settle: bool = true
@export var settle_speed_threshold: float = 0.05        # m/s
@export var settle_time_required: float = 0.5           # seconds under threshold before sleeping

# If you have an Inventory autoload, set its path here; otherwise we just emit an event.
@export var inventory_autoload_path: NodePath = NodePath("/root/Inventory")

signal picked_up(by: Node, item_id: StringName)

var _area: InteractableArea = null
var _body: RigidBody3D = null
var _bus: Node = null
var _inventory: Node = null
var _settle_timer: float = 0.0
var _has_slept: bool = false

func _ready() -> void:
	_bus = get_node_or_null("/root/MessageBus")
	_inventory = get_node_or_null(inventory_autoload_path)
	_area = get_node_or_null(area_path) as InteractableArea
	_body = get_node_or_null(body_path) as RigidBody3D

	# Let the Area forward interaction back to us.
	if _area != null:
		_area.owner_path = NodePath(".")
		if _area.prompt_text == "":
			_area.prompt_text = "Pick up %s" % (display_name if display_name != "" else String(item_id))

	# Make sure physics starts awake for dropped items.
	if _body != null:
		_body.sleeping = false

func _physics_process(dt: float) -> void:
	if not sleep_after_settle:
		return
	if _body == null:
		return
	if _has_slept:
		return

	var speed: float = _body.linear_velocity.length()
	if speed <= settle_speed_threshold and _body.is_on_floor():
		_settle_timer += dt
		if _settle_timer >= settle_time_required:
			# Go to sleep to save CPU, but keep colliding with floor/walls.
			_body.sleeping = true
			_has_slept = true
	else:
		_settle_timer = 0.0

# ---------- Public API: called by InteractableArea ----------
func interact(by: Node) -> void:
	# Tell the world first
	if _bus != null and _bus.has_method("emit_event"):
		_bus.call("emit_event", "item_picked_up", [String(item_id), self, by])

	# Optional: add to inventory if you have one
	if _inventory != null:
		if _inventory.has_method("add_item_id"):
			_inventory.call("add_item_id", item_id, 1)
		elif _inventory.has_method("add"):
			_inventory.call("add", item_id, 1)

	# Local signal for anyone nearby
	emit_signal("picked_up", by, item_id)

	# Play SFX, then despawn
	var sfx: AudioStreamPlayer3D = get_node_or_null(pickup_sfx_path) as AudioStreamPlayer3D
	if sfx != null:
		sfx.play()
		# Hide interaction instantly so you can’t spam E while it rings out
		_disable_interaction()
		# Let the sound finish before freeing
		await sfx.finished
		queue_free()
	else:
		queue_free()

# If you ever want to drop this back into the world from inventory:
func respawn_at(pos: Vector3, impulse: Vector3 = Vector3.ZERO) -> void:
	global_position = pos
	if _body != null:
		_body.sleeping = false
		_body.linear_velocity = impulse
		_has_slept = false
		_settle_timer = 0.0
	_enable_interaction()
	
func get_item_id() -> StringName:
	return item_id

func get_display_name() -> String:
	return display_name

# ---------- Helpers ----------
func _disable_interaction() -> void:
	if _area != null:
		_area.monitoring = false
		_area.set_deferred("monitoring", false) # belt and suspenders

func _enable_interaction() -> void:
	if _area != null:
		_area.monitoring = true
