extends BaseItem
## Research Note - Collectible notes that provide lore and sanity loss
## Based on items.json note entries

func _ready() -> void:
	# Set default properties for research notes
	if item_name.is_empty():
		item_name = "Research Note"
	if item_description.is_empty():
		item_description = "Dr. A's research notes"
	
	pickup_sound = "res://assets/audio/effects/paper_pickup.ogg"
	
	# Check if this note has already been collected (for permanent notes)
	call_deferred("_check_if_already_collected")
	
	super._ready()

func _check_if_already_collected() -> void:
	"""
	Check if this note has already been collected and destroy if so
	This ensures puzzle notes only spawn once ever
	"""
	var player_inventory: Node = get_node_or_null("/root/PlayerInventory")
	if not player_inventory or item_id.is_empty():
		return
	
	# Check if already in current inventory
	if player_inventory.has_method("has_item") and player_inventory.has_item(item_id):
		queue_free()
		return
	
	# Check if in backpack from previous run
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("get_backpack_inventory"):
		var backpack_items: Array = save_manager.get_backpack_inventory()
		if item_id in backpack_items:
			queue_free()
			return

func _on_item_collected(collector: Node3D) -> void:
	"""Handle research note collection effects"""
	super._on_item_collected(collector)
	
	# Research notes cause sanity loss
	var sanity_manager = get_node_or_null("/root/SanityManager")
	if sanity_manager and sanity_manager.has_method("apply_sanity_loss"):
		var sanity_loss = _get_sanity_loss_for_note()
		sanity_manager.apply_sanity_loss("research_note", sanity_loss, global_position)
	
	# Show note content
	_display_note_content()

func _get_sanity_loss_for_note() -> int:
	return 1

func _display_note_content() -> void:
	"""Display the note content to player"""
	var note_text = _get_note_text()
	
	if _message_bus and not note_text.is_empty():
		_message_bus.emit_event("note_shown", [item_id, note_text])
		_message_bus.emit_event("notification_requested", ["Found research note...", 2.0, 1])

func _get_note_text() -> String:
	"""Get the text content of this note"""
	# This would normally come from events.json via EventManager
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("get_event_data"):
		var notes_data = event_manager.get_event_data("dr_a_logs")
		for note in notes_data:
			if note.get("id", "") == item_id:
				return note.get("text", "")
	push_error("Note not found")
	return ""

func get_pickup_prompt_text() -> String:
	"""Custom prompt for research notes"""
	return "Press E to read research note"
