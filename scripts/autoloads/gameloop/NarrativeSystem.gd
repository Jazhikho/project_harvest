extends Node
## Narration System - Displays narrative text and interaction prompts
## Shows prompts at bottom of screen, handles timing and pause states
## Enhanced with story narration and controls display

signal narration_started(text: String)
signal narration_ended()
signal prompt_shown(text: String)
signal prompt_hidden()
signal controls_shown()
signal controls_hidden()

var _message_bus: Node
var _state_manager: Node
var _save_manager: Node
var _current_narration_timer: float = 0.0
var _current_narration_duration: float = 0.0
var _is_narrating: bool = false

# UI References - will be created dynamically
var _prompt_label: Label = null
var _narration_panel: Panel = null
var _narration_label: RichTextLabel = null
var _controls_panel: Panel = null
var _controls_label: RichTextLabel = null
var _fade_tween: Tween
var _controls_tween: Tween

# Current state
var _current_prompt_target: Node3D = null
var _game_paused: bool = false

# Narration queue and tracking
var _narration_queue: Array[Dictionary] = []
var _effigies_seen: int = 0
var _effigy_positions: Dictionary = {}
var _has_seen_effigy_move: bool = false
var _is_new_game: bool = false

func _ready() -> void:
	name = "NarrationSystem"
	add_to_group("ui_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize narration system and connections"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_save_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus:
		push_error("NarrationSystem: MessageBus not found")
		return
	
	# Don't create UI here - wait for game_started event
	_connect_to_events()

func _create_ui() -> void:
	"""Create narration UI elements"""
	# Create interaction prompt (simple label at bottom)
	_prompt_label = Label.new()
	_prompt_label.name = "InteractionPrompt"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.modulate = Color(1, 1, 1, 0)  # Start invisible
	
	# Create narration panel (for longer narrative text)
	_narration_panel = Panel.new()
	_narration_panel.name = "NarrationPanel"
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	_narration_panel.add_theme_stylebox_override("panel", style_box)
	_narration_panel.modulate = Color(1, 1, 1, 0)  # Start invisible
	
	_narration_label = RichTextLabel.new()
	_narration_label.bbcode_enabled = true
	_narration_label.fit_content = true
	_narration_label.scroll_active = false
	_narration_label.add_theme_color_override("default_color", Color.WHITE)
	_narration_label.add_theme_constant_override("normal_font_size", 18)
	_narration_label.add_theme_constant_override("outline_size", 2)
	_narration_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Create controls panel (for control instructions)
	_controls_panel = Panel.new()
	_controls_panel.name = "ControlsPanel"
	
	var controls_style = StyleBoxFlat.new()
	controls_style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	controls_style.border_width_left = 2
	controls_style.border_width_right = 2
	controls_style.border_width_top = 2
	controls_style.border_width_bottom = 2
	controls_style.border_color = Color(0.6, 0.6, 0.6, 0.6)
	controls_style.corner_radius_top_left = 8
	controls_style.corner_radius_top_right = 8
	controls_style.corner_radius_bottom_left = 8
	controls_style.corner_radius_bottom_right = 8
	_controls_panel.add_theme_stylebox_override("panel", controls_style)
	_controls_panel.modulate = Color(1, 1, 1, 0)  # Start invisible
	
	# Controls text
	_controls_label = RichTextLabel.new()
	_controls_label.bbcode_enabled = true
	_controls_label.fit_content = true
	_controls_label.scroll_active = false
	_controls_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9, 1.0))
	_controls_label.add_theme_constant_override("normal_font_size", 14)
	_controls_label.add_theme_constant_override("outline_size", 1)
	_controls_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Add to scene immediately (called from game_started)
	_add_to_scene()

