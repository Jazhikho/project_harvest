extends Node
## Weird Things Manager - Handles mysterious artifacts and their effects
## Now integrated with EventManager for unified event system

signal weird_thing_collected(type: String, position: Vector2i)

@export var min_weird_things: int = 5
@export var max_weird_things: int = 10

var weird_things: Array[Dictionary] = []
var collected_count: int = 0

# Reference to EventManager for data-driven behavior
var event_manager: Node

# Pickup ID mapping for integration
var pickup_mapping = {
	"porcelain_doll": "DOLL",
	"music_box": "MUSIC_BOX", 
	"mirror_fragment": "MIRROR",
	"harvest_symbol": "SYMBOL",
	"stopped_watch": "POCKET_WATCH",
	"research_note": "NOTE",
	"family_photo": "PHOTO"
}

func _ready():
	# Connect to EventManager
	await get_tree().process_frame
	_initialize_event_system()

func _initialize_event_system():
	"""Initialize connection to EventManager"""
	event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		# Connect to EventManager signals
		event_manager.pickup_spawned.connect(_on_pickup_spawned)
		event_manager.pickup_given.connect(_on_pickup_given)
		print("WeirdThingsManager: Connected to EventManager")

func place_weird_things():
	"""Place weird things randomly throughout the maze"""
	weird_things.clear()
	collected_count = 0
	
	if not event_manager:
		return
	
	var tile_manager = get_node_or_null("/root/TileManager")
	if not tile_manager:
		return
	
	# Get weird thing pickups from EventManager data
	var pickup_data = event_manager.data.get("pickups", [])
	var weird_pickups = _filter_weird_thing_pickups(pickup_data)
	
	if weird_pickups.is_empty():
		print("WeirdThingsManager: No weird thing pickups found in events.json")
		return
	
	var placement_count = randi_range(min_weird_things, max_weird_things)
	
	for i in range(placement_count):
		var pickup = _select_weighted_pickup(weird_pickups)
		var weird_thing = _create_weird_thing_from_pickup(pickup)
		var position = _find_valid_placement_position()
		
		if position != Vector2i(-1, -1):
			weird_thing["position"] = position
			weird_things.append(weird_thing)

func _filter_weird_thing_pickups(pickups: Array) -> Array:
	"""Filter pickups to only weird things with random_placement"""
	var weird_pickups = []
	for pickup in pickups:
		var spawn_rules = pickup.get("spawn_rules", {})
		if spawn_rules.get("random_placement", false):
			weird_pickups.append(pickup)
	return weird_pickups

func _select_weighted_pickup(pickups: Array) -> Dictionary:
	"""Select a pickup based on weight"""
	var total_weight = 0.0
	for pickup in pickups:
		var spawn_rules = pickup.get("spawn_rules", {})
		total_weight += spawn_rules.get("weight", 1.0)
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for pickup in pickups:
		var spawn_rules = pickup.get("spawn_rules", {})
		current_weight += spawn_rules.get("weight", 1.0)
		if random_value <= current_weight:
			return pickup
	
	return pickups[0] if not pickups.is_empty() else {}

func _create_weird_thing_from_pickup(pickup_data: Dictionary) -> Dictionary:
	"""Create weird thing from EventManager pickup data"""
	var type_str = pickup_mapping.get(pickup_data.get("id", ""), "UNKNOWN")
	
	return {
		"pickup_id": pickup_data.get("id", ""),
		"type": type_str,
		"name": pickup_data.get("name", "Unknown Item"),
		"description": pickup_data.get("desc", "A mysterious object"),
		"messages": pickup_data.get("messages", ["You found something strange..."]),
		"collected": false,
		"position": Vector2i(-1, -1)
	}

func _find_valid_placement_position() -> Vector2i:
	"""Find a valid position to place a weird thing"""
	var tile_manager = get_node_or_null("/root/TileManager")
	if not tile_manager:
		return Vector2i(-1, -1)
	
	# For now, use simple random positioning
	# TODO: Integrate with proper tile system when available
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		var x = randi_range(-50, 50)  # Simple range for now
		var y = randi_range(-50, 50)
		var pos = Vector2i(x, y)
		
		# Check if not too close to other weird things
		if _is_position_valid_for_placement(pos):
			return pos
		
		attempts += 1
	
	return Vector2i(-1, -1)  # Failed to find valid position

func _is_position_valid_for_placement(pos: Vector2i) -> bool:
	"""Check if a position is valid for weird thing placement"""
	# Check if not too close to existing weird things
	for thing in weird_things:
		var distance = pos.distance_to(thing["position"])
		if distance < 5.0:  # Minimum distance between weird things
			return false
	
	return true

func check_collection_at_position(grid_pos: Vector2i) -> Dictionary:
	"""Check if there's a weird thing to collect at given position"""
	for thing in weird_things:
		if thing["position"] == grid_pos and not thing["collected"]:
			return thing
	
	return {}

func collect_weird_thing(thing: Dictionary):
	"""Collect a weird thing and trigger its effects through EventManager"""
	if thing.is_empty() or thing["collected"]:
		return
	
	thing["collected"] = true
	collected_count += 1
	
	# Show message
	var message = thing["messages"][randi() % thing["messages"].size()]
	_show_weird_message(message)
	
	# Process through EventManager if pickup_id exists
	var pickup_id = thing.get("pickup_id", "")
	if pickup_id != "" and event_manager:
		event_manager.give_pickup(pickup_id)
	
	emit_signal("weird_thing_collected", thing["type"], thing["position"])

func _show_weird_message(message: String):
	"""Display weird thing collection message"""
	print("WEIRD THING: ", message)
	
	# TODO: Connect to UI system
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("show_weird_message"):
		ui_manager.show_weird_message(message, 4.0)

# EventManager integration handlers
func _on_pickup_spawned(pickup_id: String):
	"""Handle pickup spawning through EventManager"""
	print("WeirdThingsManager: Pickup spawned - ", pickup_id)

func _on_pickup_given(pickup_id: String):
	"""Handle pickup collection through EventManager"""
	print("WeirdThingsManager: Pickup given - ", pickup_id)

# Bridge methods for EventManager callbacks (needed for some manager connections)
func _on_event_pickup_spawned(pickup_id: String):
	"""EventManager callback for pickup spawning"""
	_on_pickup_spawned(pickup_id)

func _on_event_pickup_given(pickup_id: String):
	"""EventManager callback for pickup collection"""
	_on_pickup_given(pickup_id)

# Public API
func get_collected_count() -> int:
	return collected_count

func get_total_placed() -> int:
	return weird_things.size()

func get_weird_things_in_area(center: Vector2i, radius: int) -> Array:
	"""Get all weird things within a certain radius"""
	var nearby_things = []
	for thing in weird_things:
		if thing["position"].distance_to(center) <= radius:
			nearby_things.append(thing)
	return nearby_things
