# Narration System Implementation

## Overview
The narration system has been fully integrated into Project Harvest to provide immersive story text boxes and control displays that trigger on specific game events. The system enhances the existing `NarrativeSystem.gd` autoload with new capabilities.

## Features Implemented

### 1. New Game Opening Narration
When a player starts a **new game** (not continue), they will see a sequence of thought bubbles:
- "Where... where am I?"
- "Oh right, the old farm. I remember driving here."
- "I saw the corn maze and thought it looked interesting..."
- "But what happened after that? I can't quite remember."
- "I guess I better find my way out."

Each text appears for 4 seconds with a 5.5-second interval between them, creating a natural narrative flow.

### 2. Controls Display
**Both new and continuing games** will show a controls overlay in the top-right corner:
- Displays for 5 seconds with fade in/out animations
- Shows: WASD (movement), SPACE (sprint), F (flashlight), E (interact), I (inventory), ESC (pause)
- Styled with a semi-transparent dark background and clean typography

### 3. Effigy Interaction Narrations
The system tracks effigy encounters and triggers appropriate narrations:
- **First effigy seen**: "That... thing looks really creepy."
- **Second effigy seen**: "Is it watching me?"
- **Effigy movement detection**: "Did... did that thing just move?" (only triggers if sanity > 80%)

### 4. Sanity-Based Narrations
Additional thought bubbles trigger based on sanity levels:
- **50% sanity**: "Something's not right here..."
- **25% sanity**: "I need to get out of here. Now."

### 5. Enhanced UI System
- **Narration Panel**: Centered at bottom of screen with italic styling for thoughts
- **Controls Panel**: Top-right positioned with clean layout
- **Queueing System**: Multiple narrations queue properly without overlapping
- **Style Support**: Different text styles (thought, observation, system, normal)

## Technical Implementation

### Files Modified
- `scripts/autoloads/gameloop/NarrativeSystem.gd` - Enhanced existing system with new features

### Key Functions Added
- `show_controls(duration)` - Display controls overlay
- `trigger_custom_narration(text, duration, style)` - Public API for custom narrations
- `_track_effigy(effigy, position)` - Track effigies for movement detection
- `_monitor_effigy_movement(effigy, effigy_id)` - Monitor effigy position changes
- `_show_new_game_narration()` - Display opening sequence for new games

### Event Integration
The system connects to existing MessageBus events:
- `game_started` - Triggers new game narration and controls display
- `entity_spawned` - Tracks effigy spawning for narration triggers
- `sanity_changed` - Triggers sanity-based narrations

### New Game Detection
Uses SaveManager's `run_active` flag to distinguish between new games and continues:
```gdscript
_is_new_game = not (_save_manager and _save_manager.save_data.get("run_active", false))
```

## How to Extend the System

### Adding New Narrations
Use the public API from any script:
```gdscript
var narrative_system = get_node("/root/NarrativeSystem")
narrative_system.trigger_custom_narration("Your text here", 4.0, "thought")
```

### Style Options
- `"thought"` - Italic, centered (for player thoughts)
- `"observation"` - Normal, centered (for observations)
- `"system"` - Cyan colored, centered (for system messages)
- `"normal"` - Default styling

### Adding New Event Triggers
1. Connect to the appropriate MessageBus signal in `_connect_to_events()`
2. Create a handler function (e.g., `_on_your_event()`)
3. Call `show_narration()` with your text and style

### Example: Adding Item Collection Narration
```gdscript
# In _connect_to_events():
if _message_bus.has_signal("item_collected"):
    _message_bus.item_collected.connect(_on_item_collected)

# Handler function:
func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
    if item_id == "weird_thing":
        show_narration("What is this strange object?", 3.0, "thought")
```

## Testing the System

### To Test New Game Narration:
1. Delete any existing save data
2. Start a new game
3. Watch for the opening thought sequence and controls display

### To Test Effigy Narrations:
1. Play until effigies spawn (they spawn at death locations from previous runs)
2. Approach effigies to trigger the sight-based narrations
3. For movement detection, ensure sanity is above 80%

### To Test Sanity Narrations:
1. Let sanity drop to 50% and 25% thresholds
2. Watch for the corresponding thought bubbles

## Current State
✅ **Fully Implemented and Ready to Test**

The system is complete and integrated. When you open the game:
- New games will show the opening narration sequence
- All games will show the controls display
- Effigy and sanity-based narrations will trigger during gameplay

## Future Enhancements
Consider adding narrations for:
- First time entering specific tile types
- Puzzle interactions
- Maze shifting events
- End-game sequences
- Inventory discoveries

The foundation is now in place to easily add any narrative elements you envision for the game.
