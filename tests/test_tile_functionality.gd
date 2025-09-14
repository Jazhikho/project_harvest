# Test script to demonstrate tile functionality

extends Node

func _ready():
	# Wait a frame for tiles to initialize
	await get_tree().process_frame
	test_tile_functionality()

func test_tile_functionality():
	# Find the CrossTile2 in the scene
	var tile = get_node_or_null("/root/CrossTile2")
	if not tile:
		tile = get_tree().get_first_node_in_group("tiles")  # Alternative lookup
	
	if not tile:
		return
	
	# Initial state
	tile.debug_tile_info()
	
	# Door detection
	tile.get_door_list()
	tile.has_door(tile.DoorDirection.NORTH)
	tile.has_door(tile.DoorDirection.EAST)
	tile.has_door(tile.DoorDirection.SOUTH)
	tile.has_door(tile.DoorDirection.WEST)
	
	# Rotation
	tile.rotate_tile_clockwise()
	tile.debug_tile_info()
	
	tile.rotate_tile_clockwise()
	tile.debug_tile_info()
	
	# Reset to original position
	tile.set_tile_rotation(0)
	tile.debug_tile_info()
	
	# Door positions and orientations
	var available_doors = tile.get_available_doors()
	for direction in available_doors:
		var door_data = available_doors[direction]
		tile.get_direction_name(direction)

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
