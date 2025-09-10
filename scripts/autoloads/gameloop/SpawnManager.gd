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
	print("SpawnManager: === PROCESSING TILE SPAWNING ===")
	print("  Tile: %s at position %s" % [tile_node.name, tile_position])
	
	var spawn_results := {}
	var item_spawn_points := _get_item_spawn_points(tile_node)
	var entity_spawn_points := _get_entity_spawn_points(tile_node)
	
	print("  Found %d item spawn points and %d entity spawn points" % [item_spawn_points.size(), entity_spawn_points.size()])
	
	if item_spawn_points.is_empty() and entity_spawn_points.is_empty():
		print("  No spawn points available - skipping spawning")
		return spawn_results
	
	var context := {
		"tile_position": tile_position,
		"tile_node": tile_node,
		"item_spawn_points": item_spawn_points,
		"entity_spawn_points": entity_spawn_points,
		"is_permanent": _is_permanent_tile(tile_node)
	}
	
	# Check for death location (step 10 in GAMELOOP.md)
	var death_data: Dictionary = _state_manager.get_unused_death_at_position(tile_position)
	if not death_data.is_empty():
		print("  DEATH LOCATION FOUND: Spawning backpack and effigy")
		print("    Death cause: %s" % death_data.get("cause", "unknown"))
		print("    Inventory items: %d" % death_data.get("inventory", []).size())
		spawn_results["backpack"] = _spawn_backpack_at_death(tile_node, death_data, item_spawn_points)
		print("  ✓ Death location processing complete")
		print("===========================================")
		return spawn_results
	
	# Process regular item spawning (step 10b in GAMELOOP.md)
	print("  No death location - processing regular item spawning")
	spawn_results["items"] = _spawn_items(tile_node, context, item_spawn_points)
	
	# Process entity spawning on the tile
	print("  Processing entity spawning...")
	spawn_results["entities"] = _spawn_entities(tile_node, context, entity_spawn_points)
	
	print("  ✓ Tile spawning complete")
	print("===========================================")
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
		print("  Found ItemSpawn container with %d children" % item_spawn_parent.get_child_count())
		for child in item_spawn_parent.get_children():
			if child is Marker3D:
				points.append(child.global_position)
				print("    Added ItemSpawn point at %s" % child.global_position)
	else:
		print("  No Maze/ItemSpawn found")
		
		# Fallback: check legacy SpawnPoints
		var legacy_spawn_parent := tile_node.get_node_or_null("Maze/SpawnPoints")
		if legacy_spawn_parent:
			print("  Found legacy SpawnPoints container with %d children" % legacy_spawn_parent.get_child_count())
			for child in legacy_spawn_parent.get_children():
				if child is Marker3D:
					points.append(child.global_position)
					print("    Added legacy spawn point at %s" % child.global_position)
		else:
			print("  No legacy Maze/SpawnPoints found either")
	
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
		print("  Found EntitySpawn container with %d children" % entity_spawn_parent.get_child_count())
		for child in entity_spawn_parent.get_children():
			if child is Marker3D:
				points.append(child.global_position)
				print("    Added EntitySpawn point at %s" % child.global_position)
	else:
		print("  No Maze/EntitySpawn found")
	
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
	Spawn regular items on tile (GAMELOOP.md step 10b: 3% base chance per drop point)
	
	@param tile_node: Tile node to spawn items on
	@param context: Spawning context
	@param spawn_points: Available spawn positions
	@return: Array of spawned item IDs
	"""
	var spawned_items := []
	var shuffled_points := spawn_points.duplicate()
	shuffled_points.shuffle()
	
	print("    Checking %d spawn points for items (3%% chance each)" % shuffled_points.size())
	
	for i in range(shuffled_points.size()):
		var spawn_point = shuffled_points[i]
		
		if spawned_items.size() >= MAX_ITEMS_PER_TILE:
			print("    Max items per tile reached (%d)" % MAX_ITEMS_PER_TILE)
			break
		
		var roll = randf()
		print("    Spawn point %d: Rolling %.3f (need < %.3f)" % [i+1, roll, ITEM_SPAWN_CHANCE])
		
		if roll < ITEM_SPAWN_CHANCE:
			print("      SUCCESS: Item will spawn")
			var spawnable: Array[Dictionary] = _item_manager.get_spawnable_items(context)
			print("      Available items: %d" % spawnable.size())
			
			if not spawnable.is_empty():
				var item_id: String = _item_manager.select_random_item(spawnable)
				print("      Selected item: %s" % item_id)
				
				if _spawn_item_visual(tile_node, item_id, spawn_point):
					spawned_items.append(item_id)
					_message_bus.emit_event("item_spawned", [item_id, spawn_point, context.tile_position, {}])
					print("      ✓ Item spawned successfully")
					# GAMELOOP.md: Break after first item spawns
					break
				else:
					print("      ✗ Item spawn failed")
			else:
				print("      No spawnable items available")
		else:
			print("      No spawn (%.3f >= %.3f)" % [roll, ITEM_SPAWN_CHANCE])
	
	print("    Final result: %d items spawned" % spawned_items.size())
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

func _spawn_entities(tile_node: Node3D, context: Dictionary, spawn_points: Array[Vector3]) -> Array:
	"""
	Spawn entities on tile based on game state and conditions
	
	@param tile_node: Tile node to spawn entities on
	@param context: Spawning context
	@param spawn_points: Available entity spawn positions
	@return: Array of spawned entity types
	"""
	var spawned_entities := []
	
	if spawn_points.is_empty():
		print("    No entity spawn points available")
		return spawned_entities
	
	print("    Checking entity spawn conditions...")
	
	# Get current game state
	var current_sanity: int = _state_manager.get_state("sanity")
	var tiles_explored_value = _state_manager.get_state("tiles_explored")
	var tiles_explored: int = tiles_explored_value if tiles_explored_value != null else 0
	var weird_things_collected: int = 0
	
	# Check with WeirdThingsManager if available
	var weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	if weird_things_manager and weird_things_manager.has_method("get_collected_count"):
		weird_things_collected = weird_things_manager.get_collected_count()
	
	print("    Game state: Sanity=%d, Tiles=%d, Weird Things=%d" % [current_sanity, tiles_explored, weird_things_collected])
	
	# Chance-based spawning with different probabilities
	var spawn_chances := {}
	
	# Base spawn chances (very low for balanced gameplay)
	spawn_chances["effigy"] = 0.02  # 2% chance for effigy
	
	# Conditional spawn chances
	if current_sanity < 80:
		spawn_chances["watcher"] = 0.05  # 5% chance when sanity is low
	
	if weird_things_collected >= 2:
		spawn_chances["stalker"] = 0.03  # 3% chance when player has collected weird things
	
	if tiles_explored > 5:
		spawn_chances["echo"] = 0.01  # 1% chance after exploring several tiles
	
	# Try to spawn entities
	var shuffled_points := spawn_points.duplicate()
	shuffled_points.shuffle()
	
	for i in range(min(2, shuffled_points.size())):  # Max 2 entities per tile
		var spawn_point = shuffled_points[i]
		
		# Roll for each entity type
		for entity_type in spawn_chances.keys():
			var chance = spawn_chances[entity_type]
			var roll = randf()
			
			print("      Entity %s: Rolling %.3f (need < %.3f)" % [entity_type, roll, chance])
			
			if roll < chance:
				print("        SUCCESS: Spawning %s" % entity_type)
				
				# Use EnemyManager to spawn the entity
				var enemy_manager = get_node_or_null("/root/EnemyManager")
				if enemy_manager and enemy_manager.has_method("spawn_enemy"):
					var spawned_entity = enemy_manager.spawn_enemy(entity_type, spawn_point, true)  # Force spawn
					if spawned_entity:
						spawned_entities.append(entity_type)
						print("        ✓ %s spawned successfully" % entity_type)
						break  # Only spawn one entity per spawn point
					else:
						print("        ✗ %s spawn failed" % entity_type)
				else:
					print("        ✗ EnemyManager not available")
			else:
				print("        No spawn (%.3f >= %.3f)" % [roll, chance])
	
	print("    Entity spawning result: %d entities spawned" % spawned_entities.size())
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
