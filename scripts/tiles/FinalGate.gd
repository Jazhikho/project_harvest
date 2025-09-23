extends "res://scripts/tiles/tile.gd"
## FinalGate - The locked gate tile that leads to the game's ending sequence
## Player needs all 3 puzzles completed to get the key

@export var gate_locked: bool = true
@export var interaction_count: int = 0

# Gate components
@onready var gate_model: Node3D = $Maze/Objects/Gate if has_node("Maze/Objects/Gate") else null
@onready var gate_collision: StaticBody3D = $Maze/Objects/GateCollision if has_node("Maze/Objects/GateCollision") else null
@onready var interaction_area: Area3D = $Maze/Objects/GateInteractionArea if has_node("Maze/Objects/GateInteractionArea") else null

# System references
var _message_bus: Node
var _state_manager: Node
var _narrative_system: Node
var _player_inventory: Node

# Track if player has approached the gate
var player_approached_gate: bool = false

# Puzzle completion tracking
var completed_puzzles: Array[String] = []
var key_spawned: bool = false
var key_item: Node3D = null

func _ready() -> void:
	super () # Call parent ready
	name = "FinalGate"
	is_permanent = true # Final gate is always permanent
	add_to_group("final_gate")
	
	# Initialize systems
	call_deferred("_initialize_systems")
	
	# Setup gate interaction area if it doesn't exist
	if not interaction_area:
		_create_interaction_area()

func _initialize_systems() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/SaveManager")
	_narrative_system = get_node_or_null("/root/NarrativeSystem")
	_player_inventory = get_node_or_null("/root/PlayerInventory")

	# Load current puzzle completion state
	_load_puzzle_completion_state()

	# Connect to puzzle completion events
	if _message_bus:
		if _message_bus.has_signal("puzzle_completed"):
			_message_bus.puzzle_completed.connect(_on_puzzle_completed)
		if _message_bus.has_signal("player_interacted"):
			_message_bus.player_interacted.connect(_on_player_interacted)

func _create_interaction_area() -> void:
	"""Create an interaction area for the gate"""
	interaction_area = Area3D.new()
	interaction_area.name = "GateInteractionArea"
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3, 3, 1) # Wide area in front of gate
	collision.shape = shape
	
	interaction_area.add_child(collision)
	
	# Position in front of the gate (assuming gate is at north side)
	if gate_model:
		gate_model.add_child(interaction_area)
		interaction_area.position = Vector3(0, 1.5, -1) # Slightly in front
	else:
		# Add to tile if no gate model
		add_child(interaction_area)
		interaction_area.position = Vector3(0, 1.5, 9) # Near north edge
	
	# Connect signals
	interaction_area.body_entered.connect(_on_player_entered_gate_area)
	interaction_area.body_exited.connect(_on_player_exited_gate_area)

func _on_player_entered_gate_area(body: Node3D) -> void:
	"""Handle player approaching the gate"""
	if not body.is_in_group("player"):
		return
	
	if not player_approached_gate:
		player_approached_gate = true
		# First time approaching - show hope toast
		if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
			_narrative_system.trigger_custom_narration(
				"A gate! Maybe it's a way out of here... but damn, it's locked.",
				4.0,
				"thought"
			)

func _on_player_exited_gate_area(body: Node3D) -> void:
	"""Handle player leaving gate area"""
	if not body.is_in_group("player"):
		return
	# Could add logic here if needed

func _load_puzzle_completion_state() -> void:
	"""Load current puzzle completion state from SaveManager"""
	if not _state_manager:
		return

	var completed = _state_manager.get_completed_puzzles()
	
	# Ensure proper typing
	completed_puzzles.clear()
	for puzzle in completed:
		if puzzle is String:
			completed_puzzles.append(puzzle)

	# Check if key should already be spawned
	if completed.size() >= 3 and not key_spawned:
		_spawn_key_on_altar()

