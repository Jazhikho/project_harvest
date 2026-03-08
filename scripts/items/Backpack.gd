extends Node3D
## Backpack - Contains items from previous runs
## Player can interact to collect all items inside

@export var interaction_radius: float = 2.0

var _interaction_area: Area3D
var _player_in_range: bool = false
var _message_bus: Node
var _player_inventory: Node
var _save_manager: Node
var item_id: String = "backpack"

@onready var _mesh: MeshInstance3D = get_node_or_null("BackpackMesh")

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")
	_save_manager = get_node_or_null("/root/SaveManager")
	if not _message_bus or not _player_inventory or not _save_manager:
		push_error("Backpack: Required systems not found")
		return
	_setup_interaction_area()
	set_meta("is_backpack", true)
	add_to_group("interactables")

func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	add_child(_interaction_area)
	var collision = CollisionShape3D.new()
	collision.name = "InteractionCollision"
	var shape = SphereShape3D.new()
	shape.radius = interaction_radius
	collision.shape = shape
	_interaction_area.add_child(collision)
	_interaction_area.collision_layer = 8
	_interaction_area.collision_mask = 0
	var rigid_body = RigidBody3D.new()
	rigid_body.name = "InteractionBody"
	rigid_body.collision_layer = 8
	rigid_body.collision_mask = 0
	rigid_body.freeze = true
	add_child(rigid_body)
	var body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	body_collision.shape = BoxShape3D.new()
	rigid_body.add_child(body_collision)
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(self)
		_show_interaction_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)
		_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	if _message_bus:
		_message_bus.emit_event("show_interaction_prompt", [get_pickup_prompt_text(), self])

func _hide_interaction_prompt() -> void:
	if _message_bus:
		_message_bus.emit_event("hide_interaction_prompt", [self])

func get_pickup_prompt_text() -> String:
	return "collect backpack (%d items)" % get_item_count()

func interact() -> void:
	var backpack_items = _save_manager.get_backpack_inventory()
	if backpack_items.is_empty():
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["Backpack is empty", 2.0, 1])
		return
	var items_collected = 0
	var items_failed = []
	for collected_item_id in backpack_items:
		if _player_inventory.has_method("add_item"):
			var success = _player_inventory.add_item(collected_item_id, false)
			if success:
				ItemManager._cleanup_duplicate_items(collected_item_id)
				items_collected += 1
				var item_manager = get_node_or_null("/root/ItemManager")
				if item_manager and item_manager.has_method("mark_item_collected"):
					item_manager.mark_item_collected(collected_item_id)
				if _save_manager.has_method("_on_item_collected"):
					var dummy_collector = get_tree().get_first_node_in_group("player")
					var tile_pos = Vector2i.ZERO
					var state_manager = get_node_or_null("/root/GameStateManager")
					if state_manager:
						tile_pos = state_manager.get_state("current_tile_position")
					_save_manager._on_item_collected(collected_item_id, dummy_collector, tile_pos)
			else:
				items_failed.append(collected_item_id)
	if items_failed.is_empty():
		_save_manager.clear_backpack_inventory()
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["Collected %d items from backpack" % items_collected, 3.0, 0])
		_play_collection_effect()
	else:
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["Collected %d items, %d remain (inventory full?)" % [items_collected, items_failed.size()], 3.0, 1])

func _play_collection_effect() -> void:
	_hide_interaction_prompt()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unregister_nearby_interactable"):
		player.unregister_nearby_interactable(self)
	if _interaction_area:
		_interaction_area.set_deferred("monitoring", false)
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.4)
	tween.parallel().tween_property(self, "position:y", position.y + 1.5, 0.4)
	if _mesh:
		tween.parallel().tween_property(_mesh, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func get_item_count() -> int:
	return _save_manager.get_backpack_inventory().size()
