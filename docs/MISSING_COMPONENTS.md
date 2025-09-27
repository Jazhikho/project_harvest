# Missing Game Components Structure

This document outlines the structure and requirements for game components that are referenced in the code but not yet implemented.

## Table of Contents
- [Entity Management Systems](#entity-management-systems)
- [Tile Scene Structure](#tile-scene-structure)
- [Item Scenes](#item-scenes)
- [Puzzle System](#puzzle-system)
- [Audio Integration](#audio-integration)
- [UI Components](#ui-components)

---

## Entity Management Systems

### EnemyManager (Referenced but Missing)
**Location:** `scripts/autoloads/gameloop/EnemyManager.gd`
**Purpose:** Centralized management of enemy entities (Stalkers, Watchers)

```gdscript
extends Node
## Enemy Manager - Handles enemy spawning, behavior coordination, and lifecycle

var _message_bus: Node
var _state_manager: Node
var _active_enemies: Dictionary = {}  # entity_id -> entity_node
var _enemy_spawn_cooldowns: Dictionary = {}

func _ready() -> void:
    name = "EnemyManager"
    add_to_group("game_systems")
    call_deferred("_initialize")

# Key Methods to implement:
func spawn_enemy(enemy_type: String, position: Vector3) -> Node3D
func despawn_enemy(entity_id: String) -> void
func get_enemies_in_range(position: Vector3, radius: float) -> Array[Node3D]
func set_enemy_aggression_level(level: float) -> void
```

### EffigyManager (Referenced but Missing)
**Location:** `scripts/autoloads/gameloop/EffigyManager.gd`
**Purpose:** Manages effigy spawning and behavior based on death locations

```gdscript
extends Node
## Effigy Manager - Handles effigy creation and management

var _effigy_locations: Dictionary = {}  # Vector2i -> effigy_data
var _effigy_scene: PackedScene = preload("res://scenes/entities/effigy.tscn")

# Key Methods to implement:
func spawn_effigy_at_death_location(death_data: Dictionary) -> void
func update_effigy_stages_for_sanity(sanity: int) -> void
func cleanup_old_effigies() -> void
```

---

## Tile Scene Structure

All tile scenes should follow this structure for compatibility with the TileManager:

### Required Node Structure
```
TileRoot (Node3D)
├── Maze (Node3D)
│   ├── Walls (StaticBody3D with CollisionShape3D children)
│   ├── Floor (MeshInstance3D)
│   ├── SpawnPoints (Node3D)
│   │   ├── ItemSpawn1 (Marker3D)
│   │   ├── ItemSpawn2 (Marker3D)
│   │   └── EntitySpawn1 (Marker3D)
│   └── Doors (Node3D)
│       ├── NorthDoor (Area3D) [optional]
│       ├── EastDoor (Area3D) [optional]
│       ├── SouthDoor (Area3D) [optional]
│       └── WestDoor (Area3D) [optional]
└── [Optional special features]
```

### Required Tile Script Methods
```gdscript
extends Node3D
## Base Tile Script - All tiles must implement these methods

func get_available_doors() -> Dictionary:
    """Return dictionary of door_direction -> door_node"""
    # Example: {TileManager.DoorDirection.NORTH: north_door}
    
func is_tile_permanent() -> bool:
    """Return true if this is a puzzle/permanent tile"""
    return false  # Override in permanent tiles

func get_puzzle_id() -> String:
    """Return puzzle ID if this is a puzzle tile"""
    return ""  # Override in puzzle tiles

# Optional methods for tile state management:
func set_as_active_tile() -> void
func set_as_connecting_tile() -> void
func set_as_past_tile() -> void
```

### Tile Categories Needed

#### Basic Navigation Tiles
- `start_tile.tscn` - Player spawn point (MUST exist)
- `straight_tile.tscn` - Straight corridor
- `corner_tile.tscn` - 90-degree turn
- `t_junction_tile.tscn` - Three-way intersection
- `cross_tile.tscn` - Four-way intersection
- `dead_end_tile.tscn` - Single entrance

#### Special Event Tiles (from events.json)
- `scarecrow_crossroads.tscn` - Scarecrow orientation puzzle
- `watching_stones.tscn` - Stone sequence puzzle
- `whispering_hallow.tscn` - Choir phrase puzzle
- `murder_of_crows.tscn` - Crow arithmetic puzzle
- `bone_circle.tscn` - Final true name puzzle
- `final_event_tile.tscn` - Game ending tile

---

## Item Scenes

### Item Scene Structure
```
ItemRoot (RigidBody3D or StaticBody3D)
├── Mesh (MeshInstance3D)
├── Collision (CollisionShape3D)
├── PickupArea (Area3D)
│   └── PickupCollision (CollisionShape3D)
└── [Optional: AudioStreamPlayer3D for pickup sound]
```

### Required Item Script
```gdscript
extends RigidBody3D  # or StaticBody3D
## Base Item Script

@export var item_id: String = ""
@export var auto_pickup: bool = true

func _ready() -> void:
    set_meta("item_id", item_id)
    set_meta("is_collectible", true)
    
    var pickup_area = $PickupArea
    pickup_area.body_entered.connect(_on_pickup_area_entered)

func _on_pickup_area_entered(body: Node3D) -> void:
    if body.is_in_group("player") and auto_pickup:
        _trigger_pickup(body)

func _trigger_pickup(collector: Node3D) -> void:
    # Handled by SpawnManager's collision detection
    queue_free()
```

### Items to Create (from items.json)
- `note_1.tscn` - Research notes
- `note_2.tscn` - Additional research
- `porcelain_doll.tscn` - Creepy doll
- `music_box.tscn` - Haunting music box
- `puzzle_piece_1.tscn` - Puzzle fragment

---

## Puzzle System

### Puzzle Tile Integration
Puzzle tiles need additional script methods:

```gdscript
extends Node3D
## Puzzle Tile Base

@export var puzzle_id: String = ""
var _puzzle_state: Dictionary = {}
var _event_manager: Node

func _ready() -> void:
    _event_manager = get_node("/root/EventManager")

func is_tile_permanent() -> bool:
    return true  # Puzzle tiles are permanent

func get_puzzle_id() -> String:
    return puzzle_id

func start_puzzle() -> void:
    """Called when player interacts with puzzle"""
    if _event_manager:
        _event_manager.process_tile_events(puzzle_id, "on_interact", {})

func solve_puzzle(solution_data: Dictionary) -> bool:
    """Called when player attempts solution"""
    # Validate solution against events.json data
    # Return true if correct, trigger completion events
    pass
```

### Puzzle Types to Implement

#### Scarecrow Orientation Puzzle
- 4 interactable scarecrows that can be rotated
- Must face specific directions based on found notes
- Success spawns mirror shard

#### Stone Sequence Puzzle
- Requires crow key from previous puzzle
- Touch stones in correct order
- Triggers Dr. Amundsen speech

#### Crow Arithmetic Puzzle
- Use bone whistle to arrange crows
- Crows form numbers that must be counted
- Success gives crow key

---

## Audio Integration

### Audio File Structure
```
assets/audio/
├── ambience/
│   ├── corn_rustle.ogg
│   ├── wind_low.ogg
│   └── carnival_distant.ogg
├── effects/
│   ├── item_pickup.ogg
│   ├── door_open.ogg
│   ├── puzzle_solve.ogg
│   └── sanity_loss.ogg
├── voices/
│   ├── dr_amundsen_speech_1.ogg
│   ├── whispers_generic.ogg
│   └── choir_echoes.ogg
└── music/
    ├── exploration_theme.ogg
    ├── tension_theme.ogg
    └── menu_theme.ogg
```

### AudioManager Integration
The refactored AudioManager supports:
```gdscript
# Play positional sound
AudioManager.play_sound_3d("res://assets/audio/effects/item_pickup.ogg", Vector3(0, 0, 0))

# Play UI sound
AudioManager.play_sound_2d("res://assets/audio/effects/puzzle_solve.ogg", "SFX")
```

---

## UI Components

### Missing UI Scenes

#### HUD Improvements
The current HUD needs these enhancements:
- Sanity visual effects (screen distortion, color shifts)
- Message styling for different types (weird, sanity, normal)
- Inventory quick-access display

#### Inventory UI Polish
- Item 3D preview system
- Category filtering
- Item tooltips with descriptions

#### Settings Menu Integration
Now that SettingsManager exists, create:
```
scenes/ui/SettingsMenu.tscn
├── SettingsPanel (Panel)
│   ├── AudioSettings (VBoxContainer)
│   │   ├── MasterVolumeSlider (HSlider)
│   │   ├── MusicVolumeSlider (HSlider)
│   │   └── SFXVolumeSlider (HSlider)
│   ├── GraphicsSettings (VBoxContainer)
│   │   ├── FullscreenToggle (CheckBox)
│   │   └── VSyncToggle (CheckBox)
│   └── ControlsSettings (VBoxContainer)
│       └── SensitivitySlider (HSlider)
```

---

## Implementation Priority

### High Priority (Core Gameplay)
1. **Tile Scenes** - Essential for maze generation
2. **Basic Item Scenes** - Required for item system
3. **Entity Management** - Needed for enemy behavior

### Medium Priority (Polish)
1. **Puzzle Implementations** - Enhance gameplay depth
2. **Audio Integration** - Improve atmosphere
3. **UI Polish** - Better user experience

### Low Priority (Nice-to-Have)
1. **Advanced Visual Effects** - Screen distortions, particles
2. **Controller Support** - Input system already prepared
3. **Accessibility Features** - Settings system ready

---

## File Creation Checklist

When creating these components, ensure:

- [ ] All scripts use proper Godot 4.4.1 syntax
- [ ] Node names match the expected structure
- [ ] Required methods are implemented
- [ ] Proper collision layers are set (see project.godot)
- [ ] Meta properties are set correctly
- [ ] Signal connections use modern syntax (`signal.connect(method.bind())`)
- [ ] Error handling is included
- [ ] Debug print statements for testing

This structure ensures all components will integrate properly with the existing refactored codebase.
