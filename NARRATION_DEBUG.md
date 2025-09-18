# Narration System Debugging & Testing

## Issue Identified
The narration system wasn't showing up because:
1. UI elements were being created during autoload initialization (before game scene loads)
2. The UI was trying to attach to the wrong scene (main menu instead of game scene)

## Fixes Applied

### 1. Delayed UI Creation
- UI elements are now created only when `game_started` event is triggered
- This ensures the game scene is loaded before trying to attach UI elements

### 2. Added Debug Logging
Added extensive debug prints to track:
- When game_started event is received
- Whether UI elements are created successfully
- When narration/controls functions are called
- Whether panels exist before trying to use them

### 3. Scene Verification
- `_add_to_scene()` now checks that current scene is named "Game" before adding UI
- Added fallback logging when scene isn't ready

### 4. Manual Test Function
Added a test function accessible via the T key in-game:
- Press **T** while in the game scene to manually test the narration system
- Will show a test narration followed by the controls display

## Testing Instructions

### Method 1: Normal Game Flow
1. **Delete any existing save data** (to ensure new game detection works)
2. **Start a new game**
3. **Watch the console output** for debug messages
4. **Look for**:
   - Opening narration sequence (5 text boxes)
   - Controls display in top-right corner

### Method 2: Manual Testing
1. **Load into the game scene**
2. **Press T key** to manually trigger test narration
3. **Should see**:
   - Test narration text box at bottom
   - Controls display after 4 seconds

### Method 3: Console Testing
1. **Open the Godot debugger/console**
2. **Look for these debug messages**:
   ```
   NarrativeSystem: Game started event received
   NarrativeSystem: Creating UI for game scene
   NarrativeSystem: Adding UI to game scene
   NarrativeSystem: Is new game: true/false
   NarrativeSystem: Starting new game narration
   NarrativeSystem: Showing controls
   ```

## Expected Behavior

### New Game:
1. Game loads → "Game started event received"
2. UI created → "Creating UI for game scene"
3. UI attached → "Adding UI to game scene"
4. New game detected → "Is new game: true"
5. Narration sequence starts → 5 thought bubbles appear
6. Controls display → Top-right panel for 5 seconds

### Continue Game:
1. Game loads → "Game started event received"
2. UI created → "Creating UI for game scene"
3. Continue detected → "Is new game: false"
4. Controls display only → Top-right panel for 5 seconds

## Troubleshooting

### If Nothing Shows:
1. **Check console output** - look for error messages
2. **Verify scene name** - make sure game scene is named "Game"
3. **Try T key test** - manual test should work regardless

### If Console Shows Errors:
1. **"MessageBus not found"** - Check autoload order
2. **"Game scene not ready"** - Scene loading issue
3. **"Panel is null"** - UI creation failed

### If T Key Test Works But Game Start Doesn't:
- Issue with `game_started` event not being triggered
- Check if GameController properly emits the event
- Verify MessageBus connections

## Current Debug Features

### Temporary Debug Logging
All debug print statements can be removed once system is confirmed working:
- `print("NarrativeSystem: ...")` statements throughout the code
- T key test function in GameController

### Debug Controls
- **T key**: Manual test of narration system (while in game)
- Console output shows detailed system state

## Next Steps

1. **Test with these instructions**
2. **Share console output** if issues persist
3. **Remove debug prints** once working
4. **Remove T key binding** once confirmed functional

The system should now work correctly with proper timing and scene attachment!
