extends Node
## Player Inventory - Centralized inventory management for the player
## Single source of truth for all inventory operations

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_full()
signal inventory_changed(new_inventory: Array, added_items: Array, removed_items: Array)

@export var max_inventory_size: int = 99

var inventory: Array[String] = []
var _message_bus: Node
var _item_manager: Node
var _state_manager: Node

func _ready() -> void:
	name = "PlayerInventory"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_item_manager = get_node_or_null("/root/ItemManager")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if _message_bus:
		_message_bus.item_collected.connect(_on_item_collected_external)
		_message_bus.game_started.connect(_on_game_started)

func add_item(item_id: String, apply_effects: bool = true) -> bool:
	"""
	Add an item to inventory
	
	@param item_id: Item identifier to add
	@param apply_effects: Whether to apply item effects (false for restoration)
	@return: True if item was added successfully
	"""
	if inventory.size() >= max_inventory_size:
		emit_signal("inventory_full")
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["Inventory is full!", 2.0, 1])
		return false
	
	if item_id in inventory:
		# Item already exists, don't add duplicate
		return false
	
	inventory.append(item_id)
	
	# Apply item effects if ItemManager is available and effects should be applied
	if apply_effects and _item_manager and _item_manager.has_method("apply_item_effects"):
		_item_manager.apply_item_effects(item_id)
	
	# Emit signals
	item_added.emit(item_id)
	inventory_changed.emit(inventory.duplicate(), [item_id], [])
	
	# Sync with MessageBus
	if _message_bus:
		_message_bus.emit_event("inventory_changed", [inventory.duplicate(), [item_id], []])
	
	return true

func remove_item(item_id: String) -> bool:
	"""
	Remove an item from inventory
	
	@param item_id: Item identifier to remove
	@return: True if item was removed (was present)
	"""
	if item_id not in inventory:
		return false
	
	inventory.erase(item_id)
	
	# Emit signals
	item_removed.emit(item_id)
	inventory_changed.emit(inventory.duplicate(), [], [item_id])
	
	# Sync with MessageBus
	if _message_bus:
		_message_bus.emit_event("inventory_changed", [inventory.duplicate(), [], [item_id]])
	
	return true

func has_item(item_id: String) -> bool:
	"""
	Check if player has a specific item
	
	@param item_id: Item identifier to check
	@return: True if item is in inventory
	"""
	return item_id in inventory

func get_puzzle_pieces() -> Array[String]:
	"""
	Get all puzzle pieces in inventory
	
	@return: Array of puzzle piece item IDs
	"""
	var pieces: Array[String] = []
	
	if _item_manager and _item_manager.has_method("get_category_items"):
		var puzzle_items = _item_manager.get_category_items("puzzle_pieces")
		for item in inventory:
			if item in puzzle_items:
				pieces.append(item)
	else:
		# Fallback to string matching
		for item in inventory:
			if "puzzle" in item.to_lower() or "piece" in item.to_lower():
				pieces.append(item)
	
	return pieces

func get_inventory() -> Array[String]:
	"""
	Get current inventory
	
	@return: Duplicate of current inventory array
	"""
	return inventory.duplicate()

func get_inventory_size() -> int:
	"""
	Get current inventory size
	
	@return: Number of items in inventory
	"""
	return inventory.size()

func get_max_inventory_size() -> int:
	"""
	Get maximum inventory size
	
	@return: Maximum number of items that can be held
	"""
	return max_inventory_size

func is_inventory_full() -> bool:
	"""
	Check if inventory is full
	
	@return: True if inventory is at maximum capacity
	"""
	return inventory.size() >= max_inventory_size

func clear_inventory() -> void:
	"""Clear all items from inventory"""
	var old_inventory = inventory.duplicate()
	inventory.clear()
	
	# Emit signals for all removed items
	inventory_changed.emit([], [], old_inventory)
	
	if _message_bus:
		_message_bus.emit_event("inventory_changed", [[], [], old_inventory])
	
	pass

func load_from_backpack(backpack_inventory: Array) -> int:
	"""
	Load items from a found backpack
	
	@param backpack_inventory: Array of item IDs to load
	@return: Number of items successfully loaded
	"""
	var loaded_count = 0
	
	for item in backpack_inventory:
		if add_item(item, false): # Don't apply effects when restoring from backpack
			loaded_count += 1
		else:
			break # Stop if inventory is full
	
	if _message_bus and loaded_count > 0:
		_message_bus.emit_event("notification_requested", [
			"Found %d items from a previous explorer..." % loaded_count,
			3.0, 1
		])
	
	return loaded_count

func get_items_by_category(category: String) -> Array[String]:
	"""
	Get all items in inventory of a specific category
	
	@param category: Category to filter by
	@return: Array of item IDs in that category
	"""
	var categorized_items: Array[String] = []
	
	if not _item_manager:
		return categorized_items
	
	var category_items = _item_manager.get_category_items(category)
	for item in inventory:
		if item in category_items:
			categorized_items.append(item)
	
	return categorized_items

# Event handlers

func _on_item_collected_external(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""Handle external item collection events"""
	if collector and collector.is_in_group("player"):
		add_item(item_id)

func _on_game_started() -> void:
	"""Handle game start - clear inventory for new run"""
	clear_inventory()
