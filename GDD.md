# Project Harvest – Game Design Document

## 1. Core Concept

A survival horror game set in a shifting corn maze at **"Jeri's Happy Funtime Harvest Cornmaze Experience!"** The player enters expecting a fun Halloween attraction but quickly realizes the maze is alive, reshaping itself, and filled with disturbing objects, whispers, and doppelgänger encounters. 

**Inspirations:**
- **Creepy Maze System:** Procedural shifting maze with pickups and jumpscares
- **Forgotten in the Woods:** Branching narrative, sanity mechanics, and the Watcher entity

**Unique Feature - The Harvest System:** The game pulls **system date/time** and **death location** to integrate into replayability. Each run is logged as a prior "subject." On subsequent runs, the maze contains echoes of previous attempts—notes, corpses, whispers, or artifacts left behind. 

**Meta-Backstory:** Subjects are being **harvested for experiments** orchestrated by **Dr. Amundsen** (appears as "A", "Amundsen", or "Dr. Amundsen" in documentation). Every failed run becomes another lost soul feeding the maze's memory.

## 2. Key Features

### Core Mechanics
* **🌊 Dynamic Tile-Streaming Maze:** Infinite procedural maze using modular tile segments
  - Each tile is a self-contained 10×10m maze segment with 4 potential exits (N/E/S/W)
  - Only current tile + immediate neighbors exist in memory (3×3 grid maximum)
  - As player moves forward, new tiles spawn ahead and old tiles behind are culled
  - Creates endless, non-repeating maze that feels truly infinite
* **🔄 Tile Library System:** 5 base shapes rotated to create all variations
  - **Dead End** (1 exit), **Straight** (2 opposite), **Corner** (2 adjacent)
  - **T-Junction** (3 exits), **Cross** (4 exits)
  - Door bitmask system with rotation logic for seamless connections
* **🔦 Limited Vision:** First-person perspective with fog volumes and dynamic lighting that obscures distant areas
* **🎭 Weird Things (Pickups):** Mysterious objects scattered throughout maze segments
  - Spawn based on distance tiers and tension levels
  - Trigger narrative messages and visual effects
  - Create local reality distortions within tiles
  - Can activate Stalker pursuit and entity spawning

### Psychological Systems
* **🧠 Sanity System:** Gradually drops during encounters and over time. Lower sanity increases:
  - Watcher appearance frequency
  - Maze hostility and shift rate
  - Visual/audio distortions
* **👁️ The Watcher:** Non-corporeal entity that appears more frequently as sanity decreases
  - Causes visual/audio disturbances
  - Slowly pursues the player
  - Cannot be defeated, only avoided

### Horror Elements
* **🚪 False Exit:** The "escape" door triggers a final jumpscare - there is no true escape
* **⚱️ Harvest System:** Each run logged with timestamp, tile progression, and death data:
  - Previous run's final 6-10 tiles may spawn echo props (corpses, notes, whispers)
  - Timestamp integration: "Subject logged at 22:14. Outcome: fragmented."
  - Tile pattern matching creates familiar yet distorted revisitations
  - Auto-generated notes in "your handwriting" from tile-specific encounters

## 3. Gameplay Loop

1. **Navigate** infinite maze segments with limited vision
2. **Transition** between tiles as new areas generate ahead and old areas fade behind
3. **Collect** Weird Things and lore notes scattered throughout tiles
4. **Manage** sanity while avoiding Watcher/Stalker entities that spawn in new tiles
5. **Progress** through content tiers as distance increases (basic → intermediate → advanced threats)
6. **Encounter** false exits and harvest chambers as the maze weaponizes hope
7. **Fail or succeed** → tile progression and death location logged for future echo spawning

## 4. Narrative Layers

* **Backstory:** Project Harvest is a clandestine experiment, harvesting subjects trapped in shifting mazes. The Weird Things are fragments of past test runs, psychological conditioning props, or instruments of identity manipulation.
* **Environmental Storytelling:** Notes, Weird Things, and run echoes hint at **experiments in duplication, consciousness, and identity fragmentation**.
* **Branching Encounters (from Forgotten in the Woods):**
  * Scarecrow Crossroads
  * Equipment Shed
  * Open clearance
  * Caves/Bunker → Service Tunnel and Exit Gate
