extends Node
## Manages spawning of items, entities, and environmental objects
## Coordinates with ItemManager for item spawning decisions

var _message_bus: Node
var _item_manager: Node
var _state_manager: Node

var _spawn_history := {}
var _entity_spawners := {}

const ITEM_SPAWN_CHANCE := 0.1
const MAX_ITEMS_PER_TILE := 2

func _ready() -> void:
	name = "SpawnManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to other systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_item_manager = get_node_or_null("/root/ItemManager")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _item_manager or not _state_manager:
		push_error("SpawnManager: Required core systems not found")
		return
	
	_connect_to_events()
	_register_entity_spawners()

func _register_entity_spawners() -> void:
	"""Register entity spawn functions"""
	_entity_spawners["backpack"] = _spawn_backpack
	_entity_spawners["effigy"] = _spawn_effigy
	_entity_spawners["echo"] = _spawn_echo

func process_tile_spawning(tile_node: Node3D, tile_position: Vector2i) -> Dictionary:
	"""
	Process spawning for a newly generated tile
	
	@param tile_node: The tile node being populated
	@param tile_position: Grid position of the tile
	@return: Dictionary of spawned entities {entity_type: [positions]}
	"""
	var spawn_results := {}
	var spawn_points := _get_spawn_points(tile_node)
	
	if spawn_points.is_empty():
		return spawn_results
	
	var context := {
		"tile_position": tile_position,
		"tile_node": tile_node,
		"spawn_points": spawn_points,
		"is_permanent": _is_permanent_tile(tile_node)
	}
	
	var death_data: Dictionary = _state_manager.get_unused_death_at_position(tile_position)
	if not death_data.is_empty():
		spawn_results["backpack"] = _spawn_backpack_at_death(tile_node, death_data, spawn_points)
		return spawn_results
	
	spawn_results["items"] = _spawn_items(tile_node, context, spawn_points)
	
	return spawn_results

func _get_spawn_points(tile_node: Node3D) -> Array[Vector3]:
	"""
	Get spawn points from tile
	
	@param tile_node: Tile to extract spawn points from
	@return: Array of world positions for spawning
	"""
	var points: Array[Vector3] = []
	var spawn_parent := tile_node.get_node_or_null("Maze/SpawnPoints")
	
	if not spawn_parent:
		return points
	
	for child in spawn_parent.get_children():
		if child is Marker3D:
			points.append(child.global_position)
	
	return points

func _is_permanent_tile(tile_node: Node3D) -> bool:
	"""
	Check if tile is permanent
	
	@param tile_node: Tile to check
	@return: True if tile is permanent
	"""
	return tile_node.has_method("is_tile_permanent") and tile_node.is_tile_permanent()

func _spawn_items(tile_node: Node3D, context: Dictionary, spawn_points: Array[Vector3]) -> Array:
	"""
	Spawn regular items on tile
	
	@param tile_node: Tile node to spawn items on
	@param context: Spawning context
	@param spawn_points: Available spawn positions
	@return: Array of spawned item IDs
	"""
	var spawned_items := []
	var shuffled_points := spawn_points.duplicate()
	shuffled_points.shuffle()
	
	for spawn_point in shuffled_points:
		if spawned_items.size() >= MAX_ITEMS_PER_TILE:
			break
		
		if randf() < ITEM_SPAWN_CHANCE:
			var spawnable: Array[Dictionary] = _item_manager.get_spawnable_items(context)
			if not spawnable.is_empty():
				var item_id: String = _item_manager.select_random_item(spawnable)
				if _spawn_item_visual(tile_node, item_id, spawn_point):
					spawned_items.append(item_id)
					_message_bus.emit_event("item_spawned", [item_id, spawn_point, context.tile_position, {}])
	
	return spawned_items

func _spawn_item_visual(tile_node: Node3D, item_id: String, position: Vector3) -> bool:
	"""
	Create visual representation of spawned item
	
	@param tile_node: Parent tile node
	@param item_id: Item identifier
	@param position: World position to spawn at
	@return: True if spawned successfully
	"""
	var item_scene_path := "res://scenes/items/%s.tscn" % item_id
	
	if not FileAccess.file_exists(item_scene_path):
		_spawn_placeholder_item(tile_node, item_id, position)
		return true
	
	var item_scene := load(item_scene_path) as PackedScene
	if not item_scene:
		_spawn_placeholder_item(tile_node, item_id, position)
		return true
	
	var item_instance := item_scene.instantiate()
	tile_node.add_child(item_instance)
	item_instance.global_position = position
	item_instance.set_meta("item_id", item_id)
	
	return true

