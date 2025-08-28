# Project Harvest – Game Design Document

## 1. Core Concept

A survival horror game set in a shifting corn maze. The player enters expecting a fun Halloween attraction but quickly realizes the maze is alive, reshaping itself, and filled with disturbing objects and doppelgänger encounters. Blends two inspirations: the **Creepy Maze** system (procedural shifting maze with pickups and jumpscares) and **Forgotten in the Woods** (branching narrative, sanity, inventory, and the Watcher).

**New Feature:** The game pulls **system date/time** and integrates it into replayability: each run is logged as a prior “subject.” On a new run, the maze contains echoes of the previous attempt—notes, corpses, whispers, or artifacts left behind. The meta-backstory: subjects are being **harvested for experiments**, and every failed run is another lost soul feeding the maze.

## 2. Key Features

* **Shifting Maze:** 20×20 grid; procedural generation with distortion zones. Maze can change passively over time or triggered by certain events.
* **Fog of War & Light:** Limited vision; current cell and open neighbors are revealed. In 3D this becomes view-cone lighting and fog volumes.
* **Weird Things (Pickups):** Objects scattered in the maze (doll, music box, mirror, symbols, pocket watch). Each triggers narrative messages and effects:

  * Flicker screen/lights
  * Local maze distortion
  * Fog temporarily lifts
  * Visual distortion
  * Stalker entity begins pursuit
* **Sanity System:** Drops with encounters, rises in safe zones. Lower sanity increases Watcher appearances and maze hostility.
* **The Watcher:** Appears randomly, more frequently as sanity drops. Non-corporeal stalker that causes visual/audio effects.
* **Exit + Jumpscare:** Exit door has a pre-trigger that fires a final jumpscare before the real ending.
* **Replayability / Harvest System:** Each run is stamped with date/time. On next run, the game spawns evidence of your prior attempt:

  * Corpse or scarecrow effigy labeled with your last run’s timestamp.
  * A note written in your handwriting (auto-generated from prior pickup messages).
  * Items dropped by the “previous you” may appear, distorted.
  * Sanity whispers may reference choices from the last attempt.

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

  * Cemetery → Scarecrow Crossroads (grave + shovel analogue)
  * Frozen Lake → Irrigation Pond (reflection doppelgänger)
  * Cabin → Staff Trailer (encounter with your double)
  * Church → Equipment Shed (Watcher/false priest analog)
  * Caves/Bunker → Service Tunnel and Exit Gate
* **Doppelgänger Theme:** Encounters with doubles escalate toward the bunker/exit, where the final decision is made.

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

* **Corn Maze Aesthetic:** Foggy night, flickering carnival lights, scarecrows.
* **UI Layers:**

  * HUD counter (“Weird Findings”)
  * Message overlay (short stingers)
  * Jumpscare overlay (full screen SVG/texture + GAME OVER)
* **Audio:** Ambient low drones, whispers on events, randomized jumpscare sting, distortions when sanity drops.
* **Replayability Audio Beat:** Whispers may call the player by date/time of last run (“Subject logged: October 5, 2025. Outcome: consumed.”).

## 8. Entities

* **Player:** FPS controller; flashlight with limited battery.
* **Watcher:** Non-physical spook, triggered probabilistically based on sanity.
* **Stalker:** Activated after certain Weird Things or story beats. Patrols, chases briefly.
* **Weird Things:** 5 archetypes with effects.
* **Run Echoes:** Ghosts, corpses, or effigies representing prior attempts.

## 9. Puzzle Mapping

* Scarecrow Crossroads: Rope puzzle (Key A)
* Irrigation Pond: Reflection scare + battery cache
* Equipment Shed: Breaker puzzle (Notebook)
* Staff Trailer: Doppelgänger whisper (Code fragment)
* Shrine of Husks: Face-doll order puzzle (Key B)
* Silo Alley: Breaker lure puzzle (Key C)
* Exit Gate: Requires 3 keys + correct code

## 10. Ending Variations

* Correct exit code: Escape, but hints of lingering doubles.
* Wrong code: Maze shift + gas, respawn with memory fragments (loop mechanic).
* Stalker catch: Game over (jumpscare overlay).
* Run echoes: Regardless of outcome, your attempt is logged and becomes part of the maze for future players.

## 11. Technical Plan

* **Prototype (2D, TileMap):** Quick test of maze generation, fog-of-war, Weird Things, sanity.
* **Transition to 3D:** Modular chunks (straight, corner, T, cross) aligned to 20×20 logical grid.
* **Autoload Managers:** Sanity, Inventory, MazeManager, GameDirector, HarvestRunLog.
* **Replayability Implementation:**

  * On run end, save JSON with timestamp + summary.
  * On new run, GameDirector queries log and spawns echo props.

## 12. Balancing Knobs

* Weird Things: 5–10 per run.
* Maze shift interval: 30 → 15 seconds.
* Watcher chance per minute: sanity 100/70/40/20 = 0.1/0.2/0.35/0.5.
* Sanity loss: 5–40 depending on event.
* Replay echoes: max 1–3 echoes per run; oldest run pruned.

## 13. Content Checklist (Minimum for Sept 30)

* [ ] 10 maze chunks (3D)
* [ ] 3–5 Weird Thing props + effects
* [ ] Sanity + HUD
* [ ] Inventory UI
* [ ] Watcher prefab
* [ ] Exit Gate + jumpscare overlay
* [ ] At least 2 landmark puzzles (Scarecrow, Pond)
* [ ] Replay system logging run timestamp and spawning at least one echo in next playthrough

---

**Project Harvest**: Each run is another harvested subject. The maze remembers. Your past selves litter the corridors. You aren’t escaping alone—you’re competing with every version of you that’s already been consumed.