* **Stalker Theme:** Encounters with stalker escalate toward the exit, where the final decision is made.

## 5. Dynamic Tile-Streaming System

### Technical Architecture
* **TileManager (Autoload):** Manages active tile grid, spawning/culling, and tile selection logic
* **Tile.tscn Base Scene:** Modular maze segments with consistent structure:
  - **DoorAnchor nodes** (N/E/S/W) for seamless connection between tiles
  - **NavRegion** pre-baked per tile for AI pathfinding
  - **PortalOccluder** for performance optimization
  - **Decoration spawn points** for Weird Things and entities

### Door System & Rotation Logic
* **Door Bitmask:** 4 bits encode exits (N=1, E=2, S=4, W=8)
* **Rotation Algorithm:** 90° clockwise bit shifts for seamless tile orientation
* **Connectivity Rules:** New tiles must have entrance door matching player's exit direction
* **NavigationLink3D** connects door anchors across tile boundaries

### Streaming Rules
* **Active Radius:** Keep only current tile + immediate neighbors (3×3 grid max)
* **Forward Spawning:** Generate next tile based on player movement direction
* **Backward Culling:** Remove tiles beyond active radius to maintain performance
* **Transition Detection:** PlayerTileTrigger Area3D fires when crossing tile boundaries

### Content Generation Tiers
* **Tier 1 (Tiles 1-4):** Batteries, guiding notes, no active threats
* **Tier 2 (Tiles 5-10):** Basic Weird Things, Caretaker spawn chance
* **Tier 3 (Tiles 10+):** Advanced Weird Things, Overseer Eyes, Stalker activation
* **Special Tiles:** Landmarks, false exits, safe rooms placed by distance/state

### Performance Benefits
* **Minimal Memory Footprint:** Only 9 tiles maximum in memory
* **No Global Navigation Rebaking:** Pre-baked tiles with dynamic links
* **Predictable Performance:** Constant tile count regardless of play duration
* **Endless Exploration:** True infinite maze without repetition detection

## 6. Core Systems (Integration)

* **Sanity:** Drops from Weird Things, Watcher, narrative beats. Color and VFX feedback.
* **Inventory:** Lightweight array; visible in UI. Items: flashlight, shovel, map fragments, research files, codes, etc.
* **Maze Shifts:** Triggered every 30 s (later 15 s) or by Weird Thing type 1.
* **Narrative Progression:**

  * 3 Weird Things → whispers, headaches, hints.
  * 5 Weird Things → “something follows you.” Maze shifts accelerate.
  * Random narrative lines fire while exploring (scratching sounds, shadows, whispers).
* **Run Echo System:**

  * At end of each run, save summary: date/time, sanity at death/exit, Weird Things collected, exit status.
  * On next run, instantiate echoes: corpse/effigy, note text, or ghostly replay of prior movement.

## 7. Visual & Audio Design

### Aesthetic Direction
**🌅 Time Progression:** Late afternoon rapidly descending into foggy evening/night
**🎆 Atmosphere:** Flickering carnival lights, weathered scarecrows, corn stalks swaying unnaturally
**🎪 Tone:** Deceptive cheerfulness corrupted into organic horror

### User Interface
- **HUD Elements:** "Weird Findings" counter, sanity indicator, flashlight battery
- **Message System:** Short narrative stingers with typewriter effect
- **Jumpscare Overlay:** Full-screen effects with "SUBJECT TERMINATED" messaging
- **Inventory Display:** Minimal, context-sensitive item showing

### Audio Design
**🎵 Ambient Layers:**
- Low-frequency drones and corn rustling
- Distant carnival music (distorted)
- Whispers that increase with story progression

