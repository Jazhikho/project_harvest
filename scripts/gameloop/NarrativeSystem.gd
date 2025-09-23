extends Node

# --------- UI refs (explicit types; resolved in _ready) ----------
var narrative_panel: PanelContainer
var narrative_text: RichTextLabel
var continue_button: Button

# --------- Autoloads ----------
@onready var message_bus: Node = get_node_or_null("/root/MessageBus")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")

const NARRATIVE_JSON: String = "res://data/narrative.json"

# JSON blob
var narrative_data: Dictionary = {}

# Intro sequence state
var current_sequence: Array[Dictionary] = []
var current_sequence_index: int = 0
var is_showing_sequence: bool = false

# Toast handling
var toast_timer: Timer
var sanity_thresholds_triggered: Dictionary = {} # Set[int] via dict
var toast_queue: Array[Dictionary] = [] # { "text": String, "seconds": float }
var toast_running: bool = false

func _ready() -> void:
	randomize()
	_resolve_ui_refs()
	_load_narrative_data()

	# Timer must tick during pause so continue-toasts auto-hide
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(toast_timer)
	toast_timer.timeout.connect(_on_toast_timeout)

	continue_button.pressed.connect(_on_continue_pressed)

	narrative_panel.visible = false

	_connect_to_events()

	# Make discoverable without hardcoding a root path elsewhere
	if message_bus:
		message_bus.set_meta("narrative_system", self)

	# Decide intro vs continue after everything settles
	call_deferred("_deferred_start_check")

# Resolve UI nodes from the scene root to avoid fragile "../" paths.
func _resolve_ui_refs() -> void:
	var root_scene: Node = get_tree().current_scene
	# Expect these exact paths under the current scene:
	# UI/NarrativePanel, UI/NarrativePanel/VBoxContainer/Text, .../Continue
	narrative_panel = root_scene.get_node_or_null("UI/NarrativePanel") as PanelContainer
	narrative_text = root_scene.get_node_or_null("UI/NarrativePanel/VBoxContainer/Text") as RichTextLabel
	continue_button = root_scene.get_node_or_null("UI/NarrativePanel/VBoxContainer/Continue") as Button

	# If your Text is a Label, swap the type cast above:
	# narrative_text = root_scene.get_node_or_null("UI/NarrativePanel/VBoxContainer/Text") as Label

	if narrative_panel == null or narrative_text == null or continue_button == null:
		push_error("NarrativeSystem: UI nodes not found at 'UI/NarrativePanel/...'. Check the scene tree.")

# ─────────────────────────── Data loading ───────────────────────────

