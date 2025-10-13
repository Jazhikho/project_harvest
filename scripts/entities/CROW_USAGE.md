# Crow System Usage Guide

## Overview

The crow system consists of two scripts:
- **Crow.gd**: Controls individual crow animation and behavior
- **CrowFlock.gd**: Manages multiple crows with precise positioning

## Important Note About MultiMesh

**You cannot use MultiMesh for animated crows** because:
- MultiMesh instances are visual duplicates only
- They cannot have individual animations or behaviors
- They only support per-instance transform (position/rotation/scale) and color

For crows with individual animations and behaviors, you must use **individual instances**.

---

## Individual Crow Usage

### Basic Setup

1. The crow scene (`scenes/environments/crow.tscn`) is pre-configured with the Crow script
2. Simply instance the crow scene where needed
3. Configure properties in the Inspector:
   - `animation_speed`: Playback speed multiplier (default: 1.0)
   - `max_animation_time`: Limits animation to first N seconds (default: 6.5)
   - `time_offset`: Start time in animation for variety (default: 0.0)
   - `behavior`: Initial behavior type (default: "idle")

### Script Control

```gdscript
# Get reference to crow
var crow: Crow = get_node("crow")

# Randomize animation speed
crow.set_random_animation_speed(0.5, 1.5)

# Assign random behavior
crow.set_random_behavior()

# Randomize starting time
crow.set_time_offset_random()
```

---

## CrowFlock Usage

### Setup in Scene

1. Add a `Node3D` to your tile scene
2. Attach the `CrowFlock` script to it
3. Configure in Inspector:
   - `crow_scene`: Assign `res://scenes/environments/crow.tscn`
   - `crow_positions`: Add positions for each crow (Vector3 array)
   - `crow_rotations`: Add Y-axis rotations in degrees (float array, optional)
   - `randomize_rotation`: Enable random rotations if not specified (default: false)
   - `randomize_speed`: Enable to vary animation speeds (default: true)
   - `min_animation_speed`: Minimum speed multiplier (default: 0.5)
   - `max_animation_speed`: Maximum speed multiplier (default: 1.5)
   - `randomize_behaviors`: Enable random behaviors (default: true)
   - `randomize_time_offset`: Enable random animation offsets (default: true)
   - `auto_generate`: Spawn crows on ready (default: true)

### Example Scene Structure

```
CrowsParliament (Node3D)
├── Maze (Node3D)
│   └── Objects (Node3D)
│       └── CrowFlock (Node3D) [CrowFlock.gd]
└── ...
```

### Defining Crow Positions and Rotations

In the Godot Inspector, add positions to the `crow_positions` array:

```
CrowFlock
  ├── crow_scene: res://scenes/environments/crow.tscn
  ├── crow_positions:
  │   ├── [0]: Vector3(2.5, 0.2, 3.3)
  │   ├── [1]: Vector3(4.0, 0.2, 0.5)
  │   ├── [2]: Vector3(3.2, 0.2, -1.4)
  │   └── [3]: Vector3(-1.0, 0.2, 2.0)
  └── crow_rotations:
      ├── [0]: 0.0      (facing forward)
      ├── [1]: 45.0     (45 degrees)
      ├── [2]: 90.0     (facing right)
      └── [3]: 180.0    (facing backward)
```

**Notes:**
- Positions are **relative to the CrowFlock node**
- Rotations are **Y-axis degrees** (0 = forward, 90 = right, 180 = back, 270 = left)
- If `crow_rotations` is empty or shorter than positions, missing crows default to 0 degrees
- Enable `randomize_rotation` to auto-randomize any missing rotations

### Script Control

```gdscript
# Get reference to flock
var flock: CrowFlock = get_node("CrowFlock")

# Manually generate flock
flock.generate_flock()

# Add a single crow at runtime
var new_crow: Crow = flock.add_crow_at(Vector3(5.0, 0.2, 5.0), 90.0)  # facing right

# Add a crow with default rotation (0 degrees)
var crow2: Crow = flock.add_crow_at(Vector3(3.0, 0.2, 3.0))

# Clear all crows
flock.clear_flock()

# Get count
var count: int = flock.get_crow_count()
print("Crow count: %d" % count)
```

---

## Example: Adding CrowFlock to Existing Tile

### Step 1: Open Your Tile Scene

Open the tile scene in Godot (e.g., `scenes/tiles/crows_parliament.tscn`)

### Step 2: Add CrowFlock Node

1. Right-click on `Maze/Objects`
2. Select "Add Child Node"
3. Choose `Node3D`
4. Rename it to `CrowFlock`
5. Attach script: `res://scripts/tiles/CrowFlock.gd`

### Step 3: Configure Properties

In the Inspector:
1. Set `crow_scene` to `res://scenes/environments/crow.tscn`
2. Add 3-5 positions to `crow_positions` array
   - Use marker positions from your scene (e.g., EntityPoint1, EntityPoint2, etc.)
   - Typical Y value: 0.2 (ground level)
3. (Optional) Add matching rotations to `crow_rotations` array
   - Face crows toward specific directions or points of interest
   - Or enable `randomize_rotation` for variety
4. Enable `randomize_speed`, `randomize_behaviors`, `randomize_time_offset`
5. Set `auto_generate` to true

### Step 4: Test

Run the scene and you should see multiple crows at the defined positions, each with:
- Different animation speeds
- Random behaviors (idle, pecking, looking around, preening)
- Varied animation timing for natural variety

---

## Animation Behavior Types

The Crow script supports four behavior types that affect animation speed:

| Behavior | Speed Range | Description |
|----------|-------------|-------------|
| `idle` | 0.5 - 0.8 | Slowest, minimal movement |
| `preening` | 0.6 - 0.9 | Slow, grooming behavior |
| `looking_around` | 0.8 - 1.2 | Normal speed, alert |
| `pecking` | 1.2 - 1.5 | Fastest, feeding behavior |

Behaviors automatically change every 5-15 seconds for variety.

---

## Performance Considerations

- Each crow is a separate instance with its own AnimationPlayer
- For large numbers of crows (20+), consider:
  - Disabling some crows when player is far away
  - Using LOD (Level of Detail) techniques
  - Pooling crow instances if spawning/despawning frequently

---

## Troubleshooting

### Crows Not Animating

1. Check that AnimationPlayer exists in crow model hierarchy
2. Verify animation is imported (check `.glb.import` file: `animation/import=true`)
3. Check console for error messages

### Flock Not Spawning

1. Ensure `crow_scene` is assigned in Inspector
2. Check that `crow_positions` array is not empty
3. Verify `auto_generate` is enabled (or call `generate_flock()` manually)

### Animation Too Fast/Slow

- Adjust `min_animation_speed` and `max_animation_speed` in CrowFlock
- Or set `animation_speed` directly on individual Crow instances

### Crows in Wrong Position

- Positions are **relative to CrowFlock node**
- Check CrowFlock node's own transform
- Adjust positions in `crow_positions` array

