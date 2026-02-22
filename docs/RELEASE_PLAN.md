# Project Harvest — Release Plan & Code Review

**Version:** 1.6 (Updated Release)  
**Date:** February 2026  
**Scope:** High-impact, low-effort improvements + planned features

---

## Table of Contents

1. [Code Review Results](#code-review-results)
2. [Implementation Plan](#implementation-plan)
3. [Platform Releases](#platform-releases)

---

## Code Review Results

This section documents findings from thorough reviews against project rules (user rules, `.cursorrules_general_architecture`), plus general code quality checks.

### 1. Bugs & Critical Issues

| Issue | Severity | Location | Description |
|-------|----------|----------|-------------|
| MazeManager missing `can_move()` | **Critical** | `Stalker.gd:171,188` | Stalker calls `maze_manager.can_move()` for pathfinding; MazeManager has no such method. Deferred to Implementation Plan "The Stalker – fix & introduce". See TODO in `Stalker._calculate_next_pathfinding_step()`. |

### 2. General Code Quality

| Category | Findings |
|----------|----------|
| **Commented-out code** | Player flight-mode block removed. Concept Files/WeirdThingsManager.gd is fully commented. |
| **Script size** | Player.gd (~40+ functions), TileManager.gd (1000+ lines), ItemManager.gd (~600 lines) exceed soft ~10-functions-per-script guideline. Consider splitting. |

### 3. Inconsistencies & Technical Debt

- **Stalker activation:** Stalker starts DORMANT and must be activated; activation logic depends on WeirdThingsManager/EnemyManager. With WeirdThingsManager absent and `can_move` missing, Stalker may never function correctly.
- **Death cause vs. DeathScreen:** DeathScreen matches `death_type` to strings like "sanity", "Fragmented", "entity", "Consumed", "Terminated", "Abandoned", "Harvested". GameDirector/DeathHandler use "Consumed", "Force Quit", "Victory", "Harvested", etc. Ensure mapping is complete.
- **Duplicate death logic:** DeathHandler and GameController both handle death flow—verify no duplicate processing.
- **`emit_event` vs. direct signal emit:** MessageBus uses `emit_event(signal_name, args)`; GameDirector line 328 uses `emit_event(...)` but inherits from BaseManager. Verify BaseManager.emit_event forwards to MessageBus correctly.
- **`entity_state_changed` signal vs. call sites:** Resolved. Effigy and BaseEntity now emit 4-arg signature (entity_type, entity_node, old_state, new_state).

### 4. Asset & Data Notes

- **items.json:** 700+ lines; rich lore notes. Categories: tools, notes, puzzle_pieces, special. No `weird_objects` category.
- **GameSettings.tres:** Centralized tuning for flashlight, sanity, stalker, watcher, maze, etc. Use for scaling sanity, battery, and day/night.
- **TimeOfDayController:** `duration_sec` (default 90) controls day→night transition. Export var—configurable in Inspector.

---

## Implementation Plan

Tasks are ordered from quickest to longest effort.

| Task | Effort | Notes |
|------|--------|-------|
| ~~Fix EnemyManager typo~~ | Done | Changed `get_collecte d_count` → `get_collected_count` in `EnemyManager.gd:417` |
| Extend day/night transition | ~15 min | Increase `TimeOfDayController.duration_sec` (e.g., 90 → 180 or 240). Expose via GameSettings if desired. |
| OS username easter egg | ~20 min | Use `OS.get_environment("USERNAME")` or `OS.get_environment("USER")` in one death quote or note; e.g., "Subject [username] terminated. Data archived." |
| Add controller bindings | ~30 min | Add joypad events to Input Map in project.godot (move, sprint, interact, flashlight, inventory, journal, pause) |
| Extend run time | ~1 hr | Increase session length via GameDirector/GameStateManager. Options: longer maze shift intervals (GameSettings), slower sanity decay (SanityManager), or extend time before difficulty ramps (GameDirector `session_time > 300` threshold). |
| Flashlight battery tuning | ~1 hr | Adjust in Player.gd or GameSettings: lower `flashlight_battery_max`, increase `flashlight_drain_rate`, or narrow rand range (e.g., 120–300 instead of 120–420) to make battery feel tighter. |
| Scale sanity | ~1–2 hrs | Adjust sanity thresholds/decay in SanityManager and GameConstants. Options: slower passive decay, different threshold values (e.g., SANITY_THRESHOLD_LOW 40→35), or sanity modifiers from GameSettings for "gentler" or "harsher" runs. |
| Faux difficulty settings | ~2 hrs | Add difficulty options to Settings/Main Menu (e.g., "Easy", "Normal", "Hard"). Labels mock the player (e.g., "You think this changes anything?") but do not alter gameplay. Store in SettingsManager; optionally show different Dr. Amundsen line on death based on "selected" difficulty. |
| The Stalker – fix & introduce | ~3 hrs | 1) Add `can_move(from_x, from_y, to_x, to_y)` to MazeManager (or delegate to TileManager) so Stalker pathfinding works. 2) Ensure Stalker is activated appropriately (sanity thresholds, spawn conditions). 3) Optional: first-encounter narrative cue ("Something is watching...") when Stalker activates. |
| Reduce game file size | ~2–4 hrs | Audit assets: recompress textures (ETC2/ASTC), optimize models (LOD, decimation), remove unused assets, convert large DAE/FBX to GLB. Check ASSET_TRACKER.md for large files (e.g., paper_debris 13MB, crow 23MB, maize_corn_plant 7MB). Add `.gitattributes` for LFS if needed. |
| Fix/add lore notes | ~2–4 hrs | 1) Fix typos/consistency in items.json. 2) Add new notes for Dr. Amundsen, prior subjects, experiment logs. 3) Ensure note subcategories align with journal filters. 4) Cross-check note IDs referenced in puzzles (crows_parliament_note, watching_stones_note, etc.). |
| ~~Migrate managers to BaseManager~~ | Done | Completed: SpawnManager, ItemManager, TileManager, EnemyManager, EffigyManager, DeathHandler, EventManager, HarvestLogger, SanityManager, MazeManager, TileStateManager, SettingsManager, AudioManager extend BaseManager. MessageBus, GameStateManager, SaveManager stay as Node (foundation). |

