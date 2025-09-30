extends Control

signal closed

@onready var note_tree: Tree = $MainPanel/HSplitContainer/LeftPanel/ScrollContainer/NoteTree
@onready var note_title: Label = $MainPanel/HSplitContainer/RightPanel/NoteTitle
@onready var note_content: RichTextLabel = $MainPanel/HSplitContainer/RightPanel/ScrollContainer/NoteContent
@onready var metadata_label: Label = $MainPanel/HSplitContainer/RightPanel/MetadataLabel
@onready var read_button: Button = $MainPanel/HSplitContainer/LeftPanel/ButtonContainer/ReadButton
@onready var search_bar: LineEdit = $MainPanel/HSplitContainer/LeftPanel/SearchBar

var inventory_manager: Node
var item_manager: Node
var collected_notes: Dictionary = {} # Store note_id -> note_data
var tree_items: Dictionary = {} # Store category -> TreeItem
var selected_note_id: String = ""
var was_mouse_captured: bool = false

func _ready() -> void:
	# Set process mode so journal works when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Get managers
	inventory_manager = get_node_or_null("/root/PlayerInventory")
	item_manager = get_node_or_null("/root/ItemManager")
	
	if not inventory_manager:
		push_warning("JournalUI: PlayerInventory autoload not found")
	if not item_manager:
		push_warning("JournalUI: ItemManager autoload not found")
	
	# Setup tree
	_setup_tree()

func _setup_tree() -> void:
	"""Initialize the tree structure"""
	if not note_tree:
		return
		
	note_tree.create_item() # Create hidden root
	note_tree.set_column_title(0, "Notes")
	note_tree.set_column_titles_visible(false)
	
	# Allow single selection
	note_tree.select_mode = Tree.SELECT_SINGLE

func show_journal() -> void:
	"""Show journal and handle mouse state"""
	visible = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_journal()
	
	# Clear selection when opening
	selected_note_id = ""
	read_button.disabled = true
	note_title.text = "Select a note to read"
	note_content.text = "No note selected."
	metadata_label.text = ""

func show_journal_with_note(note_id: String) -> void:
	"""
	Show journal and immediately focus on a specific note
	
	@param note_id: Note to focus on and display
	"""
	visible = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_journal()
	
	# Wait for journal to populate
	await get_tree().process_frame
	
	# Find and select the note in the tree
	_select_note_in_tree(note_id)
	
	# Display the note immediately
	if collected_notes.has(note_id):
		selected_note_id = note_id
		read_button.disabled = false
		_display_note(note_id)

func _select_note_in_tree(note_id: String) -> void:
	"""
	Find and select a specific note in the tree
	
	@param note_id: Note to select
	"""
	var root: TreeItem = note_tree.get_root()
	if not root:
		return
	
	# Search through all categories
	var category: TreeItem = root.get_first_child()
	while category:
		# Expand the category
		category.set_collapsed(false)
		
		# Search through notes in this category
		var note: TreeItem = category.get_first_child()
		while note:
			var current_note_id: String = note.get_metadata(0)
			if current_note_id == note_id:
				# Found it! Select this note
				note.select(0)
				# Ensure it's visible (scroll to it)
				note_tree.scroll_to_item(note)
				return
			note = note.get_next()
		
		category = category.get_next()

func hide_journal() -> void:
	"""Hide journal and restore mouse state"""
	visible = false
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("closed")

