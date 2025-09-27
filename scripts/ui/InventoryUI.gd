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

func _ready() -> void:
	# Set process mode so inventory works when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Initially hide inspect panel
	if inspect_panel:
		inspect_panel.visible = false
	
	# Connect to the actual player inventory autoload
	inventory_manager = get_node_or_null("/root/PlayerInventory")
	if inventory_manager:
		_populate_inventory()
	else:
		push_warning("InventoryUI: PlayerInventory autoload not found")
	
	# Setup viewport for 3D item display
	_setup_viewport()

func _setup_viewport() -> void:
	"""Setup the 3D viewport for item inspection"""
	if not viewport:
		return
	
	# Disable transparent background to show our environment
	viewport.transparent_bg = false
	
	# Create a proper environment with lighting
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.2, 0.2) # Dark gray background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	environment.ambient_light_energy = 0.5
	
	# Create or get world environment
	if not viewport.world_3d:
		viewport.world_3d = World3D.new()
	
	# Apply environment
	var env_node: Node = viewport.get_node_or_null("WorldEnvironment")
	if not env_node:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		viewport.add_child(env_node)
	
	if env_node is WorldEnvironment:
		env_node.environment = environment
	
	# Setup camera if not already positioned
	if camera:
		camera.position = Vector3(0, 0.5, 2.5)
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		camera.fov = 45
	
	# Enhance the directional light that's already in the scene
	var light: DirectionalLight3D = viewport.get_node_or_null("DirectionalLight3D")
	if light:
		light.light_energy = 1.2
		light.shadow_enabled = true

func _populate_inventory() -> void:
	if not inventory_manager:
		return
		
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	
	# Get ItemManager for item info
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	
	# Add items from inventory
	var items: Array = inventory_manager.get_inventory()
	for item_id in items:
		var item_button: Button = Button.new()
		
		# Get display name from ItemManager if available
		var display_name: String = item_id
		if item_manager and item_manager.has_method("get_item_info"):
			var item_info: Dictionary = item_manager.get_item_info(item_id)
			display_name = item_info.get("name", item_id)
		
		item_button.text = display_name
		item_button.custom_minimum_size = Vector2(100, 100)
		item_button.pressed.connect(_on_item_selected.bind(item_id))
		item_grid.add_child(item_button)
	
	# Show message if inventory is empty
	if items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Inventory is empty"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_grid.add_child(empty_label)

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

func _load_item_model(item_id: String) -> void:
	# Clear existing model
	for child in item_model_node.get_children():
		child.queue_free()
	
	# Try to load from items folder
	var model_path: String = "res://scenes/items/" + item_id + ".tscn"
	
	# For notes, try the notes folder
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	if item_manager and item_manager.has_method("get_item_info"):
		var item_info: Dictionary = item_manager.get_item_info(item_id)
		if item_info.get("category", "") == "notes":
			# For notes, use a random note scene
			var note_number: int = randi() % 4 + 1
			model_path = "res://scenes/notes/note_%d.tscn" % note_number
	
	print("InventoryUI: Attempting to load model from: ", model_path)
	
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path) as PackedScene
		if model_scene:
			var model: Node3D = model_scene.instantiate()
			
			# Remove any scripts that might interfere with display
			if model.get_script():
				model.set_script(null)
			
			# Remove any Area3D children (collision detection not needed here)
			for child in model.get_children():
				if child is Area3D or child is RigidBody3D or child is StaticBody3D:
					child.queue_free()
			
			item_model_node.add_child(model)
			
			# Center and scale the model appropriately
			model.position = Vector3.ZERO
			
			# Auto-scale based on the model's AABB
			_auto_scale_model(model)
			
			# Start a slow rotation for visual effect
			_start_model_rotation(model)
			
			print("InventoryUI: Successfully loaded model for ", item_id)
		else:
			push_warning("InventoryUI: Failed to instantiate model for ", item_id)
			_create_placeholder_model()
	else:
		push_warning("InventoryUI: Model not found at ", model_path)
		_create_placeholder_model()
	
	# Set item name and description
	item_name_label.text = _get_item_display_name(item_id)
	description_label.text = _get_item_description(item_id)

func _auto_scale_model(model: Node3D) -> void:
	"""Auto-scale model to fit nicely in viewport"""
	# Wait a frame for the model to initialize
	await get_tree().process_frame
	
	# Get the AABB of the model
	var aabb: AABB = _get_model_aabb(model)
	if aabb.size == Vector3.ZERO:
		return
	
	# Calculate scale to fit model in view
	var max_dimension: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if max_dimension > 0:
		var target_size: float = 1.0 # Target size in viewport
		var scale_factor: float = target_size / max_dimension
		model.scale = Vector3.ONE * scale_factor
		
		# Center the model
		var center_offset: Vector3 = aabb.get_center() * scale_factor
		model.position = - center_offset

func _get_model_aabb(node: Node3D, aabb: AABB = AABB()) -> AABB:
	"""Recursively get the combined AABB of all MeshInstance3D children"""
	if node is MeshInstance3D and node.mesh:
		var mesh_aabb: AABB = node.mesh.get_aabb()
		mesh_aabb = node.transform * mesh_aabb
		if aabb.size == Vector3.ZERO:
			aabb = mesh_aabb
		else:
			aabb = aabb.merge(mesh_aabb)
	
	for child in node.get_children():
		if child is Node3D:
			aabb = _get_model_aabb(child, aabb)
	
	return aabb

func _start_model_rotation(model: Node3D) -> void:
	"""Start a slow rotation animation for the model"""
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(model, "rotation:y", TAU, 8.0)

func _get_item_description(item_id: String) -> String:
	"""Get item description from ItemManager"""
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	if not item_manager or not item_manager.has_method("get_item_info"):
		return "No description available."
	
	var item_info: Dictionary = item_manager.get_item_info(item_id)
	var description: String = item_info.get("description", "No description available.")
	
	return description

func _get_item_display_name(item_id: String) -> String:
	"""Get item display name from ItemManager"""
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	if not item_manager or not item_manager.has_method("get_item_info"):
		return item_id
	
	var item_info: Dictionary = item_manager.get_item_info(item_id)
	return item_info.get("name", item_id)

func _create_placeholder_model() -> void:
	"""Create a placeholder model when actual model cannot be loaded"""
	var placeholder: MeshInstance3D = MeshInstance3D.new()
	placeholder.mesh = BoxMesh.new()
	placeholder.mesh.size = Vector3(0.5, 0.5, 0.5)
	
	var item_material: StandardMaterial3D = StandardMaterial3D.new()
	item_material.albedo_color = Color(0.7, 0.7, 0.7)
	placeholder.set_surface_override_material(0, item_material)
	
	item_model_node.add_child(placeholder)
	print("InventoryUI: Created placeholder model")

func _input(event: InputEvent) -> void:
	# Only handle input if inventory is visible
	if not visible:
		return
	
	# Handle ESC to close inventory (with higher priority than pause)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled() # Prevent pause menu from opening
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
