extends Control
## RPG-style narrative panel that displays story messages and responds to game events

const NARRATIVE_PATH = "res://data/narrative.json"

@onready var text_label: Label = $Panel/MarginContainer/VBox/TextLabel
@onready var continue_indicator: Label = $Panel/MarginContainer/VBox/ContinueIndicator
@onready var click_blocker: Control = $ClickBlocker # Full-screen click capture

var narrative_data: Dictionary = {}
var message_queue: Array[Dictionary] = []
var is_displaying: bool = false
var current_sequence: Array = []
var sequence_index: int = 0
var waiting_for_advance: bool = false
var in_intro_sequence: bool = false
var intro_completed: bool = false
var last_effigy_stage_seen: int = 0
var flashlight_narrative_triggered: bool = false

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_load_narrative_data()
	
	# Allow processing even when game is paused (for intro input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure mouse filtering is disabled for toasts
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("Panel"):
		$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect click blocker
	if click_blocker:
		click_blocker.gui_input.connect(_on_click_blocker_input)
		click_blocker.visible = false
	
	# Connect immediately to avoid missing events
	_connect_to_events()
	if InputManager and InputManager.has_signal("control_scheme_changed"):
		InputManager.control_scheme_changed.connect(_on_prompt_context_changed)
	if InputManager and InputManager.has_signal("prompt_style_changed"):
		InputManager.prompt_style_changed.connect(_on_prompt_context_changed)

func _process(_delta: float) -> void:
	"""Check for timer-based narrative triggers"""
	# Only check if intro is completed and we haven't triggered flashlight narrative yet
	if intro_completed and not flashlight_narrative_triggered:
		_check_flashlight_timer()

func _input(event: InputEvent) -> void:
	# Allow keyboard input to advance ONLY during intro sequence
	if in_intro_sequence and waiting_for_advance and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_advance_sequence()
		get_viewport().set_input_as_handled()

func _on_click_blocker_input(event: InputEvent) -> void:
	# Allow mouse click to advance ONLY during intro sequence
	if in_intro_sequence and waiting_for_advance and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_sequence()
		get_viewport().set_input_as_handled()

func _advance_sequence() -> void:
	if waiting_for_advance:
		waiting_for_advance = false
		_show_next_in_sequence()

func _on_prompt_context_changed(_value = null) -> void:
	_refresh_continue_prompt()

func _refresh_continue_prompt() -> void:
	if not continue_indicator or not continue_indicator.visible:
		return
	var prompt: String = InputManager.get_action_prompt("continue")
	if InputManager.get_prompt_style() == InputManager.PROMPT_STYLE_KEYBOARD:
		continue_indicator.text = "Click or press %s to continue..." % prompt
	else:
		continue_indicator.text = "Press %s to continue..." % prompt

func _resolve_prompt_text(text: String) -> String:
	if text.is_empty():
		return text
	var resolved_text: String = text
	var prompt_tokens := {
		"{continue}": InputManager.get_action_prompt("continue"),
		"{toggle_flashlight}": InputManager.get_action_prompt("toggle_flashlight"),
		"{interact}": InputManager.get_action_prompt("interact"),
		"{sprint}": InputManager.get_action_prompt("sprint")
	}
	for token in prompt_tokens.keys():
		resolved_text = resolved_text.replace(token, prompt_tokens[token])
	return resolved_text