func _populate_journal() -> void:
	"""Populate the journal with collected notes"""
	if not inventory_manager or not item_manager:
		return
	
	# Clear existing tree items
	note_tree.clear()
	tree_items.clear()
	collected_notes.clear()
	
	# Create root
	var root: TreeItem = note_tree.create_item()
	
	# Get all notes from inventory
	var items: Array = inventory_manager.get_inventory()
	var notes_by_category: Dictionary = {}
	
	for item_id in items:
		if not item_manager.has_method("get_item_info"):
			continue
			
		var item_info: Dictionary = item_manager.get_item_info(item_id)
		
		# Check if this is a note
		if item_info.get("category", "") == "notes":
			collected_notes[item_id] = item_info
			
			# Get subcategory for organization (you can customize this)
			var subcategory: String = item_info.get("subcategory", "Miscellaneous")
			if subcategory == "":
				subcategory = "Miscellaneous"
			
			if not notes_by_category.has(subcategory):
				notes_by_category[subcategory] = []
			notes_by_category[subcategory].append(item_id)
	
	# Sort categories with "Puzzle Clues" first, then alphabetically
	var sorted_categories: Array = notes_by_category.keys()
	sorted_categories.sort_custom(func(a, b):
		# "Puzzle Clues" always comes first
		if a == "Puzzle Clues":
			return true
		if b == "Puzzle Clues":
			return false
		# Otherwise sort alphabetically
		return a < b
	)
	
	# Create tree structure
	for category in sorted_categories:
		# Create category item
		var category_item: TreeItem = note_tree.create_item(root)
		category_item.set_text(0, category)
		category_item.set_selectable(0, false)
		category_item.set_custom_color(0, Color(0.8, 0.8, 0.8))
		tree_items[category] = category_item
		
		# Sort notes in category alphabetically by name
		var notes_in_category: Array = notes_by_category[category]
		notes_in_category.sort_custom(func(a, b):
			var name_a = collected_notes[a].get("name", a)
			var name_b = collected_notes[b].get("name", b)
			return name_a < name_b
		)
		
		# Add notes to category
		for note_id in notes_in_category:
			var note_item: TreeItem = note_tree.create_item(category_item)
			var note_name: String = collected_notes[note_id].get("name", note_id)
			note_item.set_text(0, note_name)
			note_item.set_metadata(0, note_id)
			
			# Add icon if specified
			var icon_path: String = collected_notes[note_id].get("icon", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var icon: Texture2D = load(icon_path)
				if icon:
					note_item.set_icon(0, icon)
					note_item.set_icon_max_width(0, 16)
		
		# Expand category by default if it has few items
		if notes_in_category.size() <= 5:
			category_item.set_collapsed(false)
	
	# Show message if no notes collected
	if collected_notes.is_empty():
		var empty_item: TreeItem = note_tree.create_item(root)
		empty_item.set_text(0, "No notes collected yet")
		empty_item.set_selectable(0, false)
		empty_item.set_custom_color(0, Color(0.5, 0.5, 0.5))

func _on_note_tree_item_selected() -> void:
	"""Handle tree item selection"""
	var selected: TreeItem = note_tree.get_selected()
	if not selected:
		return
	
	var note_id: String = selected.get_metadata(0)
	if note_id == null or note_id == "":
		# Category selected, not a note
		read_button.disabled = true
		return
	
	selected_note_id = note_id
	read_button.disabled = false
	_preview_note(note_id)

func _on_note_tree_item_activated() -> void:
	"""Handle double-click on tree item"""
	if selected_note_id != "":
		_display_note(selected_note_id)

func _on_read_button_pressed() -> void:
	"""Handle read button press"""
	if selected_note_id != "":
		_display_note(selected_note_id)

func _preview_note(note_id: String) -> void:
	"""Show a preview of the note"""
	if not collected_notes.has(note_id):
		return
	
	var note_data: Dictionary = collected_notes[note_id]
	note_title.text = note_data.get("name", note_id)
	
	# Show truncated description as preview
	var description: String = note_data.get("description", "No content available.")
	note_content.text = description

func _display_note(note_id: String) -> void:
	"""Display full note content"""
	if not collected_notes.has(note_id):
		return
	
	var note_data: Dictionary = collected_notes[note_id]
	note_title.text = note_data.get("name", note_id)
	
	# Display full description with any BBCode formatting
	var description: String = note_data.get("description", "No content available.")
	note_content.text = description
	
	# Update metadata
	var date_found: String = note_data.get("date_found", "")
	var location: String = note_data.get("location", "")
	var metadata_text: String = ""
	if date_found != "":
		metadata_text += "Found: " + date_found
	if location != "":
		if metadata_text != "":
			metadata_text += " | "
		metadata_text += "Location: " + location
	metadata_label.text = metadata_text

func _on_search_text_changed(new_text: String) -> void:
	"""Filter notes based on search text"""
	if not note_tree:
		return
	
	var search_text: String = new_text.to_lower()
	
	# If search is empty, show all
	if search_text == "":
		_show_all_items()
		return
	
	# Hide items that don't match
	var root: TreeItem = note_tree.get_root()
	if not root:
		return
	
	var category: TreeItem = root.get_first_child()
	while category:
		var has_visible_children: bool = false
		var note: TreeItem = category.get_first_child()
		
		while note:
			var note_id: String = note.get_metadata(0)
			if note_id and collected_notes.has(note_id):
				var note_data: Dictionary = collected_notes[note_id]
				var note_name: String = note_data.get("name", "").to_lower()
				var note_desc: String = note_data.get("description", "").to_lower()
				
				# Check if search text is in name or description
				var is_match: bool = note_name.contains(search_text) or note_desc.contains(search_text)
				note.set_visible(is_match)
				
				if is_match:
					has_visible_children = true
			
			note = note.get_next()
		
		# Hide category if no visible children
		category.set_visible(has_visible_children)
		# Expand categories with search results
		if has_visible_children and search_text != "":
			category.set_collapsed(false)
		
		category = category.get_next()

func _show_all_items() -> void:
	"""Show all items in the tree"""
	var root: TreeItem = note_tree.get_root()
	if not root:
		return
	
	var category: TreeItem = root.get_first_child()
	while category:
		category.set_visible(true)
		
		var note: TreeItem = category.get_first_child()
		while note:
			note.set_visible(true)
			note = note.get_next()
		
		category = category.get_next()

func _input(event: InputEvent) -> void:
	"""Handle input events"""
	if not visible:
		return
	
	# Handle ESC to close journal
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_journal()

func _on_close_button_pressed() -> void:
	"""Handle close button press"""
	hide_journal()
