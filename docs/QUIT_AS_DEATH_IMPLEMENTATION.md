# Quit-as-Death Implementation

## Overview

This document describes the implementation of the quit-as-death system, which ensures that when a player quits the game (through any method), it is properly counted as a death and recorded in the game's systems.

## Problem

Previously, if a player force-quit the game (Alt+F4, closing window, task manager kill, etc.), their run data would be lost and no death would be recorded. This broke the game's progression system which relies on death locations for spawning backpacks and effigies in future runs.

## Solution

Multiple layers of quit detection have been implemented to catch all possible quit scenarios:

### 1. GameController (`scripts/systems/GameController.gd`)

**Added `_notification()` handler:**
- Catches `NOTIFICATION_WM_CLOSE_REQUEST` (window close button, Alt+F4)
- Calls `_terminate_subject("Force Quit")` to record death
- Allows quit to proceed after recording

**Existing functionality:**
- Menu-based quit: `_on_quit_requested()` → `_terminate_subject("Terminated")`
- Main menu return: `_on_main_menu_requested()` → `_terminate_subject("Abandoned")`

### 2. Player (`scripts/entities/Player.gd`)

**Enhanced `_notification()` handler:**
- Added `NOTIFICATION_WM_CLOSE_REQUEST` detection
- Calls new `_handle_force_quit()` method

**New `_handle_force_quit()` method:**
- Triggers `die("Force Quit")` to emit death events
- Calls `SaveManager.record_death()` for persistent storage

### 3. GameDirector (`scripts/autoloads/gameloop/GameDirector.gd`)

**Added `_notification()` handler:**
- Catches `NOTIFICATION_WM_CLOSE_REQUEST` as backup
- Only triggers if `game_active` is true
- Calls `end_game("Force Quit")` with termination data

### 4. MainMenu (`scripts/ui/MainMenu.gd`)

**Added `_notification()` handler:**
- Catches window close requests in main menu
- Simply allows quit (no active game to record death for)

## Death Recording Chain

When any quit occurs during active gameplay:

1. **Detection**: Window close detected by notification handlers
2. **Player Death**: `Player.die("Force Quit")` or `GameController._terminate_subject()`
3. **Event Emission**: `MessageBus.emit_event("player_died", [cause, position, data])`
4. **System Responses**:
   - `GameDirector._on_player_died()` → `end_game()`
   - `GameStateManager._on_player_died()` → `record_death_location()`
   - `HarvestLogger._on_player_died()` → `log_run_completion()`
   - `EffigyManager._on_player_died()` → Records for future effigy spawning
5. **Persistent Storage**: `SaveManager.record_death()` increments death counter

## Quit Scenarios Covered

| Scenario | Handler | Death Cause | Notes |
|----------|---------|-------------|-------|
| Pause Menu → Quit | GameController | "Terminated" | Shows death screen |
| Pause Menu → Main Menu | GameController | "Abandoned" | Returns to main menu |
| Window X button | Multiple handlers | "Force Quit" | Caught by notification |
| Alt+F4 | Multiple handlers | "Force Quit" | Caught by notification |
| Task Manager kill | N/A | N/A | Cannot be caught by application |
| Power loss/crash | N/A | N/A | Cannot be caught by application |

## Testing

A test script has been created at `tests/test_quit_as_death.gd` that can verify:
- Menu-based quit recording
- Main menu return recording  
- Force quit simulation
- Manual testing with keyboard shortcuts

## Files Modified

1. `scripts/systems/GameController.gd` - Added window close handler
2. `scripts/entities/Player.gd` - Enhanced notification handling and added force quit method
3. `scripts/autoloads/gameloop/GameDirector.gd` - Added backup quit detection
4. `scripts/ui/MainMenu.gd` - Added window close handler and fixed continue button logic
5. `scripts/autoloads/system/SaveManager.gd` - Added run state management and game event integration
6. `tests/test_quit_as_death.gd` - Created comprehensive test script
7. `docs/QUIT_AS_DEATH_IMPLEMENTATION.md` - This documentation

## Save Data Fix

**Problem Identified**: The continue button was grayed out after quit-deaths because `SaveManager.run_active` was never set to `true` when games started, only set to `false` when deaths occurred.

**Solution Implemented**:
1. Added `SaveManager.start_run()` function to mark runs as active
2. Connected SaveManager to MessageBus `game_started` event 
3. Fixed MainMenu continue button logic to check `run_active` status, not just file existence
4. Now the flow is: Game Start → `run_active = true` → Quit Death → `run_active = false` → Continue button properly disabled

## Notes

- The system uses multiple redundant handlers to ensure quit detection even if one component fails
- Graceful degradation: if MessageBus or other systems are unavailable, SaveManager is called directly
- The system only records deaths during active gameplay (`game_active` flag)
- Process kills and crashes cannot be detected by the application and will still result in lost data
- The implementation maintains the existing game's thematic language ("Terminated", "Abandoned", etc.)
