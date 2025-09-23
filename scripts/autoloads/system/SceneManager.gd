extends Node

signal scene_will_change(new_path: String)
signal scene_changed(new_path: String)

const GAME_SCENE: PackedScene = preload("res://scenes/game/Game.tscn")
const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/DeathScreen.tscn")

const MAIN_MENU_SCENE_PATH := "res://Main.tscn"

var _current_scene_path: String = ""

func _ready() -> void:
	name = "SceneManager"
	add_to_group("core_systems")

# ── Public API ────────────────────────────────────────────────────────────────

func start_new_game(payload: Dictionary = {}) -> void:
	_change_to_packed(GAME_SCENE, "res://scenes/game/Game.tscn", payload)

func go_to_main_menu(payload: Dictionary = {}) -> void:
	if MAIN_MENU_SCENE_PATH.is_empty():
		_log_error("go_to_main_menu called but MAIN_MENU_SCENE_PATH is empty. Set the path or remove this call.")
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		_log_error("Main menu scene not found at %s" % MAIN_MENU_SCENE_PATH)
		return
	var packed := ResourceLoader.load(MAIN_MENU_SCENE_PATH)
	_change_to_packed(packed, MAIN_MENU_SCENE_PATH, payload)

func load_death_screen(death_type: String, extra: Dictionary = {}) -> void:
	# Store any payload via SceneTree metadata so we don’t fight typed APIs elsewhere
	get_tree().set_meta("death_type", death_type)
	for k in extra.keys():
		get_tree().set_meta(k, extra[k])
	_change_to_packed(DEATH_SCREEN_SCENE, "res://scenes/ui/DeathScreen.tscn", {})

func load_main_menu(payload: Dictionary = {}) -> void:
	go_to_main_menu(payload)

# ── Internals ────────────────────────────────────────────────────────────────

func _change_to_packed(packed: PackedScene, debug_path: String, payload: Dictionary) -> void:
	if packed == null:
		_log_error("Failed to load scene: %s" % debug_path)
		return

	emit_signal("scene_will_change", debug_path)

	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_log_error("change_scene_to_packed failed for %s (err=%d)" % [debug_path, err])
		return

	_current_scene_path = debug_path
	emit_signal("scene_changed", debug_path)

# ── Logging helpers ──────────────────────────────────────────────────────────

func _log_error(msg: String) -> void:
	push_error("SceneManager: %s" % msg)
