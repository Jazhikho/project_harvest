extends Node
## Example script showing how to use the GameSettings system
## This demonstrates how to access and modify settings at runtime

func _ready():
	# Wait for SettingsManager to initialize
	await get_tree().process_frame
	
	# Example 1: Accessing settings
	_demonstrate_settings_access()
	
	# Example 2: Modifying settings at runtime
	_demonstrate_settings_modification()
	
	# Example 3: Using helper functions
	_demonstrate_helper_functions()

func _demonstrate_settings_access():
	"""Show how to access individual settings"""
	
	# Get the settings manager
	var settings_manager = get_node("/root/SettingsManager")
	if not settings_manager:
		return
	
	# Access individual settings
	var tile_size = settings_manager.get_tile_size()
	var player_speed = settings_manager.get_player_speed()
	var sanity_max = settings_manager.get_sanity_max()
	
	pass
	
	# Access settings by name
	var maze_size = settings_manager.get_setting("maze_size")
	var watcher_spawn_rate = settings_manager.get_watcher_spawn_rate(50)  # For 50 sanity
	
	pass

func _demonstrate_settings_modification():
	"""Show how to modify settings at runtime"""
	
	var settings_manager = get_node("/root/SettingsManager")
	if not settings_manager:
		return
	
	# Modify individual settings
	var success = settings_manager.update_setting("player_movement_speed", 6.0)
	if success:
		pass
	else:
		pass
	
	# Modify multiple settings
	settings_manager.update_setting("tile_size", 25.0)
	settings_manager.update_setting("maze_shift_interval_normal", 45.0)
	
	pass

func _demonstrate_helper_functions():
	"""Show how to use helper functions for common operations"""
	
	var settings_manager = get_node("/root/SettingsManager")
	if not settings_manager:
		return
	
	# Convert between world and grid positions
	var world_pos = Vector3(40.0, 0.0, 60.0)
	var grid_pos = settings_manager.get_grid_position_from_world(world_pos)
	var back_to_world = settings_manager.get_tile_world_position(grid_pos)
	
	pass
	
	# Handle world wrapping
	var wrapped_pos = settings_manager.get_wrapped_position(Vector2i(15, 12))
	pass
	
	# Get sanity-based spawn rates
	for sanity in [100, 75, 50, 25, 0]:
		var spawn_rate = settings_manager.get_watcher_spawn_rate(sanity)
		pass

func _on_settings_changed(setting_name: String, new_value):
	"""Handle settings change events"""
	
	# You can react to specific setting changes here
	match setting_name:
		"player_movement_speed":
			pass
		"tile_size":
			pass
		"sanity_max":
			pass

# Example of connecting to settings change events
func _connect_to_settings_events():
	var settings_manager = get_node("/root/SettingsManager")
	if settings_manager:
		settings_manager.settings_changed.connect(_on_settings_changed)
