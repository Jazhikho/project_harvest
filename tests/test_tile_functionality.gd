# Test script to demonstrate tile functionality
# Add this to a node in your scene to test the tile system

extends Node

func _ready():
	# Wait a frame for tiles to initialize
	await get_tree().process_frame
	test_tile_functionality()

func test_tile_functionality():
	print("\n=== Testing Tile Functionality ===")
	
	# Find the CrossTile2 in the scene
	var tile = get_node_or_null("/root/CrossTile2")
	if not tile:
		tile = get_tree().get_first_node_in_group("tiles")  # Alternative lookup
	
	if not tile:
		print("ERROR: Could not find tile to test!")
		return
	
	print("Found tile: ", tile.name)
	
	# Test 1: Show initial state
	print("\n--- Initial State ---")
	tile.debug_tile_info()
	
	# Test 2: Test door detection
	print("\n--- Door Detection Test ---")
	print("Available doors: ", tile.get_door_list())
	print("Has North door: ", tile.has_door(tile.DoorDirection.NORTH))
	print("Has East door: ", tile.has_door(tile.DoorDirection.EAST))
	print("Has South door: ", tile.has_door(tile.DoorDirection.SOUTH))
	print("Has West door: ", tile.has_door(tile.DoorDirection.WEST))
	
	# Test 3: Test rotation
	print("\n--- Rotation Test ---")
	print("Original rotation: ", tile.current_rotation * 90, "°")
	
	tile.rotate_tile_clockwise()
	print("After 90° clockwise:")
	tile.debug_tile_info()
	
	tile.rotate_tile_clockwise()
	print("After 180° total:")
	tile.debug_tile_info()
	
	# Reset to original position
	tile.set_tile_rotation(0)
	print("Reset to 0°:")
	tile.debug_tile_info()
	
	# Test 4: Door positions and orientations
	print("\n--- Door Position/Orientation Test ---")
	var available_doors = tile.get_available_doors()
	for direction in available_doors:
		var door_data = available_doors[direction]
		print("Door ", tile.get_direction_name(direction), ":")
		print("  World Position: ", door_data.world_position)
		print("  World Orientation: ", door_data.world_orientation)
	
	print("\n=== Test Complete ===\n")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		test_tile_functionality()
	elif event.is_action_pressed("ui_right"):  # Right arrow
		var tile = get_node_or_null("/root/CrossTile2")
		if tile:
			tile.rotate_tile_clockwise()
	elif event.is_action_pressed("ui_left"):  # Left arrow  
		var tile = get_node_or_null("/root/CrossTile2")
		if tile:
			tile.rotate_tile_counter_clockwise()
