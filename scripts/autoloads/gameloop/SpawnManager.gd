extends Node
## Manages spawning of items, entities, and environmental objects
## Coordinates with ItemManager for item spawning decisions

var _message_bus: Node
var _item_manager: Node
var _state_manager: Node

@onready var _items: Node = get_node_or_null("/root/ItemManager")
@onready var _enemies: Node = get_node_or_null("/root/EnemyManager")

var _spawn_history := {}

const ITEM_SPAWN_CHANCE := 0.25 # 25% chance per spawn point
const MAX_ITEMS_PER_TILE := 4

func _ready() -> void:
	name = "SpawnManager"
	_validate_deps()
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
	
func _validate_deps() -> void:
	if _items == null:
		push_error("SpawnManager: ItemManager not found.")
	if _enemies == null:
		push_error("SpawnManager: EnemyManager not found.")

func process_tile_spawning(tile_node: Node3D, tile_position: Vector2i) -> Dictionary:
	"""
	Process spawning for a newly generated tile
	
	@param tile_node: The tile node being populated
	@param tile_position: Grid position of the tile
	@return: Dictionary of spawned entities {entity_type: [positions]}
	"""
	
	var spawn_results := {}
	var item_spawn_points := _get_item_spawn_points(tile_node)
	var entity_spawn_points := _get_entity_spawn_points(tile_node)
	
	if item_spawn_points.is_empty() and entity_spawn_points.is_empty():
		return spawn_results
	
	var context := {
		"tile_position": tile_position,
		"tile_node": tile_node,
		"item_spawn_points": item_spawn_points,
		"entity_spawn_points": entity_spawn_points,
		"is_permanent": _is_permanent_tile(tile_node)
	}
	
	spawn_results["items"] = _spawn_items(tile_node, context, item_spawn_points)
	
	spawn_results["entities"] = _spawn_entities(tile_node, context, entity_spawn_points)
	
	return spawn_results

func _get_item_spawn_points(tile_node: Node3D) -> Array[Vector3]:
	"""
	Get ITEM spawn points from tile
	
	@param tile_node: Tile to extract item spawn points from
	@return: Array of world positions for item spawning only
	"""
	var points: Array[Vector3] = []
	
	# Check for ItemSpawn points
	var item_spawn_parent := tile_node.get_node_or_null("Maze/ItemSpawn")
	if item_spawn_parent:
		for child in item_spawn_parent.get_children():
			if child is Marker3D:
				points.append(child.global_position)
	return points

