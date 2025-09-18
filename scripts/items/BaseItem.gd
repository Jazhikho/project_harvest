extends RigidBody3D
## Base Item Script - Template for all collectible items
## Handles pickup interaction and integration with inventory system

class_name BaseItem

# Item configuration - set these in child classes or in the editor
@export var item_id: String = ""
@export var item_name: String = ""
@export var item_description: String = ""
@export var pickup_sound: String = ""

# Node references
@onready var pickup_area: Area3D = $PickupArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# System references
var _message_bus: Node
var _player_inventory: Node

# Pickup state
var _is_collected: bool = false
var _pickup_tween: Tween
var _player_in_range: bool = false

func _ready() -> void:
	# Validate configuration
	if item_id.is_empty():
		push_error("BaseItem: item_id not set for %s" % name)
		return
	
	# Set metadata for systems
	set_meta("item_id", item_id)
	set_meta("is_collectible", true)
	set_meta("is_interactable", true)
	add_to_group("interactable_items")
	
	# Initialize systems
	call_deferred("_initialize_systems")
	
	# Connect pickup area signals
	_connect_pickup_signals()
	
	# Setup visual effects
	_setup_visual_effects()
	
	# Call custom initialization
	_on_item_ready()

func _initialize_systems() -> void:
	"""Initialize connections to game systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_player_inventory = get_node_or_null("/root/PlayerInventory")
	
	if not _message_bus:
		push_error("BaseItem: MessageBus not found")
	if not _player_inventory:
		push_error("BaseItem: PlayerInventory not found")

func _connect_pickup_signals() -> void:
	"""Connect pickup area signals"""
	if pickup_area:
		if not pickup_area.body_entered.is_connected(_on_player_entered_range):
			pickup_area.body_entered.connect(_on_player_entered_range)
		if not pickup_area.body_exited.is_connected(_on_player_exited_range):
			pickup_area.body_exited.connect(_on_player_exited_range)

func _setup_visual_effects() -> void:
	"""Setup visual effects for the item"""
	# Add subtle floating animation
	_start_floating_animation()
	
	# Set initial physics state
	gravity_scale = 0.0
	freeze = true

func _start_floating_animation() -> void:
	"""Start subtle floating animation"""
	if not mesh_instance:
		return
		
	var start_pos = mesh_instance.position
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh_instance, "position:y", start_pos.y + 0.15, 1.5)
	tween.tween_property(mesh_instance, "position:y", start_pos.y - 0.15, 1.5)

func _on_player_entered_range(body: Node3D) -> void:
	"""Show interaction prompt when player enters range"""
	if _is_collected or not body.is_in_group("player"):
		return
	
	_player_in_range = true
	
	# Show interaction prompt
	if _message_bus:
		var prompt_text = get_pickup_prompt_text()
		_message_bus.emit_event("show_interaction_prompt", [prompt_text, self])

func _on_player_exited_range(body: Node3D) -> void:
	"""Hide interaction prompt when player leaves range"""
	if body.is_in_group("player"):
		_player_in_range = false
		
		# Hide interaction prompt
		if _message_bus:
			_message_bus.emit_event("hide_interaction_prompt", [self])

func interact() -> bool:
	"""Called when player interacts with this item"""
	if not _player_in_range or _is_collected:
		return false
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
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
	
	# Hide interaction prompt
	if _message_bus:
		_message_bus.emit_event("hide_interaction_prompt", [self])
	
	# Emit collection event
	if _message_bus:
		_message_bus.emit_event("item_collected", [item_id, collector, tile_pos])
	
	# Call custom collection handler
	_on_item_collected(collector)
	
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

func _play_pickup_effect() -> void:
	"""Play visual pickup effect and remove item"""
	# Disable pickup area
	if pickup_area:
		pickup_area.set_deferred("monitoring", false)
	
	# Animate pickup effect
	_pickup_tween = create_tween()
	_pickup_tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.3)
	_pickup_tween.parallel().tween_property(self, "position:y", position.y + 2.0, 0.3)
	_pickup_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	
	# Remove after animation
	_pickup_tween.tween_callback(queue_free)

# === PUBLIC API ===

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
	"""Force pickup regardless of distance"""
	_trigger_pickup(collector)

func set_pickup_enabled(enabled: bool) -> void:
	"""Enable/disable pickup capability"""
	if pickup_area:
		pickup_area.monitoring = enabled

func update_visual(mesh: Mesh, material: Material = null) -> void:
	"""
	Update item visual appearance
	
	@param mesh: New mesh to display
	@param material: Optional material to apply
	"""
	if mesh_instance:
		mesh_instance.mesh = mesh
		if material:
			mesh_instance.material_override = material

# === OVERRIDE POINTS FOR CHILD CLASSES ===

func _on_item_ready() -> void:
	"""
	Called after base initialization - override in child classes
	"""
	pass

func _on_item_collected(collector: Node3D) -> void:
	"""
	Called after successful collection - override in child classes
	
	@param collector: Node that collected the item
	"""
	pass

func get_pickup_prompt_text() -> String:
	"""
	Get text to show when player can pick up item - override in child classes
	
	@return: Prompt text
	"""
	return "Press E to pick up %s" % get_item_name()

func get_item_color() -> Color:
	"""
	Get color for item visual - override in child classes
	
	@return: Color for the item
	"""
	return Color.WHITE
