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
	# Validate configuration
	if item_id.is_empty():
		push_error("BaseItem: item_id not set for %s" % name)
		return
	
	# Set metadata for SpawnManager compatibility
	set_meta("item_id", item_id)
	set_meta("is_collectible", true)
	
	# Find or create pickup area
	_setup_pickup_area()
	
	# Connect to systems
	call_deferred("_initialize_systems")
	
	# Visual setup
	_setup_visual_effects()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")

func _setup_pickup_area() -> void:
	"""Setup or find pickup collision area"""
	pickup_area = get_node_or_null("PickupArea") as Area3D
	
	if not pickup_area:
		pickup_area = get_node_or_null("Area3D") as Area3D # Also check for generic Area3D
	
	if not pickup_area:
		# Create pickup area if it doesn't exist
		pickup_area = Area3D.new()
		pickup_area.name = "PickupArea"
		add_child(pickup_area)
		
		# Create larger collision shape for easier pickup
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "PickupCollision"
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 2.0 # Increased from 1.0 for easier detection
		collision.shape = shape
		pickup_area.add_child(collision)
	
	# Set collision layers
	CollisionHelper.setup_pickup_area(pickup_area)
	
	# Add to groups for easier detection
	add_to_group("collectibles")
	add_to_group("items")
	
	# Connect pickup signals
	if not pickup_area.body_entered.is_connected(_on_pickup_area_entered):
		pickup_area.body_entered.connect(_on_pickup_area_entered.bind())
	if not pickup_area.body_exited.is_connected(_on_pickup_area_exited):
		pickup_area.body_exited.connect(_on_pickup_area_exited.bind())

func _setup_visual_effects() -> void:
	"""Setup visual effects for the item"""
	# Add subtle floating animation
	if auto_pickup:
		_start_floating_animation()

func _start_floating_animation() -> void:
	"""Start subtle floating animation"""
	var start_y = position.y
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", start_y + 0.5, 1.0)
	tween.tween_property(self, "position:y", start_y, 1.0)
	
	# Store tween reference so we can stop it later
	set_meta("floating_tween", tween)

func _stop_floating_animation() -> void:
	"""Stop the floating animation to prevent tween warnings"""
	if has_meta("floating_tween"):
		var tween = get_meta("floating_tween")
		if tween and is_instance_valid(tween):
			tween.kill()
		remove_meta("floating_tween")

func _on_pickup_area_entered(body: Node3D) -> void:
	"""Handle pickup area collision - now shows interaction prompt instead of auto-pickup"""
	if _is_collected or not body.is_in_group("player"):
		return
	
	# OLD AUTO-PICKUP CODE:
	# if auto_pickup:
	#	_trigger_pickup(body)
	
	if _message_bus:
		_message_bus.emit_event("show_interaction_prompt", ["Pickup " + display_name, self])

func _on_pickup_area_exited(body: Node3D) -> void:
	"""Handle player leaving pickup area"""
	if body.is_in_group("player"):
		# Hide interaction prompt
		if _message_bus:
			_message_bus.emit_event("hide_interaction_prompt", [self])

func interact() -> bool:
	"""Called when player interacts with this item"""
	var player = get_tree().get_first_node_in_group("player")
	if player and not _is_collected:
		_trigger_pickup(player)
		return true
	return false

func _trigger_pickup(collector: Node3D) -> void:
	"""
	Trigger item pickup
	
	@param collector: Node that collected the item (usually player)
	"""
	if _is_collected:
		return
	
	_is_collected = true
	
	# Play pickup sound
	if not pickup_sound.is_empty():
		_play_pickup_sound()
	
	# Add to inventory
	if _player_inventory and _player_inventory.has_method("add_item"):
		var success = _player_inventory.add_item(item_id)
		if not success:
			# Inventory full, don't collect
			_is_collected = false
			return
	
	# Get current tile position for events
	var tile_pos = Vector2i.ZERO
	var state_manager = get_node_or_null("/root/GameStateManager")
	if state_manager:
		tile_pos = state_manager.get_state("current_tile_position")
	
	# Emit collection event
	if _message_bus:
		_message_bus.emit_event("item_collected", [item_id, collector, tile_pos])
	
	# Visual pickup effect
	_play_pickup_effect()

func _play_pickup_sound() -> void:
	"""Play pickup sound effect"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sound_3d"):
		if FileAccess.file_exists(pickup_sound):
			audio_manager.play_sound_3d(pickup_sound, global_position)
		else:
			# Fallback to generic pickup sound
			audio_manager.play_sound_3d("res://assets/audio/effects/item_pickup.ogg", global_position)

func _exit_tree() -> void:
	"""Clean up when node is removed"""
	_stop_floating_animation()

func _play_pickup_effect() -> void:
	"""Play visual pickup effect and remove item"""
	
	# Stop floating animation to prevent tween warning
	_stop_floating_animation()
	
	# Disable pickup area
	if pickup_area:
		pickup_area.set_deferred("monitoring", false)
	
# Public API

func get_item_id() -> String:
	"""Get item identifier"""
	return item_id

func get_item_name() -> String:
	"""Get display name"""
	return item_name if not item_name.is_empty() else item_id

func get_item_description() -> String:
	"""Get item description"""
	return item_description

func is_collected() -> bool:
	"""Check if item has been collected"""
	return _is_collected

func force_pickup(collector: Node3D) -> void:
	"""Force pickup regardless of auto_pickup setting"""
	_trigger_pickup(collector)

func set_pickup_enabled(enabled: bool) -> void:
	"""Enable/disable pickup capability"""
	if pickup_area:
		pickup_area.monitoring = enabled

# Override in child classes for special behavior

func _on_item_collected(collector: Node3D) -> void:
	"""
	Called after successful collection
	Override in child classes for special effects
	
	@param collector: Node that collected the item
	"""
	pass

func _on_pickup_failed(collector: Node3D, reason: String) -> void:
	"""
	Called when pickup fails (e.g., inventory full)
	Override in child classes for feedback
	
	@param collector: Node that attempted pickup
	@param reason: Reason for failure
	"""
	if _message_bus:
		_message_bus.emit_event("notification_requested", ["Cannot pickup %s: %s" % [get_item_name(), reason], 2.0, 1])

func get_pickup_prompt_text() -> String:
	"""
	Get text to show when player can pick up item
	Override in child classes for custom prompts
	
	@return: Prompt text
	"""
	return "Press E to pick up %s" % get_item_name()
