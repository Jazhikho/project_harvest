extends Node
## Manages spawning of items, entities, and environmental objects
## Coordinates with ItemManager for item spawning decisions

var _message_bus: Node
var _item_manager: Node
var _state_manager: Node

var _spawn_history := {}

const ITEM_SPAWN_CHANCE := 0.10 # 10% chance per spawn point
const MAX_NON_NOTE_ITEMS_PER_TILE := 1

func _ready() -> void:
	name = "SpawnManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to other systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/SaveManager")
	
	# Get local ItemManager from the game scene
	var game_controllers = get_parent()
	_item_manager = game_controllers.get_node_or_null("ItemManager")
	
	if not _message_bus or not _state_manager:
		push_error("SpawnManager: Required core systems not found")
		return
		
	if not _item_manager:
		push_error("SpawnManager: ItemManager not found in local managers")
		return
	
	_connect_to_events()

func process_tile_spawning(tile_node: Node3D, tile_position: Vector2i) -> Dictionary:
	"""
	Process spawning for a newly generated tile
	
	@param tile_node: The tile node being populated
	@param tile_position: Grid position of the tile
	@return: Dictionary of spawned entities {entity_type: [positions]}
	"""
	print("SpawnManager: === PROCESSING TILE SPAWNING ===")
	
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
	
	# Process regular item spawning (steps 80-86 in GAMELOOP.md)
	var spawnable_items = _item_manager.get_spawnable_items(context)
	print("    DEBUG: Found %d spawnable items: %s" % [spawnable_items.size(), spawnable_items])
	spawn_results["items"] = _spawn_items(tile_node, context, item_spawn_points)
	
	# Process entity spawning on the tile (steps 87-98)
	var enemy_manager = get_parent().get_node_or_null("EnemyManager")
	if enemy_manager and enemy_manager.has_method("spawn_entities_on_tile"):
		spawn_results["entities"] = enemy_manager.spawn_entities_on_tile(tile_node, context, entity_spawn_points)
	else:
		spawn_results["entities"] = []
		if not enemy_manager:
			print("SpawnManager: EnemyManager not found under GameControllers")
	
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
	var non_note_items_spawned: int = 0
	var shuffled_points := spawn_points.duplicate()
	shuffled_points.shuffle()
	
	
	for i in range(shuffled_points.size()):
		var spawn_point = shuffled_points[i]
		
		# Respect max non-note items per tile, but allow notes regardless
		if non_note_items_spawned >= MAX_NON_NOTE_ITEMS_PER_TILE:
			# We can still spawn notes, so do not break; just skip non-notes below
			pass
		
		var roll = randf()
		
		if roll < ITEM_SPAWN_CHANCE:
			var spawnable: Array[Dictionary] = _item_manager.get_spawnable_items(context)
			
			if not spawnable.is_empty():
				var item_id: String = _item_manager.select_random_item(spawnable)
				# Prevent duplicates of the same item existing in world when already owned
				var player_inventory = get_node_or_null("/root/PlayerInventory")
				if player_inventory and player_inventory.has_method("has_item") and player_inventory.has_item(item_id):
					continue
				# If we've already spawned a non-note item, only allow notes to spawn
				if non_note_items_spawned >= MAX_NON_NOTE_ITEMS_PER_TILE and not item_id.begins_with("note_"):
					continue
				if _item_manager.has_method("spawn_item_visual") and _item_manager.spawn_item_visual(tile_node, item_id, spawn_point):
					spawned_items.append(item_id)
					_message_bus.emit_event("item_spawned", [item_id, spawn_point, context["tile_position"], {}])
					if not item_id.begins_with("note_"):
						non_note_items_spawned += 1
						# Do not break; continue so notes can still spawn at other points
				else:
					pass
			else:
				pass
		else:
			pass
	
	return spawned_items
	
func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.tile_generated.connect(_on_tile_generated)
	_message_bus.game_started.connect(_on_game_started)

func _on_tile_generated(tile_node: Node3D, position: Vector2i, tile_data: Dictionary) -> void:
	process_tile_spawning(tile_node, position)

func _on_game_started() -> void:
	_spawn_history.clear()
