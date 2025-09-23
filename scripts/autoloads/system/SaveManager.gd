extends Node
## Persistence for: active inventory, backpack stash, puzzle completion, notes, run status, sanity value.
## On boot: any leftover active inventory is merged into the backpack stash so quits don't lose progress.

const SAVE_PATH: String = "user://save_data.sav"

# -----------------------------
# Persisted state
# -----------------------------
var save_data: Dictionary = {
	"inventory_active": PackedStringArray(),    # items acquired this run
	"backpack_stash": PackedStringArray(),      # delivered to backpack on next run's start tile
	"completed_puzzles": PackedStringArray(),
	"collected_notes": PackedStringArray(),
	"sanity": 100,                              # SanityManager drives this during runs
	"run_active": false,
	"is_completely_new_game": true
}

# -----------------------------
# Internal refs
# -----------------------------
var _bus: Node = null

# =========================
# Lifecycle
# =========================

func _ready() -> void:
	"""Load, reconcile mid-run items into stash, and connect minimal bus hooks."""
	_load_game()
	_bus = get_node_or_null("/root/MessageBus")
	_reconcile_active_inventory_into_stash()   # ensures quit-without-dying progress is preserved
	save_data.run_active = false               # runs start when something calls start_run()
	_connect_bus_minimal()
	_save_game()

# =========================
# Minimal bus hookups
# =========================

func _connect_bus_minimal() -> void:
	"""Only what we truly need: stash inventory on death."""
	if _bus == null:
		return
	if _bus.has_signal("player_died"):
		_bus.connect("player_died", _on_player_died)

func _on_player_died(cause: String, position: Vector2i, data: Dictionary) -> void:
	"""On death, move all active inventory into backpack stash for next run."""
	end_run_to_backpack("death")

# =========================
# File IO
# =========================

func _save_game() -> void:
	"""Write the current save_data to disk."""
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

func _load_game() -> void:
	"""Load save_data from disk and merge with defaults to survive schema changes."""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file")
		return
	var loaded: Variant = file.get_var()
	file.close()
	if typeof(loaded) == TYPE_DICTIONARY:
		var d: Dictionary = loaded as Dictionary
		for k in save_data.keys():
			if d.has(k):
				save_data[k] = d[k]

func delete_save() -> void:
	"""Delete save file and reset to defaults."""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_reset_to_defaults()

func _reset_to_defaults() -> void:
	"""Hard reset to a new-game state."""
	save_data.inventory_active = PackedStringArray()
	save_data.backpack_stash = PackedStringArray()
	save_data.completed_puzzles = PackedStringArray()
	save_data.collected_notes = PackedStringArray()
	save_data.sanity = 100
	save_data.run_active = false
	save_data.is_completely_new_game = true
	_save_game()

# =========================
# Run control
# =========================

func start_run() -> void:
	"""Begin a run. Backpack stash remains untouched until the StartTile consumes it."""
	save_data.run_active = true
	save_data.is_completely_new_game = false
	_save_game()

func end_run_to_backpack(reason: String = "death") -> void:
	"""
	Finish the run and move all active items to the backpack stash.
	Use when the player dies or when you explicitly end a run.
	"""
	_merge_unique_into(save_data.backpack_stash, save_data.inventory_active)
	save_data.inventory_active = PackedStringArray()
	save_data.run_active = false
	_save_game()

func is_continued_run() -> bool:
	"""StartTile uses this to decide whether to show backpack/effigy."""
	return save_data.backpack_stash.size() > 0

# =========================
# Active inventory (this run)
# =========================

func add_item(item_id: StringName) -> void:
	"""Add an item to the active-run inventory and save."""
	var sid: String = String(item_id)
	if not save_data.inventory_active.has(sid):
		save_data.inventory_active.append(sid)
	_save_game()

func remove_item(item_id: StringName) -> void:
	"""Remove an item from the active-run inventory and save."""
	var sid: String = String(item_id)
	save_data.inventory_active = _removed_copy(save_data.inventory_active, sid)
	_save_game()