func _spawn_key_on_altar() -> void:
	"""Spawn the final key on the KeyCheck altar"""
	if key_spawned:
		return

	key_spawned = true

	# Find the KeyCheck altar (should be outside the maze 3D node)
	var key_check = get_node_or_null("KeyCheck")
	if not key_check:
		push_error("FinalGate: KeyCheck node not found!")
		return

	var altar = key_check.get_node_or_null("altar")
	if not altar:
		push_error("FinalGate: Altar not found in KeyCheck!")
		return

	# Create the key item
	var key_scene = preload("res://scenes/misc/key.tscn")
	if key_scene:
		key_item = key_scene.instantiate()
		key_item.set_meta("item_id", "final_key")
		key_item.set_meta("is_collectible", true)
		key_item.set_meta("is_key", true)
		key_item.name = "FinalKey"

		# Position the key on the altar
		key_item.position = Vector3(0, 1.5, 0)
		altar.add_child(key_item)

		print("FinalGate: Final key spawned on altar")
	else:
		push_error("FinalGate: Failed to load key scene!")

func _on_player_interacted(target: Node3D, interaction_type: String) -> void:
	"""Handle player interaction with objects in this tile"""
	# Check if player is in this tile
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Check if player is near the gate
	if interaction_area and interaction_area.overlaps_body(player):
		_interact_with_gate()

func _interact_with_gate() -> void:
	"""Handle gate interaction based on current state"""
	interaction_count += 1

	# Check if player has the key
	var has_key = false
	if _player_inventory and _player_inventory.has_method("has_item"):
		has_key = _player_inventory.has_item("final_key")

	if has_key:
		# Player has the key - unlock gate and trigger ending
		_unlock_gate_and_end_game()
	elif key_spawned:
		# Key has spawned but player doesn't have it yet
		if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
			_narrative_system.trigger_custom_narration(
				"I need to find that key... it should be on one of the altars.",
				3.0,
				"thought"
			)
	else:
		# No key available yet - show appropriate message based on interaction count
		match interaction_count:
			1:
				# First interaction - thump sound
				_play_gate_sound("thump")
				if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
					_narrative_system.trigger_custom_narration(
						"Locked tight. I need to find a key.",
						3.0,
						"thought"
					)
			2:
				# Second interaction - kick sound
				_play_gate_sound("kick")
				if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
					_narrative_system.trigger_custom_narration(
						"Ow! Ok, lesson learned. Steel door vs foot - steel door wins.",
						4.0,
						"thought"
					)
			_:
				# Subsequent interactions
				if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
					_narrative_system.trigger_custom_narration(
						"Yeah, I'm not kicking it again. I need to find the key to unlock this.",
						3.0,
						"thought"
					)

func _play_gate_sound(sound_type: String) -> void:
	"""Play gate interaction sounds"""
	# TODO: Wire up actual sound effects
	print("FinalGate: Play sound effect - %s" % sound_type)
	# Instructions for wiring:
	# 1. Add AudioStreamPlayer3D as child of gate
	# 2. Load appropriate sound file based on sound_type
	# 3. Play the sound

func _unlock_gate_and_end_game() -> void:
	"""Unlock the gate and trigger the ending sequence"""
	gate_locked = false

	# Play unlock sound
	_play_gate_sound("unlock")

	# Remove key from inventory
	if _player_inventory and _player_inventory.has_item("final_key"):
		_player_inventory.remove_item("final_key")
		# Hide the key visual
		if key_item:
			key_item.visible = false

	# Start ending sequence
	_start_ending_sequence()

func _start_ending_sequence() -> void:
	"""Start the game's ending sequence"""
	print("FinalGate: Starting ending sequence...")
	
	# Fade to black
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_method("fade_to_black"):
		await scene_manager.fade_to_black(3.0)
	else:
		# Simple fade using a ColorRect
		var fade_rect = ColorRect.new()
		fade_rect.color = Color.BLACK
		fade_rect.modulate.a = 0.0
		fade_rect.anchor_right = 1.0
		fade_rect.anchor_bottom = 1.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.z_index = 100
		
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		get_tree().current_scene.add_child(canvas_layer)
		canvas_layer.add_child(fade_rect)
		
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 3.0)
		await tween.finished
	
	# Show ending dialogue
	_show_ending_dialogue()

