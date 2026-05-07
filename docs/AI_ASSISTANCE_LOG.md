# AI Assistance Log

## 2026-04-23

- Model/tool used: GPT-5.4 (Codex)
- Task purpose: Diagnose and fix the crash after opening the final gate when the game should transition to the ending credits.
- Input materials used: `scripts/puzzles/FinalGatePuzzle.gd`, `scripts/autoloads/system/SceneManager.gd`, `scripts/autoloads/gameloop/GameDirector.gd`, `scripts/ui/EndingCredits.gd`, `scenes/ui/EndingCredits.tscn`, Godot runtime logs, existing regression tests, version/history tracking files.
- What AI produced: A safer victory sequence that caches autoload references, runs game-end cleanup before loading credits, avoids relying on the final gate node after cleanup, guards optional SFX/message bus calls, adds a final-gate transition regression test, and updates version/history tracking.
- What the user accepted: Pending review in this working tree.
- What the user rejected: None recorded.
- What the user changed: None recorded in this patch set.
- Who approved the final version: Pending user approval.

## 2026-04-22

- Model/tool used: GPT-5.4 (Codex)
- Task purpose: Diagnose why existing saves still failed to unlock the final gate key and repair puzzle completion persistence without requiring a new game.
- Input materials used: `scripts/autoloads/system/SaveManager.gd`, `scripts/puzzles/WellPuzzle.gd`, `scripts/puzzles/WatchingStonesPuzzle.gd`, `scripts/puzzles/CrowsParliamentPuzzle.gd`, local Windows save data, existing regression tests, version/history tracking files.
- What AI produced: Root-cause analysis for overwritten puzzle completion flags, a save-state merge fix, a load-time repair routine that reconstructs completed puzzles from permanently used puzzle items, a regression test for save repair, and version/history tracking updates.
- What the user accepted: Pending review in this working tree.
- What the user rejected: None recorded.
- What the user changed: None recorded in this patch set.
- Who approved the final version: Pending user approval.

## 2026-04-22

- Model/tool used: GPT-5.4 (Codex)
- Task purpose: Diagnose and fix the final gate key not entering the world-item drop rotation after all prerequisite puzzles were solved in the Windows build.
- Input materials used: `scripts/autoloads/gameloop/ItemManager.gd`, `scripts/puzzles/FinalGatePuzzle.gd`, `scripts/autoloads/system/SaveManager.gd`, `data/items.json`, `data/SpawnCatalog.tres`, `project.godot`, `scripts/utils/BuildInfo.gd`, repository instructions.
- What AI produced: Root-cause analysis, a spawn-logic patch that prioritizes `hollow_key` once all three prerequisite puzzles are complete, a duplicate-filter fix for per-tile spawn lists, and version/history tracking updates.
- What the user accepted: Pending review in this working tree.
- What the user rejected: None recorded.
- What the user changed: None recorded in this patch set.
- Who approved the final version: Pending user approval.

## 2026-04-22

- Model/tool used: GPT-5.4 (Codex)
- Task purpose: Add a deterministic fallback so the final gate key cannot fail to appear after the prerequisite puzzles are completed.
- Input materials used: `scripts/puzzles/FinalGatePuzzle.gd`, `scenes/tiles/Final_Gate.tscn`, `scripts/items/BaseItem.gd`, `scripts/autoloads/gameloop/ItemManager.gd`, existing version/history tracking files.
- What AI produced: A gate-side key spawn fallback, a version bump to `1.6.0.2`, and documentation updates for the additional bug fix.
- What the user accepted: Pending review in this working tree.
- What the user rejected: None recorded.
- What the user changed: None recorded in this patch set.
- Who approved the final version: Pending user approval.
