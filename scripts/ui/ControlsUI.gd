extends Control

@onready var full_controls: PanelContainer = $FullControls
@onready var minimized_hints: HBoxContainer = $MinimizedHints
@onready var backpack_icon: TextureRect = $MinimizedHints/BackpackHint/Icon
@onready var flashlight_icon: TextureRect = $MinimizedHints/FlashlightHint/Icon
@onready var journal_icon: TextureRect = $MinimizedHints/JournalHint/Icon

const DISPLAY_DURATION: float = 5.0
const FADE_DURATION: float = 0.5

var _has_been_shown: bool = false

## _ready
## Purpose: Initialize the controls UI and set up event connections
## @return void.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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

## _connect_to_events
## Purpose: Connect to MessageBus events for player spawn
## @return void.
func _connect_to_events() -> void:
	var bus: Node = get_node_or_null("/root/MessageBus")
	if bus == null:
		push_error("ControlsUI: MessageBus not found")
		return

	if bus.has_method("connect_event"):
		bus.connect_event("player_spawned", _on_player_spawned)
	elif bus.has_signal("player_spawned"):
		bus.player_spawned.connect(_on_player_spawned)
	
	# Check if player already exists (in case we missed the spawn event)
	call_deferred("_check_for_existing_player")

## _check_for_existing_player
## Purpose: Check if player already spawned (fallback for race condition)
## @return void.
func _check_for_existing_player() -> void:
	print("ControlsUI: _check_for_existing_player called, _has_been_shown=", _has_been_shown)
	
	if _has_been_shown:
		print("ControlsUI: Already shown, skipping fallback check")
		return
	
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("ControlsUI: Found player via fallback check")
		_on_player_spawned(players[0])

## _on_player_spawned
## Purpose: Handle player spawn event and show controls
## @param player_node: The spawned player node
## @return void.
func _on_player_spawned(player_node: Node3D) -> void:
	print("ControlsUI: player_spawned received, _has_been_shown=", _has_been_shown)
	
	if _has_been_shown:
		print("ControlsUI: Already shown, skipping")
		return
	
	# Wait for narrative intro to finish (if it's playing)
	var narrative_ui: Control = get_node_or_null("../NarrativeUI")
	if narrative_ui:
		print("ControlsUI: Found NarrativeUI, checking if intro is playing...")
		if narrative_ui.has_method("is_intro_playing"):
			var wait_count: int = 0
			while narrative_ui.is_intro_playing():
				print("ControlsUI: Waiting for intro to finish... (", wait_count, ")")
				await get_tree().create_timer(0.1).timeout
				wait_count += 1
			print("ControlsUI: Intro finished, showing controls")
		else:
			print("ControlsUI: NarrativeUI doesn't have is_intro_playing method")
	else:
		print("ControlsUI: NarrativeUI not found")
	
	# Show controls every run
	_show_controls_sequence()

## _show_controls_sequence
## Purpose: Show full controls, wait, then transition to minimized hints
## @return void.
func _show_controls_sequence() -> void:
	print("ControlsUI: Starting controls sequence")
	_has_been_shown = true
	
	# Make absolutely sure we're not blocking input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimized_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_fade_in_full_controls()
	
	print("ControlsUI: Controls visible, waiting ", DISPLAY_DURATION, " seconds...")
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	
	print("ControlsUI: Transitioning to minimized")
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
	print("ControlsUI: Fading out full controls")
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(full_controls, "modulate:a", 0.0, FADE_DURATION)
	
	tween.chain()
	tween.tween_callback(func():
		full_controls.visible = false
		print("ControlsUI: Full controls hidden")
	)
	tween.tween_callback(_fade_in_minimized)

## _fade_in_minimized
## Purpose: Fade in the minimized hints
## @return void.
func _fade_in_minimized() -> void:
	print("ControlsUI: Fading in minimized hints")
	minimized_hints.visible = true
	minimized_hints.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(minimized_hints, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	print("ControlsUI: Minimized hints visible, controls sequence complete")


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
