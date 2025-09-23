extends Control
## Inventory UI - Handles display and interaction with player inventory

const ManagerAccess = preload("res://scripts/utils/ManagerAccess.gd")

signal item_selected(item_id: String)
signal item_selected_for_placement(item_id: String)
signal closed() # ADDED - Signal emitted when inventory is closed

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
var is_selection_mode: bool = false # For puzzle piece placement

func _ready() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	# Defer getting item_manager until managers are registered
	call_deferred("_initialize_managers")
	# Ensure UI receives input while the game is paused (Godot 4)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	visible = false
	main_panel.visible = true
	inspect_panel.visible = false
	
	# Connect input
	set_process_input(true)

func _initialize_managers() -> void:
	await get_tree().create_timer(0.1).timeout
	_item_manager = ManagerAccess.get_item_manager()
	if not _item_manager:
		push_warning("InventoryUI: ItemManager not found after initialization, will retry...")
		# Retry after a short delay to allow GameController to finish setup
		await get_tree().create_timer(0.1).timeout
		_item_manager = ManagerAccess.get_item_manager()
		if not _item_manager:
			push_error("InventoryUI: ItemManager still not found after retry")

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
	
	# Pause game and release mouse for UI
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_inventory() -> void:
	"""Hide inventory UI"""
	visible = false
	inspect_panel.visible = false
	main_panel.visible = false
	
	# Unpause game and recapture mouse handled by GameController, but ensure here too
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
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
	visible = true
	main_panel.visible = false
	inspect_panel.visible = true
	# Ensure mouse is captured by the UI context (visible for pointer)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
	
	# For notes: load a note scene visual and set description to note content
	if item_id.begins_with("note_"):
		# Try to load a generic note model/scene
		var note_scene_path = "res://scenes/notes/%s.tscn" % item_id
		if not FileAccess.file_exists(note_scene_path):
			note_scene_path = "res://scenes/notes/note_1.tscn" # fallback visual
		if FileAccess.file_exists(note_scene_path):
			var note_scene = load(note_scene_path) as PackedScene
			if note_scene:
				var note_instance = note_scene.instantiate()
				note_instance.scale = Vector3(1.2, 1.2, 1.2)
				item_model_container.add_child(note_instance)
				var t = create_tween()
				t.set_loops()
				t.tween_property(note_instance, "rotation_degrees:y", 360, 8.0)
			# Set description text to note content if available
			var note_text = item_info.get("description", "")
			if description_text:
				description_text.text = note_text
			return
	
	# Special case for flag - use flag scene from misc
	if item_id == "flag":
		_load_flag_model()
		return
	
	# Try to load the actual item scene
	var item_scene_path = "res://scenes/items/%s.tscn" % item_id
	if FileAccess.file_exists(item_scene_path):
		var item_scene = load(item_scene_path) as PackedScene
		if item_scene:
			var item_instance = item_scene.instantiate()
			
			# Extract just the visual mesh from the item
			var mesh_instance = _extract_mesh_from_item(item_instance)
			if mesh_instance:
				# Scale and center it for inspection view
				mesh_instance.scale = Vector3(1.2, 1.2, 1.2)
				mesh_instance.position = Vector3.ZERO
				item_model_container.add_child(mesh_instance)
				
				# Add rotation animation for inspection (multi-axis)
				var tween = create_tween()
				tween.set_loops()
				tween.tween_property(mesh_instance, "rotation_degrees:y", 360, 6.0)
				# Chain a secondary, slow X rotation
				var tween2 = create_tween()
				tween2.set_loops()
				tween2.tween_property(mesh_instance, "rotation_degrees:x", 360, 18.0)
			
			# Clean up the temporary item instance
			item_instance.queue_free()
			return
	
	# Fallback to placeholder if no scene found
	_create_placeholder_model(item_id)

func _load_flag_model() -> void:
	"""Load flag model from misc folder"""
	var flag_scene_path = "res://scenes/misc/flag.tscn"
	if FileAccess.file_exists(flag_scene_path):
		var flag_scene = load(flag_scene_path) as PackedScene
		if flag_scene:
			var flag_instance = flag_scene.instantiate()
			flag_instance.scale = Vector3(0.6, 0.6, 0.6)
			item_model_container.add_child(flag_instance)
			
			# Add rotation animation
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(flag_instance, "rotation_degrees:y", 360, 4.0)
			return
	
	# Fallback to placeholder
	_create_placeholder_model("flag")

func _extract_mesh_from_item(item_node: Node) -> MeshInstance3D:
	"""Extract the main mesh from an item node"""
	# Look for MeshInstance3D in the item
	for child in item_node.get_children():
		if child is MeshInstance3D:
			var mesh_copy = MeshInstance3D.new()
			mesh_copy.mesh = child.mesh
			mesh_copy.material_override = child.material_override
			mesh_copy.material_overlay = child.material_overlay
			# Copy surface materials
			for i in range(child.get_surface_override_material_count()):
				mesh_copy.set_surface_override_material(i, child.get_surface_override_material(i))
			return mesh_copy
	
	return null

func _create_placeholder_model(item_id: String) -> void:
	"""Create a placeholder model for items without scenes"""
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.2, 1.2, 1.2)
	mesh_instance.mesh = box_mesh
	
	# Create material based on item type
	var item_material = StandardMaterial3D.new()
	if _item_manager and _item_manager.has_method("is_puzzle_piece") and _item_manager.is_puzzle_piece(item_id):
		item_material.albedo_color = Color.CYAN
	elif item_id.begins_with("note_"):
		item_material.albedo_color = Color.LIGHT_YELLOW
	else:
		item_material.albedo_color = Color.WHITE
	
	mesh_instance.material_override = item_material
	item_model_container.add_child(mesh_instance)
	
	# Add rotation animation (multi-axis)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh_instance, "rotation_degrees:y", 360, 6.0)
	var tween2 = create_tween()
	tween2.set_loops()
	tween2.tween_property(mesh_instance, "rotation_degrees:x", 360, 18.0)

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
