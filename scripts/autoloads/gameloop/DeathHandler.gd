extends Node
## Handles spawning effigy and backpack on start tile for continued games

var _save_manager: Node
var _enemy_manager: Node
var _message_bus: Node

# Reference to the start tile
var _start_tile: Node3D

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize system connections"""
	_save_manager = get_node_or_null("/root/SaveManager")
	_enemy_manager = get_node_or_null("/root/EnemyManager")
	_message_bus = get_node_or_null("/root/MessageBus")
	
	if not _save_manager or not _enemy_manager or not _message_bus:
		push_error("StartTileSpawner: Required systems not found")
		return
	
	# Connect to game started event
	_message_bus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	"""Called when game starts - check if we should spawn continue items"""
	
	# Wait a few frames for start tile to be registered
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find the start tile
	_start_tile = _find_start_tile()
	
	if not _start_tile:
		push_error("StartTileSpawner: Could not find start tile")
		return
	
	# Check if this is a continue (run was active when loaded)
	if _is_continue_game():
		print("StartTileSpawner: Continue detected, spawning effigy and backpack")
		_spawn_continue_items()
	else:
		print("StartTileSpawner: New game, no continue items spawned")

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

func _is_continue_game() -> bool:
	"""
	Check if this is a continue game (player died in previous run)
	
	@return: True if continuing from a death
	"""
	# Check if save data exists and had an active run
	if not _save_manager.has_save_data():
		return false
	
	# If run was active, that means player died and this is a continue
	return _save_manager.save_data.get("deaths", 0) > 0

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
	var backpack_scene_path = "res://scenes/misc/backpack.tscn"
	
	if not FileAccess.file_exists(backpack_scene_path):
		push_error("StartTileSpawner: Backpack scene not found at ", backpack_scene_path)
		return
	
	var backpack_scene: PackedScene = load(backpack_scene_path) as PackedScene
	if not backpack_scene:
		push_error("StartTileSpawner: Failed to load backpack scene")
		return
	
	var backpack: Node3D = backpack_scene.instantiate() as Node3D
	if not backpack:
		push_error("StartTileSpawner: Failed to instantiate backpack")
		return
	
	# Get previous run's inventory from save data
	var previous_inventory: Array = _save_manager.save_data.get("collectibles", [])
	
	# Set backpack metadata
	backpack.set_meta("inventory", previous_inventory)
	backpack.set_meta("is_backpack", true)
	
	# Add to start tile
	_start_tile.add_child(backpack)
	backpack.global_position = position
	
	print("StartTileSpawner: Spawned backpack at ", position, " with ", previous_inventory.size(), " items")
