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
var permanent_items: Array = ["flashlight", "journal"]

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
	
	var displayed_items: int = 0
	
	# First, add permanent items (flashlight, journal)
	for item_id in permanent_items:
		var item_slot: Panel = _create_item_slot(item_id, true) # true = permanent item
		item_grid.add_child(item_slot)
		displayed_items += 1
	
	# Then add regular items from inventory (excluding notes)
	var items: Array = inventory_manager.get_inventory()
	for item_id in items:
		# Skip notes - they're in the journal now
		if item_manager and item_manager.has_method("get_item_info"):
			var item_info: Dictionary = item_manager.get_item_info(item_id)
			if item_info.get("category", "") == "notes":
				continue
		
		# Create item slot
		var item_slot: Panel = _create_item_slot(item_id, false)
		item_grid.add_child(item_slot)
		displayed_items += 1
	
	# Add empty slots to maintain grid structure (optional)
	var min_slots: int = 20 # Minimum number of slots to show
	var empty_slots_needed: int = min_slots - displayed_items
	if empty_slots_needed > 0:
		for i in empty_slots_needed:
			var empty_slot: Panel = _create_empty_slot()
			item_grid.add_child(empty_slot)
	
	# Show message if inventory is completely empty (only permanent items)
	if displayed_items == permanent_items.size():
		# Don't show empty message, they have permanent items
		pass

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
	
	var model_path: String
	if item_id in ["flashlight", "journal"]:
		model_path = "res://scenes/misc/" + item_id + ".tscn"
	elif item_id == "hollow_key":
		model_path = "res://scenes/misc/key.tscn"
	else:
		model_path = "res://scenes/items/" + item_id + ".tscn"
	
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

func _create_item_slot(item_id: String, is_permanent: bool = false) -> Panel:
	"""Create a properly formatted item slot with thumbnail and name"""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(120, 140) # Fixed size for grid consistency
	
	# Add visual indicator for permanent items
	if is_permanent:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.4, 0.5) # Slightly different background
		style.border_color = Color(0.6, 0.6, 0.8, 0.8) # Subtle border
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		slot.add_theme_stylebox_override("panel", style)
	
	# Create vertical container for icon and text
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	slot.add_child(vbox)
	
	# Create button for the item icon
	var icon_button: Button = Button.new()
	icon_button.custom_minimum_size = Vector2(100, 100)
	icon_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_button.expand_icon = true
	icon_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Permanent items have different interaction
	if is_permanent:
		icon_button.pressed.connect(_on_permanent_item_selected.bind(item_id))
	else:
		icon_button.pressed.connect(_on_item_selected.bind(item_id))
	
	# Try to load thumbnail
	var thumbnail_path: String = "res://assets/thumbnails/" + item_id + ".png"
	if ResourceLoader.exists(thumbnail_path):
		var thumbnail: Texture2D = load(thumbnail_path)
		if thumbnail:
			icon_button.icon = thumbnail
			# Make the icon fill the button
			icon_button.add_theme_constant_override("icon_max_width", 96)
	else:
		# Create placeholder if no thumbnail exists
		icon_button.text = "?"
		icon_button.add_theme_font_size_override("font_size", 32)
		push_warning("InventoryUI: Thumbnail not found for " + item_id + " at " + thumbnail_path)
	
	vbox.add_child(icon_button)
	
	# Add item name label
	var name_label: Label = Label.new()
	name_label.custom_minimum_size = Vector2(120, 20)
	name_label.size_flags_horizontal = Control.SIZE_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	
	# Get display name from ItemManager
	var display_name: String = item_id
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	if item_manager and item_manager.has_method("get_item_info"):
		var item_info: Dictionary = item_manager.get_item_info(item_id)
		display_name = item_info.get("name", item_id)
	
	# Truncate name if too long
	if display_name.length() > 15:
		display_name = display_name.substr(0, 13) + "..."
	
	name_label.text = display_name
	name_label.tooltip_text = display_name # Show full name on hover
	vbox.add_child(name_label)
	
	# Add permanent indicator label
	if is_permanent:
		var perm_label: Label = Label.new()
		perm_label.text = "[EQUIPPED]"
		perm_label.add_theme_font_size_override("font_size", 9)
		perm_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		perm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(perm_label)
	else:
		# Add quantity label for regular items if you track quantities (optional)
		if inventory_manager and inventory_manager.has_method("get_item_quantity"):
			var quantity: int = inventory_manager.get_item_quantity(item_id)
			if quantity > 1:
				var qty_label: Label = Label.new()
				qty_label.text = "x" + str(quantity)
				qty_label.add_theme_font_size_override("font_size", 10)
				qty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(qty_label)
	
	return slot

func _create_empty_slot() -> Panel:
	"""Create an empty slot to maintain grid structure"""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(120, 140)
	slot.modulate = Color(0.5, 0.5, 0.5, 0.3) # Make it semi-transparent
	
	return slot

func _on_permanent_item_selected(item_id: String):
	"""Handle selection of permanent items (flashlight, journal)"""
	selected_item = item_id
	main_panel.visible = false
	inspect_panel.visible = true
	_load_item_model(item_id)
