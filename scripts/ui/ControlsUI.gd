extends Control

@onready var full_controls: PanelContainer = $FullControls
@onready var minimized_hints: HBoxContainer = $MinimizedHints
@onready var backpack_icon: TextureRect = $MinimizedHints/BackpackHint/Icon
@onready var flashlight_icon: TextureRect = $MinimizedHints/FlashlightHint/Icon
@onready var journal_icon: TextureRect = $MinimizedHints/JournalHint/Icon
@onready var interaction_prompt: Label = $InteractionPrompt

const DISPLAY_DURATION: float = 5.0
const FADE_DURATION: float = 0.5

var _has_been_shown: bool = false
var _current_interaction_target: Node = null

## _ready
## Purpose: Initialize the controls UI and set up event connections
## @return void.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Setup responsive sizing (deferred to ensure viewport is ready)
	call_deferred("_setup_responsive_sizing")
	
	# Both start hidden
	full_controls.visible = false
	full_controls.modulate.a = 0.0
	minimized_hints.visible = false
	minimized_hints.modulate.a = 0.0
	
	# Load icons for minimized view
	_load_icons()
	_add_background_to_full_controls()
	
	# Connect immediately to avoid missing the player_spawned event
	_connect_to_events()

## _setup_responsive_sizing
## Purpose: Setup responsive sizing for different screen resolutions
## @return void.
func _setup_responsive_sizing() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Calculate responsive panel size for full controls
	var panel_width: float = max(320.0, viewport_size.x * 0.25) # 25% of screen width, min 320px
	var panel_height: float = max(400.0, viewport_size.y * 0.6) # 60% of screen height, min 400px
	
	# Update full controls panel size
	if full_controls:
		full_controls.offset_left = 20.0
		full_controls.offset_top = - panel_height / 2.0
		full_controls.offset_right = 20.0 + panel_width
		full_controls.offset_bottom = panel_height / 2.0
	
	# Update minimized hints position (top-right corner)
	# Since MinimizedHints uses anchor_right = 1.0, offsets are relative to right edge
	if minimized_hints:
		var hints_width: float = 150.0
		var hints_height: float = 50.0
		minimized_hints.offset_left = - hints_width - 10.0 # Negative offset from right edge
		minimized_hints.offset_top = 10.0
		minimized_hints.offset_right = -10.0 # Negative offset from right edge
		minimized_hints.offset_bottom = hints_height

## _connect_to_events
## Purpose: Connect to MessageBus events for player spawn and interactions
## @return void.
func _connect_to_events() -> void:
	var bus: Node = get_node_or_null("/root/MessageBus")
	if bus == null:
		push_error("ControlsUI: MessageBus not found")
		return

	if bus.has_method("connect_event"):
		bus.connect_event("player_spawned", _on_player_spawned)
		bus.connect_event("show_interaction_prompt", _on_show_interaction_prompt)
		bus.connect_event("hide_interaction_prompt", _on_hide_interaction_prompt)
	elif bus.has_signal("player_spawned"):
		bus.player_spawned.connect(_on_player_spawned)
		if bus.has_signal("show_interaction_prompt"):
			bus.show_interaction_prompt.connect(_on_show_interaction_prompt)
		if bus.has_signal("hide_interaction_prompt"):
			bus.hide_interaction_prompt.connect(_on_hide_interaction_prompt)
	
	# Check if player already exists (in case we missed the spawn event)
	call_deferred("_check_for_existing_player")

## _check_for_existing_player
## Purpose: Check if player already spawned (fallback for race condition)
## @return void.
func _check_for_existing_player() -> void:
	if _has_been_shown:
		return
	
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_on_player_spawned(players[0])