func _add_to_scene() -> void:
	"""Add UI elements to the scene tree"""
	var game_scene = get_tree().current_scene
	if game_scene and game_scene.name == "Game":
		print("NarrativeSystem: Adding UI to game scene")
		# Add prompt to root of game scene
		game_scene.add_child(_prompt_label)
		_setup_prompt_position()
		
		# Add narration panel
		game_scene.add_child(_narration_panel)
		_narration_panel.add_child(_narration_label)
		_setup_narration_position()
		
		# Add controls panel
		game_scene.add_child(_controls_panel)
		_controls_panel.add_child(_controls_label)
		_setup_controls_position()
	else:
		print("NarrativeSystem: Game scene not ready, current scene: ", game_scene.name if game_scene else "none")

func _setup_prompt_position() -> void:
	"""Position the interaction prompt at bottom of screen"""
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.offset_top = -100
	_prompt_label.offset_bottom = -50

func _setup_narration_position() -> void:
	"""Position the narration panel at bottom of screen"""
	_narration_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_narration_panel.offset_left = 100
	_narration_panel.offset_right = -100
	_narration_panel.offset_top = -150
	_narration_panel.offset_bottom = -50
	
	_narration_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration_label.offset_left = 10
	_narration_label.offset_right = -10
	_narration_label.offset_top = 10
	_narration_label.offset_bottom = -10

func _setup_controls_position() -> void:
	"""Position the controls panel at top right of screen"""
	_controls_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_controls_panel.custom_minimum_size = Vector2(350, 200)
	_controls_panel.offset_left = -370
	_controls_panel.offset_top = 20
	_controls_panel.offset_right = -20
	_controls_panel.offset_bottom = 220
	
	_controls_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_label.offset_left = 10
	_controls_label.offset_right = -10
	_controls_label.offset_top = 10
	_controls_label.offset_bottom = -10

func _process(delta: float) -> void:
	"""Update narration timing"""
	if not _is_narrating or _game_paused:
		return
	
	_current_narration_timer += delta
	if _current_narration_timer >= _current_narration_duration:
		hide_narration()

func show_interaction_prompt(message: String, target: Node3D = null) -> void:
	"""
	Show interaction prompt at bottom of screen
	
	@param message: Prompt text to display
	@param target: Optional target object for the prompt
	"""
	if not _prompt_label:
		return
	
	_current_prompt_target = target
	_prompt_label.text = message
	
	# Fade in
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_prompt_label, "modulate:a", 1.0, 0.3)
	
	prompt_shown.emit(message)

func hide_interaction_prompt(target: Node3D = null) -> void:
	"""
	Hide interaction prompt
	
	@param target: Optional target to verify we're hiding the right prompt
	"""
	if not _prompt_label:
		return
	
	# Only hide if this is the current target or no target specified
	if target and target != _current_prompt_target:
		return
	
	# Fade out
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_prompt_label, "modulate:a", 0.0, 0.3)
	
	_current_prompt_target = null
	prompt_hidden.emit()

func show_narration(text: String, duration: float = 3.0, style: String = "normal") -> void:
	"""
	Show narrative text in panel
	
	@param text: Narrative text to display
	@param duration: How long to show the text
	@param style: Style of narration ("thought", "observation", "system", "normal")
	"""
	print("NarrativeSystem: show_narration called: '", text, "', panel exists: ", _narration_panel != null)
	if not _narration_panel or not _narration_label:
		print("NarrativeSystem: Narration panel or label is null!")
		return
	
	# Queue the narration if one is already playing
	if _is_narrating:
		print("NarrativeSystem: Queueing narration (already narrating)")
		_narration_queue.append({"text": text, "duration": duration, "style": style})
		return
	
	# Format text based on style
	var formatted_text: String
	match style:
		"thought":
			formatted_text = "[center][i]" + text + "[/i][/center]"
		"observation":
			formatted_text = "[center]" + text + "[/center]"
		"system":
			formatted_text = "[center][color=cyan]" + text + "[/color][/center]"
		_:
			formatted_text = "[center]" + text + "[/center]"
	
	_narration_label.text = formatted_text
	_current_narration_duration = duration
	_current_narration_timer = 0.0
	_is_narrating = true
	
	print("NarrativeSystem: Starting narration animation")
	
	# Fade in
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_narration_panel, "modulate:a", 1.0, 0.5)
	
	narration_started.emit(text)

