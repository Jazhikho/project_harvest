extends SceneTree

var _failed: bool = false

class FakeTileStateManager:
	extends Node

	var cleaned_positions: Array[Vector2i] = []

	func cleanup_tile(position: Vector2i) -> void:
		cleaned_positions.append(position)

	func register_tile(_tile_node: Node3D, _position: Vector2i, _initial_state: int) -> void:
		pass

	func set_tile_state(_position: Vector2i, _new_state: int) -> bool:
		return true

	func get_tile_node(_position: Vector2i) -> Node3D:
		return null

class FakeSourceTile:
	extends Node3D

	var _door_direction: int = 0

	func configure(door_direction: int) -> void:
		_door_direction = door_direction

	func get_available_doors() -> Dictionary:
		return {_door_direction: true}

func _initialize() -> void:
	_assert_stale_established_connection_is_purged()
	_assert_invalid_reference_cleanup_notifies_tile_state_manager()

	if _failed:
		printerr("test_tile_manager_ghost_connection: FAIL")
		quit(1)
		return

	print("test_tile_manager_ghost_connection: PASS")
	quit(0)

func _assert_stale_established_connection_is_purged() -> void:
	var manager: Node = load("res://scripts/autoloads/gameloop/TileManager.gd").new()
	var fake_tile_state_manager: FakeTileStateManager = FakeTileStateManager.new()
	manager.set("_tile_state_manager", fake_tile_state_manager)

	var source_pos: Vector2i = Vector2i.ZERO
	var connecting_pos: Vector2i = Vector2i(1, 0)
	manager._establish_connection(source_pos, connecting_pos)

	var stale_tile: Node3D = Node3D.new()
	stale_tile.free()
	manager.set("_active_tiles", {connecting_pos: stale_tile})

	var source_tile: FakeSourceTile = FakeSourceTile.new()
	source_tile.configure(manager.DoorDirection.NORTH)
	source_tile.position = Vector3.ZERO

	manager._spawn_tile_connections(source_tile, source_pos)

	if manager._is_connection_established(source_pos, connecting_pos):
		_fail("Expected stale established connection to be purged before spawn skip")
	elif manager.get("_active_tiles").has(connecting_pos):
		_fail("Expected stale active tile entry to be removed during ghost connection recovery")
	elif connecting_pos not in fake_tile_state_manager.cleaned_positions:
		_fail("Expected TileStateManager cleanup for stale ghost connection position")

	source_tile.free()
	fake_tile_state_manager.free()
	manager.free()

func _assert_invalid_reference_cleanup_notifies_tile_state_manager() -> void:
	var manager: Node = load("res://scripts/autoloads/gameloop/TileManager.gd").new()
	var fake_tile_state_manager: FakeTileStateManager = FakeTileStateManager.new()
	manager.set("_tile_state_manager", fake_tile_state_manager)

	var invalid_pos: Vector2i = Vector2i(2, 2)
	var stale_tile: Node3D = Node3D.new()
	stale_tile.free()
	manager.set("_active_tiles", {invalid_pos: stale_tile})

	manager.cleanup_invalid_tile_references()

	if manager.get("_active_tiles").has(invalid_pos):
		_fail("Expected invalid active tile reference to be removed")
	elif invalid_pos not in fake_tile_state_manager.cleaned_positions:
		_fail("Expected cleanup_invalid_tile_references to notify TileStateManager")

	fake_tile_state_manager.free()
	manager.free()

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
