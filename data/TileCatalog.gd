@tool
class_name TileDatabase
extends Resource

@export var normal_tile_scenes: Array[PackedScene]
@export var four_door_tile_scenes: Array[PackedScene]
@export var three_door_tile_scenes: Array[PackedScene]
@export var corner_tile_scenes: Array[PackedScene]
@export var straight_tile_scenes: Array[PackedScene]
@export var permanent_tile_scenes: Array[PackedScene]
@export var permanent_tile_puzzle_ids: Array[String]

func get_permanent_tile_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var count := mini(permanent_tile_scenes.size(), permanent_tile_puzzle_ids.size())
	for index in range(count):
		var tile_scene: PackedScene = permanent_tile_scenes[index]
		if tile_scene == null:
			continue
		entries.append({
			"scene": tile_scene,
			"puzzle_id": permanent_tile_puzzle_ids[index],
		})
	return entries
