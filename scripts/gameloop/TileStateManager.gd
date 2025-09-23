extends Node
class_name TileStateStore

signal tile_state_changed(tile: Vector2i)
signal tile_visited(tile: Vector2i)

@onready var save_manager: Node = get_node_or_null("/root/SaveManager")
@onready var message_bus: Node = get_node_or_null("/root/MessageBus")

var tiles_state: Dictionary = {} # "x,y" -> { "visited": bool, "opened_doors": PackedStringArray, "items": PackedStringArray, "puzzles": Dictionary }

func _ready() -> void:
	_load_from_save()
	if message_bus != null and message_bus.has_signal("tile_entered"):
		message_bus.tile_entered.connect(_on_tile_entered)

func _on_tile_entered(tile_node: Node3D, position: Vector2i, player: Node3D) -> void:
	mark_visited(position)

func mark_visited(tile: Vector2i) -> void:
	var k: String = _key(tile)
	var state: Dictionary = tiles_state.get(k, {})
	if not bool(state.get("visited", false)):
		state["visited"] = true
		tiles_state[k] = state
		emit_signal("tile_visited", tile)
		emit_signal("tile_state_changed", tile)
		_save_to_save_manager()

func add_opened_door(tile: Vector2i, door_id: String) -> void:
	var k: String = _key(tile)
	var state: Dictionary = tiles_state.get(k, {})
	var arr: PackedStringArray = state.get("opened_doors", PackedStringArray())
	if not arr.has(door_id):
		arr.append(door_id)
		state["opened_doors"] = arr
		tiles_state[k] = state
		emit_signal("tile_state_changed", tile)
		_save_to_save_manager()

func add_collected_item(tile: Vector2i, item_id: String) -> void:
	var k: String = _key(tile)
	var state: Dictionary = tiles_state.get(k, {})
	var arr: PackedStringArray = state.get("items", PackedStringArray())
	if not arr.has(item_id):
		arr.append(item_id)
		state["items"] = arr
		tiles_state[k] = state
		emit_signal("tile_state_changed", tile)
		_save_to_save_manager()

func set_puzzle_flag(tile: Vector2i, key: String, value: bool) -> void:
	var k: String = _key(tile)
	var state: Dictionary = tiles_state.get(k, {})
	var puzzles: Dictionary = state.get("puzzles", {})
	puzzles[key] = value
	state["puzzles"] = puzzles
	tiles_state[k] = state
	emit_signal("tile_state_changed", tile)
	_save_to_save_manager()

func get_tile_state(tile: Vector2i) -> Dictionary:
	return tiles_state.get(_key(tile), {})

# ---- persistence ----
func _load_from_save() -> void:
	if save_manager == null or not save_manager.has_method("get_state"):
		return
	var stored: Variant = save_manager.call("get_state", "tiles_state")
	if typeof(stored) == TYPE_DICTIONARY:
		tiles_state = stored as Dictionary
	else:
		tiles_state = {}

func _save_to_save_manager() -> void:
	if save_manager == null:
		return
	if save_manager.has_method("set_state"):
		save_manager.call("set_state", "tiles_state", tiles_state)

func _key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