func _load_narrative_data() -> void:
	if not FileAccess.file_exists(NARRATIVE_PATH):
		push_error("NarrativeUI: narrative.json not found at ", NARRATIVE_PATH)
		return
	
	var file = FileAccess.open(NARRATIVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			narrative_data = json.data
		else:
			push_error("NarrativeUI: Failed to parse narrative.json")
		file.close()

func _connect_to_events() -> void:
	var bus = get_node_or_null("/root/MessageBus")
	if not bus:
		push_error("NarrativeUI: MessageBus not found")
		return
	
	bus.player_spawned.connect(_on_player_spawned)
	bus.item_collected.connect(_on_item_collected)
	bus.sanity_changed.connect(_on_sanity_changed)
	bus.player_looking_at.connect(_on_player_looking_at)
	
	# Check if player already exists (fallback for race condition)
	call_deferred("_check_for_existing_player")

## is_intro_playing
## Purpose: Check if intro sequence is currently playing
## @return bool: True if intro is playing.
func is_intro_playing() -> bool:
	return in_intro_sequence

func _check_for_existing_player() -> void:
	"""Check if player already spawned (fallback for race condition)"""
	if intro_completed:
		return
		
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_on_player_spawned(players[0])

func _on_player_spawned(player_node: Node3D) -> void:
	if intro_completed:
		return
	
	# Wait for game_started to fire and SaveManager to update had_existing_save flag
	# We need to wait because game_started fires AFTER player spawns
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return
	
	# Wait a few frames to ensure game_started signal has been processed
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if this is a new game using SaveManager's had_existing_save flag
	# This flag is set in SaveManager._on_game_started() before start_run() creates a new save file
	var is_new_game: bool = not save_mgr.had_existing_save
	
	if is_new_game:
		in_intro_sequence = true
		await get_tree().create_timer(0.5).timeout
		_start_intro_sequence()
	else:
		# Show continue toast but don't make it interactable
		_show_continue_toast()
		intro_completed = true

func _start_intro_sequence() -> void:
	if not narrative_data.has("sequences") or not narrative_data.sequences.has("intro"):
		push_error("NarrativeUI: No intro sequence found in narrative data")
		in_intro_sequence = false
		return
	# in_intro_sequence is already true (set in _on_player_spawned)
	current_sequence = narrative_data.sequences.intro.duplicate()
	sequence_index = 0
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if click_blocker:
		click_blocker.visible = true
	
	get_tree().paused = true
	
	_show_next_in_sequence()

func _show_next_in_sequence() -> void:
	if sequence_index >= current_sequence.size():
		_end_intro_sequence()
		return
	
	var entry = current_sequence[sequence_index]
	sequence_index += 1
	
	_display_intro_message(entry.text)

func _display_intro_message(text: String) -> void:
	"""Display a message during intro sequence (waits for player input)"""
	text_label.text = _resolve_prompt_text(text)
	visible = true
	
	# Show continue indicator for intro
	continue_indicator.visible = true
	_refresh_continue_prompt()
	waiting_for_advance = true
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished

func _end_intro_sequence() -> void:
	current_sequence = []
	sequence_index = 0
	in_intro_sequence = false
	intro_completed = true
	continue_indicator.visible = false
	waiting_for_advance = false
	
	# Hide click blocker
	if click_blocker:
		click_blocker.visible = false
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
	
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _show_continue_toast() -> void:
	var continue_toasts = []
	if not narrative_data.has("toasts"):
		return
		
	for key in narrative_data.toasts.keys():
		if key.begins_with("continue_toast_"):
			continue_toasts.append(key)
	
	if continue_toasts.is_empty():
		return
	
	var random_key = continue_toasts[randi() % continue_toasts.size()]
	var toast = narrative_data.toasts[random_key]
	_queue_message(toast.text, toast.get("seconds", 5.0))

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	var toast_key = "item_" + item_id
	if narrative_data.has("toasts") and narrative_data.toasts.has(toast_key):
		var toast = narrative_data.toasts[toast_key]
		_queue_message(toast.text, toast.get("seconds", 4.0))
	elif item_id.begins_with("weird_") and narrative_data.toasts.has("weird_thing_found"):
		var toast = narrative_data.toasts.weird_thing_found
		_queue_message(toast.text, toast.get("seconds", 5.0))

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	# Don't show sanity messages during intro
	if in_intro_sequence:
		return
		
	var thresholds = [90, 80, 70, 60, 50, 40, 30, 20, 10]
	
	for threshold_percent in thresholds:
		var threshold_value: int = int(round(float(GameConstants.MAX_SANITY) * (float(threshold_percent) / 100.0)))
		if old_value > threshold_value and new_value <= threshold_value:
			var toast_key = "sanity_" + str(threshold_percent)
			if narrative_data.has("toasts") and narrative_data.toasts.has(toast_key):
				var toast = narrative_data.toasts[toast_key]
				_queue_message(toast.text, toast.get("seconds", 3.0))
			break

func _on_player_looking_at(target: Node3D, target_type: String) -> void:
	"""Handle when player looks at an entity"""
	if target_type == "effigy":
		# Get the effigy's current stage
		var current_stage: int = target.get_meta("current_stage", 1)
		
		# Check if this is the first time seeing this stage
		if current_stage != last_effigy_stage_seen:
			last_effigy_stage_seen = current_stage
			
			# Fire narrative toast for first time seeing this stage
			var toast_key: String = "effigy_stage" + str(current_stage) + "_seen"
			if narrative_data.has("toasts") and narrative_data.toasts.has(toast_key):
				var toast = narrative_data.toasts[toast_key]
				_queue_message(toast.text, toast.get("seconds", 5.0))

func _check_flashlight_timer() -> void:
	"""Check if 3 minutes have passed and trigger flashlight narrative"""
	var game_director = get_node_or_null("/root/GameDirector")
	if not game_director:
		return
	
	var session_duration: float = game_director.get_session_duration()
	
	if session_duration >= GameConstants.FLASHLIGHT_HINT_TIME:
		flashlight_narrative_triggered = true
		var player: Node = get_tree().get_first_node_in_group("player")
		if player and player.has_method("is_flashlight_enabled") and player.is_flashlight_enabled():
			return
		
		# Trigger the flashlight narrative
		if narrative_data.has("toasts") and narrative_data.toasts.has("flashlight_after_3m"):
			var toast = narrative_data.toasts.flashlight_after_3m
			_queue_message(toast.text, toast.get("seconds", 5.0))

func _queue_message(text: String, duration: float) -> void:
	"""Queue a toast message (non-interactive, timed display)"""
	if in_intro_sequence:
		return
	
	if intro_completed and in_intro_sequence:
		in_intro_sequence = false
		
	message_queue.append({"text": _resolve_prompt_text(text), "duration": duration})
	
	if not is_displaying:
		_process_queue()

func _process_queue() -> void:
	if message_queue.is_empty():
		is_displaying = false
		return
	
	is_displaying = true
	var msg = message_queue.pop_front()
	_display_toast(msg.text, msg.duration)

func _display_toast(text: String, duration: float) -> void:
	"""Display a timed toast message (no interaction)"""
	text_label.text = text
	visible = true
	
	# NO continue indicator for toasts
	continue_indicator.visible = false
	
	# Make sure mouse filter is IGNORE (toasts should not block input)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("Panel"):
		$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished
	
	# Wait for duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
	
	_fade_out_toast()

func _fade_out_toast() -> void:
	"""Fade out and continue processing queue"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	
	visible = false
	
	# Continue processing queue
	_process_queue()
