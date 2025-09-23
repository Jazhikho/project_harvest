extends Node
## Utility class for accessing game managers
## Provides a consistent interface for accessing managers that are now local to the Game scene

static func get_manager(manager_name: String) -> Node:
	"""
	Get a manager reference by name using MessageBus metadata
	@param manager_name: Name of the manager (e.g., "tile_manager", "item_manager")
	@return: Manager node or null if not found
	"""
	var message_bus = Engine.get_main_loop().root.get_node("/root/MessageBus")
	if not message_bus:
		push_warning("ManagerAccess: MessageBus not found")
		return null

	return message_bus.get_manager(manager_name)

static func get_tile_manager() -> Node:
	"""Get TileManager reference"""
	return get_manager("tile_manager")

static func get_journal_manager() -> Node:
	"""Get JournalManager reference"""
	return get_manager("journal_manager")

static func get_item_manager() -> Node:
	"""Get ItemManager reference"""
	return get_manager("item_manager")

static func get_spawn_manager() -> Node:
	"""Get SpawnManager reference"""
	return get_manager("spawn_manager")

# Removed: get_event_manager() - EventManager no longer exists

static func get_sanity_manager() -> Node:
	"""Get SanityManager reference"""
	return get_manager("sanity_manager")

static func get_enemy_manager() -> Node:
	"""Get EnemyManager reference"""
	return get_manager("enemy_manager")

static func get_tile_state_manager() -> Node:
	"""Get TileStateManager reference"""
	return get_manager("tile_state_manager")

# Removed: get_maze_manager() - MazeManager no longer exists

static func get_effigy_manager() -> Node:
	"""Get EffigyManager reference"""
	return get_manager("effigy_manager")

# Core system managers (still autoloads)
static func get_message_bus() -> Node:
	"""Get MessageBus reference (still an autoload)"""
	return Engine.get_main_loop().root.get_node("/root/MessageBus")

static func get_state_manager() -> Node:
	return Engine.get_main_loop().root.get_node("/root/SaveManager")

static func get_save_manager() -> Node:
	"""Get SaveManager reference (still an autoload)"""
	return Engine.get_main_loop().root.get_node("/root/SaveManager")

static func get_scene_manager() -> Node:
	"""Get SceneManager reference (still an autoload)"""
	return Engine.get_main_loop().root.get_node("/root/SceneManager")

static func get_audio_manager() -> Node:
	"""Get AudioManager reference (still an autoload)"""
	return Engine.get_main_loop().root.get_node("/root/AudioManager")

static func get_input_manager() -> Node:
	"""Get InputManager reference (still an autoload)"""
	return Engine.get_main_loop().root.get_node("/root/InputManager")
