extends Node3D
## Base Item Script - Template for all collectible items
## Handles pickup interaction and integration with inventory system

class_name BaseItem

# Item configuration
@export var item_id: String = ""
@export var item_name: String = ""
@export var item_description: String = ""
@export var display_name: String = ""
@export var auto_pickup: bool = true
@export var pickup_sound: String = ""

# Pickup area reference
@onready var pickup_area: Area3D = get_node_or_null("Area3D")
var _message_bus: Node
var _player_inventory: Node

# Pickup state
var _is_collected: bool = false

func _ready() -> void:
	if item_id.is_empty():
		push_error("BaseItem: item_id not set for %s" % name)
		return
	set_meta("item_id", item_id)
	set_meta("is_collectible", true)
	_setup_pickup_area()
	call_deferred("_initialize_systems")
	_setup_visual_effects()

func _initialize_systems() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")

func _setup_pickup_area() -> void:
	pickup_area = get_node_or_null("PickupArea") as Area3D
	if not pickup_area:
		pickup_area = get_node_or_null("Area3D") as Area3D
	if not pickup_area:
		pickup_area = Area3D.new()
		pickup_area.name = "PickupArea"
		add_child(pickup_area)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "PickupCollision"
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 2.0
		collision.shape = shape
		pickup_area.add_child(collision)
	CollisionHelper.setup_pickup_area(pickup_area)
	add_to_group("collectibles")
	add_to_group("items")
	if not pickup_area.body_entered.is_connected(_on_pickup_area_entered):
		pickup_area.body_entered.connect(_on_pickup_area_entered.bind())
	if not pickup_area.body_exited.is_connected(_on_pickup_area_exited):
		pickup_area.body_exited.connect(_on_pickup_area_exited.bind())

func _setup_visual_effects() -> void:
	if auto_pickup:
		_start_floating_animation()

func _start_floating_animation() -> void:
	var start_y = position.y
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", start_y + 0.5, 1.0)
	tween.tween_property(self, "position:y", start_y, 1.0)
	set_meta("floating_tween", tween)

func _stop_floating_animation() -> void:
	if has_meta("floating_tween"):
		var tween = get_meta("floating_tween")
		if tween and is_instance_valid(tween):
			tween.kill()
		remove_meta("floating_tween")

func _on_pickup_area_entered(body: Node3D) -> void:
	if _is_collected or not body.is_in_group("player"):
		return
	if body.has_method("register_nearby_interactable"):
		body.register_nearby_interactable(self)
	if _message_bus:
		_message_bus.emit_event("show_interaction_prompt", [get_pickup_prompt_text(), self])

func _on_pickup_area_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)
		if _message_bus:
			_message_bus.emit_event("hide_interaction_prompt", [self])

func interact() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player and not _is_collected:
		_trigger_pickup(player)
		return true
	return false

func _trigger_pickup(collector: Node3D) -> void:
	if _is_collected:
		return
	_is_collected = true
	if collector and collector.has_method("unregister_nearby_interactable"):
		collector.unregister_nearby_interactable(self)
	if not pickup_sound.is_empty():
		_play_pickup_sound()
	if _player_inventory and _player_inventory.has_method("add_item"):
		var success = _player_inventory.add_item(item_id)
		if not success:
			_is_collected = false
			if collector and collector.has_method("register_nearby_interactable"):
				collector.register_nearby_interactable(self)
			return
	var tile_pos = Vector2i.ZERO
	var state_manager = get_node_or_null("/root/GameStateManager")
	if state_manager:
		tile_pos = state_manager.get_state("current_tile_position")
	if _message_bus:
		_message_bus.emit_event("item_collected", [item_id, collector, tile_pos])
	_play_pickup_effect()

func _play_pickup_sound() -> void:
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sound_3d"):
		if FileAccess.file_exists(pickup_sound):
			audio_manager.play_sound_3d(pickup_sound, global_position)
		else:
			audio_manager.play_sound_3d("res://assets/audio/effects/item_pickup.ogg", global_position)

func _exit_tree() -> void:
	_stop_floating_animation()

func _play_pickup_effect() -> void:
	_stop_floating_animation()
	if pickup_area:
		pickup_area.set_deferred("monitoring", false)
	queue_free()

func get_item_id() -> String:
	return item_id

func get_item_name() -> String:
	if not item_name.is_empty():
		return item_name
	return item_id

func get_item_description() -> String:
	return item_description

func is_collected() -> bool:
	return _is_collected

func force_pickup(collector: Node3D) -> void:
	_trigger_pickup(collector)

func set_pickup_enabled(enabled: bool) -> void:
	if pickup_area:
		pickup_area.monitoring = enabled

func _on_item_collected(collector: Node3D) -> void:
	pass

func _on_pickup_failed(collector: Node3D, reason: String) -> void:
	if _message_bus:
		_message_bus.emit_event("notification_requested", ["Cannot pickup %s: %s" % [get_item_name(), reason], 2.0, 1])

func get_pickup_prompt_text() -> String:
	return "pick up %s" % get_item_name()
