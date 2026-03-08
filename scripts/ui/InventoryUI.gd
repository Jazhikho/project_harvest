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
@onready var close_button: Button = $MainPanel/VBoxContainer/CloseButton
@onready var back_button: Button = $InspectPanel/VBoxContainer/HBoxContainer/BackButton

var inventory_manager: Node
var selected_item: String = ""
var is_rotating: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var was_mouse_captured: bool = false
var permanent_items: Array = ["flashlight", "journal"]
var _scene_cache: Dictionary = {}
var _thumbnail_cache: Dictionary = {}
var _item_buttons: Array[Button] = []
var _item_buttons_by_id: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as Node.ProcessMode
	inspect_panel.visible = false
	call_deferred("_setup_responsive_sizing")
	inventory_manager = get_node_or_null("/root/PlayerInventory")
	if inventory_manager:
		_populate_inventory()
	_setup_viewport()
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	close_button.focus_mode = Control.FOCUS_ALL as Control.FocusMode
	back_button.focus_mode = Control.FOCUS_ALL as Control.FocusMode

func _setup_responsive_sizing() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = viewport_size.x * 0.8
	var panel_height: float = viewport_size.y * 0.7
	main_panel.offset_left = -panel_width / 2.0
	main_panel.offset_top = -panel_height / 2.0
	main_panel.offset_right = panel_width / 2.0
	main_panel.offset_bottom = panel_height / 2.0
	item_grid.columns = 5 if panel_width < 900 else 7 if panel_width > 1200 else 6

func _setup_viewport() -> void:
	viewport.transparent_bg = false
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.2, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	environment.ambient_light_energy = 0.5
	if not viewport.world_3d:
		viewport.world_3d = World3D.new()
	var env_node: Node = viewport.get_node_or_null("WorldEnvironment")
	if not env_node:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		viewport.add_child(env_node)
	(env_node as WorldEnvironment).environment = environment
	camera.position = Vector3(0, 0.5, 2.5)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.fov = 45
	var light: DirectionalLight3D = viewport.get_node_or_null("DirectionalLight3D")
	if light:
		light.light_energy = 1.2
		light.shadow_enabled = true

func _populate_inventory() -> void:
	if not inventory_manager:
		return
	_item_buttons.clear()
	_item_buttons_by_id.clear()
	for child in item_grid.get_children():
		child.queue_free()
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	for item_id in permanent_items:
		item_grid.add_child(_create_item_slot(item_id, true))
	for item_id in inventory_manager.get_inventory():
		if item_manager and item_manager.has_method("get_item_info"):
			var item_info: Dictionary = item_manager.get_item_info(item_id)
			if item_info.get("category", "") == "notes":
				continue
		item_grid.add_child(_create_item_slot(item_id, false))
	call_deferred("_configure_inventory_focus")

func show_inventory() -> void:
	visible = true
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_inventory()
	call_deferred("_focus_inventory_default")

func show_inventory_with_item(item_id: String) -> void:
	show_inventory()
	await get_tree().process_frame
	_on_item_selected(item_id)

func hide_inventory() -> void:
	_stop_model_rotation()
	visible = false
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("closed")

func _focus_inventory_default() -> void:
	if not selected_item.is_empty() and _focus_inventory_item(selected_item):
		return
	if not _item_buttons.is_empty():
		_item_buttons[0].grab_focus()
		return
	close_button.grab_focus()

func _focus_inventory_item(item_id: String) -> bool:
	if not _item_buttons_by_id.has(item_id):
		return false
	var button: Button = _item_buttons_by_id[item_id]
	if button and is_instance_valid(button):
		button.grab_focus()
		return true
	return false

func _configure_inventory_focus() -> void:
	if _item_buttons.is_empty():
		close_button.focus_neighbor_top = NodePath()
		close_button.focus_neighbor_bottom = NodePath()
		return
	var columns: int = max(1, item_grid.columns)
	for index in range(_item_buttons.size()):
		var button: Button = _item_buttons[index]
		var left_index: int = index - 1
		var right_index: int = index + 1
		var up_index: int = index - columns
		var down_index: int = index + columns
		button.focus_neighbor_left = _get_focus_target_path(left_index)
		button.focus_neighbor_right = _get_focus_target_path(right_index)
		button.focus_neighbor_top = _get_focus_target_path(up_index)
		button.focus_neighbor_bottom = close_button.get_path() if down_index >= _item_buttons.size() else _get_focus_target_path(down_index)
	close_button.focus_neighbor_top = _get_focus_target_path(max(0, _item_buttons.size() - 1))
	close_button.focus_neighbor_bottom = _get_focus_target_path(0)

func _get_focus_target_path(index: int) -> NodePath:
	if index < 0 or index >= _item_buttons.size():
		return NodePath()
	return _item_buttons[index].get_path()

func _on_item_selected(item_id: String) -> void:
	selected_item = item_id
	main_panel.visible = false
	inspect_panel.visible = true
	_load_item_model(item_id)
	back_button.grab_focus()

