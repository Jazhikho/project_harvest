# Shifting Harvest — Corn Maze Horror (Godot) | Game Design Document (GDD)

**Version:** 0.1 • **Date:** Aug 28, 2025 • **Target:** Playable vertical slice by Sep 30, 2025 (New York time)

## 0. Scope-at-a-glance (optimized for ~10–15 hrs/week)
- **Engine:** Godot 4.x, GDScript
- **View:** First-person 3D (fallback: 2.5D top-down prototype if needed)
- **Core Loop:** Explore → collect keys/clues → avoid threats → reach exit before maze fully “awakens.”
- **Single environment:** Corn maze with shifting layout and 3 setpiece sub-areas (Scarecrow Crossroads, Silo Alley, Shrine of Husks)
- **Session length:** 20–35 minutes for the slice
- **MVP must-have:**
  1) Walk, run, crouch, flashlight with battery drain
  2) Dynamic maze shift event on timer or trigger
  3) One stealth predator AI ("The Stalker") with patrol and chase
  4) 3 keys → unlock exit gate
  5) 8–10 environmental story notes + 2 audio stingers
  6) UI: health, stamina, battery, key counter, simple pause menu
- **Nice-to-have (only if time left):**
  - Second threat type (ambient hands in corn rows that snare briefly)
  - Weather pass (wind gusts that move corn, occasional fog bank)
  - Photo mode with grainy film filter

## 1. Concept
**Pitch:** A Halloween corn maze where the path is fun until it isn’t. The rows shift, scarecrows watch, and something talks through the irrigation pipes. Find the exit, or the maze keeps you for the harvest.

**Tone:** Folk horror meets liminal Americana. Rusted farm metal, tacky hayride decorations, cheap jump-scare props that slowly become wrong.

**Player Fantasy:** You are clever, careful, and just fast enough. Survival through preparation and attention, not brute force.

## 2. Narrative & World
- **Backdrop:** Seasonal pop-up maze on the edge of town. Family-run, rumors of prior disappearances.
- **Inciting Incident:** Power flickers, “actors” vanish, gates lock. The maze shifts with a dry hiss.
- **Antagonistic Force:** The Maze (entity) manipulates rows, sound, and scarecrow effigies; employs a human-scale predator wearing farm gear: **The Stalker**.
- **Act Structure (vertical slice):**
  - **Act I: Welcome Night** — Tutorial area, flashlight, first shift. Find Map Fragment A.
  - **Act II: Crop Circle** — Open routes to 3 landmarks; retrieve Keys 1–3; avoid roaming Stalker.
  - **Act III: Harvest Gate** — Maze shifts aggressively; sprint to the Exit Gate with keys.

**Environmental storytelling beats:**
- Child’s glow-sticks half-buried along a “safe path” that ends at a scarecrow with a wristband.
- A staff clipboard with a map that doesn’t match the current layout.
- An unplugged speaker that still emits whispers when you turn away.
- The irrigation valve that, when opened, plays a reversed carnival tune.

## 3. Gameplay & Systems
### 3.1 Movement
- FP controller: walk, sprint (stamina), crouch (stealth bonus), lean (optional)
- Footstep volume scales with surface (dirt vs wood pallets)

### 3.2 Light & Visibility
- Flashlight with flicker and battery drain; pocket batteries as pickups
- The Stalker reacts to light within cone if in front arc; otherwise uses sound

### 3.3 Stealth & Threat
- **The Stalker** AI states: Idle → Patrol → Investigate (noise/light) → Chase → Search → Resume
- Line-of-sight with peripheral falloff; brief stun if hit by camera flash (optional pickup)
- Player health: 2 hits = down; medkit restores 1

### 3.4 Maze Shifts
- Triggers: timer, key pickups, or crossing a threshold
- Implementation: pool of modular maze chunks (10–20 tiles). On shift, selected chunks rotate/swap; navmesh and AI paths rebuild; landmarks remain constant.
- Telegraphed by wind gust, rustle, distant metal drag, brief UI vignette

### 3.5 Objectives
- Collect 3 keys from landmark sub-areas; keys placed in small puzzle spaces:
  1. **Scarecrow Crossroads** — rope puzzle: cut correct knot order from notes
  2. **Silo Alley** — breaker box mini-circuit reconnect
  3. **Shrine of Husks** — memory path (follow whispered names)
- Exit Gate requires all keys.

### 3.6 Progression
- No XP. Progress through items: batteries, medkit, optional camera flash, map fragments (A/B).

### 3.7 Fail States & Accessibility
- On capture: wake at nearby haybale “nest,” lose 1 item and 1 battery (limited retries). Accessibility toggle for fewer penalties.
- Options: reduce motion blur, tweak FOV, subtitle all whispers, color-blind friendly key icons.

## 4. Level Design
- **Playable grid:** ~80×80 m with 2-meter-wide paths; walls are corn meshes with billboards to save draw calls
- **Landmarks:**
  - Crossroads with giant scarecrow and windmill
  - Service lane with metal silos and pallets
  - Clearing with stone ring and offerings
- **Safe rooms:** tool sheds; map board; each contains a save point or checkpoint

## 5. Art Direction
- **Palette:** dead greens, dusty yellows, oxidized red, sodium-vapor orange, cool moonlight accents
- **Style:** grounded PBR with light film grain; keep geometry simple; use decals for grime
- **LOD:** low poly corn stalk clusters; cards with alpha for leaves; impostor billboards in distance