func _load_narrative_data() -> void:
	var file: FileAccess = FileAccess.open(NARRATIVE_JSON, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()
		var parser: JSON = JSON.new()
		if parser.parse(json_text) == OK:
			narrative_data = parser.data as Dictionary
		else:
			push_error("NarrativeSystem: Failed to parse %s" % NARRATIVE_JSON)
	else:
		push_error("NarrativeSystem: Could not open %s" % NARRATIVE_JSON)

# ─────────────────────────── Event wiring ───────────────────────────

func _connect_to_events() -> void:
	if message_bus == null:
		return
	if message_bus.has_signal("game_started"):
		message_bus.game_started.connect(_on_game_started)
	if message_bus.has_signal("sanity_changed"):
		message_bus.sanity_changed.connect(_on_sanity_changed)
	if message_bus.has_signal("item_collected"):
		message_bus.item_collected.connect(_on_item_collected)
	if message_bus.has_signal("effigy_stage_changed"):
		message_bus.effigy_stage_changed.connect(_on_effigy_stage_changed)
	if message_bus.has_signal("entered_effigy_area"):
		message_bus.entered_effigy_area.connect(_on_entered_effigy_area)
	if message_bus.has_signal("weird_thing_found"):
		message_bus.weird_thing_found.connect(_on_weird_thing_found)
	if message_bus.has_signal("show_interaction_prompt"):
		message_bus.show_interaction_prompt.connect(_on_show_interaction_prompt)
	if message_bus.has_signal("hide_interaction_prompt"):
		message_bus.hide_interaction_prompt.connect(_on_hide_interaction_prompt)

func _on_game_started() -> void:
	if is_showing_sequence or toast_running:
		return
	_deferred_start_check()

func _deferred_start_check() -> void:
	var is_loading_from_save: bool = get_tree().get_meta("load_from_save", false) as bool
	if is_loading_from_save:
		_show_continue_toast()
		return

	if save_manager != null and save_manager.has_method("is_completely_new_game"):
		var is_new_game: bool = save_manager.call("is_completely_new_game") as bool
		if is_new_game:
			_start_intro_sequence()
		else:
			_show_continue_toast()
	else:
		_start_intro_sequence()

# ─────────────────────────── Intro sequence ───────────────────────────

func _start_intro_sequence() -> void:
	if not narrative_data.has("sequences"):
		push_error("NarrativeSystem: 'sequences' missing in narrative.json")
		return
	var sequences_dict: Dictionary = narrative_data["sequences"] as Dictionary
	if not sequences_dict.has("intro"):
		push_error("NarrativeSystem: No 'intro' sequence in narrative.json")
		return

	# Cast the generic Array to Array[Dictionary] by iterating through it
	var intro_array: Array = sequences_dict["intro"] as Array
	current_sequence.clear()
	for entry in intro_array:
		current_sequence.append(entry as Dictionary)
	current_sequence_index = 0
	is_showing_sequence = true

	_show_panel()
	get_tree().paused = true
	# Set the GameController's game_paused flag to prevent input interception
	var game_controller = get_tree().current_scene
	if game_controller and game_controller.has_method("_set_narrative_pause"):
		game_controller._set_narrative_pause(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_display_current_sequence_text()

func _display_current_sequence_text() -> void:
	if current_sequence_index >= current_sequence.size():
		_end_intro_sequence()
		return

	var sequence_entry: Dictionary = current_sequence[current_sequence_index] as Dictionary
	var sequence_text: String = String(sequence_entry.get("text", ""))
	narrative_text.text = sequence_text

func _on_continue_pressed() -> void:
	if not is_showing_sequence:
		return
	current_sequence_index += 1
	_display_current_sequence_text()

func _end_intro_sequence() -> void:
	is_showing_sequence = false
	_hide_panel()
	get_tree().paused = false
	# Reset the GameController's game_paused flag
	var game_controller = get_tree().current_scene
	if game_controller and game_controller.has_method("_set_narrative_pause"):
		game_controller._set_narrative_pause(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if save_manager != null and save_manager.has_method("start_run"):
		save_manager.call("start_run")
	_try_run_toast() # drain any queued toasts

# ─────────────────────────── Continue toast ───────────────────────────

func _show_continue_toast() -> void:
	# Always mark run as started when showing continue toast (for any continue scenario)
	if save_manager != null and save_manager.has_method("start_run"):
		save_manager.call("start_run")
	
	if not narrative_data.has("toasts"):
		return
	var toasts_dict: Dictionary = narrative_data["toasts"] as Dictionary

	var continue_keys: Array[String] = []
	for key_any: Variant in toasts_dict.keys():
		var key_string: String = String(key_any)
		if key_string.begins_with("continue_toast_"):
			continue_keys.append(key_string)
	if continue_keys.is_empty():
		return

	var chosen_key: String = continue_keys[randi() % continue_keys.size()]
	var toast_definition: Dictionary = toasts_dict[chosen_key] as Dictionary
	var text_value: String = String(toast_definition.get("text", ""))
	var seconds_value: float = float(toast_definition.get("seconds", 5.0))
	_queue_and_maybe_show_toast(text_value, seconds_value)

# ─────────────────────────── Toasts ───────────────────────────

func _queue_and_maybe_show_toast(text: String, seconds: float) -> void:
	if is_showing_sequence:
		toast_queue.append({"text": text, "seconds": seconds})
		return
	_show_toast(text, seconds)

func _show_toast(text: String, duration_seconds: float) -> void:
	if toast_running:
		toast_queue.append({"text": text, "seconds": duration_seconds})
		return

	toast_running = true
	continue_button.visible = false
	narrative_text.text = text
	_show_panel()

	toast_timer.stop()
	toast_timer.wait_time = max(0.1, duration_seconds)
	toast_timer.start()

func _on_toast_timeout() -> void:
	_hide_panel()
	continue_button.visible = true
	toast_running = false
	_try_run_toast()

func _try_run_toast() -> void:
	if toast_running or is_showing_sequence or toast_queue.is_empty():
		return
	var next_entry: Dictionary = toast_queue.pop_front() as Dictionary
	var next_text: String = String(next_entry.get("text", ""))
	var next_seconds: float = float(next_entry.get("seconds", 5.0))
	_show_toast(next_text, next_seconds)

func _show_panel() -> void:
	narrative_panel.visible = true
	# Ensure the panel can receive input during pause
	narrative_panel.process_mode = Node.PROCESS_MODE_ALWAYS

func _hide_panel() -> void:
	narrative_panel.visible = false
	# Reset process mode when hiding
	narrative_panel.process_mode = Node.PROCESS_MODE_INHERIT

# ─────────────────────────── Event hooks ───────────────────────────

func _on_sanity_changed(old_sanity: int, new_sanity: int, _delta: int) -> void:
	var old_threshold: int = (old_sanity / 10) * 10
	var new_threshold: int = (new_sanity / 10) * 10
	if new_threshold < old_threshold and not sanity_thresholds_triggered.has(new_threshold):
		sanity_thresholds_triggered[new_threshold] = true
		_show_toast_by_key("sanity_%d" % new_threshold)

func _on_item_collected(item_id: String, _collector: Node3D, _tile_pos: Vector2i) -> void:
	# Handle note collection with special toasts
	if item_id.begins_with("note_"):
		_handle_note_collection(item_id)
	else:
		var toast_key: String = "item_%s" % item_id.to_lower()
		if not _show_toast_by_key(toast_key):
			_show_toast_by_key("weird_thing_found")

func _handle_note_collection(item_id: String) -> void:
	"""Handle note collection with special toast messages"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		return
	
	# Check if this is the first note collected
	var has_collected_notes = false
	if save_manager.has_method("has_event_flag"):
		has_collected_notes = save_manager.has_event_flag("has_collected_note")
	
	if not has_collected_notes:
		# First note - show special message
		_queue_and_maybe_show_toast("A note? Out here?", 3.0)
		# Mark that we've collected a note
		if save_manager.has_method("set_event_flag"):
			save_manager.set_event_flag("has_collected_note", true)
	else:
		# Subsequent notes
		_queue_and_maybe_show_toast("Another note", 2.0)

func _on_effigy_stage_changed(stage: int) -> void:
	_show_toast_by_key("effigy_stage%d_seen" % stage)

func _on_weird_thing_found() -> void:
	_show_toast_by_key("weird_thing_found")

func _on_entered_effigy_area() -> void:
	_show_toast_by_key("entered_effigy_area")

func _on_show_interaction_prompt(message: String, target: Node3D) -> void:
	"""Handle interaction prompt display"""
	print("DEBUG NarrativeSystem: Show interaction prompt: %s" % message)
	# For now, show a simple toast notification
	# TODO: Implement proper UI prompt system
	_queue_and_maybe_show_toast(message, 2.0)

func _on_hide_interaction_prompt(target: Node3D) -> void:
	"""Handle interaction prompt hiding"""
	print("DEBUG NarrativeSystem: Hide interaction prompt for %s" % target.name)
	# TODO: Implement proper UI prompt hiding

func _show_toast_by_key(key: String) -> bool:
	if not narrative_data.has("toasts"):
		return false
	var toasts_dict: Dictionary = narrative_data["toasts"] as Dictionary
	if not toasts_dict.has(key):
		return false
	var toast_definition: Dictionary = toasts_dict[key] as Dictionary
	var text_value: String = String(toast_definition.get("text", ""))
	var seconds_value: float = float(toast_definition.get("seconds", 5.0))
	_queue_and_maybe_show_toast(text_value, seconds_value)
	return true

# ─────────────────────────── Public API ───────────────────────────

func trigger_narrative(narrative_key: String) -> void:
	_show_toast_by_key(narrative_key)

func trigger_flashlight_timer() -> void:
	_show_toast_by_key("flashlight_after_3m")

# Effigy compatibility
func queue_toast(key: String, seconds: float = -1.0) -> void:
	if not narrative_data.has("toasts"):
		return
	var toasts_dict: Dictionary = narrative_data["toasts"] as Dictionary
	if not toasts_dict.has(key):
		return
	var toast_definition: Dictionary = toasts_dict[key] as Dictionary
	var text_value: String = String(toast_definition.get("text", ""))
	var seconds_value: float = seconds if seconds > 0.0 else float(toast_definition.get("seconds", 5.0))
	_queue_and_maybe_show_toast(text_value, seconds_value)
