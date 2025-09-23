extends Node
## Journal Manager - Stores collected notes separately from inventory and displays a journal UI

signal journal_opened()
signal journal_closed()
signal journal_entry_added(item_id: String)

var _message_bus: Node
var _item_manager: Node

# Data
var _entries: Array[Dictionary] = [] # [{item_id, title, text, timestamp}]
var _current_index: int = 0

# UI
var _journal_panel: Panel = null
var _title_label: Label = null
var _content_label: RichTextLabel = null
var _prev_button: Button = null
var _next_button: Button = null
var _close_button: Button = null

func _ready() -> void:
	name = "JournalManager"
	add_to_group("ui_systems")
	# Enable input processing for ESC key handling
	set_process_input(true)
	call_deferred("_initialize")

func _initialize() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	
	# Get local ItemManager from the game scene
	var game_controllers = get_parent()
	_item_manager = game_controllers.get_node_or_null("ItemManager")
	
	if _message_bus:
		if _message_bus.has_signal("item_collected"):
			_message_bus.item_collected.connect(_on_item_collected)

func add_entry_from_item(item_id: String) -> void:
	if not _item_manager:
		return
	var info: Dictionary = _item_manager.get_item_info(item_id)
	if info.is_empty():
		return
	var entry := {
		"item_id": item_id,
		"title": info.get("name", item_id),
		"text": info.get("description", ""),
		"timestamp": Time.get_unix_time_from_system()
	}
	_entries.append(entry)
	_current_index = _entries.size() - 1
	if _message_bus:
		_message_bus.emit_event("notification_requested", ["New journal entry added", 2.0, 1])
	journal_entry_added.emit(item_id)

func get_entries() -> Array[Dictionary]:
	return _entries.duplicate()

func is_open() -> bool:
	return _journal_panel != null and _journal_panel.visible

func toggle_open() -> void:
	if is_open():
		hide_journal()
	else:
		show_journal()

func show_journal() -> void:
	if not _journal_panel:
		_create_ui()
	_update_page()
	_journal_panel.visible = true
	journal_opened.emit()

func hide_journal() -> void:
	if _journal_panel:
		_journal_panel.visible = false
	journal_closed.emit()

func _input(event: InputEvent) -> void:
	"""Handle input when journal is open"""
	if not is_open():
		return

	# Only handle navigation keys (left/right arrows for page navigation)
	# ESC and journal toggle are handled by GameController
	if event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()

func _create_ui() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return

	_journal_panel = Panel.new()
	_journal_panel.name = "JournalPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_journal_panel.add_theme_stylebox_override("panel", style)
	_journal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_journal_panel.offset_left = 100
	_journal_panel.offset_right = -100
	_journal_panel.offset_top = 80
	_journal_panel.offset_bottom = -80
	_journal_panel.visible = false

	# Layout
	var vbox := VBoxContainer.new()
	_journal_panel.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 16
	vbox.offset_bottom = -16

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_constant_override("outline_size", 1)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(_title_label)

	_content_label = RichTextLabel.new()
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = true
	_content_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95, 1.0))
	_content_label.add_theme_constant_override("normal_font_size", 16)
	_content_label.custom_minimum_size = Vector2(0, 360)
	vbox.add_child(_content_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_prev_button = Button.new()
	_prev_button.text = "Previous"
	_prev_button.pressed.connect(_on_prev_pressed)
	hbox.add_child(_prev_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.pressed.connect(_on_next_pressed)
	hbox.add_child(_next_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(_on_close_button_pressed)
	hbox.add_child(_close_button)

	scene.add_child(_journal_panel)

func _update_page() -> void:
	if _entries.is_empty():
		_title_label.text = "Journal"
		_content_label.text = "[center]No entries yet.[/center]"
		_prev_button.disabled = true
		_next_button.disabled = true
		return

	_current_index = clampi(_current_index, 0, _entries.size() - 1)
	var e := _entries[_current_index]
	_title_label.text = "%s (%d/%d)" % [e.get("title", e.get("item_id", "")), _current_index + 1, _entries.size()]
	var body: String = e.get("text", "")
	_content_label.text = "[left]" + body + "[/left]"
	_prev_button.disabled = _current_index <= 0
	_next_button.disabled = _current_index >= (_entries.size() - 1)

func _on_prev_pressed() -> void:
	_current_index = max(0, _current_index - 1)
	_update_page()

func _on_next_pressed() -> void:
	_current_index = min(_entries.size() - 1, _current_index + 1)
	_update_page()

func _on_close_button_pressed() -> void:
	hide_journal()

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	if item_id.begins_with("note_"):
		add_entry_from_item(item_id)