func has_item(item_id: StringName) -> bool:
	"""Check if an item is in the active-run inventory."""
	return save_data.inventory_active.has(String(item_id))

func get_inventory() -> PackedStringArray:
	"""Return a copy of the active-run inventory list."""
	return save_data.inventory_active

# =========================
# Backpack stash (carryover)
# =========================

func get_previous_run_items() -> PackedStringArray:
	"""Compat for BackpackRestore; items waiting in the backpack."""
	return save_data.backpack_stash

func clear_previous_run_items() -> void:
	"""Backpack consumed its queue; clear it."""
	save_data.backpack_stash = PackedStringArray()
	_save_game()

# =========================
# Puzzles
# =========================

func mark_puzzle_completed(puzzle_id: StringName) -> void:
	"""Mark a puzzle id as completed (idempotent)."""
	var pid: String = String(puzzle_id)
	if not save_data.completed_puzzles.has(pid):
		save_data.completed_puzzles.append(pid)
	_save_game()

func is_puzzle_completed(puzzle_id: StringName) -> bool:
	"""Query whether a puzzle id is completed."""
	return save_data.completed_puzzles.has(String(puzzle_id))

func get_completed_puzzles() -> PackedStringArray:
	"""List all completed puzzle ids."""
	return save_data.completed_puzzles

# =========================
# Notes / Journal
# =========================

func has_note_collected(note_id: StringName) -> bool:
	"""Query whether a note has been collected (journal unlocked)."""
	return save_data.collected_notes.has(String(note_id))

func add_note_collected(note_id: StringName) -> void:
	"""Record a collected note (journal unlock)."""
	var nid: String = String(note_id)
	if not save_data.collected_notes.has(nid):
		save_data.collected_notes.append(nid)
	_save_game()

func get_collected_notes() -> PackedStringArray:
	"""Return all collected note ids."""
	return save_data.collected_notes

# =========================
# Sanity (storage only)
# =========================

func get_sanity() -> int:
	"""Current sanity value (0-100)."""
	return int(save_data.sanity)

func set_sanity(value: int) -> void:
	"""Directly set sanity and emit bus event; SanityManager should prefer modify_sanity."""
	var prev: int = int(save_data.sanity)
	var v: int = clamp(value, 0, 100)
	save_data.sanity = v
	_save_game()
	_emit_sanity_changed(prev, v, v - prev)

func modify_sanity(delta: int) -> void:
	"""Adjust sanity by delta and emit bus event. Called by SanityManager."""
	var prev: int = int(save_data.sanity)
	var v: int = clamp(prev + delta, 0, 100)
	save_data.sanity = v
	_save_game()
	_emit_sanity_changed(prev, v, delta)

func _emit_sanity_changed(old_v: int, new_v: int, delta: int) -> void:
	"""Forward a single sanity_changed event on the bus, if present."""
	if _bus == null:
		return
	if _bus.has_method("emit_event"):
		_bus.call("emit_event", "sanity_changed", [old_v, new_v, delta])

# =========================
# Generic state (limited)
# =========================

func get_state(key: String) -> Variant:
	"""Read a known key from save_data. Avoid using this for new features."""
	return save_data.get(key, null)

# =========================
# Helpers
# =========================

func _reconcile_active_inventory_into_stash() -> void:
	"""
	On boot: move any active-run items into the backpack stash so the
	backpack can present them on the next run. Prevents loss on quit.
	"""
	if save_data.inventory_active.size() <= 0:
		return
	_merge_unique_into(save_data.backpack_stash, save_data.inventory_active)
	save_data.inventory_active = PackedStringArray()

func _merge_unique_into(target: PackedStringArray, add: PackedStringArray) -> void:
	"""In-place uniqueness merge for string arrays."""
	for i in add.size():
		var id: String = add[i]
		if not target.has(id):
			target.append(id)

func _removed_copy(src: PackedStringArray, id: String) -> PackedStringArray:
	"""Return a copy of src without the given id."""
	var out: PackedStringArray = PackedStringArray()
	for i in src.size():
		var v: String = src[i]
		if v != id:
			out.append(v)
	return out
