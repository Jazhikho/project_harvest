extends RefCounted
## GameConstants - Central location for all game constants
## Eliminates magic numbers and strings throughout the codebase
## Follows KISS principle by having one source of truth for constants

class_name GameConstants

# === SANITY SYSTEM ===
const MAX_SANITY: int = 100
const MIN_SANITY: int = 0

# Sanity thresholds
const SANITY_THRESHOLD_HIGH: int = 80
const SANITY_THRESHOLD_MEDIUM: int = 60
const SANITY_THRESHOLD_LOW: int = 40
const SANITY_THRESHOLD_CRITICAL: int = 20

# Sanity decay rates
const SANITY_DECAY_NORMAL: float = 0.5
const SANITY_DECAY_STRESSED: float = 1.0
const SANITY_DECAY_PANIC: float = 2.0

# === TILE SYSTEM ===
const TILE_SIZE: float = 20.0
const MAX_TILES_ACTIVE: int = 10
const CLEANUP_DISTANCE: int = 3

# Door directions (bit flags)
enum DoorDirection { 
	NONE = 0,
	NORTH = 1, 
	EAST = 2, 
	SOUTH = 4, 
	WEST = 8,
	ALL = 15
}

# Tile states
enum TileState {
	INACTIVE,
	LOADING,
	ACTIVE,
	CONNECTING,
	PREVIOUS,
	CLEANUP_PENDING
}

# === PLAYER SYSTEM ===
const PLAYER_MOVE_SPEED: float = 5.0
const PLAYER_RUN_SPEED: float = 8.0
const PLAYER_WALK_SPEED: float = 3.0

# Player interaction
const INTERACTION_DISTANCE: float = 3.0
const FLASHLIGHT_RANGE: float = 15.0
const VISION_RANGE: float = 10.0

# === ENEMY SYSTEM ===
# Enemy types
const ENEMY_TYPE_STALKER: String = "stalker"
const ENEMY_TYPE_WATCHER: String = "watcher"
const ENEMY_TYPE_EFFIGY: String = "effigy"

# Enemy spawn cooldowns (seconds)
const ENEMY_SPAWN_COOLDOWN_STALKER: float = 30.0
const ENEMY_SPAWN_COOLDOWN_WATCHER: float = 15.0
const ENEMY_SPAWN_COOLDOWN_EFFIGY: float = 45.0

# Enemy behavior
const ENEMY_DETECTION_RANGE: float = 12.0
const ENEMY_ATTACK_RANGE: float = 2.0
const ENEMY_PATROL_RADIUS: float = 8.0

# Effigy stages
const EFFIGY_STAGE_COUNT: int = 4
const EFFIGY_STAGE_SANITY_THRESHOLDS: Array[int] = [70, 50, 40, 0]

# === AUDIO SYSTEM ===
const AUDIO_BUS_MASTER: String = "Master"
const AUDIO_BUS_MUSIC: String = "Music"
const AUDIO_BUS_SFX: String = "SFX"

# Volume ranges
const VOLUME_MIN: float = 0.0
const VOLUME_MAX: float = 1.0
const VOLUME_DEFAULT: float = 0.8

# === ITEM SYSTEM ===
# Item types
const ITEM_TYPE_WEIRD_THING: String = "weird_thing"
const ITEM_TYPE_RESEARCH_NOTE: String = "research_note"
const ITEM_TYPE_BACKPACK: String = "backpack"

# Item spawn rates
const ITEM_SPAWN_RATE_COMMON: float = 0.7
const ITEM_SPAWN_RATE_UNCOMMON: float = 0.2
const ITEM_SPAWN_RATE_RARE: float = 0.1

# === UI SYSTEM ===
# Screen effects
const SCREEN_EFFECT_FADE_DURATION: float = 1.0
const SCREEN_EFFECT_FLASH_DURATION: float = 0.2
const SCREEN_EFFECT_SHAKE_DURATION: float = 0.5

# Notification durations
const NOTIFICATION_SHORT: float = 2.0
const NOTIFICATION_MEDIUM: float = 4.0
const NOTIFICATION_LONG: float = 6.0

# UI priorities
const UI_PRIORITY_LOW: int = 1
const UI_PRIORITY_MEDIUM: int = 2
const UI_PRIORITY_HIGH: int = 3
const UI_PRIORITY_CRITICAL: int = 4