func _get_entity_spawn_points(tile_node: Node3D) -> Array[Vector3]:
	"""
	Get ENTITY spawn points from tile
	
	@param tile_node: Tile to extract entity spawn points from
	@return: Array of world positions for entity spawning only
	"""
	var points: Array[Vector3] = []
	
	# Check for EntitySpawn points
	var entity_spawn_parent := tile_node.get_node_or_null("Maze/EntitySpawn")
	if entity_spawn_parent:
		for child in entity_spawn_parent.get_children():
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
	Spawn regular items on tile (10% base chance per drop point)
	
	@param tile_node: Tile node to spawn items on
	@param context: Spawning context
	@param spawn_points: Available spawn positions
	@return: Array of spawned item IDs
	"""
	var spawned_items := []
	var shuffled_points := spawn_points.duplicate()
	shuffled_points.shuffle()
	
	for i in range(shuffled_points.size()):
		var spawn_point = shuffled_points[i]
		
		var roll = randf()
		
		if roll < ITEM_SPAWN_CHANCE:
			var spawnable: Array[Dictionary] = _item_manager.get_spawnable_items(context, spawned_items)
			if not spawnable.is_empty():
				var item_id: String = _item_manager.select_random_item(spawnable)
				
				if _spawn_item_visual(tile_node, item_id, spawn_point):
					spawned_items.append(item_id)
					_message_bus.emit_event("item_spawned", [item_id, spawn_point, context["tile_position"], {}])
				else:
					pass
			else:
				pass
		else:
			pass
	
	return spawned_items

func _spawn_item_visual(tile_node: Node3D, item_id: String, position: Vector3) -> bool:
	"""
	Create visual representation of spawned item
	
	@param tile_node: Parent tile node
	@param item_id: Item identifier
	@param position: World position to spawn at
	@return: True if spawned successfully
	"""
	# Get item info to check category
	var item_info: Dictionary = _item_manager.get_item_info(item_id)
	var item_category: String = item_info.get("category", "")
	
	# Special handling for notes
	if item_category == "notes":
		return _spawn_note_visual(tile_node, item_id, position, item_info)
	
	# Regular item spawning - use ItemManager's scene mapping system
	var item_instance: Node3D = _item_manager.spawn_item_instance(item_id, position, tile_node)
	if not item_instance:
		_spawn_placeholder_item(tile_node, item_id, position)
		return true
	
	return true

func _spawn_note_visual(tile_node: Node3D, note_id: String, position: Vector3, note_info: Dictionary) -> bool:
	"""
	Create visual representation of a research note using random note scene
	
	@param tile_node: Parent tile node
	@param note_id: Note identifier
	@param position: World position to spawn at
	@param note_info: Note configuration data
	@return: True if spawned successfully
	"""
	# Array of available note visual scenes
	var note_scene_paths: Array[String] = [
		"res://scenes/notes/note_1.tscn",
		"res://scenes/notes/note_2.tscn",
		"res://scenes/notes/note_3.tscn",
		"res://scenes/notes/note_4.tscn"
	]
	
	# Filter to only existing scenes for export safety
	var valid_note_scenes: Array[String] = []
	for path in note_scene_paths:
		if ResourceLoader.exists(path, "PackedScene"):
			valid_note_scenes.append(path)
	
	if valid_note_scenes.is_empty():
		push_error("SpawnManager: No valid note scenes found for export")
		_spawn_placeholder_item(tile_node, note_id, position)
		return false
	
	# Pick a random note scene from valid ones
	var random_index: int = randi() % valid_note_scenes.size()
	var chosen_scene_path: String = valid_note_scenes[random_index]
	
	# Load the chosen note scene
	var note_scene: PackedScene = load(chosen_scene_path) as PackedScene
	if not note_scene:
		push_error("SpawnManager: Failed to load note scene: %s" % chosen_scene_path)
		_spawn_placeholder_item(tile_node, note_id, position)
		return false
	
	# Create the note instance
	var note_instance: Node3D = note_scene.instantiate()
	
	var has_research_script: bool = note_instance.has_method("_get_note_text")
	
	# Check if it needs the ResearchNote script
	if not note_instance.has_method("_get_note_text"):
		var research_note_script: Script = load("res://scripts/items/ResearchNote.gd")
		if research_note_script:
			note_instance.set_script(research_note_script)
	
	note_instance.item_id = note_id
	print("note has id: ", note_id)
	note_instance.item_name = note_info.get("name", "Research Note")
	note_instance.item_description = note_info.get("description", "")
	note_instance.display_name = note_info.get("name", "Research Note")
	note_instance.auto_pickup = false # Notes require interaction

	# Set required metadata
	note_instance.set_meta("item_id", note_id)
	note_instance.set_meta("is_collectible", true)
	
	# Add to tile and position
	tile_node.add_child(note_instance)
	note_instance.global_position = position
	
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

	var enemy_manager = get_node_or_null("/root/EnemyManager")
	if enemy_manager and enemy_manager.has_method("spawn_enemy"):
		enemy_manager.spawn_enemy("effigy", effigy_pos, true)
	else:
		var effigy_manager = get_node_or_null("/root/EffigyManager")
		if effigy_manager and effigy_manager.has_method("spawn_effigy_at_death_location"):
			var modified_death = death_data.duplicate()
			modified_death["position"] = Vector2i(int(effigy_pos.x / 20.0), int(effigy_pos.z / 20.0))
			effigy_manager.spawn_effigy_at_death_location(modified_death)
		else:
			var effigy := MeshInstance3D.new()
			effigy.name = "Effigy_Debug"
			effigy.mesh = CapsuleMesh.new()
			(effigy.mesh as CapsuleMesh).height = 2.0
			tile_node.add_child(effigy)
			effigy.global_position = effigy_pos
			effigy.position.y = 1.0

	_state_manager.mark_death_used(death_data.get("position"))
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
	Spawn effigy entity (placeholder - actual spawning handled by Effi
EffigyManager)
	
	@param tile_node: Parent tile
	@param position: Spawn position
	"""
	# Effigy spawning is handled by EffigyManager
	pass

