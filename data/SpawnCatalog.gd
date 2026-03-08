extends Resource
class_name SpawnCatalog

@export var item_scenes: Array[PackedScene]
@export var item_scene_ids: Array[String]
@export var enemy_scenes: Array[PackedScene]
@export var enemy_scene_ids: Array[String]

const LEGACY_ITEM_ID_OVERRIDES := {
	"res://scenes/misc/key.tscn": "hollow_key",
}

func get_item_catalog_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in range(item_scenes.size()):
		var scene: PackedScene = item_scenes[index]
		var item_id: String = _resolve_item_id(scene, index)
		if scene != null and not item_id.is_empty():
			entries.append({
				"id": item_id,
				"scene": scene,
			})
	return entries

func get_enemy_catalog_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in range(enemy_scenes.size()):
		var scene: PackedScene = enemy_scenes[index]
		var enemy_id: String = _resolve_enemy_id(scene, index)
		if scene != null and not enemy_id.is_empty():
			entries.append({
				"id": enemy_id,
				"scene": scene,
			})
	return entries

func _resolve_item_id(scene: PackedScene, index: int) -> String:
	if index < item_scene_ids.size():
		var explicit_id: String = item_scene_ids[index]
		if not explicit_id.is_empty():
			return explicit_id
	if scene == null:
		return ""
	var scene_path: String = scene.resource_path
	if LEGACY_ITEM_ID_OVERRIDES.has(scene_path):
		return LEGACY_ITEM_ID_OVERRIDES[scene_path]
	return scene_path.get_file().get_basename()

func _resolve_enemy_id(scene: PackedScene, index: int) -> String:
	if index < enemy_scene_ids.size():
		var explicit_id: String = enemy_scene_ids[index]
		if not explicit_id.is_empty():
			return explicit_id
	if scene == null:
		return ""
	return scene.resource_path.get_file().get_basename()
