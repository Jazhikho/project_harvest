extends Node
## BaseManager - Base class for all manager autoloads
## Implements common initialization patterns to reduce code duplication
## Follows DRY principle by centralizing manager boilerplate

class_name BaseManager

# Core system references - available to all managers
var _message_bus: Node
var _state_manager: Node
var _save_manager: Node

# Initialization state
var _is_initialized: bool = false
var _required_systems: Array[String] = []

# Constants for system paths
const SYSTEM_PATHS = {
	"MessageBus": "/root/MessageBus",
	"GameStateManager": "/root/GameStateManager",
	"SaveManager": "/root/SaveManager",
	"TileManager": "/root/TileManager",
	"SpawnManager": "/root/SpawnManager",
	"ItemManager": "/root/ItemManager",
	"EnemyManager": "/root/EnemyManager",
	"SanityManager": "/root/SanityManager",
	"AudioManager": "/root/AudioManager",
	"EventManager": "/root/EventManager",
	"HarvestLogger": "/root/HarvestLogger",
	"EffigyManager": "/root/EffigyManager",
	"WeirdThingsManager": "/root/WeirdThingsManager",
	"SettingsManager": "/root/SettingsManager",
	"MazeManager": "/root/MazeManager",
	"TileStateManager": "/root/TileStateManager"
}

func _ready() -> void:
	# Set default group membership
	add_to_group("managers")
	
	# Defer initialization to allow all autoloads to load first
	call_deferred("_base_initialize")

func _base_initialize() -> void:
	"""Base initialization - handles common setup patterns"""
	if _is_initialized:
		return
	
	# Get core system references
	_message_bus = get_system_node("MessageBus")
	_state_manager = get_system_node("GameStateManager")
	_save_manager = get_system_node("SaveManager")
	
	# Check required systems
	if not _validate_required_systems():
		push_error("%s: Required systems not available" % get_manager_name())
		return
	
	# Call derived class initialization
	_initialize_manager()
	
	# Connect to common events
	_connect_base_events()
	
	_is_initialized = true

func _initialize_manager() -> void:
	"""Override in derived classes for specific initialization"""
	pass

func _connect_base_events() -> void:
	"""Connect to common events that most managers need"""
	if _message_bus and _message_bus.has_signal("game_started"):
		_message_bus.game_started.connect(_on_game_started)
	if _message_bus and _message_bus.has_signal("game_ended"):
		_message_bus.game_ended.connect(_on_game_ended)

func get_system_node(system_name: String) -> Node:
	"""
	Get reference to a system node with error handling
	
	@param system_name: Name of the system (key in SYSTEM_PATHS)
	@return: System node or null if not found
	"""
	if not SYSTEM_PATHS.has(system_name):
		push_warning("%s: Unknown system name '%s'" % [get_manager_name(), system_name])
		return null
	
	var node: Node = get_node_or_null(SYSTEM_PATHS[system_name])
	if not node:
		push_warning("%s: System '%s' not found at %s" % [get_manager_name(), system_name, SYSTEM_PATHS[system_name]])
	
	return node

func require_systems(systems: Array[String]) -> void:
	"""
	Specify which systems this manager requires
	
	@param systems: Array of system names that must be available
	"""
	_required_systems = systems

func _validate_required_systems() -> bool:
	"""Validate that all required systems are available.

	@return: True if all required systems are available
	"""
	for system_name in _required_systems:
		var system_node: Node = get_system_node(system_name)
		if not system_node:
			push_error("%s: Required system '%s' not available" % [get_manager_name(), system_name])
			return false
	
	return true

func get_manager_name() -> String:
	"""Get the name of this manager for logging"""
	if name:
		return name
	else:
		return get_script().get_path().get_file().get_basename()

func is_initialized() -> bool:
	"""Check if manager is fully initialized"""
	return _is_initialized

# Event handlers - override in derived classes as needed
func _on_game_started() -> void:
	"""Handle game start - override in derived classes"""
	pass

func _on_game_ended(cause: String, data: Dictionary) -> void:
	"""Handle game end - override in derived classes"""
	pass

# Utility methods for common patterns
func emit_event(event_name: String, args: Array = []) -> void:
	"""
	Emit event through MessageBus with error handling
	
	@param event_name: Name of the event to emit
	@param args: Arguments to pass with the event
	"""
	if not _message_bus:
		push_warning("%s: Cannot emit event '%s' - MessageBus not available" % [get_manager_name(), event_name])
		return
	
	_message_bus.emit_event(event_name, args)

func connect_event(event_name: String, callable: Callable) -> bool:
	"""
	Connect to MessageBus event with error handling
	
	@param event_name: Name of the event to connect to
	@param callable: Function to call when event is triggered
	@return: True if connection was successful
	"""
	if not _message_bus:
		push_warning("%s: Cannot connect to event '%s' - MessageBus not available" % [get_manager_name(), event_name])
		return false
	
	if not _message_bus.has_signal(event_name):
		push_warning("%s: Event '%s' not found in MessageBus" % [get_manager_name(), event_name])
		return false
	
	var signal_obj: Variant = _message_bus.get(event_name)
	if signal_obj and signal_obj is Signal:
		signal_obj.connect(callable)
		return true
	
	return false

func log_warning(message: String) -> void:
	"""Log warning message with manager name prefix"""
	push_warning("%s: %s" % [get_manager_name(), message])

func log_error(message: String) -> void:
	"""Log error message with manager name prefix"""
	push_error("%s: %s" % [get_manager_name(), message])
