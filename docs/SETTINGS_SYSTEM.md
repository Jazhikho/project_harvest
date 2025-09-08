# Game Settings System

This document explains how to use the centralized game settings system in Project Harvest.

## Overview

The settings system consists of two main components:

1. **GameSettings.gd** - A Resource class containing all configurable game parameters
2. **SettingsManager.gd** - An autoload singleton that provides global access to settings

## Key Benefits

- **Centralized Configuration**: All game parameters in one place
- **Editor-Friendly**: All settings are exportable and visible in the inspector
- **Runtime Modifiable**: Settings can be changed during gameplay
- **Persistent**: Settings are automatically saved to disk
- **Fallback Safe**: Graceful degradation if settings manager is unavailable

## Usage

### Accessing Settings

```gdscript
# Get the settings manager
var settings_manager = get_node("/root/SettingsManager")

# Access individual settings using convenience methods
var tile_size = settings_manager.get_tile_size()
var player_speed = settings_manager.get_player_speed()
var sanity_max = settings_manager.get_sanity_max()

# Access any setting by name
var maze_size = settings_manager.get_setting("maze_size")
var watcher_spawn_rate = settings_manager.get_watcher_spawn_rate(50)
```

### Modifying Settings

```gdscript
# Update individual settings
settings_manager.update_setting("player_movement_speed", 6.0)
settings_manager.update_setting("tile_size", 25.0)

# Settings are automatically saved when modified
```

### Helper Functions

```gdscript
# Convert between world and grid positions
var world_pos = Vector3(40.0, 0.0, 60.0)
var grid_pos = settings_manager.get_grid_position_from_world(world_pos)
var back_to_world = settings_manager.get_tile_world_position(grid_pos)

# Handle world wrapping
var wrapped_pos = settings_manager.get_wrapped_position(Vector2i(15, 12))

# Get sanity-based spawn rates
var spawn_rate = settings_manager.get_watcher_spawn_rate(75)  # For 75 sanity
```

### Reacting to Settings Changes

```gdscript
func _ready():
    var settings_manager = get_node("/root/SettingsManager")
    if settings_manager:
        settings_manager.settings_changed.connect(_on_settings_changed)

func _on_settings_changed(setting_name: String, new_value):
    match setting_name:
        "player_movement_speed":
            # Update movement system
        "tile_size":
            # Regenerate maze if needed
        "sanity_max":
            # Update UI
```

## Settings Categories

### Tile System
- `tile_size`: Size of each tile in world units
- `grid_size`: Grid cell size for pathfinding
- `tile_cleanup_distance`: Distance for tile cleanup
- `max_active_tiles`: Maximum number of active tiles
- `max_past_tiles`: Maximum number of past tiles

### Player
- `player_movement_speed`: Base movement speed
- `player_sprint_multiplier`: Sprint speed multiplier
- `player_mouse_sensitivity`: Mouse look sensitivity
- `player_health_max`: Maximum health
- `player_move_cooldown`: Movement cooldown time

### Flashlight
- `flashlight_battery_max`: Maximum battery life (seconds)
- `flashlight_drain_rate`: Battery drain per second
- `flashlight_flicker_threshold`: Battery level for flickering
- `flashlight_flicker_chance`: Chance of flicker when low

### Sanity System
- `sanity_max`: Maximum sanity value
- `sanity_min`: Minimum sanity value
- `sanity_passive_decay_rate`: Decay rate per 30 seconds
- `sanity_critical_threshold`: Critical sanity level
- `sanity_visual_distortion_threshold`: Visual effects threshold

### Entity Spawning
- `watcher_spawn_base`: Base watcher spawn rate
- `stalker_spawn_base`: Base stalker spawn rate
- `watcher_spawn_by_sanity`: Array of sanity-based spawn rates

### Stalker
- `stalker_movement_speed`: Patrol movement speed
- `stalker_hunt_speed`: Hunting movement speed
- `stalker_patrol_radius`: Patrol area radius
- `stalker_detection_range`: Player detection range
- `stalker_lose_target_range`: Range to lose target
- `stalker_sanity_drain_range`: Sanity drain proximity
- `stalker_sanity_drain_rate`: Sanity drain amount
- `stalker_spawn_distance_min/max`: Spawn distance range

### Watcher
- `watcher_visibility_duration`: How long watcher stays visible
- `watcher_min/max_distance_from_player`: Spawn distance range
- `watcher_sanity_loss_per_encounter`: Sanity loss when seen
- `watcher_look_detection_threshold`: Look detection sensitivity

### Maze System
- `maze_size`: World map size
- `maze_shift_interval_normal`: Normal maze shift interval
- `maze_shift_interval_stressed`: Stressed maze shift interval
- `maze_world_size`: World wrapping size

### Item Spawning
- `item_spawn_chance`: Chance of item spawning per tile
- `max_notes_available`: Maximum notes available
- `total_puzzles`: Total number of puzzles
- `max_death_locations`: Maximum stored death locations
- `weird_things_min/max`: Weird things count range
- `weird_things_min_distance`: Minimum distance between weird things

### Collision Layers
- `collision_layer_player`: Player collision layer
- `collision_layer_walls`: Wall collision layer
- `collision_layer_objects`: Object collision layer
- `collision_layer_entities`: Entity collision layer

### Audio
- `master_volume`: Master audio volume
- `sfx_volume`: Sound effects volume
- `music_volume`: Music volume
- `voice_volume`: Voice volume

### Debug
- `debug_mode_enabled`: Enable debug mode
- `debug_show_tile_bounds`: Show tile boundaries
- `debug_show_collision_shapes`: Show collision shapes
- `debug_log_level`: Logging verbosity level

### Performance
- `max_fps`: Target FPS
- `vsync_enabled`: Enable VSync
- `shadow_quality`: Shadow quality (0-2)
- `texture_quality`: Texture quality (0-2)

## File Locations

- **Settings Resource**: `scripts/resources/GameSettings.gd`
- **Settings Manager**: `scripts/autoloads/SettingsManager.gd`
- **Example Usage**: `scripts/examples/SettingsExample.gd`
- **Settings File**: `user://game_settings.tres` (auto-generated)

## Integration

The settings system is automatically integrated into all major game systems:

- **Player**: Movement speed, flashlight settings, health
- **Tiles**: Size, cleanup distance, collision layers
- **Entities**: Spawn rates, movement speeds, detection ranges
- **Managers**: Maze size, shift intervals, sanity thresholds

All systems gracefully fall back to hardcoded defaults if the settings manager is unavailable.

## Best Practices

1. **Always check if settings_manager exists** before using it
2. **Use convenience methods** when available (e.g., `get_tile_size()`)
3. **Connect to settings_changed** for reactive systems
4. **Test fallback behavior** when settings manager is unavailable
5. **Group related settings** in your code for better organization

## Future Enhancements

- Settings validation and bounds checking
- Settings presets (Easy, Normal, Hard)
- Runtime settings UI
- Settings import/export
- Settings versioning and migration
