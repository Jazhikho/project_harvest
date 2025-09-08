extends Node
## Player Inventory - Manages items the player is carrying

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_full()

@export var max_inventory_size: int = 20

var inventory: Array[String] = []
var event_manager: Node

func _ready():
	event_manager = get_node_or_null("/root/EventManager")
	add_to_group("player_inventory")

func add_item(item_id: String) -> bool:
	"""Add an item to inventory. Returns true if successful"""
	if inventory.size() >= max_inventory_size:
		emit_signal("inventory_full")
		return false
	
	inventory.append(item_id)
	emit_signal("item_added", item_id)
	
	# Sync with EventManager
	if event_manager:
		event_manager.on_item_collected(item_id)
	
	print("Added to inventory: ", item_id, " (", inventory.size(), "/", max_inventory_size, ")")
	return true

func remove_item(item_id: String) -> bool:
	"""Remove an item from inventory. Returns true if item was present"""
	if item_id in inventory:
		inventory.erase(item_id)
		emit_signal("item_removed", item_id)
		print("Removed from inventory: ", item_id)
		return true
	return false

func has_item(item_id: String) -> bool:
	"""Check if player has a specific item"""
	return item_id in inventory

func get_puzzle_pieces() -> Array[String]:
	"""Get all puzzle pieces in inventory"""
	var pieces = []
	for item in inventory:
		if "puzzle" in item.to_lower() or "piece" in item.to_lower():
			pieces.append(item)
	return pieces

func get_inventory() -> Array[String]:
	"""Get current inventory"""
	return inventory.duplicate()

func clear_inventory():
	"""Clear all items from inventory"""
	inventory.clear()

func load_from_backpack(backpack_inventory: Array):
	"""Load items from a found backpack"""
	for item in backpack_inventory:
		if inventory.size() < max_inventory_size:
			add_item(item)
	print("Loaded ", backpack_inventory.size(), " items from backpack")
