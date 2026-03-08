extends Control

signal closed

@onready var note_tree: Tree = $MainPanel/HSplitContainer/LeftPanel/ScrollContainer/NoteTree
@onready var note_title: Label = $MainPanel/HSplitContainer/RightPanel/NoteTitle
@onready var note_content: RichTextLabel = $MainPanel/HSplitContainer/RightPanel/ScrollContainer/NoteContent
@onready var metadata_label: Label = $MainPanel/HSplitContainer/RightPanel/MetadataLabel
@onready var read_button: Button = $MainPanel/HSplitContainer/LeftPanel/ButtonContainer/ReadButton
@onready var search_bar: LineEdit = $MainPanel/HSplitContainer/LeftPanel/SearchBar
@onready var close_button: Button = $MainPanel/HSplitContainer/LeftPanel/ButtonContainer/CloseButton

var inventory_manager: Node
var item_manager: Node
var collected_notes: Dictionary = {}
var selected_note_id: String = ""
var was_mouse_captured: bool = false
var _icon_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as Node.ProcessMode
	call_deferred("_setup_responsive_sizing")
	inventory_manager = get_node_or_null("/root/PlayerInventory")
	item_manager = get_node_or_null("/root/ItemManager")
	_setup_tree()

func _setup_responsive_sizing() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = viewport_size.x * 0.85
	var panel_height: float = viewport_size.y * 0.8
	var main_panel: Control = $MainPanel
	main_panel.offset_left = -panel_width / 2.0
	main_panel.offset_top = -panel_height / 2.0
	main_panel.offset_right = panel_width / 2.0
	main_panel.offset_bottom = panel_height / 2.0
	$MainPanel/HSplitContainer.split_offset = int(max(250.0, panel_width * 0.4))

func _setup_tree() -> void:
	note_tree.create_item()
	note_tree.set_column_titles_visible(false)
	note_tree.select_mode = Tree.SELECT_SINGLE

func show_journal() -> void:
	visible = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_journal()
	selected_note_id = ""
	read_button.disabled = true
	note_title.text = "Select a note to read"
	note_content.text = "No note selected."
	metadata_label.text = ""
	call_deferred("_focus_default")

func show_journal_with_note(note_id: String) -> void:
	show_journal()
	await get_tree().process_frame
	_select_note_in_tree(note_id)
	if collected_notes.has(note_id):
		selected_note_id = note_id
		read_button.disabled = false
		_display_note(note_id)
		read_button.grab_focus()

func _focus_default() -> void:
	if note_tree:
		note_tree.grab_focus()
	else:
		close_button.grab_focus()

func hide_journal() -> void:
	visible = false
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("closed")

func _populate_journal() -> void:
	if not inventory_manager or not item_manager:
		return
	note_tree.clear()
	collected_notes.clear()
	var root: TreeItem = note_tree.create_item()
	var notes_by_category: Dictionary = {}
	for item_id in inventory_manager.get_inventory():
		var item_info: Dictionary = item_manager.get_item_info(item_id)
		if item_info.get("category", "") != "notes":
			continue
		collected_notes[item_id] = item_info
		var subcategory: String = item_info.get("subcategory", "Miscellaneous")
		if subcategory == "":
			subcategory = "Miscellaneous"
		if not notes_by_category.has(subcategory):
			notes_by_category[subcategory] = []
		notes_by_category[subcategory].append(item_id)
	var sorted_categories: Array = notes_by_category.keys()
	sorted_categories.sort()
	for category in sorted_categories:
		var category_item: TreeItem = note_tree.create_item(root)
		category_item.set_text(0, category)
		category_item.set_selectable(0, false)
		for note_id in notes_by_category[category]:
			var note_item: TreeItem = note_tree.create_item(category_item)
			note_item.set_text(0, collected_notes[note_id].get("name", note_id))
			note_item.set_metadata(0, note_id)
			var icon_path: String = collected_notes[note_id].get("icon", "")
			var icon: Texture2D = _get_cached_icon(icon_path)
			if icon:
				note_item.set_icon(0, icon)
		category_item.set_collapsed(false)
	if collected_notes.is_empty():
		var empty_item: TreeItem = note_tree.create_item(root)
		empty_item.set_text(0, "No notes collected yet")
		empty_item.set_selectable(0, false)

func _get_cached_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var icon: Texture2D = load(path)
	if icon:
		_icon_cache[path] = icon
	return icon

func _select_note_in_tree(note_id: String) -> void:
	var root: TreeItem = note_tree.get_root()
	if not root:
		return
	var category: TreeItem = root.get_first_child()
	while category:
		var note: TreeItem = category.get_first_child()
		while note:
			if note.get_metadata(0) == note_id:
				note.select(0)
				return
			note = note.get_next()
		category = category.get_next()

func _on_note_tree_item_selected() -> void:
	var selected: TreeItem = note_tree.get_selected()
	if not selected:
		return
	var note_id: String = selected.get_metadata(0)
	if note_id == null or note_id == "":
		read_button.disabled = true
		return
	selected_note_id = note_id
	read_button.disabled = false
	_preview_note(note_id)
	read_button.grab_focus()

func _on_note_tree_item_activated() -> void:
	if selected_note_id != "":
		_display_note(selected_note_id)

func _on_read_button_pressed() -> void:
	if selected_note_id != "":
		_display_note(selected_note_id)

func _preview_note(note_id: String) -> void:
	if not collected_notes.has(note_id):
		return
	var note_data: Dictionary = collected_notes[note_id]
	note_title.text = note_data.get("name", note_id)
	note_content.text = note_data.get("description", "No content available.")

func _display_note(note_id: String) -> void:
	if not collected_notes.has(note_id):
		return
	var note_data: Dictionary = collected_notes[note_id]
	note_title.text = note_data.get("name", note_id)
	note_content.text = note_data.get("description", "No content available.")
	metadata_label.text = note_data.get("location", "")

func _on_search_text_changed(new_text: String) -> void:
	var search_text: String = new_text.to_lower()
	var root: TreeItem = note_tree.get_root()
	if not root:
		return
	var category: TreeItem = root.get_first_child()
	while category:
		var has_visible_children: bool = false
		var note: TreeItem = category.get_first_child()
		while note:
			var note_id: String = note.get_metadata(0)
			var matches_filter: bool = search_text == "" or collected_notes[note_id].get("name", "").to_lower().contains(search_text) or collected_notes[note_id].get("description", "").to_lower().contains(search_text)
			note.set_visible(matches_filter)
			if matches_filter:
				has_visible_children = true
			note = note.get_next()
		category.set_visible(has_visible_children)
		category = category.get_next()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_journal()

func _on_close_button_pressed() -> void:
	hide_journal()
