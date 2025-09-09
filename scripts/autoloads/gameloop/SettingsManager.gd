extends Node
## Settings Manager - Global access to game settings
## Provides a centralized way to access and modify game configuration

signal settings_changed(setting_name: String, new_value)

var settings: GameSettings
var settings_file_path: String = "user://game_settings.tres"

func _ready():
	_load_settings()

func _load_settings():
	"""Load settings from file or create default"""
	if FileAccess.file_exists(settings_file_path):
		settings = load(settings_file_path) as GameSettings
		if not settings:
			push_error("SettingsManager: Failed to load settings file, creating default")
			_create_default_settings()
	else:
		_create_default_settings()

func _create_default_settings():
	"""Create default settings and save them"""
	settings = GameSettings.new()
	_save_settings()

func _save_settings():
	"""Save current settings to file"""
	var error = ResourceSaver.save(settings, settings_file_path)
	if error != OK:
		push_error("SettingsManager: Failed to save settings - Error: " + str(error))

func get_settings() -> GameSettings:
	"""Get the current settings resource"""
	return settings

func update_setting(setting_name: String, value) -> bool:
	"""Update a specific setting by name"""
	if not settings:
		push_error("SettingsManager: No settings loaded")
		return false
	
	# Use reflection to set the property
	if settings.has_method("set") and settings.get(setting_name) != null:
		settings.set(setting_name, value)
		emit_signal("settings_changed", setting_name, value)
		_save_settings()
		return true
	else:
		push_error("SettingsManager: Setting '" + setting_name + "' not found or not settable")
		return false

func get_setting(setting_name: String):
	"""Get a specific setting by name"""
	if not settings:
		push_error("SettingsManager: No settings loaded")
		return null
	
	if settings.has_method("get") and settings.get(setting_name) != null:
		return settings.get(setting_name)
	else:
		push_error("SettingsManager: Setting '" + setting_name + "' not found")
		return null

func reset_to_defaults():
	"""Reset all settings to default values"""
	_create_default_settings()
	emit_signal("settings_changed", "all", null)

# === CONVENIENCE GETTERS ===

func get_tile_size() -> float:
	return settings.tile_size

func get_grid_size() -> float:
	return settings.grid_size

func get_player_speed() -> float:
	return settings.player_movement_speed

func get_sanity_max() -> int:
	return settings.sanity_max

func get_sanity_min() -> int:
	return settings.sanity_min

func get_watcher_spawn_rate(sanity: int) -> float:
	return settings.get_watcher_spawn_rate_for_sanity(sanity)

func get_tile_world_position(grid_pos: Vector2i) -> Vector3:
	return settings.get_tile_world_position(grid_pos)

func get_grid_position_from_world(world_pos: Vector3) -> Vector2i:
	return settings.get_grid_position_from_world(world_pos)

func get_wrapped_position(pos: Vector2i) -> Vector2i:
	return settings.get_wrapped_position(pos)

# === DEBUG FUNCTIONS ===

func print_all_settings():
	"""Print all current settings (for debugging)"""
	if not settings:
		print("SettingsManager: No settings loaded")
		return
	
	print("=== GAME SETTINGS ===")
	print("Tile Size: ", settings.tile_size)
	print("Grid Size: ", settings.grid_size)
	print("Player Speed: ", settings.player_movement_speed)
	print("Sanity Max: ", settings.sanity_max)
	print("Maze Shift Normal: ", settings.maze_shift_interval_normal)
	print("Maze Shift Stressed: ", settings.maze_shift_interval_stressed)
	print("=====================")