# === GAME FLOW ===
# Game states
enum GameState {
	MENU,
	LOADING,
	PLAYING,
	PAUSED,
	GAME_OVER,
	CREDITS
}

# Game difficulties
const DIFFICULTY_EASY: String = "easy"
const DIFFICULTY_NORMAL: String = "normal"
const DIFFICULTY_HARD: String = "hard"
const DIFFICULTY_NIGHTMARE: String = "nightmare"

# Game timing
const MAZE_SHIFT_INTERVAL_MIN: float = 30.0
const MAZE_SHIFT_INTERVAL_MAX: float = 120.0
const MAZE_SHIFT_DURATION: float = 3.0

# === FILE PATHS ===
const PATH_EVENTS_DATA: String = "res://data/events.json"
const PATH_ITEMS_DATA: String = "res://data/items.json"
const PATH_SETTINGS_FILE: String = "user://settings.json"
const PATH_SAVE_FILE: String = "user://save_game.json"

# Scene paths
const SCENE_MAIN_MENU: String = "res://scenes/ui/MainMenu.tscn"
const SCENE_GAME: String = "res://scenes/game/Game.tscn"
const SCENE_PAUSE_MENU: String = "res://scenes/ui/PauseMenu.tscn"

# Tile scene paths
const SCENE_START_TILE: String = "res://scenes/tiles/start_tile.tscn"
const SCENE_FINAL_TILE: String = "res://scenes/tiles/final_event_tile.tscn"

# === ERROR MESSAGES ===
const ERROR_SYSTEM_NOT_FOUND: String = "Required system not found: %s"
const ERROR_INVALID_PARAMETER: String = "Invalid parameter: %s"
const ERROR_FILE_NOT_FOUND: String = "File not found: %s"
const ERROR_INITIALIZATION_FAILED: String = "Initialization failed for: %s"

# === PHYSICS ===
# Collision layers (bit positions)
const COLLISION_LAYER_WORLD: int = 1
const COLLISION_LAYER_PLAYER: int = 2
const COLLISION_LAYER_ENEMIES: int = 3
const COLLISION_LAYER_ITEMS: int = 4
const COLLISION_LAYER_TRIGGERS: int = 5

# === PERFORMANCE ===
const MAX_ENTITIES_PER_TILE: int = 5
const MAX_ITEMS_PER_TILE: int = 3
const MAX_HISTORY_ENTRIES: int = 50
const CLEANUP_INTERVAL: float = 5.0

# === DEVELOPMENT ===
const DEBUG_TILE_LABELS: bool = false
const DEBUG_ENEMY_PATHS: bool = false
const DEBUG_COLLISION_SHAPES: bool = false
const VERBOSE_LOGGING: bool = false

# Helper functions for common calculations
static func sanity_to_stage(sanity: int) -> int:
	"""Convert sanity value to effigy stage number"""
	for i in range(EFFIGY_STAGE_SANITY_THRESHOLDS.size()):
		if sanity >= EFFIGY_STAGE_SANITY_THRESHOLDS[i]:
			return i + 1
	return EFFIGY_STAGE_COUNT

static func get_door_direction_name(direction: DoorDirection) -> String:
	"""Get human-readable name for door direction"""
	match direction:
		DoorDirection.NORTH: return "North"
		DoorDirection.EAST: return "East"
		DoorDirection.SOUTH: return "South"
		DoorDirection.WEST: return "West"
		_: return "Unknown"

static func get_opposite_door_direction(direction: DoorDirection) -> DoorDirection:
	"""Get opposite door direction"""
	match direction:
		DoorDirection.NORTH: return DoorDirection.SOUTH
		DoorDirection.EAST: return DoorDirection.WEST
		DoorDirection.SOUTH: return DoorDirection.NORTH
		DoorDirection.WEST: return DoorDirection.EAST
		_: return DoorDirection.NONE

static func clamp_sanity(value: int) -> int:
	"""Clamp sanity value to valid range"""
	return clampi(value, MIN_SANITY, MAX_SANITY)

static func linear_to_db_clamped(linear: float) -> float:
	"""Convert linear volume to dB with proper clamping"""
	linear = clampf(linear, VOLUME_MIN, VOLUME_MAX)
	return linear_to_db(linear) if linear > 0.0 else -80.0
