extends Node3D
class_name TileBase
## TileBase
## Minimal, explicit API for TileManager and friends:
## - Door discovery by cardinal direction
## - Handles references to Item and Entity spawn controllers
## - Consistent state flags for active/connecting/past tiles
##
## Scene expectations (default names used if NodePaths not assigned):
##   Maze/Doors         (Node3D containing NDoor, SDoor, EDoor, WDoor markers)
##   Maze/ItemSpawn     (Node3D with ItemSpawnController.gd attached)
##   Maze/EntitySpawn   (Node3D with EntitySpawnController.gd attached)

# -------------------------
# Enums & Signals
# -------------------------

enum DoorDirection { NORTH = 0, SOUTH = 1, EAST = 2, WEST = 3 }

signal tile_became_active
signal tile_became_connecting
signal tile_became_past

# -------------------------
# Configuration
# -------------------------

@export var tile_id: StringName = &""                    # optional identifier for saves/debug
@export_node_path("Node3D") var doors_root_path: NodePath
@export_node_path("Node3D") var item_spawn_root_path: NodePath
@export_node_path("Node3D") var entity_spawn_root_path: NodePath

# -------------------------
# Cached references
# -------------------------

var _doors_root: Node3D = null
var _item_spawn: Node3D = null
var _entity_spawn: Node3D = null

var _north_door: Node3D = null
var _south_door: Node3D = null
var _east_door: Node3D = null
var _west_door: Node3D = null

# -------------------------
# State flags
# -------------------------

var is_active_tile: bool = false
var is_connecting_tile: bool = false
var is_past_tile: bool = false

# =========================
# Internal helpers (first)
# =========================

func _get_or_default(path: NodePath, fallback: String) -> Node:
	"""Return node at path or fallback, or null."""
	if path != NodePath():
		var n1: Node = get_node_or_null(path)
		if n1 != null:
			return n1
	var n2: Node = get_node_or_null(fallback)
	return n2

func _cache_doors() -> void:
	"""Locate door markers under doors_root by conventional names."""
	_north_door = null
	_south_door = null
	_east_door  = null
	_west_door  = null
	
	if _doors_root == null:
		return
	
	_north_door = _doors_root.get_node_or_null("NDoor") as Node3D
	_south_door = _doors_root.get_node_or_null("SDoor") as Node3D
	_east_door  = _doors_root.get_node_or_null("EDoor") as Node3D
	_west_door  = _doors_root.get_node_or_null("WDoor") as Node3D

func _resolve_children() -> void:
	"""Resolve standard subnodes with sensible defaults."""
	_doors_root  = _get_or_default(doors_root_path, "Maze/Doors") as Node3D
	_item_spawn  = _get_or_default(item_spawn_root_path, "Maze/ItemSpawn") as Node3D
	_entity_spawn = _get_or_default(entity_spawn_root_path, "Maze/EntitySpawn") as Node3D
	_cache_doors()

# =========================
# Lifecycle
# =========================

func _ready() -> void:
	"""Cache standard children on ready."""
	_resolve_children()
	add_to_group("tile")

# =========================
# Public API: Doors
# =========================

func get_available_doors() -> PackedInt32Array:
	"""
	Return a list of available door directions on this tile.
	Directions are values from DoorDirection enum.
	"""
	var dirs: PackedInt32Array = PackedInt32Array()
	if _north_door != null:
		dirs.append(DoorDirection.NORTH)
	if _south_door != null:
		dirs.append(DoorDirection.SOUTH)
	if _east_door != null:
		dirs.append(DoorDirection.EAST)
	if _west_door != null:
		dirs.append(DoorDirection.WEST)
	return dirs

func has_door(direction: int) -> bool:
	"""Return true if the given door direction exists on this tile."""
	if direction == DoorDirection.NORTH and _north_door != null:
		return true
	if direction == DoorDirection.SOUTH and _south_door != null:
		return true
	if direction == DoorDirection.EAST and _east_door != null:
		return true
	if direction == DoorDirection.WEST and _west_door != null:
		return true
	return false

func get_door_marker(direction: int) -> Node3D:
	"""
	Return the Node3D marker for a given direction, or null.
	TileManager uses this transform to place/align neighbors.
	"""
	if direction == DoorDirection.NORTH:
		return _north_door
	if direction == DoorDirection.SOUTH:
		return _south_door
	if direction == DoorDirection.EAST:
		return _east_door
	if direction == DoorDirection.WEST:
		return _west_door
	return null

func get_all_door_markers() -> Dictionary:
	"""
	Return a dictionary mapping DoorDirection -> Node3D for all present doors.
	Keys are ints from DoorDirection enum.
	"""
	var d: Dictionary = {}
	if _north_door != null:
		d[DoorDirection.NORTH] = _north_door
	if _south_door != null:
		d[DoorDirection.SOUTH] = _south_door
	if _east_door != null:
		d[DoorDirection.EAST] = _east_door
	if _west_door != null:
		d[DoorDirection.WEST] = _west_door
	return d

# =========================
# Public API: Spawns
# =========================

func get_item_spawn_controller() -> Node:
	"""
	Return the ItemSpawnController on Maze/ItemSpawn, or the node itself.
	Controller is expected to provide:
	  - get_points() -> Array[Node3D]
	  - spawn_item_at(index: int, scene: PackedScene) -> Node3D
	"""
	if _item_spawn == null:
		return null
	return _item_spawn

func get_entity_spawn_controller() -> Node:
	"""
	Return the EntitySpawnController on Maze/EntitySpawn, or the node itself.
	Controller is expected to provide:
	  - get_points() -> Array[Node3D]
	  - spawn_at(index: int, scene: PackedScene) -> Node3D
	"""
	if _entity_spawn == null:
		return null
	return _entity_spawn

# =========================
# Public API: Tile state
# =========================

func set_as_active_tile() -> void:
	"""Mark this tile as the current active tile."""
	is_active_tile = true
	is_connecting_tile = false
	is_past_tile = false
	emit_signal("tile_became_active")

func set_as_connecting_tile() -> void:
	"""Mark this tile as a temporary connector for the active tile."""
	is_active_tile = false
	is_connecting_tile = true
	is_past_tile = false
	emit_signal("tile_became_connecting")

func set_as_past_tile() -> void:
	"""Mark this tile as previously visited and no longer active."""
	is_active_tile = false
	is_connecting_tile = false
	is_past_tile = true
	emit_signal("tile_became_past")

func get_tile_state() -> Dictionary:
	"""Return a compact dictionary describing this tile's current role."""
	return {
		"active": is_active_tile,
		"connecting": is_connecting_tile,
		"past": is_past_tile
	}

# =========================
# Editor helpers (optional)
# =========================

func refresh_cached_nodes() -> void:
	"""
	Editor-time helper for re-caching after you rename/move subnodes.
	Safe to call at runtime if needed.
	"""
	_resolve_children()