## _on_player_spawned
## Purpose: Handle player spawn event and show controls
## @param player_node: The spawned player node
## @return void.
func _on_player_spawned(player_node: Node3D) -> void:
	if _has_been_shown:
		return
	
	# Wait for narrative intro to finish (if it's playing)
	var narrative_ui: Control = get_node_or_null("../NarrativeUI")
	if narrative_ui:
		if narrative_ui.has_method("is_intro_playing"):
			var intro_playing: bool = narrative_ui.is_intro_playing()
			if intro_playing:
				var wait_count: int = 0
				while narrative_ui.is_intro_playing():
					await get_tree().create_timer(0.1).timeout
					wait_count += 1
					if wait_count > 300:
						break
	
	# Show controls every run
	_show_controls_sequence()

## _show_controls_sequence
## Purpose: Show full controls, wait, then transition to minimized hints
## @return void.
func _show_controls_sequence() -> void:
	_has_been_shown = true
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimized_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_fade_in_full_controls()
	
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	
	_transition_to_minimized()

## _fade_in_full_controls
## Purpose: Fade in the full controls panel
## @return void.
func _fade_in_full_controls() -> void:
	full_controls.visible = true
	full_controls.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(full_controls, "modulate:a", 1.0, FADE_DURATION)

## _transition_to_minimized
## Purpose: Transition from full controls to minimized hints
## @return void.
func _transition_to_minimized() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(full_controls, "modulate:a", 0.0, FADE_DURATION)
	
	tween.chain()
	tween.tween_callback(func():
		full_controls.visible = false
	)
	tween.tween_callback(_fade_in_minimized)

## _fade_in_minimized
## Purpose: Fade in the minimized hints
## @return void.
func _fade_in_minimized() -> void:
	minimized_hints.visible = true
	minimized_hints.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(minimized_hints, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

## force_show_minimized_hints
## Purpose: Force show minimized hints (for debugging or fallback)
## @return void.
func force_show_minimized_hints() -> void:
	if minimized_hints:
		minimized_hints.visible = true
		minimized_hints.modulate.a = 1.0
	else:
		push_error("ControlsUI: minimized_hints node not found")


## _load_icons
## Purpose: Load the thumbnail icons for minimized view
## @return void.
func _load_icons() -> void:
	var backpack_texture: Texture2D = _try_load_texture([
		"res://assets/thumbnails/backpack.png",
		"res://assets/thumbnails/inventory.png",
		"res://assets/thumbnails/bag.png"
	])
	if backpack_texture:
		backpack_icon.texture = backpack_texture
	
	var flashlight_texture: Texture2D = load("res://assets/thumbnails/flashlight.png")
	if flashlight_texture:
		flashlight_icon.texture = flashlight_texture
	
	var journal_texture: Texture2D = load("res://assets/thumbnails/journal.png")
	if journal_texture:
		journal_icon.texture = journal_texture

## _try_load_texture
## Purpose: Try to load texture from multiple possible paths
## @param paths: Array of possible file paths
## @return Texture2D or null if no texture found.
func _try_load_texture(paths: Array) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null

## _on_show_interaction_prompt
## Purpose: Show the interaction prompt when player is near an interactable object
## @param prompt_text: The text to display (e.g., "Examine gargoyle")
## @param target: The object that can be interacted with
## @return void.
func _on_show_interaction_prompt(prompt_text: String, target: Node) -> void:
	if not interaction_prompt:
		return
	
	_current_interaction_target = target
	
	# Format the prompt text to include "Press E to"
	var formatted_text: String = "Press E to " + prompt_text
	interaction_prompt.text = formatted_text
	
	# Fade in the prompt
	interaction_prompt.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

## _on_hide_interaction_prompt
## Purpose: Hide the interaction prompt when player leaves range
## @param target: The object that was being interacted with
## @return void.
func _on_hide_interaction_prompt(target: Node) -> void:
	if not interaction_prompt:
		return
	
	# Only hide if this is the current target
	if _current_interaction_target != target:
		return
	
	_current_interaction_target = null
	
	# Fade out the prompt
	var tween: Tween = create_tween()
	tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): interaction_prompt.visible = false)

## _add_background_to_full_controls
## Purpose: Add a semi-transparent background panel to full controls
## @return void.
func _add_background_to_full_controls() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.2, 0.6)
	
	full_controls.add_theme_stylebox_override("panel", style)