**🔊 Dynamic Audio:**
- Randomized jumpscare stings
- Sanity-based audio distortions
- Harvest system callbacks: "Subject logged: [date]. Outcome: [death type]"

## 8. Entities

* **Player:** FPS controller; flashlight with limited battery.
* **Watcher:** Non-physical spook, triggered probabilistically based on sanity.
* **Stalker:** Activated after certain Weird Things or story beats. Patrols, chases briefly.
* **Weird Things:** 5 archetypes with effects.
* **Run Echoes:** Ghosts, corpses, or effigies representing prior attempts.

## 9. Entity Design

### Primary Antagonists

**🕴️ Dr. Amundsen (The Architect)**
- **Purpose:** Unseen mastermind orchestrating Project Harvest
- **Presence:** Notes, PA announcements, surveillance systems
- **Symbolism:** Human cruelty disguised as scientific progress

**🌾 The Stalker (The Harvester)**
- **Purpose:** Apex predator representing inevitable consumption
- **Behavior:** Hunt-and-chase entity activated after collecting enough Weird Things
- **Mechanics:** Cannot be defeated, only temporarily evaded

**👁️ The Watcher** 
- **Purpose:** Half-formed duplicate from failed experiments
- **Behavior:** Flickers at vision's edge, triggers sanity loss
- **Mechanics:** Appears more frequently as sanity decreases

### Environmental Entities

**🎭 Effigies (Failed Subjects)**
- **Purpose:** Corpses of past subjects displayed as warnings
- **Behavior:** Whisper and twitch at low sanity levels
- **Mechanics:** Environmental storytelling that echoes prior player runs

**🗣️ The Choir (Whisperers)**
- **Purpose:** Psychic remnants of harvested subjects
- **Behavior:** Audio-only entities that drain sanity over time
- **Mechanics:** Provide misleading hints about exits and solutions

**🤖 Overseer Eyes**
- **Purpose:** Bio-organic surveillance tied to Dr. Amundsen's systems
- **Behavior:** Scan and track player movement
- **Mechanics:** Detection accelerates maze shifts and increases difficulty

### Supporting Entities

**🌽 Caretakers (Corn Hands)**
- **Purpose:** Biomechanical "farmhands" that corral subjects
- **Behavior:** Briefly slow and restrain the player
- **Mechanics:** Create opportunities for Stalker to close distance

**👻 Residual Subjects (Ghost-Runners)** 
- **Purpose:** Shadows of past participants echoing through time
- **Behavior:** Fleeting silhouettes that can be followed
- **Mechanics:** May lead to lore/items but waste sanity and time

**🚪 The False Exit**
- **Purpose:** The maze weaponizing hope itself
- **Behavior:** Appears as salvation but triggers harvest sequence
- **Mechanics:** Final jumpscare before revealing no true escape exists

## 10. Ending Variations (No True Escape)

Every ending reinforces the "harvest" theme - player survival is temporary or hollow.

### Death States
- **💀 Consumed:** Stalker or Watcher overwhelms you → logged as "consumed"
- **⚗️ Harvested:** Reach the escape gate → harvested at the moment of apparent freedom
- **🌫️ Fragmented:** Sanity reaches zero → consciousness dissolves into maze whispers
- **🎭 Exchanged:** Doppelgänger replaces you → "successful" escape but you become the trapped version

### Meta-Progression
**📊 Experiment Log:** Regardless of outcome, each run is archived with:
- Timestamp and duration
- Cause of termination
- Weird Things collected
- Sanity level at death
- Death location coordinates

**🔄 Legacy System:** Future runs reference your previous "cause of death" through whispers, notes, and environmental storytelling

## 11. Technical Implementation (Godot 4.x)

### Current Architecture
* **Engine:** Godot 4.4.1 with GDScript
* **3D Tile System:** Modular maze segments with dynamic streaming
* **Autoload Managers:** 
  - `GameDirector.gd` - Core game state and progression
  - `TileManager.gd` - Dynamic tile spawning and culling
  - `SanityManager.gd` - Psychological state tracking
  - `WeirdThingsManager.gd` - Artifact spawning and effects
  - `HarvestLogger.gd` - Run persistence and echo system
  - `MazeManager.gd` - Maze generation and navigation