func _load_item_model(item_id: String) -> void:
	for child in item_model_node.get_children():
		child.queue_free()
	var model_path: String = "res://scenes/items/%s.tscn" % item_id
	if item_id in ["flashlight", "journal"]:
		model_path = "res://scenes/misc/%s.tscn" % item_id
	elif item_id == "hollow_key":
		model_path = "res://scenes/misc/key.tscn"
	var model_scene: PackedScene = _get_cached_scene(model_path)
	if model_scene:
		var model: Node3D = model_scene.instantiate()
		if model.get_script():
			model.set_script(null)
		item_model_node.add_child(model)
		_auto_scale_model(model)
		_start_model_rotation(model)
	else:
		_create_placeholder_model()
	item_name_label.text = _get_item_display_name(item_id)
	description_label.text = _get_item_description(item_id)

func _get_cached_scene(model_path: String) -> PackedScene:
	if _scene_cache.has(model_path):
		return _scene_cache[model_path]
	if not ResourceLoader.exists(model_path):
		return null
	var scene: PackedScene = load(model_path) as PackedScene
	if scene:
		_scene_cache[model_path] = scene
	return scene

func _get_cached_thumbnail(path: String) -> Texture2D:
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture:
		_thumbnail_cache[path] = texture
	return texture

func _auto_scale_model(model: Node3D) -> void:
	await get_tree().process_frame
	var aabb: AABB = _get_model_aabb(model)
	if aabb.size == Vector3.ZERO:
		return
	var max_dimension: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if max_dimension > 0.0:
		var scale_factor: float = 1.0 / max_dimension
		model.scale = Vector3.ONE * scale_factor
		model.position = -(aabb.get_center() * scale_factor)

func _get_model_aabb(node: Node3D, aabb: AABB = AABB()) -> AABB:
	if node is MeshInstance3D and node.mesh:
		var mesh_aabb: AABB = node.transform * node.mesh.get_aabb()
		aabb = mesh_aabb if aabb.size == Vector3.ZERO else aabb.merge(mesh_aabb)
	for child in node.get_children():
		if child is Node3D:
			aabb = _get_model_aabb(child, aabb)
	return aabb

func _start_model_rotation(model: Node3D) -> void:
	_stop_model_rotation()
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(model, "rotation:y", TAU, 8.0)
	set_meta("rotation_tween", tween)

func _stop_model_rotation() -> void:
	if has_meta("rotation_tween"):
		var tween = get_meta("rotation_tween")
		if tween and is_instance_valid(tween):
			tween.kill()
		remove_meta("rotation_tween")

func _get_item_description(item_id: String) -> String:
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	return item_manager.get_item_info(item_id).get("description", "No description available.") if item_manager and item_manager.has_method("get_item_info") else "No description available."

func _get_item_display_name(item_id: String) -> String:
	var item_manager: Node = get_node_or_null("/root/ItemManager")
	return item_manager.get_item_info(item_id).get("name", item_id) if item_manager and item_manager.has_method("get_item_info") else item_id

func _create_placeholder_model() -> void:
	var placeholder: MeshInstance3D = MeshInstance3D.new()
	placeholder.mesh = BoxMesh.new()
	item_model_node.add_child(placeholder)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if inspect_panel.visible:
			_on_back_pressed()
		else:
			hide_inventory()
		return
	if inspect_panel.visible and event is InputEventMouseMotion and is_rotating:
		var delta = event.position - last_mouse_pos
		item_model_node.rotation.y += delta.x * 0.01
		item_model_node.rotation.x += delta.y * 0.01
		last_mouse_pos = event.position
	elif inspect_panel.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_rotating = event.pressed
		last_mouse_pos = event.position

func _on_close_pressed() -> void:
	hide_inventory()

func _on_back_pressed() -> void:
	_stop_model_rotation()
	inspect_panel.visible = false
	main_panel.visible = true
	_populate_inventory()
	call_deferred("_focus_inventory_default")

func _create_item_slot(item_id: String, is_permanent: bool = false) -> Panel:
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(120, 140)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(vbox)
	var icon_button: Button = Button.new()
	icon_button.custom_minimum_size = Vector2(96, 96)
	icon_button.focus_mode = Control.FOCUS_ALL as Control.FocusMode
	if is_permanent:
		icon_button.pressed.connect(_on_permanent_item_selected.bind(item_id))
	else:
		icon_button.pressed.connect(_on_item_selected.bind(item_id))
	var thumb_path: String = "res://assets/thumbnails/%s.png" % item_id
	if item_id == "hollow_key":
		thumb_path = "res://assets/thumbnails/key.png"
	var thumbnail: Texture2D = _get_cached_thumbnail(thumb_path)
	if thumbnail:
		icon_button.icon = thumbnail
	else:
		icon_button.text = "?"
	vbox.add_child(icon_button)
	var name_label: Label = Label.new()
	name_label.text = _get_item_display_name(item_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	_item_buttons.append(icon_button)
	_item_buttons_by_id[item_id] = icon_button
	return slot

func _on_permanent_item_selected(item_id: String) -> void:
	_on_item_selected(item_id)
