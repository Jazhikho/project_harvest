extends Control
## PuzzleUI - Handles UI for puzzle interactions like the well

class_name PuzzleUI

signal item_selected(item_id: String)
signal puzzle_closed

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/Title
@onready var description_label: Label = $Panel/VBoxContainer/Description
@onready var item_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ItemList
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var current_puzzle: Node3D = null
var was_mouse_captured: bool = false
var current_interaction_type: String = ""
var _item_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as Node.ProcessMode
	visible = false
	
	if close_button:
		close_button.focus_mode = Control.FOCUS_ALL as Control.FocusMode

func show_well_puzzle(well_puzzle: Node3D) -> void:
	"""Show UI for well puzzle interaction"""
	current_puzzle = well_puzzle
	
	# Pause the game
	get_tree().paused = true
	
	# Store mouse state and make visible
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Set UI text
	title_label.text = "Ancient Well"
	description_label.text = "Maybe I should drop something inside?"
	
	# Populate item list
	_populate_item_list()
	
	visible = true
	call_deferred("_focus_default_control")
	
func show_watching_stones_puzzle(puzzle: Node3D, interaction_type: String) -> void:
	"""Show UI for Watching Stones puzzle"""
	current_puzzle = puzzle
	current_interaction_type = interaction_type # Add this as a class variable
	
	get_tree().paused = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	title_label.text = "Watching Stones - %s" % interaction_type.capitalize()
	description_label.text = "Place an offering on the %s." % interaction_type
	
	_populate_item_list()
	visible = true
	call_deferred("_focus_default_control")

func show_mirror_puzzle(puzzle: Node3D) -> void:
	"""Show UI for Crows Parliament mirror puzzle"""
	current_puzzle = puzzle
	
	get_tree().paused = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	title_label.text = "Broken Mirror"
	description_label.text = "The mirror is shattered. Perhaps the right pieces can restore it."
	
	_populate_item_list()
	visible = true
	call_deferred("_focus_default_control")

func _populate_item_list() -> void:
	"""Populate the list of available puzzle pieces"""
	# Clear existing items
	_item_buttons.clear()
	for child in item_list.get_children():
		child.queue_free()
	
	if not current_puzzle or not current_puzzle.has_method("get_available_puzzle_pieces"):
		return
	
	var puzzle_pieces: Array = current_puzzle.get_available_puzzle_pieces()
	
	if puzzle_pieces.is_empty():
		var no_items_label: Label = Label.new()
		no_items_label.text = "You don't have any items to drop in."
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
		item_list.add_child(no_items_label)
		_configure_close_button_focus()
		return
	
	# Create button for each puzzle piece
	for index in range(puzzle_pieces.size()):
		var piece: Dictionary = puzzle_pieces[index]
		var item_id: String = piece.get("id", "")
		var item_name: String = piece.get("name", item_id)
		
		var item_button: Button = Button.new()
		item_button.text = item_name
		item_button.custom_minimum_size = Vector2(0, 40)
		item_button.focus_mode = Control.FOCUS_ALL as Control.FocusMode
		
		# Use callable for connection
		var on_pressed: Callable = func(): _on_item_selected(item_id)
		item_button.pressed.connect(on_pressed)
		
		item_list.add_child(item_button)
		_item_buttons.append(item_button)

		if index > 0:
			var previous_button: Button = _item_buttons[index - 1]
			previous_button.focus_neighbor_bottom = previous_button.get_path_to(item_button)
			item_button.focus_neighbor_top = item_button.get_path_to(previous_button)

	_configure_close_button_focus()

func _configure_close_button_focus() -> void:
	if not close_button:
		return
	if _item_buttons.is_empty():
		close_button.focus_neighbor_top = NodePath()
		return
	var last_button: Button = _item_buttons[_item_buttons.size() - 1]
	last_button.focus_neighbor_bottom = last_button.get_path_to(close_button)
	close_button.focus_neighbor_top = close_button.get_path_to(last_button)

func _focus_default_control() -> void:
	if _item_buttons.is_empty():
		if close_button:
			close_button.grab_focus()
		return
	_item_buttons[0].grab_focus()

func _on_item_selected(item_id: String) -> void:
	"""Handle item selection"""
	if not current_puzzle or not current_puzzle.has_method("try_place_item"):
		return
	
	# Try to place the item
	var result: Dictionary
	if current_interaction_type.is_empty():
		result = current_puzzle.try_place_item(item_id)
	else:
		result = current_puzzle.try_place_item(item_id, current_interaction_type)
	
	# Show result message
	_show_result_message(result.get("message", ""))
	
	if result.get("success", false):
		# Refresh the item list
		_populate_item_list()
		call_deferred("_focus_default_control")
		
		# If puzzle completed, close UI
		if result.get("completed", false):
			await get_tree().create_timer(2.0).timeout
			_close_ui()

func _show_result_message(message: String) -> void:
	"""Show feedback message to player"""
	description_label.text = message

func _on_close_pressed() -> void:
	"""Handle close button press"""
	_close_ui()

func _close_ui() -> void:
	"""Close the puzzle UI"""
	visible = false
	
	# Unpause the game
	get_tree().paused = false
	
	# Restore mouse state
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	emit_signal("puzzle_closed")
	current_puzzle = null
	current_interaction_type = ""
	_item_buttons.clear()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_ui()