func _spawn_placeholder_item(tile_node: Node3D, item_id: String, position: Vector3) -> void:
	"""
	Spawn placeholder visual for item without scene
	
	@param tile_node: Parent tile node
	@param item_id: Item identifier
	@param position: World position to spawn at
	"""
	var placeholder := MeshInstance3D.new()
	placeholder.name = "Item_" + item_id
	placeholder.mesh = SphereMesh.new()
	placeholder.mesh.radius = 0.3
	
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_item_color(item_id)
	placeholder.set_surface_override_material(0, material)
	
	tile_node.add_child(placeholder)
	placeholder.global_position = position
	placeholder.position.y += 0.5
	placeholder.set_meta("item_id", item_id)
	placeholder.set_meta("is_collectible", true)
	
	_setup_item_collision(placeholder)

func _get_item_color(item_id: String) -> Color:
	"""
	Get debug color for item type
	
	@param item_id: Item identifier
	@return: Color for visual representation
	"""
	var info: Dictionary = _item_manager.get_item_info(item_id)
	var category: String = info.get("category", "")
	
	match category:
		"notes": return Color.YELLOW
		"weird_objects": return Color.PURPLE
		"puzzle_pieces": return Color.CYAN
		_: return Color.WHITE

func _setup_item_collision(item_node: Node3D) -> void:
	"""
	Setup collision detection for item pickup
	
	@param item_node: Item node to setup collision for
	"""
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	
	shape.radius = 0.5
	collision.shape = shape
	
	item_node.add_child(area)
	area.add_child(collision)
	
	area.collision_layer = 0
	area.collision_mask = 1
	
	area.body_entered.connect(_on_item_pickup.bind(item_node))

func _spawn_backpack_at_death(tile_node: Node3D, death_data: Dictionary, spawn_points: Array[Vector3]) -> Array[Vector3]:
	"""
	Spawn backpack with previous run's items
	
	@param tile_node: Tile to spawn on
	@param death_data: Death location data
	@param spawn_points: Available spawn positions
	@return: Array with backpack and effigy positions
	"""
	if spawn_points.is_empty():
		return []
	
	var backpack_pos := spawn_points[0]
	var effigy_pos := backpack_pos + Vector3(1.5, 0, 0)
	
	_spawn_backpack(tile_node, backpack_pos, death_data.get("inventory", []))
	_spawn_effigy(tile_node, effigy_pos)
	
	_state_manager.mark_death_used(death_data.position)
	
	return [backpack_pos, effigy_pos]

func _spawn_backpack(tile_node: Node3D, position: Vector3, inventory: Array) -> void:
	"""
	Spawn backpack entity
	
	@param tile_node: Parent tile
	@param position: Spawn position
	@param inventory: Items in backpack
	"""
	var backpack := MeshInstance3D.new()
	backpack.name = "Backpack"
	backpack.mesh = BoxMesh.new()
	backpack.mesh.size = Vector3(0.5, 0.5, 0.5)
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.3, 0.1)
	backpack.set_surface_override_material(0, material)
	
	tile_node.add_child(backpack)
	backpack.global_position = position
	backpack.set_meta("inventory", inventory)
	backpack.set_meta("is_backpack", true)

func _spawn_effigy(tile_node: Node3D, position: Vector3) -> void:
	"""
	Spawn effigy entity
	
	@param tile_node: Parent tile
	@param position: Spawn position
	"""
	var effigy := MeshInstance3D.new()
	effigy.name = "Effigy"
	effigy.mesh = CapsuleMesh.new()
	effigy.mesh.height = 2.0
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	effigy.set_surface_override_material(0, material)
	
	tile_node.add_child(effigy)
	effigy.global_position = position
	effigy.position.y = 1.0

func _spawn_echo(tile_node: Node3D, position: Vector3) -> void:
	"""
	Spawn echo entity (placeholder)
	
	@param tile_node: Parent tile
	@param position: Spawn position
	"""
	pass

func _on_item_pickup(body: Node3D, item_node: Node3D) -> void:
	"""
	Handle item pickup collision
	
	@param body: Body that entered collision
	@param item_node: Item that was touched
	"""
	if not body.is_in_group("player"):
		return
	
	var item_id: String = item_node.get_meta("item_id", "")
	if item_id.is_empty():
		return
	
	var tile_pos: Vector2i = _state_manager.get_state("current_tile_position")
	_message_bus.emit_event("item_collected", [item_id, body, tile_pos])
	
	item_node.queue_free()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.tile_generated.connect(_on_tile_generated)
	_message_bus.game_started.connect(_on_game_started)

func _on_tile_generated(tile_node: Node3D, position: Vector2i, tile_data: Dictionary) -> void:
	process_tile_spawning(tile_node, position)

func _on_game_started() -> void:
	_spawn_history.clear()
