extends Control

signal closed

@onready var item_grid = $MainPanel/VBoxContainer/ScrollContainer/ItemGrid
@onready var main_panel = $MainPanel
@onready var inspect_panel = $InspectPanel
@onready var viewport = $InspectPanel/VBoxContainer/ViewportContainer/Viewport
@onready var item_model_node = $InspectPanel/VBoxContainer/ViewportContainer/Viewport/ItemModel
@onready var camera = $InspectPanel/VBoxContainer/ViewportContainer/Viewport/Camera3D
@onready var item_name_label = $InspectPanel/VBoxContainer/ItemName
@onready var description_label = $InspectPanel/VBoxContainer/Description

var inventory_manager: Node
var selected_item = null
var is_rotating = false
var last_mouse_pos = Vector2.ZERO
var was_mouse_captured: bool = false

func _ready():
	# Set process mode so inventory works when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect to the actual player inventory autoload
	inventory_manager = get_node_or_null("/root/PlayerInventory")
	if inventory_manager:
		_populate_inventory()
	else:
		push_warning("InventoryUI: PlayerInventory autoload not found")

func _populate_inventory():
	if not inventory_manager:
		return
		
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	
	# Add items from inventory
	var items = inventory_manager.get_inventory()
	for item_id in items:
		var item_button = Button.new()
		item_button.text = item_id
		item_button.custom_minimum_size = Vector2(100, 100)
		item_button.pressed.connect(_on_item_selected.bind(item_id))
		item_grid.add_child(item_button)

func show_inventory():
	"""Show inventory and handle mouse state"""
	visible = true
	# Store current mouse state and make visible
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_inventory()

func hide_inventory():
	"""Hide inventory and restore mouse state"""
	visible = false
	# Restore mouse state
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("closed")

func _on_item_selected(item_id: String):
	selected_item = item_id
	main_panel.visible = false
	inspect_panel.visible = true
	_load_item_model(item_id)

func _load_item_model(item_id: String):
	# Clear existing model
	for child in item_model_node.get_children():
		child.queue_free()
	
	# Load item model (you'll need to implement item model loading)
	var model_path = "res://models/items/" + item_id + ".tscn"
	if ResourceLoader.exists(model_path):
		var model_scene = load(model_path)
		var model = model_scene.instantiate()
		item_model_node.add_child(model)
	
	item_name_label.text = item_id
	description_label.text = _get_item_description(item_id)

func _get_item_description(item_id: String) -> String:
	# Implement item descriptions
	return "This is a " + item_id

func _input(event):
	# Only handle input if inventory is visible
	if not visible:
		return
	
	# Handle ESC to close inventory (with higher priority than pause)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # Prevent pause menu from opening
		hide_inventory()
		return
	
	# Handle rotation in inspect panel
	if inspect_panel.visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_rotating = event.pressed
				last_mouse_pos = event.position
		elif event is InputEventMouseMotion and is_rotating:
			var delta = event.position - last_mouse_pos
			item_model_node.rotation.y += delta.x * 0.01
			item_model_node.rotation.x += delta.y * 0.01
			last_mouse_pos = event.position

func _on_close_pressed():
	hide_inventory()

func _on_back_pressed():
	inspect_panel.visible = false
	main_panel.visible = true
	_populate_inventory()