func _spawn_stalker(tile_node: Node3D, position: Vector3) -> void:
	"""
	Spawn stalker entity (placeholder - actual spawning handled by EnemyManager)
	
	@param tile_node: Parent tile
	@param position: Spawn position
	"""
	# Stalker spawning is handled by EnemyManager
	pass

func _calculate_entity_spawn_chance(current_sanity: int, tiles_explored: int, weird_things_collected: int) -> float:
	"""
	Calculate entity spawn chance - simplified sliding scale
	
	@param current_sanity: Current player sanity (0-100)
	@param tiles_explored: Number of tiles explored
	@param weird_things_collected: Number of weird things collected
	@return: Final spawn chance as decimal (0.0 to 1.0)
	"""
	# Base 10% chance
	var base_chance: float = 0.10
	
	# Sanity modifier: 0% at 100 sanity, +20% at 0 sanity
	var sanity_modifier: float = (100 - current_sanity) * 0.002 # 0.2 at 0 sanity
	
	# Exploration modifier: Start adding after 5 tiles, +1% per tile
	var exploration_modifier: float = max(0.0, (tiles_explored - 5) * 0.01)
	
	# Collection modifier: +2% per weird thing collected
	var collection_modifier: float = weird_things_collected * 0.02
	
	# Calculate final chance
	var final_chance: float = base_chance + sanity_modifier + exploration_modifier + collection_modifier
	
	# Clamp between 10% and 60%
	final_chance = clampf(final_chance, 0.10, 0.60)
	
	
	return final_chance

func _spawn_entities(tile_node: Node3D, context: Dictionary, spawn_points: Array[Vector3]) -> Array:
	"""
	Spawn entities on tile - only Stalker or Effigy in MVP
	
	@param tile_node: Tile node to spawn entities on
	@param context: Spawning context
	@param spawn_points: Available entity spawn positions
	@return: Array of spawned entity types
	"""
	var spawned_entities := []
	
	if spawn_points.is_empty():
		return spawned_entities
	
	# Get current game state
	var current_sanity: int = _state_manager.get_state("sanity")
	var tiles_explored_value = _state_manager.get_state("tiles_explored")
	var tiles_explored: int = tiles_explored_value if tiles_explored_value != null else 0
	var weird_things_collected: int = 1
	
	# Calculate spawn chance
	var spawn_chance: float = _calculate_entity_spawn_chance(current_sanity, tiles_explored, weird_things_collected)
	
	# Determine which entity to spawn
	var entity_type: String = "effigy"
	
	# Try to spawn entity
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var roll = randf()
	
	if roll < spawn_chance:
		# Use EnemyManager to spawn the entity
		var enemy_manager = get_node_or_null("/root/EnemyManager")
		if enemy_manager and enemy_manager.has_method("spawn_enemy"):
			var spawned_entity = enemy_manager.spawn_enemy(entity_type, spawn_point, true) # Force spawn
			if spawned_entity:
				spawned_entities.append(entity_type)
			else:
				pass
		else:
			pass
	
	return spawned_entities

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
