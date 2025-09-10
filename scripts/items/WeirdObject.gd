extends BaseItem
## Weird Object - Cursed items that trigger weird effects
## Based on items.json weird_objects entries (porcelain_doll, music_box, etc.)

@export var sanity_loss_amount: int = 10
@export var trigger_weird_effects: bool = true

func _ready() -> void:
	# Set default properties for weird objects
	if item_name.is_empty():
		item_name = "Strange Object"
	if item_description.is_empty():
		item_description = "Something feels wrong about this..."
	
	pickup_sound = "res://assets/audio/effects/weird_pickup.ogg"
	
	super._ready()

func _on_item_collected(collector: Node3D) -> void:
	"""Handle weird object collection effects"""
	super._on_item_collected(collector)
	
	# Weird objects cause significant sanity loss
	_apply_sanity_effects()
	
	# Trigger weird effects
	if trigger_weird_effects:
		_trigger_weird_effects()
	
	# Show ominous message
	_show_collection_message()

func _apply_sanity_effects() -> void:
	"""Apply sanity loss from touching cursed object"""
	var sanity_manager = get_node_or_null("/root/SanityManager")
	if sanity_manager and sanity_manager.has_method("apply_sanity_loss"):
		var loss_amount = _get_sanity_loss_for_object()
		sanity_manager.apply_sanity_loss("weird_object", loss_amount, global_position)

func _get_sanity_loss_for_object() -> int:
	"""Get sanity loss based on specific object type"""
	match item_id:
		"porcelain_doll":
			return 15
		"music_box":
			return 12
		"mirror_fragment":
			return 7
		"harvest_symbol":
			return 12
		"stopped_watch":
			return 9
		"staff_photo":
			return 11
		_:
			return sanity_loss_amount

func _trigger_weird_effects() -> void:
	"""Trigger weird environmental effects"""
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("trigger_weird_effect"):
		var tile_pos = Vector2i.ZERO
		var state_manager = get_node_or_null("/root/GameStateManager")
		if state_manager:
			tile_pos = state_manager.get_state("current_tile_position")
		
		weird_things_manager.trigger_weird_effect(item_id, tile_pos)

func _show_collection_message() -> void:
	"""Show ominous message when weird object is collected"""
	var message = _get_collection_message()
	
	if _message_bus and not message.is_empty():
		_message_bus.emit_event("notification_requested", [message, 4.0, 2])

func _get_collection_message() -> String:
	"""Get specific message for this weird object"""
	match item_id:
		"porcelain_doll":
			return "The doll's hollow eyes seem to follow your movement..."
		"music_box":
			return "The melody echoes memories that aren't your own..."
		"mirror_fragment":
			return "Your reflection shows someone... different..."
		"harvest_symbol":
			return "The symbol burns itself into your memory..."
		"stopped_watch":
			return "Time stopped when the first subject was harvested..."
		"staff_photo":
			return "The faces shift when you're not looking directly..."
		_:
			return "Your mind reels as you touch the cursed object..."

func get_pickup_prompt_text() -> String:
	"""Custom prompt for weird objects"""
	return "Press E to examine %s (Warning: May affect sanity)" % get_item_name()

func _setup_visual_effects() -> void:
	"""Enhanced visual effects for weird objects"""
	super._setup_visual_effects()
	
	# Add ominous glow effect
	_add_ominous_glow()

func _add_ominous_glow() -> void:
	"""Add subtle ominous glow to weird objects"""
	var mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0.5, 0.1, 0.1, 0.3)  # Dark red glow
	material.emission_energy = 0.5
	
	# Apply to mesh
	mesh_instance.set_surface_override_material(0, material)
	
	# Animate glow intensity
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(material, "emission_energy", 0.8, 2.0)
	tween.tween_property(material, "emission_energy", 0.2, 2.0)
