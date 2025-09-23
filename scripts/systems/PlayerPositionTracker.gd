extends Node
## PlayerPositionTracker - Monitors player movement and detects tile changes
## Emits tile_entered signals when player moves between tiles

@onready var message_bus: Node = get_node_or_null("/root/MessageBus")

var player: Node3D = null
var tile_manager: Node = null
var current_tile_position: Vector2i = Vector2i.ZERO
var previous_tile_position: Vector2i = Vector2i(9999, 9999)
var tile_size: Vector2 = Vector2(20, 20) # Should match tile size

func _ready() -> void:
	name = "PlayerPositionTracker"
	add_to_group("core_systems")
	
	# Wait for scene to be ready, then find player and tile_manager
	call_deferred("_find_player")
	call_deferred("_find_tile_manager")

func _find_player() -> void:
	"""Find the player node in the scene"""
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try again after a short delay
		await get_tree().create_timer(0.1).timeout
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_error("PlayerPositionTracker: Player not found in scene!")
		return
	
	print("PlayerPositionTracker: Player found, starting position tracking")

func _find_tile_manager() -> void:
	"""Find the tile manager from GameControllers"""
	# Try to get it from MessageBus metadata first
	if message_bus and message_bus.has_method("get_manager"):
		tile_manager = message_bus.get_manager("tile_manager")
		if tile_manager:
			print("PlayerPositionTracker: Found TileManager via MessageBus")
			return
	
	# Fallback: try to find it in the scene tree
	var game_scene = get_tree().current_scene
	if game_scene:
		var controllers = game_scene.get_node_or_null("GameControllers")
		if controllers:
			tile_manager = controllers.get_node_or_null("TileManager")
			if tile_manager:
				print("PlayerPositionTracker: Found TileManager via scene tree")
				return
	
	print("PlayerPositionTracker: TileManager not found!")

func _process(delta: float) -> void:
	"""Check player position every frame and detect tile changes"""
	if not player:
		return
	
	var new_tile_position: Vector2i = _world_position_to_tile_position(player.global_position)
	
	# Check if player has moved to a different tile
	if new_tile_position != current_tile_position:
		print("PlayerPositionTracker: _process detected tile change from %s to %s" % [current_tile_position, new_tile_position])
		_handle_tile_change(current_tile_position, new_tile_position)
		previous_tile_position = current_tile_position
		current_tile_position = new_tile_position

func _world_position_to_tile_position(world_pos: Vector3) -> Vector2i:
	"""
	Convert world position to tile grid position
	Assumes tiles are positioned at multiples of tile_size
	"""
	var tile_x: int = int(round(world_pos.x / tile_size.x))
	var tile_z: int = int(round(world_pos.z / tile_size.y))
	
	# Apply world wrapping for 7x7 grid (-3 to 3)
	tile_x = _wrap_coordinate(tile_x)
	tile_z = _wrap_coordinate(tile_z)
	
	return Vector2i(tile_x, tile_z)

func _wrap_coordinate(coord: int) -> int:
	"""Wrap coordinate to 7x7 grid range (-3 to 3)"""
	if coord > 3:
		coord = -3 + (coord - 4)
	elif coord < -3:
		coord = 3 + (coord + 4)
	return coord

func _handle_tile_change(old_tile: Vector2i, new_tile: Vector2i) -> void:
	"""Handle player moving from one tile to another"""
	print("PlayerPositionTracker: Player moved from tile %s to tile %s" % [old_tile, new_tile])
	print("PlayerPositionTracker: tile_manager = %s" % tile_manager)
	print("PlayerPositionTracker: tile_manager has on_player_entered_tile = %s" % (tile_manager.has_method("on_player_entered_tile") if tile_manager else "N/A"))
	
	# First, notify TileManager to spawn new tiles if needed
	if tile_manager and tile_manager.has_method("on_player_entered_tile"):
		tile_manager.on_player_entered_tile(new_tile)
		print("PlayerPositionTracker: Notified TileManager of tile entry at %s" % new_tile)
	else:
		print("PlayerPositionTracker: Cannot notify TileManager - tile_manager=%s, has_method=%s" % [tile_manager, tile_manager.has_method("on_player_entered_tile") if tile_manager else "N/A"])
	
	# Then find the tile node at the new position (after spawning)
	var tile_node: Node3D = _find_tile_at_position(new_tile)
	if not tile_node:
		print("PlayerPositionTracker: No tile found at position %s after spawning attempt" % new_tile)
		return
	
	# Emit tile_entered signal
	if message_bus and message_bus.has_method("emit_event"):
		message_bus.emit_event("tile_entered", [tile_node, new_tile, player])
		print("PlayerPositionTracker: Emitted tile_entered signal for tile %s" % new_tile)

func _find_tile_at_position(tile_pos: Vector2i) -> Node3D:
	"""Find the tile node at the given grid position"""
	# Look for tiles with the correct grid_position metadata
	var maze_container = get_tree().current_scene.get_node_or_null("MazeContainer")
	if not maze_container:
		return null
	
	for child in maze_container.get_children():
		if child is Node3D:
			var node3d: Node3D = child
			if node3d.has_meta("grid_position"):
				var meta_pos: Vector2i = node3d.get_meta("grid_position")
				if meta_pos == tile_pos:
					return node3d
	
	return null

func set_current_tile_position(pos: Vector2i) -> void:
	"""Set the current tile position (used for initialization)"""
	current_tile_position = pos
	previous_tile_position = pos

func get_current_tile_position() -> Vector2i:
	"""Get the current tile position"""
	return current_tile_position
