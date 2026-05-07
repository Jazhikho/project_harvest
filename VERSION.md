# Version History

## 1.6.0.4 - 2026-04-23

- Fixed final gate victory handling so game-end cleanup runs before the credits transition, and the transition no longer depends on the final gate node surviving scene cleanup.
- Added guards around optional final-gate SFX and message bus calls during the victory sequence.

## 1.6.0.3 - 2026-04-22

- Fixed puzzle save-state updates so they no longer erase a puzzle's persisted `completed` flag.
- Added save repair on load to restore completed prerequisite puzzles from permanently used puzzle items, allowing affected existing saves to recover without starting over.

## 1.6.0.2 - 2026-04-22

- Added a deterministic fallback for the final gate key: once `whispering_hollow`, `watching_stones`, and `crows_parliament` are complete, the key spawns at the gate if it is not already in inventory, backpack, or the world.

## 1.6.0.1 - 2026-04-22

- Fixed the final gate key so it becomes the next eligible world-item drop after `whispering_hollow`, `watching_stones`, and `crows_parliament` are all completed.
- Fixed duplicate spawn-list filtering so the same item is not selected multiple times on a single tile pass.
