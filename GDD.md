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
* **🌪️ Shifting Maze:** 100×100 grid with procedural generation and distortion zones. Maze actively reshapes over time or when triggered by events
* **🔦 Limited Vision:** First-person perspective with fog volumes and dynamic lighting that obscures distant areas
* **🎭 Weird Things (Pickups):** Mysterious objects scattered throughout (doll, music box, mirror, symbols, pocket watch, notes)
  - Trigger narrative messages and visual effects
  - Cause screen/light flickers
  - Create local maze distortions
  - Temporarily lift fog of war
  - Can activate Stalker pursuit

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
* **⚱️ Harvest System:** Each run is timestamped and logged. Subsequent runs contain echoes:
  - Corpse/scarecrow effigy with previous run's timestamp
  - Auto-generated notes in "your handwriting" from prior attempts
  - Distorted items dropped by the "previous you"
  - Sanity whispers referencing past choices and deaths

## 3. Gameplay Loop

1. Navigate maze with limited vision.
2. Collect Weird Things and lore notes.
3. Manage sanity while avoiding Watcher/Stalker.
4. Survive maze shifts that alter known paths.
5. Find and unlock the exit gate.
6. Fail or succeed → new run integrates echoes of the last subject.

## 4. Narrative Layers

* **Backstory:** Project Harvest is a clandestine experiment, harvesting subjects trapped in shifting mazes. The Weird Things are fragments of past test runs, psychological conditioning props, or instruments of identity manipulation.
* **Environmental Storytelling:** Notes, Weird Things, and run echoes hint at **experiments in duplication, consciousness, and identity fragmentation**.
* **Branching Encounters (from Forgotten in the Woods):**
  * Scarecrow Crossroads
  * Equipment Shed
  * Open clearance
  * Caves/Bunker → Service Tunnel and Exit Gate
* **Stalker Theme:** Encounters with stalker escalate toward the exit, where the final decision is made.

## 5. Level & Systems Mapping

* **Maze Generator:** Grid DFS with distortion patterns and `changeMazePart` (local wall toggling). Direct lift from JS Creepy Maze.
* **Player Movement:** Continuous first-person controller in 3D (grid-mapped for logic).
* **Renderer/Presentation:** Fog-of-war and lighting ported to 3D fog volumes and flashlight.
* **WeirdThings Manager:** Items randomly placed (5–10). Random effects + story text.
* **Game Director:** Oversees sanity, maze shift timers, narrative thresholds, replay logging, and run echoes.

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

## 11. Technical Plan

* **Prototype (2D, TileMap):** Quick test of maze generation, fog-of-war, Weird Things, sanity.
* **Transition to 3D:** Modular chunks (straight, corner, T, cross) aligned to 20×20 logical grid.
* **Autoload Managers:** Sanity, Inventory, MazeManager, GameDirector, HarvestRunLog.
* **Replayability Implementation:**

  * On run end, save JSON with timestamp + summary.
  * On new run, GameDirector queries log and spawns echo props.

## 12. Balancing Parameters

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

## 13. MVP Checklist (Target: September 30)

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