## 6. Audio Direction
- Foley: wind through corn, distant tractor, chains clink, dry leaves
- Music: minimal drones, tape-warped carnival motif
- Stalker audio: wet boot squeaks, buckle jangles when sprinting; proximity stinger

## 7. UI/UX
- Diegetic map boards in sheds; minimalist HUD (stamina arc, battery pip, key icons)
- Subtitles for whispers with direction indicator
- Clear prompt affordances for interactables (outline or icon)

## 8. Technical Design (Godot 4.x, GDScript)
**Core Nodes:**
- Player: CharacterBody3D + Camera3D + RayCast3D
- AI: NavigationAgent3D + State machine script
- Maze Chunks: GridMap or custom Tile3D system; chunk scenes with sockets
- Shifts: Manager singleton swaps chunk scenes; rebuilds NavigationRegion3D
- Interactables: Area3D with prompt; signal-based interactions
- Optimization: baked GI fallback to SDFGI off if perf dips; occlusion culling via portals in sheds; corn uses GPU instancing

**Key Scripts:**
- `PlayerController.gd` — input, movement, stamina, crouch, flashlight
- `StalkerAI.gd` — states, sensing, pathing, chase logic
- `MazeManager.gd` — chunk registry, shift scheduler, nav rebuild
- `Interactable.gd` — base class with `use()` and prompt text
- `ObjectiveManager.gd` — key state, exit gate unlock, UI updates
- `AudioDirector.gd` — global SFX hooks for shifts and proximity

## 9. Content List (vertical slice)
- 1 player prefab, 1 enemy prefab
- 10–20 maze chunk scenes (straight, T, cross, dead ends, corners)
- 3 landmark mini-puzzle scenes + assets
- 6 props: scarecrow, windmill, pallets, silos, shrine stones, tool shed
- 8–10 note pickups, 2 audio logs
- 6 SFX loops + 8 one-shots; 2 music cues

## 10. Production Plan (Aug 28 → Sep 30)
**Assumption:** ~10–15 hrs/week across 4.5 weeks.

### Week 0.5 (Aug 28–31)
- Repo setup, Godot project, input map, graybox maze with 10 chunks
- Player controller + flashlight + simple HUD
- Stalker AI greybox: patrol between waypoints
- Narrative pass: outline note texts and key locations

### Week 1 (Sep 1–7)
- MazeManager with basic shift on timer; 3 landmarks stubbed
- Navigation rebuild on shift; enemy patrol adapts
- Implement Key 1 puzzle (Scarecrow Crossroads)
- Art blockout: corn clusters, scarecrow proxy, silo proxy

### Week 2 (Sep 8–14)
- Implement Key 2 puzzle (Silo Alley) + audio hooks
- Implement capture/respawn logic; health/stamina tuning
- First audio pass: wind, footsteps, rustle; placeholder music
- UI polish: key icons, battery, pause menu

### Week 3 (Sep 15–21)
- Implement Key 3 puzzle (Shrine of Husks) + whisper subtitles
- Maze shift telegraphing, camera vignette, fog volumes
- Performance pass: LODs, instancing, occlusion in sheds
- Content: 8–10 notes in world, 2 audio logs

### Week 4 (Sep 22–28)
- Art polish on landmarks; decal grime, prop set dressing
- AI tuning: search behavior, chase fairness, audio tells
- QA checklist: controller, keybindings, accessibility toggles
- Build candidate 1 on Sep 28

### Sprint Buffer (Sep 29–30)
- Bugfixes, lighting balance, cut any risky features
- Final build, quick trailer capture if time

## 11. Risks & Cuts
- **Risk:** Navmesh rebuild hitches during shifts → Mitigate by restricting swaps to 2–4 chunks and pre-baking alt layouts.
- **Risk:** AI pathing fails on swap → Teleport AI to nearest valid navpoint on shift.
- **Risk:** Performance in dense corn → Use billboards, cull aggressively, limit light/shadow casters.
- **Hard cuts if behind:** photo mode, second threat type, leaning, camera flash item.

## 12. Testing Plan
- Daily 5-minute smoke test checklist
- Playtest goals: average clear time 25–30 minutes; 2–4 genuine scares; <3 hard stalls
- Log issues in a simple Kanban: Backlog, Doing, Verify, Done

## 13. Asset & Tooling Budget (time, not money)
- Models: kitbash from low-poly primitives; 1–2 hours per landmark polish
- Textures: trim sheets for wood/metal; corn card atlas
- Audio: open-licensed rustle/metal loops; record 2 VO whispers

## 14. Accessibility & UX Considerations
- Subtitles always on by default
- Toggle screen shake; FOV 80–95 slider; brightness slider
- Color-blind safe key icons and UI contrast

## 15. Definition of Done (Vertical Slice)
- Start to exit possible; all three keys collectible and gate unlocks
- One enemy that patrols, detects, chases, and can down the player
- At least 8 notes delivering coherent micro-story
- Stable 60 FPS at 1080p on midrange GPU; no blockers, no crash on shift

## 16. Future Extensions (post-slice)
- Additional threats (corn hands, scarecrow sentries)
- Weather system, day-night cycle for New Game+
- Procedural story events and rogue-lite permutations
- Photo evidence scoring system

---
**Owner tasks (today):**
- Create Godot project and repo
- Import template chunk and build 10-piece graybox
- Implement `PlayerController.gd` skeleton
- Draft 8 note texts in a single text file for quick placement