### Suggested Week Schedule

| Day | Tasks |
|-----|-------|
| 1 | Fix EnemyManager typo, extend day/night, OS username, controller bindings |
| 2 | Extend run time, flashlight battery, scale sanity |
| 3 | Faux difficulty settings; migrate managers to BaseManager |
| 4 | The Stalker – fix & introduce |
| 5 | Fix/add lore notes; begin file size audit |
| 6 | Reduce game file size; validate macOS release |
| 7 | Web release (export preset, Web-specific fixes, host and test); polish |

### Code Review Fixes to Incorporate

Before or during the above work, address:

1. **Stalker `can_move` bug** — implement `can_move` in MazeManager (or TileManager) using connection data.
2. **~~EnemyManager typo~~** — Done. Fixed `get_collecte d_count` → `get_collected_count`.
3. **~~HUD robustness~~** — Done. GameDirector now has `get_weird_findings_count()` stub.
4. **~~File naming~~** — Done. Tile.gd/Corn.gd PascalCase; CrowsParlimentPuzzle.gd removed.
5. **~~Explicit typing~~** — Done. BaseManager `system_node`; Player `items_array`/`items_to_check`; Watcher/Stalker return types added.
6. **~~SaveManager autoload access~~** — Done. SaveManager uses `get_node_or_null` and null check.
7. **~~Remove debug prints~~** — Done. All `print()` calls removed from release scripts.
8. **~~Remove commented code~~** — Done. Player flight-mode block removed.
9. **~~Player.gd hearbeat typo~~** — Done. Fallback branch and comment removed; SFX uses `heartbeat`.
10. **~~@export descriptions~~** — Done. Added `##` above exports in GameController, MainMenu, Watcher, Effigy, WatchingStonesPuzzle, WellPuzzle, FinalGatePuzzle, TimeOfDayController.
11. **~~Player.gd indentation~~** — Done. Fixed extra indent in `_make_player3d`; sibling functions at same level.
12. **~~Effigy `set_aggression_mode(active)`~~** — Done. Uses `active` parameter; branches on active for enter/exit behavior.
13. **~~Watcher / SanityManager~~** — Done. Watcher connects to MessageBus `sanity_changed`; SanityManager has `get_sanity_spawn_rate()`.
14. **~~MessageBus `entity_state_changed`~~** — Done. Effigy and BaseEntity emit 4-arg signature.
15. **~~Dead code~~** — Done. Effigy helpers, Stalker transitions, BaseManager/BaseEntity log_info, MessageBus _format_args/debug_print_emission_stack removed; Player `_show_interaction_prompt` implemented.
16. **~~NodePath caching~~** — Done. Watcher caches Camera3D; Player caches GameStateManager, SaveManager, GameController in `_initialize_systems()`.

