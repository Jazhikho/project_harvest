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

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_load_narrative_data()
	
	# Allow processing even when game is paused (for intro input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("NarrativeUI: Set process_mode to ALWAYS")
	
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

func _input(event: InputEvent) -> void:
	# Allow keyboard input to advance ONLY during intro sequence
	if in_intro_sequence and waiting_for_advance and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		print("NarrativeUI: Keyboard input detected (Space/E), advancing sequence")
		_advance_sequence()
		get_viewport().set_input_as_handled()

func _on_click_blocker_input(event: InputEvent) -> void:
	# Allow mouse click to advance ONLY during intro sequence
	if in_intro_sequence and waiting_for_advance and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("NarrativeUI: Mouse click detected on blocker, advancing sequence")
		_advance_sequence()
		get_viewport().set_input_as_handled()

func _advance_sequence() -> void:
	print("NarrativeUI: _advance_sequence called, waiting_for_advance=", waiting_for_advance)
	if waiting_for_advance:
		waiting_for_advance = false
		print("NarrativeUI: Advancing to next message...")
		_show_next_in_sequence()

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
	bus.entity_stage_changed.connect(_on_entity_stage_changed)
	
	# Check if player already exists (fallback for race condition)
	call_deferred("_check_for_existing_player")

## is_intro_playing
## Purpose: Check if intro sequence is currently playing
## @return bool: True if intro is playing.
func is_intro_playing() -> bool:
	return in_intro_sequence

func _check_for_existing_player() -> void:
	"""Check if player already spawned (fallback for race condition)"""
	print("NarrativeUI: _check_for_existing_player called, intro_completed=", intro_completed)
	
	# Don't check if already handled
	if intro_completed:
		print("NarrativeUI: Already handled, skipping fallback check")
		return
		
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("NarrativeUI: Found player via fallback check")
		_on_player_spawned(players[0])

func _on_player_spawned(player_node: Node3D) -> void:
	print("NarrativeUI: player_spawned received, intro_completed=", intro_completed)
	
	if intro_completed:
		print("NarrativeUI: Intro already completed, skipping")
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
	print("NarrativeUI: SaveManager had_existing_save=", save_mgr.had_existing_save, ", is_new_game=", is_new_game)
	
	if is_new_game:
		# Set flag IMMEDIATELY so ControlsUI knows to wait
		in_intro_sequence = true
		print("NarrativeUI: Set in_intro_sequence=true, waiting 0.5 seconds before showing...")
		await get_tree().create_timer(0.5).timeout
		print("NarrativeUI: Starting intro sequence (new game)")
		_start_intro_sequence()
	else:
		print("NarrativeUI: Showing continue toast (returning player)")
		# Show continue toast but don't make it interactable
		_show_continue_toast()
		intro_completed = true

func _start_intro_sequence() -> void:
	print("NarrativeUI: _start_intro_sequence called, in_intro_sequence=", in_intro_sequence)
	
	if not narrative_data.has("sequences") or not narrative_data.sequences.has("intro"):
		print("NarrativeUI: ERROR - No intro sequence found in narrative data!")
		in_intro_sequence = false
		return
	
	print("NarrativeUI: Initializing intro, pausing game")
	# in_intro_sequence is already true (set in _on_player_spawned)
	current_sequence = narrative_data.sequences.intro.duplicate()
	sequence_index = 0
	
	# Release mouse for intro
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("NarrativeUI: Mouse mode set to VISIBLE")
	
	# Show click blocker to capture all clicks
	if click_blocker:
		click_blocker.visible = true
		print("NarrativeUI: Click blocker enabled")
	
	# Pause the game during intro
	get_tree().paused = true
	print("NarrativeUI: Game paused=", get_tree().paused)
	
	_show_next_in_sequence()

func _show_next_in_sequence() -> void:
	print("NarrativeUI: _show_next_in_sequence, index=", sequence_index, "/", current_sequence.size())
	
	if sequence_index >= current_sequence.size():
		# Intro sequence finished
		print("NarrativeUI: Intro sequence complete, ending...")
		_end_intro_sequence()
		return
	
	var entry = current_sequence[sequence_index]
	print("NarrativeUI: Displaying message ", sequence_index + 1, ": ", entry.text.substr(0, 30), "...")
	sequence_index += 1
	
	_display_intro_message(entry.text)

func _display_intro_message(text: String) -> void:
	"""Display a message during intro sequence (waits for player input)"""
	print("NarrativeUI: _display_intro_message called")
	print("NarrativeUI: Text: ", text.substr(0, 50), "...")
	print("NarrativeUI: Current modulate.a=", modulate.a, ", visible=", visible)
	
	text_label.text = text
	visible = true
	
	# Show continue indicator for intro
	continue_indicator.visible = true
	continue_indicator.text = "Click or press SPACE/E to continue..."
	waiting_for_advance = true
	print("NarrativeUI: Set waiting_for_advance=true, continue_indicator visible")
	
	# Always fade in from 0 for intro messages
	modulate.a = 0.0
	print("NarrativeUI: Starting fade in tween...")
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished
	print("NarrativeUI: Intro message visible (modulate.a=", modulate.a, "), waiting for player input")
	print("NarrativeUI: Panel exists: ", has_node("Panel"), ", Panel visible: ", $Panel.visible if has_node("Panel") else "N/A")
	print("NarrativeUI: Global position: ", global_position, ", Size: ", size)

