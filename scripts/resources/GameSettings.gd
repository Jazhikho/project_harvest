extends Resource
class_name GameSettings
## Game Settings Resource - Centralized configuration for Project Harvest
## All game parameters that should be tweakable in the editor

# === TILE SYSTEM SETTINGS ===
@export_group("Tile System")
@export var tile_size: float = 20.0
@export var grid_size: float = 4.0
@export var tile_cleanup_distance: float = 2.0
@export var max_active_tiles: int = 9
@export var max_past_tiles: int = 1

# === PLAYER SETTINGS ===
@export_group("Player")
@export var player_movement_speed: float = 4.5
@export var player_sprint_multiplier: float = 1.6
@export var player_mouse_sensitivity: float = 0.003
@export var player_health_max: int = 100
@export var player_move_cooldown: float = 0.2

# === FLASHLIGHT SETTINGS ===
@export_group("Flashlight")
@export var flashlight_battery_max: float = 600.0  # 10 minutes max
@export var flashlight_drain_rate: float = 1.0     # per second
@export var flashlight_flicker_threshold: float = 0.2  # 20% battery
@export var flashlight_flicker_chance: float = 0.1     # 10% chance when low

# === SANITY SYSTEM SETTINGS ===
@export_group("Sanity System")
@export var sanity_max: int = 200
@export var sanity_min: int = 0
@export var sanity_passive_decay_rate: float = 1.0  # Points per 30 seconds
@export var sanity_critical_threshold: int = 40
@export var sanity_visual_distortion_threshold: int = 100

# === MAZE SYSTEM SETTINGS ===
@export_group("Maze System")
@export var maze_shift_interval_normal: float = 60.0
@export var maze_shift_interval_stressed: float = 30.0
@export var maze_size: Vector2i = Vector2i(100, 100)
@export var maze_world_size: int = 20  # For wrapping calculations

# === ITEM SPAWNING SETTINGS ===
@export_group("Item Spawning")
@export var item_spawn_chance: float = 0.1
@export var max_notes_available: int = 5
@export var total_puzzles: int = 5
@export var max_death_locations: int = 10
@export var weird_things_min: int = 5
@export var weird_things_max: int = 10
@export var weird_things_min_distance: float = 5.0

# === COLLISION LAYERS ===
@export_group("Collision Layers")
@export var collision_layer_player: int = 1
@export var collision_layer_walls: int = 2
@export var collision_layer_objects: int = 3
@export var collision_layer_entities: int = 4

# === AUDIO SETTINGS ===
@export_group("Audio")
@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
@export var voice_volume: float = 1.0

# === DEBUG SETTINGS ===
@export_group("Debug")
@export var debug_mode_enabled: bool = false
@export var debug_show_tile_bounds: bool = false
@export var debug_show_collision_shapes: bool = false
@export var debug_log_level: int = 1  # 0=Error, 1=Warning, 2=Info, 3=Debug

# === PERFORMANCE SETTINGS ===
@export_group("Performance")
@export var max_fps: int = 60
@export var vsync_enabled: bool = true
@export var shadow_quality: int = 2  # 0=Low, 1=Medium, 2=High
@export var texture_quality: int = 2  # 0=Low, 1=Medium, 2=High

# === HELPER FUNCTIONS ===


func get_sanity_ratio(sanity: int) -> float:
	"""Get sanity as a ratio between 0.0 and 1.0"""
	return float(sanity) / float(sanity_max)

func is_sanity_critical(sanity: int) -> bool:
	"""Check if sanity is in critical range"""
	return sanity <= sanity_critical_threshold

func get_tile_world_position(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to world position"""
	return Vector3(
		grid_pos.x * tile_size,
		0.0,
		grid_pos.y * tile_size
	)

func get_grid_position_from_world(world_pos: Vector3) -> Vector2i:
	"""Convert world position to grid position"""
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.z / tile_size)
	)

func get_wrapped_position(pos: Vector2i) -> Vector2i:
	"""Handle world map wrapping (edges wrap to opposite side)"""
	var wrapped_x = pos.x
	var wrapped_y = pos.y
	
	if pos.x > maze_world_size / 2:
		wrapped_x = -(maze_world_size / 2) + (pos.x - maze_world_size / 2)
	elif pos.x < -(maze_world_size / 2):
		wrapped_x = (maze_world_size / 2) + (pos.x + maze_world_size / 2)
		
	if pos.y > maze_world_size / 2:
		wrapped_y = -(maze_world_size / 2) + (pos.y - maze_world_size / 2)
	elif pos.y < -(maze_world_size / 2):
		wrapped_y = (maze_world_size / 2) + (pos.y + maze_world_size / 2)
	
	return Vector2i(wrapped_x, wrapped_y)