---

## Platform Releases

### Web Release

| Task | Effort | Notes |
|------|--------|-------|
| Add Web export preset | ~30 min | Project → Export → Add… → Web. Configure export path (e.g., `../web/index.html`). Choose export type (template or custom). |
| Address Web-specific constraints | ~2–4 hrs | **Audio:** Browsers require user gesture before playback. Ensure first input (click/any key) enables audio before music/sfx. **Mouse lock:** Use `pointer lock` for look; may need click-to-focus prompt. **Storage:** `user://` maps to IndexedDB; save/load should work. **OS.get_environment("USERNAME")** in OS username easter egg may be empty or restricted in browser—add fallback or omit for Web build. |
| Optimize for Web payload | ~1–2 hrs | Web export adds overhead. Consider: reduce texture resolution, lower LOD, enable export compression. Align with "Reduce game file size" task. |
| Host and test | ~1 hr | Host exported `index.html`, `.pck`, `.wasm` on static host (GitHub Pages, itch.io, Netlify). Verify full playthrough in Chrome, Firefox, Safari. |

**Dependencies:** Complete "Reduce game file size" first to improve load times.

### Validate macOS Release

| Task | Effort | Notes |
|------|--------|-------|
| Build and smoke test | ~30 min | Export with macOS preset. Launch on Intel and Apple Silicon (or via Rosetta). Confirm game starts, loads, and runs. |
| Gatekeeper flow | ~15 min | Follow MACOS_INSTALL.md steps. Ensure MAC_USERS_READ_THIS.txt is in .zip per MAC_DISTRIBUTION_GUIDE.md. Verify right-click → Open and "Open Anyway" paths work. |
| Full playthrough | ~1 hr | Run start → puzzles → escape path on macOS. Check: mouse capture, audio, save/load, death screen, credits. |
| System requirements | ~15 min | Confirm min macOS versions (currently Intel 10.12, ARM 11.00) in export_presets.cfg. Update README if needed. |

**Reference:** `MACOS_INSTALL.md`, `MAC_DISTRIBUTION_GUIDE.md`, `export_presets.cfg` (preset.1)

---

## Appendix: Reference Locations

- **GameConstants:** `scripts/utils/GameConstants.gd`
- **GameSettings:** `scripts/resources/GameSettings.gd`
- **TimeOfDayController:** `scripts/systems/TimeOfDayController.gd`
- **Player (flashlight):** `scripts/entities/Player.gd` (flashlight_battery, flashlight_drain_rate)
- **SanityManager:** `scripts/autoloads/gameloop/SanityManager.gd`
- **Stalker:** `scripts/entities/Stalker.gd`
- **MazeManager:** `scripts/autoloads/gameloop/MazeManager.gd`
- **items.json:** `data/items.json`
- **ASSET_TRACKER:** `ASSET_TRACKER.md`
- **Export presets:** `export_presets.cfg`
- **macOS install:** `MACOS_INSTALL.md`
- **macOS distribution:** `MAC_DISTRIBUTION_GUIDE.md`