func hide_narration() -> void:
	"""Hide narrative text panel"""
	if not _narration_panel:
		return
	
	_is_narrating = false
	
	# Fade out
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_narration_panel, "modulate:a", 0.0, 0.5)
	
	narration_ended.emit()
	
	# Process next narration in queue
	if _narration_queue.size() > 0:
		var next_narration = _narration_queue.pop_front()
		call_deferred("show_narration", next_narration.text, next_narration.duration, next_narration.style)

func show_controls(duration: float = 5.0) -> void:
	"""Show controls overlay"""
	print("NarrativeSystem: show_controls called, panel exists: ", _controls_panel != null)
	if not _controls_panel or not _controls_label:
		print("NarrativeSystem: Controls panel or label is null!")
		return
	
	var controls_text = """[center][b]CONTROLS[/b][/center]

[b]WASD[/b] - Movement
[b]SPACE[/b] - Sprint
[b]F[/b] - Flashlight
[b]E[/b] - Interact
[b]I[/b] - Inventory
[b]ESC[/b] - Pause Menu

[i]Mouse to look around[/i]"""
	
	_controls_label.text = controls_text
	print("NarrativeSystem: Controls text set, starting animation")
	
	# Animate in
	if _controls_tween:
		_controls_tween.kill()
	_controls_tween = create_tween()
	_controls_tween.tween_property(_controls_panel, "modulate:a", 1.0, 0.8)
	
	controls_shown.emit()
	
	# Wait for duration, then fade out
	await get_tree().create_timer(duration).timeout
	
	_controls_tween = create_tween()
	_controls_tween.tween_property(_controls_panel, "modulate:a", 0.0, 1.0)
	await _controls_tween.finished
	
	controls_hidden.emit()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	if _message_bus.has_signal("show_interaction_prompt"):
		_message_bus.show_interaction_prompt.connect(_on_show_prompt_requested)
	if _message_bus.has_signal("hide_interaction_prompt"):
		_message_bus.hide_interaction_prompt.connect(_on_hide_prompt_requested)
	if _message_bus.has_signal("narration_requested"):
		_message_bus.narration_requested.connect(_on_narration_requested)
	if _message_bus.has_signal("game_paused"):
		_message_bus.game_paused.connect(_on_game_paused)
	if _message_bus.has_signal("game_started"):
		_message_bus.game_started.connect(_on_game_started)
	if _message_bus.has_signal("entity_spawned"):
		_message_bus.entity_spawned.connect(_on_entity_spawned)
	if _message_bus.has_signal("sanity_changed"):
		_message_bus.sanity_changed.connect(_on_sanity_changed)

func _on_show_prompt_requested(message: String, target: Node3D) -> void:
	"""Handle prompt show request from MessageBus"""
	show_interaction_prompt(message, target)

func _on_hide_prompt_requested(target: Node3D) -> void:
	"""Handle prompt hide request from MessageBus"""
	hide_interaction_prompt(target)

func _on_narration_requested(text: String, duration: float) -> void:
	"""Handle narration request from MessageBus"""
	show_narration(text, duration)

func _on_game_paused(paused: bool) -> void:
	"""Handle game pause state"""
	_game_paused = paused
	
	if paused:
		# Hide prompts and pause narration when game is paused
		if _prompt_label:
			_prompt_label.modulate.a = 0
		# Narration continues to show but doesn't advance timer

# New event handlers for story narration