### Tile Streaming System
* **Base Tile Scene:** `tile.gd` with door anchor system
* **Tile Variants:** 5 base shapes (dead end, straight, corner, T-junction, cross)
* **Dynamic Loading:** 3×3 active grid with forward spawning and backward culling
* **Performance:** Pre-baked navigation regions with dynamic links

### Harvest System Implementation
* **Run Logging:** JSON persistence with timestamp and death data
* **Echo Spawning:** Previous run artifacts integrated into new maze generation
* **Meta-Narrative:** System date/time integration for unique harvest logs

## 12. Development Status & Current Focus

### ✅ Implemented Systems
* **Core Tile System:** Base tile scenes with door anchor connectivity
* **Player Controller:** FPS movement with grid-based navigation
* **Autoload Architecture:** All core managers initialized and connected
* **Tile Streaming:** Dynamic spawning and culling of maze segments
* **Basic UI:** HUD framework with sanity display

### 🔄 In Development
* **Spawning Behavior:** Tile generation and entity placement logic
* **Weird Things System:** Artifact spawning and interaction mechanics
* **Entity AI:** Watcher and Stalker behavior implementation
* **Harvest Logging:** Run persistence and echo system

### 📋 Next Priorities
* **Graybox Testing:** Validate tile connectivity and spawning patterns
* **Entity Spawning:** Implement Weird Things and hostile entity placement
* **Sanity Integration:** Connect psychological state to visual/audio effects
* **Performance Optimization:** Ensure stable 60fps with dynamic tile streaming

## 13. Balancing Parameters

### Core Mechanics
- **Weird Things:** 5–10 spawned per run
- **Maze Shifts:** 30s initial interval → 15s when stalker activates
- **Sanity Decay:** 1 point per 30 seconds baseline + event triggers

### Probability Tables
**Watcher Spawn Rates (per minute):**
- 100-80 Sanity: 10% chance
- 79-50 Sanity: 25% chance  
- 49-20 Sanity: 40% chance
- 19-0 Sanity: 60% chance

**Sanity Loss Events:**
- Weird Thing pickup: 5-15 points
- Watcher encounter: 10-25 points
- Maze shift witness: 5 points
- Stalker proximity: 20-40 points

### Harvest System
- **Echo Limit:** Maximum 3 echoes per run
- **Log Retention:** Oldest runs pruned after 10 entries
- **Echo Spawn Rate:** 80% chance per eligible prior death

## 14. MVP Checklist (Target: September 30)

### Essential Systems
- [ ] **Maze Generation:** 10+ modular 3D chunks with procedural assembly
- [ ] **Player Systems:** FPS controller with flashlight and grid-based logic
- [ ] **Weird Things:** 3-5 interactive props with narrative effects
- [ ] **Sanity System:** HUD display with visual feedback and decay mechanics
- [ ] **Entity AI:** Watcher spawning and basic stalking behavior

### Horror Elements
- [ ] **Exit Sequence:** False escape door with jumpscare trigger
- [ ] **Audio System:** Ambient sounds, whispers, and jumpscare stings
- [ ] **Visual Effects:** Screen distortions, lighting changes, fog manipulation

### Harvest Features
- [ ] **Run Logging:** Timestamp and death data persistence
- [ ] **Echo System:** Spawn at least one prior-run artifact per new game
- [ ] **Meta Narrative:** Whispers referencing previous attempts

### Polish Elements
- [ ] **UI Polish:** Clean HUD, message overlays, inventory display
- [ ] **Performance:** Stable 60fps with 100x100 maze grid
- [ ] **Content:** 2+ landmark areas (Scarecrow Crossroads, Equipment Shed)

---

**Project Harvest**: Each run is another harvested subject. The maze remembers. Your past selves litter the corridors. You aren’t escaping alone—you’re competing with every version of you that’s already been consumed.
