extends Node
## Settings Manager - Centralized game settings management
## Handles all game settings including audio, graphics, and controls

var _message_bus: Node
var _save_manager: Node

# Settings data
var _settings: Dictionary = {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0
	},
	"graphics": {
		"fullscreen": false,
		"vsync": true,
		"resolution": Vector2i(1920, 1080)
	},
	"controls": {
		"mouse_sensitivity": 0.003,
		"control_scheme": "keyboard"
	},
	"gameplay": {
		"show_debug": false,
		"accessibility_mode": false
	}
}

const SETTINGS_FILE_PATH: String = "user://settings.json"

func _ready() -> void:
	name = "SettingsManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_save_manager = get_node_or_null("/root/SaveManager")
	
	if not _message_bus:
		push_error("SettingsManager: MessageBus not found")
		return
	
	_load_settings()
	_apply_all_settings()

func get_setting(category: String, key: String) -> Variant:
	"""
	Get a specific setting value
	
	@param category: Settings category (audio, graphics, controls, gameplay)
	@param key: Setting key within category
	@return: Setting value or null if not found
	"""
	if not _settings.has(category):
		push_warning("SettingsManager: Unknown category '%s'" % category)
		return null
	
	if not _settings[category].has(key):
		push_warning("SettingsManager: Unknown setting '%s.%s'" % [category, key])
		return null
	
	return _settings[category][key]

func set_setting(category: String, key: String, value: Variant) -> bool:
	"""
	Set a specific setting value
	
	@param category: Settings category
	@param key: Setting key within category
	@param value: New value to set
	@return: True if setting was changed successfully
	"""
	if not _settings.has(category):
		push_error("SettingsManager: Cannot set unknown category '%s'" % category)
		return false
	
	if not _settings[category].has(key):
		push_error("SettingsManager: Cannot set unknown setting '%s.%s'" % [category, key])
		return false
	
	var old_value = _settings[category][key]
	if old_value == value:
		return false # No change needed
	
	_settings[category][key] = value
	_apply_setting(category, key, value)
	_save_settings()
	
	# Emit change event
	if _message_bus:
		_message_bus.emit_event("setting_changed", [category, key, old_value, value])
	
	return true

func reset_category(category: String) -> bool:
	"""
	Reset all settings in a category to defaults
	
	@param category: Category to reset
	@return: True if category was reset
	"""

	_settings[category] = _settings[category].duplicate(true)
	_apply_category_settings(category)
	_save_settings()
	
	if _message_bus:
		_message_bus.emit_event("settings_category_reset", [category])
	
	return true

func reset_all_settings() -> void:
	"""Reset all settings to defaults"""
	_settings = _settings.duplicate(true)
	_apply_all_settings()
	_save_settings()
	
	if _message_bus:
		_message_bus.emit_event("settings_reset", [])

func _apply_setting(category: String, key: String, value: Variant) -> void:
	"""
	Apply a single setting change to the appropriate system
	
	@param category: Settings category
	@param key: Setting key
	@param value: New value
	"""
	match category:
		"audio":
			_apply_audio_setting(key, value)
		"graphics":
			_apply_graphics_setting(key, value)
		"controls":
			_apply_controls_setting(key, value)
		"gameplay":
			_apply_gameplay_setting(key, value)

func _apply_audio_setting(key: String, value: Variant) -> void:
	"""Apply audio setting changes"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if not audio_manager:
		return
	
	match key:
		"master_volume":
			audio_manager.set_bus_volume("Master", value)
		"music_volume":
			audio_manager.set_bus_volume("Music", value)
		"sfx_volume":
			audio_manager.set_bus_volume("SFX", value)

func _apply_graphics_setting(key: String, value: Variant) -> void:
	"""Apply graphics setting changes"""
	match key:
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
		"resolution":
			if value is Vector2i:
				DisplayServer.window_set_size(value)

func _apply_controls_setting(key: String, value: Variant) -> void:
	"""Apply controls setting changes"""
	var input_manager = get_node_or_null("/root/InputManager")
	if not input_manager:
		return
	
	match key:
		"control_scheme":
			input_manager.set_control_scheme(value)

func _apply_gameplay_setting(key: String, value: Variant) -> void:
	"""Apply gameplay setting changes"""
	match key:
		"show_debug":
			var message_bus = get_node_or_null("/root/MessageBus")
			if message_bus:
				message_bus.set_debug_mode(value)

func _apply_category_settings(category: String) -> void:
	"""Apply all settings in a category"""
	if not _settings.has(category):
		return
	
	for key in _settings[category]:
		_apply_setting(category, key, _settings[category][key])

func _apply_all_settings() -> void:
	"""Apply all settings to their respective systems"""
	for category in _settings:
		_apply_category_settings(category)

func _save_settings() -> void:
	"""Save settings to file"""
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SettingsManager: Could not open settings file for writing")
		return
	
	var save_data = {
		"version": "1.0",
		"settings": _settings,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	file.store_string(JSON.stringify(save_data))
	file.close()

func _load_settings() -> void:
	"""Load settings from file"""
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("SettingsManager: Could not open settings file for reading")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("SettingsManager: Failed to parse settings file")
		return
	
	var data = json.data
	if data.has("settings"):
		# Merge loaded settings with defaults (in case new settings were added)
		_merge_settings(data.settings)
	else:
		push_warning("SettingsManager: Invalid settings file format")

func _merge_settings(loaded_settings: Dictionary) -> void:
	_settings.merge(loaded_settings, true)

# Public API for UI systems

func get_audio_settings() -> Dictionary:
	"""Get all audio settings"""
	return _settings.audio.duplicate()

func get_graphics_settings() -> Dictionary:
	"""Get all graphics settings"""
	return _settings.graphics.duplicate()

func get_controls_settings() -> Dictionary:
	"""Get all control settings"""
	return _settings.controls.duplicate()

func get_gameplay_settings() -> Dictionary:
	"""Get all gameplay settings"""
	return _settings.gameplay.duplicate()

func get_all_settings() -> Dictionary:
	"""Get all settings"""
	return _settings.duplicate(true)
