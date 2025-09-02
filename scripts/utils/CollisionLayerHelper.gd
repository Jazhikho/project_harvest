extends Node
## Helper script to set up collision layers for existing tile scenes

# Call this function on a tile scene to set up proper collision layers
static func setup_tile_collision_layers(tile_node: Node3D):
	"""Set up collision layers for a tile - walls on layer 2"""
	_set_walls_collision_layer(tile_node, 2)

# Recursively find and set collision layers for all StaticBody3D nodes (walls)
static func _set_walls_collision_layer(node: Node, layer: int):
	if node is StaticBody3D:
		# This is a wall - set it to layer 2
		node.collision_layer = layer
		node.collision_mask = 0  # Walls don't need to detect anything
		print("Set wall collision layer: ", node.get_path())
	
	# Recursively process children
	for child in node.get_children():
		_set_walls_collision_layer(child, layer)

# Helper function to setup all collision layers in the scene
static func setup_all_collision_layers():
	"""Setup collision layers for common game objects"""
	print("Setting up collision layers...")
	
	# Find and setup player
	var player = Engine.get_main_loop().get_first_node_in_group("player")
	if player and player is CharacterBody3D:
		player.collision_layer = 1  # Layer 1: player
		player.collision_mask = 2   # Mask 2: walls
		print("Setup player collision layers")
	
	# Find and setup all tiles
	var maze_container = Engine.get_main_loop().current_scene.get_node_or_null("MazeContainer")
	if maze_container:
		for child in maze_container.get_children():
			setup_tile_collision_layers(child)
		print("Setup tile collision layers")