func _end_intro_sequence() -> void:
	print("NarrativeUI: _end_intro_sequence called")
	current_sequence = []
	sequence_index = 0
	in_intro_sequence = false
	intro_completed = true
	continue_indicator.visible = false
	waiting_for_advance = false
	
	# Hide click blocker
	if click_blocker:
		click_blocker.visible = false
		print("NarrativeUI: Click blocker disabled")
	
	# Fade out the narrative panel
	print("NarrativeUI: Fading out narrative panel...")
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
	print("NarrativeUI: Narrative panel hidden")
	
	# Resume game
	get_tree().paused = false
	print("NarrativeUI: Game unpaused, paused=", get_tree().paused)
	
	# Recapture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("NarrativeUI: Mouse mode set to CAPTURED, intro sequence ended")

func _show_continue_toast() -> void:
	print("NarrativeUI: _show_continue_toast called")
	var continue_toasts = []
	if not narrative_data.has("toasts"):
		print("NarrativeUI: No toasts in narrative data")
		return
		
	for key in narrative_data.toasts.keys():
		if key.begins_with("continue_toast_"):
			continue_toasts.append(key)
	
	if continue_toasts.is_empty():
		print("NarrativeUI: No continue toasts found")
		return
	
	var random_key = continue_toasts[randi() % continue_toasts.size()]
	var toast = narrative_data.toasts[random_key]
	print("NarrativeUI: Showing continue toast: ", random_key, " - ", toast.text.substr(0, 30), "...")
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
	
	for threshold in thresholds:
		if old_value > threshold and new_value <= threshold:
			var toast_key = "sanity_" + str(threshold)
			if narrative_data.has("toasts") and narrative_data.toasts.has(toast_key):
				var toast = narrative_data.toasts[toast_key]
				_queue_message(toast.text, toast.get("seconds", 3.0))
			break

func _on_player_looking_at(target: Node3D, target_type: String) -> void:
	# Can be extended for specific look-at triggers
	pass

func _on_entity_stage_changed(entity_type: String, entity_node: Node3D, old_stage: int, new_stage: int) -> void:
	if entity_type == "effigy":
		var toast_key = "effigy_stage" + str(new_stage) + "_seen"
		if narrative_data.has("toasts") and narrative_data.toasts.has(toast_key):
			var toast = narrative_data.toasts[toast_key]
			_queue_message(toast.text, toast.get("seconds", 5.0))

func _queue_message(text: String, duration: float) -> void:
	"""Queue a toast message (non-interactive, timed display)"""
	print("NarrativeUI: _queue_message called, in_intro_sequence=", in_intro_sequence, ", is_displaying=", is_displaying)
	print("NarrativeUI: intro_completed=", intro_completed, ", get_tree().paused=", get_tree().paused)
	
	# Don't queue messages during intro sequence
	if in_intro_sequence:
		print("NarrativeUI: Skipping message queue (intro is playing)")
		return
	
	# Safety check: if intro is completed but in_intro_sequence is still true, force it false
	if intro_completed and in_intro_sequence:
		print("NarrativeUI: WARNING - intro_completed=true but in_intro_sequence=true, forcing correction")
		in_intro_sequence = false
		
	message_queue.append({"text": text, "duration": duration})
	print("NarrativeUI: Message queued, queue size=", message_queue.size())
	
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
	print("NarrativeUI: _display_toast called, duration=", duration, "s")
	print("NarrativeUI: Toast text: ", text.substr(0, 50), "...")
	print("NarrativeUI: Current global_position: ", global_position, ", size: ", size)
	print("NarrativeUI: Current modulate.a=", modulate.a, ", visible=", visible)
	
	text_label.text = text
	visible = true
	
	# NO continue indicator for toasts
	continue_indicator.visible = false
	
	# Make sure mouse filter is IGNORE (toasts should not block input)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("Panel"):
		$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("NarrativeUI: Toast visible, fading in...")
	print("NarrativeUI: After setting visible=true: global_position=", global_position, ", size=", size, ", modulate.a=", modulate.a)
	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished
	
	print("NarrativeUI: Toast displayed, waiting ", duration, "s...")
	print("NarrativeUI: After fade in: modulate.a=", modulate.a, ", visible=", visible)
	# Wait for duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
	
	print("NarrativeUI: Toast duration complete, fading out...")
	# Fade out
	_fade_out_toast()

func _fade_out_toast() -> void:
	"""Fade out and continue processing queue"""
	print("NarrativeUI: _fade_out_toast called")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	
	visible = false
	print("NarrativeUI: Toast hidden, checking queue...")
	
	# Continue processing queue
	_process_queue()