func _show_ending_dialogue() -> void:
	"""Show the ending dialogue between Dr. Amundsen and staff"""
	# Create dialogue UI
	var dialogue_container = Control.new()
	dialogue_container.anchor_right = 1.0
	dialogue_container.anchor_bottom = 1.0
	dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var dialogue_text = RichTextLabel.new()
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = true
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.anchor_left = 0.2
	dialogue_text.anchor_right = 0.8
	dialogue_text.anchor_top = 0.3
	dialogue_text.anchor_bottom = 0.7
	dialogue_text.add_theme_font_size_override("normal_font_size", 24)
	dialogue_text.modulate.a = 0.0
	
	dialogue_container.add_child(dialogue_text)
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 101
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(dialogue_container)
	
	# Show dialogue lines
	var dialogues = [
		{"text": "[color=white]Subject 24-A has completed the qualification trials.[/color]", "duration": 3.0},
		{"text": "[color=red]Excellent. The duplicate shows promise.[/color]", "duration": 3.0},
		{"text": "[color=white]Shall we proceed to Stage 1 of the Harvest Protocol?[/color]", "duration": 3.0},
		{"text": "[color=red]Yes. And reset the maze for the next subject series.[/color]", "duration": 3.0},
		{"text": "[color=red]The harvest must continue.[/color]", "duration": 4.0}
	]
	
	for dialogue in dialogues:
		dialogue_text.text = dialogue.text
		
		# Fade in text
		var tween_in = create_tween()
		tween_in.tween_property(dialogue_text, "modulate:a", 1.0, 0.5)
		await tween_in.finished
		
		# Wait
		await get_tree().create_timer(dialogue.duration).timeout
		
		# Fade out text
		var tween_out = create_tween()
		tween_out.tween_property(dialogue_text, "modulate:a", 0.0, 0.5)
		await tween_out.finished
	
	# Clean up dialogue UI
	canvas_layer.queue_free()
	
	# Trigger death screen with special cause
	_trigger_harvest_ending()

func _trigger_harvest_ending() -> void:
	"""Trigger the death screen with harvest ending"""
	print("FinalGate: Triggering harvest ending...")

	# Set the death type for the DeathScreen
	get_tree().set_meta("death_type", "Harvested")

	# Emit death event to trigger DeathScreen
	if _message_bus:
		_message_bus.emit_event("player_died", [
			"Passed to Stage 1 Harvest Protocol",
			Vector2i.ZERO,
			{"harvest_ending": true}
		])

	# After death screen, the continue button should lead to credits
	# This will be handled by the death screen logic

func _on_puzzle_completed(puzzle_id: String, tile_pos: Vector2i, reward: Dictionary) -> void:
	"""Handle puzzle completion and check if all puzzles are complete"""
	if puzzle_id not in completed_puzzles:
		completed_puzzles.append(puzzle_id)
		print("FinalGate: Puzzle completed: %s (Total completed: %d)" % [puzzle_id, completed_puzzles.size()])

		# Check if all 3 puzzles are complete
		if completed_puzzles.size() >= 3:
			_spawn_key_on_altar()

			# Show narrative about the key spawning
			if _narrative_system and _narrative_system.has_method("trigger_custom_narration"):
				_narrative_system.trigger_custom_narration(
					"Something has changed... I sense a key has appeared somewhere in this place.",
					4.0,
					"thought"
				)

func interact() -> bool:
	"""Called when player tries to interact with the gate directly"""
	_interact_with_gate()
	return true

func get_gate_status() -> Dictionary:
	"""Get current gate status for debugging"""
	return {
		"locked": gate_locked,
		"interaction_count": interaction_count,
		"player_approached": player_approached_gate
	}