func _on_game_started() -> void:
	"""Handle game start - determine if new game or continue"""
	print("NarrativeSystem: Game started event received")
	
	# Ensure UI is created for the game scene
	if not _narration_panel:
		print("NarrativeSystem: Creating UI for game scene")
		_create_ui()
	
	# Check if this is a new game by looking at save data state
	_is_new_game = not (_save_manager and _save_manager.save_data.get("run_active", false))
	print("NarrativeSystem: Is new game: ", _is_new_game)
	
	# Wait a moment for the game scene to fully load
	await get_tree().create_timer(1.0).timeout
	
	if _is_new_game:
		print("NarrativeSystem: Starting new game narration")
		_show_new_game_narration()
	
	# Always show controls (both new and continue)
	print("NarrativeSystem: Showing controls")
	show_controls(5.0)

func _show_new_game_narration() -> void:
	"""Show the opening narration for new games"""
	var opening_texts = [
		"Where... where am I?",
		"Oh right, the old farm. I remember driving here.",
		"I saw the corn maze and thought it looked interesting...",
		"But what happened after that? I can't quite remember.",
		"I guess I better find my way out."
	]
	
	# Show each text with delays
	for i in range(opening_texts.size()):
		await get_tree().create_timer(i * 5.5).timeout  # Slight overlap
		show_narration(opening_texts[i], 4.0, "thought")

func _on_entity_spawned(entity_type: String, entity_node: Node3D, position: Vector3) -> void:
	"""Handle entity spawning - track effigies"""
	if entity_type == "effigy":
		_track_effigy(entity_node, position)

func _track_effigy(effigy: Node3D, position: Vector3) -> void:
	"""Track effigy for narration triggers"""
	var effigy_id = effigy.get_instance_id()
	_effigy_positions[effigy_id] = position
	
	_effigies_seen += 1
	
	# Trigger narration based on how many effigies seen
	if _effigies_seen == 1:
		show_narration("That... thing looks really creepy.", 3.0, "thought")
	elif _effigies_seen == 2:
		show_narration("Is it watching me?", 3.0, "thought")
	
	# Set up monitoring for effigy movement
	_monitor_effigy_movement(effigy, effigy_id)

func _monitor_effigy_movement(effigy: Node3D, effigy_id: int) -> void:
	"""Monitor an effigy for movement"""
	var original_position = _effigy_positions[effigy_id]
	var check_timer = Timer.new()
	check_timer.wait_time = 1.0
	check_timer.timeout.connect(func():
		if not is_instance_valid(effigy):
			check_timer.queue_free()
			return
		
		var current_position = effigy.global_position
		var distance_moved = original_position.distance_to(current_position)
		
		if distance_moved > 1.0 and not _has_seen_effigy_move:
			# Check sanity level - only trigger if above 80%
			var current_sanity = _state_manager.get_state("sanity") if _state_manager else 100
			if current_sanity >= 80:
				_has_seen_effigy_move = true
				show_narration("Did... did that thing just move?", 3.5, "thought")
				check_timer.queue_free()
	)
	
	add_child(check_timer)
	check_timer.start()

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity changes for additional narration triggers"""
	# Add more sanity-based narrations here if needed
	if new_value <= 50 and old_value > 50:
		show_narration("Something's not right here...", 3.0, "thought")
	elif new_value <= 25 and old_value > 25:
		show_narration("I need to get out of here. Now.", 3.5, "thought")

# Public API extensions

func trigger_custom_narration(text: String, duration: float = 4.0, style: String = "thought") -> void:
	"""Trigger a custom narration from other systems"""
	show_narration(text, duration, style)

func is_narrating() -> bool:
	"""Check if currently showing narration"""
	return _is_narrating

func clear_narration_queue() -> void:
	"""Clear any queued narrations"""
	_narration_queue.clear()

# Debug/Test functions
func test_narration() -> void:
	"""Test function to manually trigger narration"""
	print("NarrativeSystem: Testing narration system")
	if not _narration_panel:
		print("NarrativeSystem: Creating UI for test")
		_create_ui()
	
	show_narration("Test narration - if you see this, the system works!", 3.0, "system")
	
	# Also test controls
	await get_tree().create_timer(4.0).timeout
	show_controls(3.0)
