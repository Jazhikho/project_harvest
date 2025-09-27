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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

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
	
func show_watching_stones_puzzle(puzzle: Node3D, interaction_type: String) -> void:
	"""Show UI for Watching Stones puzzle"""
	current_puzzle = puzzle
	current_interaction_type = interaction_type  # Add this as a class variable
	
	get_tree().paused = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	title_label.text = "Watching Stones - %s" % interaction_type.capitalize()
	description_label.text = "Place an offering on the %s." % interaction_type
	
	_populate_item_list()
	visible = true

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

func _populate_item_list() -> void:
	"""Populate the list of available puzzle pieces"""
	# Clear existing items
	for child in item_list.get_children():
		child.queue_free()
	
	if not current_puzzle or not current_puzzle.has_method("get_available_puzzle_pieces"):
		return
	
	var puzzle_pieces: Array = current_puzzle.get_available_puzzle_pieces()
	
	print("PuzzleUI: Found ", puzzle_pieces.size(), " puzzle pieces")
	
	if puzzle_pieces.is_empty():
		var no_items_label: Label = Label.new()
		no_items_label.text = "You don't have any items to drop in."
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list.add_child(no_items_label)
		return
	
	# Create button for each puzzle piece
	for piece in puzzle_pieces:
		var item_id: String = piece.get("id", "")
		var item_name: String = piece.get("name", item_id)
		
		var item_button: Button = Button.new()
		item_button.text = item_name
		item_button.custom_minimum_size = Vector2(0, 40)
		
		# Use callable for connection
		var on_pressed: Callable = func(): _on_item_selected(item_id)
		item_button.pressed.connect(on_pressed)
		
		item_list.add_child(item_button)
		
		print("PuzzleUI: Added button for ", item_id)

func _on_item_selected(item_id: String) -> void:
	"""Handle item selection"""
	if not current_puzzle or not current_puzzle.has_method("try_place_item"):
		return
	
	# Try to place the item
	var result: Dictionary = current_puzzle.try_place_item(item_id)
	
	# Show result message
	_show_result_message(result.get("message", ""))
	
	if result.get("success", false):
		# Refresh the item list
		_populate_item_list()
		
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

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_ui()
