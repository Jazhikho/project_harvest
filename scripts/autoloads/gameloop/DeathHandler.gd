extends Node
## Handles spawning effigy and backpack on start tile for continued games

var _save_manager: Node
var _enemy_manager: Node
var _message_bus: Node
var _item_manager: Node

# Reference to the start tile
var _start_tile: Node3D

# Track if this was a continue game (checked before save is created)
var _is_continue: bool = false

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize system connections"""
	_save_manager = get_node_or_null("/root/SaveManager")
	_enemy_manager = get_node_or_null("/root/EnemyManager")
	_message_bus = get_node_or_null("/root/MessageBus")
	_item_manager = get_node_or_null("/root/ItemManager")
	
	if not _save_manager or not _enemy_manager or not _message_bus or not _item_manager:
		push_error("StartTileSpawner: Required systems not found")
		return
	
	# Connect to game started event
	# We check for save data when the event fires, not now, because autoloads
	# persist across scene changes and this only runs once at app startup
	_message_bus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	"""Called when game starts - check if we should spawn continue items"""
	
	# Check if this is a continue using SaveManager's flag
	# SaveManager sets had_existing_save before start_run() creates a new save
	# This is the most reliable way to detect if this is a truly new game or a continue
	_is_continue = _save_manager.had_existing_save
	print("DeathHandler: SaveManager had_existing_save: ", _is_continue, ", is_continue: ", _is_continue)
	
	# Wait a few frames for start tile to be registered
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find the start tile
	_start_tile = _find_start_tile()
	
	if not _start_tile:
		push_error("StartTileSpawner: Could not find start tile")
		return
	
	# Use the flag we checked before awaiting
	if _is_continue:
		print("StartTileSpawner: Continue detected, spawning effigy and backpack, hiding start note")
		_hide_start_note()
		_spawn_continue_items()
	else:
		print("StartTileSpawner: New game, start note available")

func _find_start_tile() -> Node3D:
	"""Find the start tile in the scene"""
	
	# Try various possible paths
	var possible_paths = [
		"StartTile",
		"/root/Game/MazeContainer/StartTile",
		"/root/Game/StartTile"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node:
			return node as Node3D
	
	# Try finding by name in current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child.name == "StartTile" or "StartTile" in child.name:
				return child as Node3D
		
		# Check MazeContainer
		var maze_container = current_scene.get_node_or_null("MazeContainer")
		if maze_container:
			for child in maze_container.get_children():
				if child.name == "StartTile" or "StartTile" in child.name:
					return child as Node3D
	
	return null

func _hide_start_note() -> void:
	"""
	Hide the start note on the start tile for continue games
	The note should only be visible on brand new games
	"""
	if not _start_tile:
		return
	
	var objects_node = _start_tile.get_node_or_null("Objects")
	if not objects_node:
		return
	
	var start_note = objects_node.get_node_or_null("start_note")
	if start_note:
		print("DeathHandler: Hiding start note for continue game")
		start_note.queue_free()

func _spawn_continue_items() -> void:
	"""Spawn effigy and backpack at marked positions on start tile"""
	
	var objects_node = _start_tile.get_node_or_null("Objects")
	if not objects_node:
		push_error("StartTileSpawner: Objects node not found in start tile")
		return
	
	# Get spawn markers
	var entity_marker = objects_node.get_node_or_null("Entity1") as Marker3D
	var item_marker = objects_node.get_node_or_null("Item1") as Marker3D
	
	if not entity_marker or not item_marker:
		push_error("StartTileSpawner: Spawn markers not found")
		return
	
	# Spawn effigy at Entity1
	_spawn_effigy(entity_marker.global_position)
	
	# Spawn backpack at Item1
	_spawn_backpack(item_marker.global_position)

func _spawn_effigy(position: Vector3) -> void:
	"""
	Spawn effigy at position
	
	@param position: World position to spawn at
	"""
	if _enemy_manager.has_method("spawn_enemy"):
		var effigy = _enemy_manager.spawn_enemy("effigy", position, true)
		if effigy:
			print("StartTileSpawner: Spawned effigy at ", position)
		else:
			push_warning("StartTileSpawner: Failed to spawn effigy")
	else:
		push_error("StartTileSpawner: EnemyManager missing spawn_enemy method")

func _spawn_backpack(position: Vector3) -> void:
	"""
	Spawn backpack with previous run's items at position
	
	@param position: World position to spawn at
	"""
	if not _item_manager.has_method("spawn_item_instance"):
		push_error("DeathHandler: ItemManager missing spawn_item_instance method")
		return
	
	# Use ItemManager to spawn backpack from catalog
	var backpack: Node3D = _item_manager.spawn_item_instance("backpack", position, _start_tile) as Node3D
	if not backpack:
		push_error("DeathHandler: Failed to spawn backpack via ItemManager")
		return
	
	# Get previous run's inventory from backpack (notes and puzzle pieces persist)
	var previous_inventory: Array = _save_manager.get_backpack_inventory()
	print("DeathHandler: Backpack inventory: ", previous_inventory)
	
	# Set backpack metadata
	backpack.set_meta("inventory", previous_inventory)
	backpack.set_meta("is_backpack", true)
	
	print("DeathHandler: Spawned backpack at ", position, " with ", previous_inventory.size(), " items")
