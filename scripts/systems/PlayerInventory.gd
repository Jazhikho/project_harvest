extends Node
## Player Inventory - Centralized inventory management for the player
## Single source of truth for all inventory operations

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_full()
signal inventory_changed(new_inventory: Array, added_items: Array, removed_items: Array)

@export var max_inventory_size: int = 20

var inventory: Array[String] = []
var _message_bus: Node
var _item_manager: Node
var _state_manager: Node

# UI references
var inventory_ui: Control = null

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

func add_item(item_id: String) -> bool:
	"""
	Add an item to inventory
	
	@param item_id: Item identifier to add
	@return: True if item was added successfully
	"""
	if inventory.size() >= max_inventory_size:
		emit_signal("inventory_full")
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["Inventory is full!", 2.0, 1])
		return false
	
	if item_id in inventory:
		# Item already exists, don't add duplicate
		if _message_bus:
			_message_bus.emit_event("notification_requested", ["You already have this item", 2.0, 1])
		return false
	
	inventory.append(item_id)
	
	# Apply item effects if ItemManager is available
	if _item_manager and _item_manager.has_method("apply_item_effects"):
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
	
	if _item_manager and _item_manager.has_method("is_puzzle_piece"):
		for item in inventory:
			if _item_manager.is_puzzle_piece(item):
				pieces.append(item)
	else:
		# Fallback to string matching
		for item in inventory:
			if "puzzle" in item.to_lower() and "piece" in item.to_lower():
				pieces.append(item)
	
	return pieces

func get_puzzle_pieces_for_puzzle(puzzle_id: String) -> Array[String]:
	"""
	Get puzzle pieces in inventory for a specific puzzle
	
	@param puzzle_id: Puzzle identifier
	@return: Array of puzzle piece IDs for this puzzle
	"""
	var pieces: Array[String] = []
	
	if _item_manager and _item_manager.has_method("get_puzzle_pieces_for_puzzle"):
		var all_pieces = _item_manager.get_puzzle_pieces_for_puzzle(puzzle_id)
		for piece in all_pieces:
			if has_item(piece):
				pieces.append(piece)
	
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

func load_from_backpack(backpack_inventory: Array) -> int:
	"""
	Load items from a found backpack
	
	@param backpack_inventory: Array of item IDs to load
	@return: Number of items successfully loaded
	"""
	var loaded_count = 0
	
	for item in backpack_inventory:
		if add_item(item):
			loaded_count += 1
		else:
			break  # Stop if inventory is full
	
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

# === UI INTEGRATION ===

func show_inventory_ui() -> void:
	"""Show the inventory UI"""
	if not inventory_ui:
		inventory_ui = preload("res://scenes/ui/InventoryUI.tscn").instantiate()
		get_tree().current_scene.add_child(inventory_ui)
		# Connect UI signals
		inventory_ui.item_selected.connect(_on_item_selected_for_inspection)
		inventory_ui.item_selected_for_placement.connect(_on_item_selected_for_placement)
	
	inventory_ui.show_inventory(inventory)

func hide_inventory_ui() -> void:
	"""Hide the inventory UI"""
	if inventory_ui:
		inventory_ui.hide_inventory()

func show_item_inspection(item_id: String) -> void:
	"""Show item inspection view"""
	if not inventory_ui:
		show_inventory_ui()
	
	inventory_ui.show_inspection(item_id)

# === EVENT HANDLERS ===

func _on_item_collected_external(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""Handle external item collection events"""
	if collector and collector.is_in_group("player"):
		if add_item(item_id):
			# Show immediate inspection with proper pause/mouse handling
			_show_auto_inspection(item_id)

func _show_auto_inspection(item_id: String) -> void:
	"""Show auto-inspection when item is collected"""
	if not inventory_ui:
		inventory_ui = preload("res://scenes/ui/InventoryUI.tscn").instantiate()
		get_tree().current_scene.add_child(inventory_ui)
		# Connect UI signals
		inventory_ui.item_selected.connect(_on_item_selected_for_inspection)
		inventory_ui.item_selected_for_placement.connect(_on_item_selected_for_placement)
		inventory_ui.closed.connect(_on_auto_inspection_closed)
	
	# Set mouse visible and pause for inspection
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	
	inventory_ui.show_inspection(item_id)
	
func _on_auto_inspection_closed() -> void:
	"""Handle auto-inspection being closed"""
	# Return mouse to captured and unpause
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false

func _on_item_selected_for_inspection(item_id: String) -> void:
	"""Handle item selected for inspection from UI"""
	show_item_inspection(item_id)

func _on_item_selected_for_placement(item_id: String) -> void:
	"""Handle item selected for puzzle placement"""
	# This will be called by puzzle platforms when they need an item
	# The item is still in inventory until successfully placed
	if _message_bus:
		_message_bus.emit_event("item_selected_for_placement", [item_id])

func _on_game_started() -> void:
	"""Handle game start - clear inventory for new run"""
	clear_inventory()
