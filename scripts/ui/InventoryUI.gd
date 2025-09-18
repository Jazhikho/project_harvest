extends Control
## Inventory UI - Handles display and interaction with player inventory

signal item_selected(item_id: String)
signal item_selected_for_placement(item_id: String)
signal closed()  # ADDED - Signal emitted when inventory is closed

@onready var main_panel: Panel = $MainPanel
@onready var inspect_panel: Panel = $InspectPanel
@onready var item_grid: GridContainer = $MainPanel/VBoxContainer/ScrollContainer/ItemGrid
@onready var item_name_label: Label = $InspectPanel/VBoxContainer/ItemName
@onready var description_text: RichTextLabel = $InspectPanel/VBoxContainer/Description
@onready var item_model_container: Node3D = $InspectPanel/VBoxContainer/ViewportContainer/Viewport/ItemModel

var _message_bus: Node
var _item_manager: Node
var current_inventory: Array[String] = []
var item_buttons: Array[Button] = []
var is_selection_mode: bool = false  # For puzzle piece placement

func _ready() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_item_manager = get_node_or_null("/root/ItemManager")
	
	visible = false
	main_panel.visible = true
	inspect_panel.visible = false
	
	# Connect input
	set_process_input(true)

func _input(event: InputEvent) -> void:
	"""Handle input when UI is visible"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		if inspect_panel.visible:
			_on_back_pressed()
		else:
			_on_close_pressed()

func show_inventory(inventory: Array[String] = [], selection_mode: bool = false) -> void:
	"""
	Show inventory UI
	
	@param inventory: Array of item IDs to display (gets from PlayerInventory if empty)
	@param selection_mode: True if selecting items for puzzle placement
	"""
	# If no inventory passed, get it from PlayerInventory
	if inventory.is_empty():
		var player_inventory = get_node_or_null("/root/PlayerInventory")
		if player_inventory and player_inventory.has_method("get_inventory"):
			current_inventory = player_inventory.get_inventory()
		else:
			current_inventory = []
	else:
		current_inventory = inventory.duplicate()
	
	is_selection_mode = selection_mode
	
	_populate_item_grid()
	
	visible = true
	main_panel.visible = true
	inspect_panel.visible = false
	
	# Pause game
	#get_tree().paused = true

func hide_inventory() -> void:
	"""Hide inventory UI"""
	visible = false
	inspect_panel.visible = false
	main_panel.visible = false
	
	# Unpause game
	#get_tree().paused = false
	
	# ADDED - Emit closed signal
	closed.emit()

func show_inspection(item_id: String) -> void:
	"""
	Show item inspection view
	
	@param item_id: Item to inspect
	"""
	if not _item_manager:
		return
	
	var item_info = _item_manager.get_item_info(item_id)
	if item_info.is_empty():
		return
	
	# Update inspection panel
	item_name_label.text = item_info.get("name", item_id)
	description_text.text = item_info.get("description", "No description available.")
	
	# Load 3D model if available
	_load_item_model(item_id, item_info)
	
	# Show inspection panel
	main_panel.visible = false
	inspect_panel.visible = true

func _populate_item_grid() -> void:
	"""Populate the item grid with current inventory"""
	# Clear existing buttons
	for button in item_buttons:
		button.queue_free()
	item_buttons.clear()
	
	# Create new buttons
	for item_id in current_inventory:
		var button = _create_item_button(item_id)
		if button:
			item_grid.add_child(button)
			item_buttons.append(button)

func _create_item_button(item_id: String) -> Button:
	"""
	Create a button for an inventory item - creates buttons programmatically
	
	@param item_id: Item identifier
	@return: Configured button or null
	"""
	if not _item_manager:
		return null
	
	var item_info = _item_manager.get_item_info(item_id)
	if item_info.is_empty():
		return null
	
	var button = Button.new()
	button.text = item_info.get("name", item_id)
	button.custom_minimum_size = Vector2(120, 80)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Connect button signal
	button.pressed.connect(_on_item_button_pressed.bind(item_id))
	
	# Style based on item category
	if _item_manager.is_puzzle_piece(item_id):
		button.modulate = Color.CYAN
	elif item_id.begins_with("note_"):
		button.modulate = Color.LIGHT_YELLOW
	
	return button

func _load_item_model(item_id: String, item_info: Dictionary) -> void:
	"""
	Load 3D model for item inspection
	
	@param item_id: Item identifier
	@param item_info: Item definition data
	"""
	# Clear existing model
	for child in item_model_container.get_children():
		child.queue_free()
	
	# For now, just show a placeholder cube
	# In the future, load actual 3D models based on item_info
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 1, 1)
	mesh_instance.mesh = box_mesh
	
	# Create material based on item type
	var item_material = StandardMaterial3D.new()
	if _item_manager.is_puzzle_piece(item_id):
		item_material.albedo_color = Color.CYAN
	elif item_id.begins_with("note_"):
		item_material.albedo_color = Color.LIGHT_YELLOW
	else:
		item_material.albedo_color = Color.WHITE
	
	mesh_instance.material_override = item_material
	item_model_container.add_child(mesh_instance)

func _on_item_button_pressed(item_id: String) -> void:
	"""Handle item button pressed"""
	if is_selection_mode:
		# Emit for puzzle placement
		item_selected_for_placement.emit(item_id)
		hide_inventory()
	else:
		# Show inspection
		item_selected.emit(item_id)
		show_inspection(item_id)

func _on_close_pressed() -> void:
	"""Handle close button pressed"""
	hide_inventory()

func _on_back_pressed() -> void:
	"""Handle back button pressed in inspection view"""
	inspect_panel.visible = false
	main_panel.visible = true
