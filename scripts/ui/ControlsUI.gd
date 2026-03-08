extends Control

@onready var full_controls: PanelContainer = $FullControls
@onready var minimized_hints: HBoxContainer = $MinimizedHints
@onready var backpack_icon: TextureRect = $MinimizedHints/BackpackHint/Icon
@onready var flashlight_icon: TextureRect = $MinimizedHints/FlashlightHint/Icon
@onready var journal_icon: TextureRect = $MinimizedHints/JournalHint/Icon
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var movement_key: Label = $FullControls/MarginContainer/VBoxContainer/Movement/Key
@onready var sprint_key: Label = $FullControls/MarginContainer/VBoxContainer/Sprint/Key
@onready var look_key: Label = $FullControls/MarginContainer/VBoxContainer/Look/Key
@onready var interact_key: Label = $FullControls/MarginContainer/VBoxContainer/Interact/Key
@onready var flashlight_key: Label = $FullControls/MarginContainer/VBoxContainer/Flashlight/Key
@onready var inventory_key: Label = $FullControls/MarginContainer/VBoxContainer/Inventory/Key
@onready var journal_key: Label = $FullControls/MarginContainer/VBoxContainer/Journal/Key
@onready var pause_key: Label = $FullControls/MarginContainer/VBoxContainer/Pause/Key
@onready var minimized_inventory_key: Label = $MinimizedHints/BackpackHint/Key
@onready var minimized_flashlight_key: Label = $MinimizedHints/FlashlightHint/Key
@onready var minimized_journal_key: Label = $MinimizedHints/JournalHint/Key

const DISPLAY_DURATION: float = 5.0
const FADE_DURATION: float = 0.5

var _has_been_shown: bool = false
var _current_interaction_target: Node = null
var _current_interaction_verb: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_setup_responsive_sizing")
	full_controls.visible = false
	full_controls.modulate.a = 0.0
	minimized_hints.visible = false
	minimized_hints.modulate.a = 0.0
	_load_icons()
	_add_background_to_full_controls()
	_refresh_control_prompts()
	_connect_to_events()
	if InputManager and InputManager.has_signal("control_scheme_changed"):
		InputManager.control_scheme_changed.connect(_on_control_scheme_changed)
	if InputManager and InputManager.has_signal("prompt_style_changed"):
		InputManager.prompt_style_changed.connect(_on_prompt_style_changed)

func _setup_responsive_sizing() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = max(320.0, viewport_size.x * 0.25)
	var panel_height: float = max(400.0, viewport_size.y * 0.6)
	if full_controls:
		full_controls.offset_left = 20.0
		full_controls.offset_top = -panel_height / 2.0
		full_controls.offset_right = 20.0 + panel_width
		full_controls.offset_bottom = panel_height / 2.0
	if minimized_hints:
		minimized_hints.offset_left = -160.0
		minimized_hints.offset_top = 10.0
		minimized_hints.offset_right = -10.0
		minimized_hints.offset_bottom = 50.0

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
	call_deferred("_check_for_existing_player")

func _refresh_control_prompts() -> void:
	movement_key.text = InputManager.get_action_prompt("move")
	sprint_key.text = InputManager.get_action_prompt("sprint")
	look_key.text = InputManager.get_action_prompt("look")
	interact_key.text = InputManager.get_action_prompt("interact")
	flashlight_key.text = InputManager.get_action_prompt("toggle_flashlight")
	inventory_key.text = InputManager.get_action_prompt("inventory")
	journal_key.text = InputManager.get_action_prompt("journal")
	pause_key.text = InputManager.get_action_prompt("pause")
	minimized_inventory_key.text = InputManager.get_action_prompt("inventory")
	minimized_flashlight_key.text = InputManager.get_action_prompt("toggle_flashlight")
	minimized_journal_key.text = InputManager.get_action_prompt("journal")
	_refresh_interaction_prompt()

func _on_control_scheme_changed(_scheme: String) -> void:
	_refresh_control_prompts()

func _on_prompt_style_changed(_prompt_style: String) -> void:
	_refresh_control_prompts()

func _check_for_existing_player() -> void:
	if _has_been_shown:
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_on_player_spawned(players[0])

func _on_player_spawned(player_node: Node3D) -> void:
	if _has_been_shown:
		return
	_show_controls_sequence()

func _show_controls_sequence() -> void:
	_has_been_shown = true
	_fade_in_full_controls()
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	_transition_to_minimized()

func _fade_in_full_controls() -> void:
	full_controls.visible = true
	full_controls.modulate.a = 0.0
	create_tween().tween_property(full_controls, "modulate:a", 1.0, FADE_DURATION)

func _transition_to_minimized() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(full_controls, "modulate:a", 0.0, FADE_DURATION)
	tween.chain()
	tween.tween_callback(func(): full_controls.visible = false)
	tween.tween_callback(_fade_in_minimized)

func _fade_in_minimized() -> void:
	minimized_hints.visible = true
	minimized_hints.modulate.a = 0.0
	create_tween().tween_property(minimized_hints, "modulate:a", 1.0, FADE_DURATION)

func force_show_minimized_hints() -> void:
	minimized_hints.visible = true
	minimized_hints.modulate.a = 1.0

func _load_icons() -> void:
	var backpack_texture: Texture2D = _try_load_texture(["res://assets/thumbnails/backpack.png", "res://assets/thumbnails/inventory.png", "res://assets/thumbnails/bag.png"])
	if backpack_texture:
		backpack_icon.texture = backpack_texture
	var flashlight_texture: Texture2D = load("res://assets/thumbnails/flashlight.png")
	if flashlight_texture:
		flashlight_icon.texture = flashlight_texture
	var journal_texture: Texture2D = load("res://assets/thumbnails/journal.png")
	if journal_texture:
		journal_icon.texture = journal_texture

func _try_load_texture(paths: Array) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _on_show_interaction_prompt(prompt_text: String, target: Node) -> void:
	_current_interaction_target = target
	var normalized := prompt_text.strip_edges()
	var lower := normalized.to_lower()
	if lower.begins_with("press "):
		var to_index := lower.find(" to ")
		if to_index != -1:
			normalized = normalized.substr(to_index + 4).strip_edges()
	_current_interaction_verb = normalized
	_refresh_interaction_prompt()
	interaction_prompt.visible = true
	create_tween().tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

func _on_hide_interaction_prompt(target: Node) -> void:
	if _current_interaction_target != target:
		return
	_current_interaction_target = null
	_current_interaction_verb = ""
	var tween: Tween = create_tween()
	tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): interaction_prompt.visible = false)

func _refresh_interaction_prompt() -> void:
	if _current_interaction_verb.is_empty():
		return
	interaction_prompt.text = "Press %s to %s" % [InputManager.get_action_prompt("interact"), _current_interaction_verb]

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
