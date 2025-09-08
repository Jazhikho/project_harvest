extends Node
## Event Manager - Unified event system for Project Harvest
## Central coordinator for items, puzzles, and game progression

# Core EventDirector signals
signal note_shown(id: String, text: String)
signal speech_played(id: String, text: String)
signal pickup_spawned(id: String, position: Vector3)
signal pickup_collected(id: String)
signal entity_spawned(kind: String, position: Vector3)
signal puzzle_started(id: String)
signal puzzle_piece_used(piece_id: String, puzzle_id: String)
signal puzzle_completed(puzzle_id: String)
signal sanity_changed(value: int)
signal exit_opened(id: String)
signal run_logged(summary: String)
signal echo_spawned(text: String)
signal ui_glitch(mode: String)
signal cutscene_requested(name: String)
signal run_ended(mode: String)
signal final_event_available()

# Item spawning signals
signal item_spawn_requested(tile_position: Vector2i, spawn_points: Array)
signal backpack_spawned(position: Vector3, inventory: Array)
signal effigy_spawned(position: Vector3)

# Additional signals for manager integration
signal weird_thing_collected(type: String, position: Vector2i)
signal weird_effect_triggered(effect_type: String)
signal maze_shift_requested()
signal tile_entered(tile_id: String, position: Vector2i)
signal interaction_triggered(tile_id: String, target_id: String)

var data: Dictionary
var state := {
	"sanity": 100,
	"flags": {},
	"inventory": [],  # Changed to array of item IDs
	"visited_once": {},
	"visited_per_run": {},
	"puzzles_completed": [],  # Track which puzzles are complete
	"puzzle_pieces_placed": {},  # puzzle_id -> [piece_ids]
	"death_locations": [],  # Array of {position: Vector2i, inventory: [], run_id: String}
	"run": {
		"subject_id": "S-" + str(randi() % 1000),
		"last_tile": "",
		"last_position": Vector2i(0, 0),
		"death_type": "",
		"timestamp": "",
		"sanity": 100,
		"start_time": 0.0
	}
}

# Item management
var available_items := {
	"notes": [],  # All note IDs
	"weird_objects": [],  # All weird object IDs
	"puzzle_pieces": []  # All puzzle piece IDs
}
var collected_items := []  # Items that have been collected this run
var spawned_items := {}  # tile_position -> [item_ids] - track what's spawned where

# Puzzle management
var puzzle_requirements := {}  # puzzle_id -> [required_piece_ids]
var permanent_tile_puzzles := {}  # tile_position -> puzzle_id

# Constants
const ITEM_SPAWN_CHANCE := 0.1
const MAX_NOTES_AVAILABLE := 5
const TOTAL_PUZZLES := 5

# Manager references
var game_director: Node
var sanity_manager: Node
var harvest_logger: Node
var tile_manager: Node

func _ready() -> void:
	randomize()
	load_content("res://data/events.json")
	await get_tree().process_frame
	_initialize_manager_connections()
	_initialize_item_pools()

func _initialize_manager_connections():
	"""Connect to existing manager systems"""
	game_director = get_node_or_null("/root/GameDirector")
	sanity_manager = get_node_or_null("/root/SanityManager")
	harvest_logger = get_node_or_null("/root/HarvestLogger") 
	tile_manager = get_node_or_null("/root/TileManager")
	
	# Connect our signals to managers
	if sanity_manager:
		sanity_changed.connect(sanity_manager._on_event_sanity_changed)
	if harvest_logger:
		run_logged.connect(harvest_logger._on_event_run_logged)
		echo_spawned.connect(harvest_logger._on_event_echo_spawned)
	if tile_manager:
		maze_shift_requested.connect(tile_manager._on_event_maze_shift)

func _initialize_item_pools():
	"""Initialize the available items from events.json"""
	if not data.has("pickups"):
		push_error("EventManager: No pickups defined in events.json")
		return
	
	available_items.clear()
	available_items["notes"] = []
	available_items["weird_objects"] = []
	available_items["puzzle_pieces"] = []
	
	for pickup in data.pickups:
		var pickup_type = pickup.get("type", "")
		var pickup_id = pickup.get("id", "")
		
		match pickup_type:
			"note":
				available_items["notes"].append(pickup_id)
			"weird_object":
				available_items["weird_objects"].append(pickup_id)
			"puzzle_piece":
				available_items["puzzle_pieces"].append(pickup_id)
	
	# Initialize puzzle requirements
	if data.has("puzzles"):
		for puzzle in data.puzzles:
			var puzzle_id = puzzle.get("id", "")
			var required_pieces = puzzle.get("required_pieces", [])
			puzzle_requirements[puzzle_id] = required_pieces
	
	print("EventManager: Initialized item pools - ", 
		available_items["notes"].size(), " notes, ",
		available_items["weird_objects"].size(), " weird objects, ",
		available_items["puzzle_pieces"].size(), " puzzle pieces")

func load_content(json_path: String) -> void:
	"""Load events.json content"""
	if not FileAccess.file_exists(json_path):
		push_error("EventManager: events.json not found at " + json_path)
		return
		
	var raw := FileAccess.get_file_as_string(json_path)
	var json = JSON.new()
	var parse_result = json.parse(raw)
	
	if parse_result != OK:
		push_error("EventManager: Failed to parse events.json")
		return
		
	data = json.data
	print("EventManager: Loaded events.json v", data.get("version", "unknown"))

# ===== TILE SPAWNING AND ITEM PLACEMENT =====

func on_tile_spawning(tile_position: Vector2i, spawn_points: Array, is_permanent: bool) -> Dictionary:
	"""Called when a tile is spawning to determine what items should appear
	Returns: { spawn_backpack: bool, backpack_pos: Vector3, items: [{id: String, position: Vector3}], spawn_effigy: bool, effigy_pos: Vector3 }
	"""
	var result = {
		"spawn_backpack": false,
		"backpack_pos": Vector3.ZERO,
		"backpack_inventory": [],
		"items": [],
		"spawn_effigy": false,
		"effigy_pos": Vector3.ZERO
	}
	
	# Step 1: Check if this is a permanent/unique tile
	if is_permanent:
		print("EventManager: Permanent tile at ", tile_position, " - skipping item spawn")
		return result
	
	# Step 2: Randomize spawn point order
	var randomized_spawn_points = spawn_points.duplicate()
	randomized_spawn_points.shuffle()
	
	# Step 3: Check if this is a death location
	var death_data = _get_death_at_position(tile_position)
	if death_data:
		print("EventManager: Death location found at ", tile_position, " - spawning backpack")
		result["spawn_backpack"] = true
		result["backpack_pos"] = randomized_spawn_points[0] if not randomized_spawn_points.is_empty() else Vector3.ZERO
		result["backpack_inventory"] = death_data.get("inventory", [])
		
		# Spawn effigy near the backpack
		result["spawn_effigy"] = true
		result["effigy_pos"] = _calculate_effigy_position(result["backpack_pos"])
		
		# Mark this death location as used
		_mark_death_location_used(tile_position)
		return result
	
	# Step 4: Try to spawn an item (10% chance per spawn point)
	for spawn_point in randomized_spawn_points:
		if randf() < ITEM_SPAWN_CHANCE:
			var item = _select_item_for_spawn()
			if item != "":
				result["items"].append({
					"id": item,
					"position": spawn_point
				})
				_mark_item_spawned(item, tile_position)
				print("EventManager: Spawning item '", item, "' at tile ", tile_position)
				break  # Only one item per tile
	
	return result

func _get_death_at_position(position: Vector2i) -> Dictionary:
	"""Check if there's a death location at this position"""
	for death in state.death_locations:
		if death.get("position") == position and not death.get("used", false):
			return death
	return {}

func _mark_death_location_used(position: Vector2i):
	"""Mark a death location as having spawned its backpack"""
	for death in state.death_locations:
		if death.get("position") == position:
			death["used"] = true

func _calculate_effigy_position(backpack_pos: Vector3) -> Vector3:
	"""Calculate effigy spawn position near backpack"""
	# Try random positions up to 1 meter away
	for attempt in range(10):
		var offset = Vector3(
			randf_range(-1.0, 1.0),
			0,
			randf_range(-1.0, 1.0)
		)
		var test_pos = backpack_pos + offset
		
		# TODO: Add wall collision check here
		# For now, just return the offset position
		return test_pos
	
	return backpack_pos + Vector3(0.5, 0, 0.5)

func _select_item_for_spawn() -> String:
	"""Select an item to spawn based on availability rules"""
	var available_for_spawn = []
	
	# Add first 5 uncollected notes
	var uncollected_notes = []
	for note_id in available_items["notes"]:
		if note_id not in collected_items:
			uncollected_notes.append(note_id)
	
	# Take only first 5 available notes
	for i in range(min(MAX_NOTES_AVAILABLE, uncollected_notes.size())):
		available_for_spawn.append(uncollected_notes[i])
	
	# Add all remaining weird objects
	for weird_id in available_items["weird_objects"]:
		if weird_id not in collected_items:
			available_for_spawn.append(weird_id)
	
	# Add all remaining puzzle pieces
	for piece_id in available_items["puzzle_pieces"]:
		if piece_id not in collected_items:
			available_for_spawn.append(piece_id)
	
	if available_for_spawn.is_empty():
		return ""
	
	# Randomly select one
	return available_for_spawn[randi() % available_for_spawn.size()]

func _mark_item_spawned(item_id: String, tile_position: Vector2i):
	"""Track that an item has been spawned at a tile"""
	if not spawned_items.has(tile_position):
		spawned_items[tile_position] = []
	spawned_items[tile_position].append(item_id)

# ===== ITEM COLLECTION =====

func on_item_collected(item_id: String, tile_position: Vector2i = Vector2i()):
	"""Handle item collection"""
	print("EventManager: Item collected - ", item_id)
	
	# Add to inventory
	if item_id not in state.inventory:
		state.inventory.append(item_id)
	
	# Mark as collected
	if item_id not in collected_items:
		collected_items.append(item_id)
	
	# Remove from spawned items
	if spawned_items.has(tile_position):
		spawned_items[tile_position].erase(item_id)
	
	# If this was a note, make the next note available
	if item_id in available_items["notes"]:
		_unlock_next_note(item_id)
	
	# Apply item effects
	_apply_item_effects(item_id)
	
	emit_signal("pickup_collected", item_id)

func _unlock_next_note(collected_note_id: String):
	"""When a note is collected, make the next one available"""
	var note_index = available_items["notes"].find(collected_note_id)
	if note_index >= 0 and note_index < available_items["notes"].size() - 1:
		var next_note = available_items["notes"][note_index + 1]
		print("EventManager: Next note unlocked - ", next_note)

func _apply_item_effects(item_id: String):
	"""Apply effects when an item is collected"""
	for pickup in data.get("pickups", []):
		if pickup.get("id") == item_id:
			var effects = pickup.get("effects", {})
			
			if effects.has("sanity_delta"):
				adjust_sanity(effects.sanity_delta)
			
			if effects.has("flags_set"):
				for flag in effects.flags_set:
					set_flag(flag)
			
			break

# ===== PUZZLE MANAGEMENT =====

func on_puzzle_piece_used(piece_id: String, puzzle_id: String, tile_position: Vector2i) -> bool:
	"""Handle using a puzzle piece on a puzzle. Returns true if piece was valid"""
	if puzzle_id not in puzzle_requirements:
		print("EventManager: Unknown puzzle - ", puzzle_id)
		return false
	
	var required_pieces = puzzle_requirements[puzzle_id]
	if piece_id not in required_pieces:
		print("EventManager: Wrong piece for puzzle - ", piece_id, " not in ", required_pieces)
		return false
	
	# Remove from inventory
	state.inventory.erase(piece_id)
	
	# Track piece placement
	if puzzle_id not in state.puzzle_pieces_placed:
		state.puzzle_pieces_placed[puzzle_id] = []
	state.puzzle_pieces_placed[puzzle_id].append(piece_id)
	
	emit_signal("puzzle_piece_used", piece_id, puzzle_id)
	
	# Check if puzzle is complete
	var placed_pieces = state.puzzle_pieces_placed[puzzle_id]
	var all_pieces_placed = true
	for required_piece in required_pieces:
		if required_piece not in placed_pieces:
			all_pieces_placed = false
			break
	
	if all_pieces_placed:
		_complete_puzzle(puzzle_id, tile_position)
	
	return true

func _complete_puzzle(puzzle_id: String, tile_position: Vector2i):
	"""Handle puzzle completion"""
	print("EventManager: PUZZLE COMPLETED - ", puzzle_id)
	
	state.puzzles_completed.append(puzzle_id)
	emit_signal("puzzle_completed", puzzle_id)
	
	# Remove tile from permanent status
	if tile_manager and tile_manager.has_method("remove_permanent_tile"):
		tile_manager.remove_permanent_tile(tile_position)
	
	# Check if all puzzles are complete
	if state.puzzles_completed.size() >= TOTAL_PUZZLES:
		print("EventManager: ALL PUZZLES COMPLETE - Final event now available!")
		set_flag("final_event_available")
		emit_signal("final_event_available")

func register_permanent_tile_puzzle(tile_position: Vector2i, puzzle_id: String):
	"""Register that a permanent tile has a specific puzzle"""
	permanent_tile_puzzles[tile_position] = puzzle_id
	print("EventManager: Registered puzzle '", puzzle_id, "' at tile ", tile_position)

# ===== DEATH AND RUN MANAGEMENT =====

func on_player_death(cause: String, position: Vector2i):
	"""Handle player death and save state for next run"""
	state.run.death_type = cause
	
	# Save death location with current inventory
	state.death_locations.append({
		"position": position,
		"inventory": state.inventory.duplicate(),
		"run_id": state.run.subject_id,
		"used": false
	})
	
	# Limit stored death locations
	if state.death_locations.size() > 10:
		state.death_locations.pop_front()
	
	_log_harvest(cause)
	emit_signal("run_ended", cause)

func on_tile_cleanup(tile_position: Vector2i):
	"""Called when a tile is being cleaned up"""
	# Remove any spawned items that weren't collected
	if spawned_items.has(tile_position):
		print("EventManager: Cleaning up ", spawned_items[tile_position].size(), " items from tile ", tile_position)
		spawned_items.erase(tile_position)

# ===== STATE MANAGEMENT =====

func set_timestamp(ts: String) -> void:
	state.run.timestamp = ts

func set_sanity(v: int) -> void:
	state.sanity = clampi(v, 0, 100)
	state.run.sanity = state.sanity
	emit_signal("sanity_changed", state.sanity)

func adjust_sanity(delta: int) -> void:
	set_sanity(state.sanity + delta)

func has_flag(f: String) -> bool:
	return state.flags.get(f, false)

func set_flag(f: String, v: bool = true) -> void:
	state.flags[f] = v

func get_inventory() -> Array:
	"""Get current player inventory"""
	return state.inventory.duplicate()

func has_item(item_id: String) -> bool:
	"""Check if player has a specific item"""
	return item_id in state.inventory

func remove_from_inventory(item_id: String) -> bool:
	"""Remove an item from inventory. Returns true if item was present"""
	if item_id in state.inventory:
		state.inventory.erase(item_id)
		return true
	return false

# ===== TILE AND INTERACTION EVENTS =====

func on_tile_enter(tile_id: String, tile_position: Vector2i = Vector2i()) -> void:
	"""Process tile entry - core game loop integration point"""
	state.run.last_tile = tile_id
	state.run.last_position = tile_position
	emit_signal("tile_entered", tile_id, tile_position)
	
	# Get tile data from events.json
	var tile: Dictionary = data.tiles.get(tile_id, {})
	if tile.is_empty(): 
		return
	
	# Apply entry effects
	for eff in tile.get("entry_effects", []):
		_apply_action(eff)
	
	# Process on_enter events with conditions
	_process_events(tile.get("events", []), "on_enter")

# [Keep remaining helper functions and action processing from original...]

func reset_run_state() -> void:
	"""Reset state for new run"""
	state.visited_per_run.clear()
	state.inventory.clear()
	state.run.subject_id = "S-" + str(randi() % 1000)
	state.run.last_tile = ""
	state.run.last_position = Vector2i(0, 0)
	state.run.death_type = ""
	state.run.sanity = 100
	state.run.start_time = Time.get_unix_time_from_system()
	
	# Reset collected items but keep death locations and puzzle progress
	collected_items.clear()
	spawned_items.clear()

# ===== PUBLIC API =====

func get_state() -> Dictionary:
	"""Get current game state"""
	return state.duplicate(true)

func get_sanity() -> int:
	"""Get current sanity value"""
	return state.sanity

func get_flags() -> Dictionary:
	"""Get current flags"""
	return state.flags.duplicate()

func is_final_event_available() -> bool:
	"""Check if the final event tile should spawn"""
	return has_flag("final_event_available")

func get_final_tile_spawn_weight() -> float:
	"""Get spawn weight for final tile (0.5 when available, 0.0 otherwise)"""
	return 0.5 if is_final_event_available() else 0.0
	
func _process_events(events: Array, needed_trigger: String) -> void:
	"""Process events with specific trigger"""
	for e in events:
		if e.trigger != needed_trigger: 
			continue
		if _check_conditions(e.get("conditions", {})):
			_apply_actions(e.get("actions", []))
			
			# Handle once/once_per_run tracking
			var conditions = e.get("conditions", {})
			if conditions.get("once", false):
				state.visited_once[e.get("id", "__anon__")] = true
			if conditions.get("once_per_run", false):
				state.visited_per_run[e.get("id", "__anon__")] = true

func _check_conditions(cond: Dictionary) -> bool:
	"""Check if event conditions are met"""
	if cond.is_empty(): 
		return true
	
	# Once per save
	if cond.get("once", false) and state.visited_once.get(cond.get("id","__anon__"), false):
		return false
	if cond.get("once_per_run", false) and state.visited_per_run.get(cond.get("id","__anon__"), false):
		return false
	
	# Sanity bounds
	if cond.has("sanity_min") and state.sanity < int(cond.sanity_min): 
		return false
	if cond.has("sanity_max") and state.sanity > int(cond.sanity_max): 
		return false
	
	# Flags
	if cond.has("flags_all"):
		for f in cond.flags_all:
			if not has_flag(f): 
				return false
	if cond.has("flags_any"):
		var ok := false
		for f in cond.flags_any:
			if has_flag(f): 
				ok = true
		if not ok: 
			return false
	if cond.has("flags_not"):
		for f in cond.flags_not:
			if has_flag(f): 
				return false
	
	return true

func _apply_actions(actions: Array) -> void:
	"""Apply multiple actions"""
	for a in actions:
		_apply_action(a)

func _apply_action(a: Dictionary) -> void:
	"""Apply single action - core of the event system"""
	match a.get("action", ""):
		"adjust_sanity":
			adjust_sanity(int(a.get("amount", 0)))
		"set_flag":
			set_flag(String(a.get("flag", "")), true)
		"show_note":
			show_note(String(a.get("id", "")))
		"show_speech":
			show_speech(String(a.get("id", "")))
		"spawn_entity":
			spawn_entity(String(a.get("type", "")))
		"spawn_pickup":
			spawn_pickup(String(a.get("id", "")))
		"give_pickup":
			on_item_collected(String(a.get("id", "")))  # Changed to use new function
		"start_puzzle":
			start_puzzle(String(a.get("id", "")))
		"open_exit":
			open_exit(String(a.get("exit_id", "")))
		"spawn_echo":
			_spawn_echo(String(a.get("template", "")))
		"ui_glitch":
			emit_signal("ui_glitch", String(a.get("mode", "")))
		"log_harvest":
			_log_harvest(String(a.get("outcome", "")))
		"cutscene":
			emit_signal("cutscene_requested", String(a.get("name", "")))
		"end_run":
			emit_signal("run_ended", String(a.get("mode", "")))
		"weird_effect":
			emit_signal("weird_effect_triggered", String(a.get("type", "")))
		_:
			print("EventManager: Unknown action '", a.get("action", ""), "'")

func _log_harvest(outcome: String) -> void:
	"""Log harvest outcome"""
	var summary := "Subject %s harvested at %s | outcome=%s | sanity=%d | tile=%s" % [
		state.run.subject_id, state.run.timestamp, outcome, state.sanity, state.run.last_tile
	]
	emit_signal("run_logged", summary)

# ===== CONTENT DISPLAY FUNCTIONS =====

func show_note(id: String) -> void:
	var text := _lookup_note_text(id)
	if text != "":
		emit_signal("note_shown", id, text)

func show_speech(id: String) -> void:
	var t: String = data.speeches.get(id, "")
	if t != "":
		emit_signal("speech_played", id, t)

func spawn_entity(kind: String) -> void:
	emit_signal("entity_spawned", kind, Vector3.ZERO)

func open_exit(exit_id: String) -> void:
	emit_signal("exit_opened", exit_id)

func start_puzzle(pid: String) -> void:
	emit_signal("puzzle_started", pid)

func spawn_pickup(id: String) -> void:
	emit_signal("pickup_spawned", id, Vector3.ZERO)

# ===== HELPER FUNCTIONS =====

func _lookup_note_text(id: String) -> String:
	"""Look up note text from events.json"""
	# Search logs, drafts, staff, env
	for n in data.get("dr_a_logs", []):
		if n.id == id: return n.text
	for n in data.get("dr_a_drafts", []):
		if n.id == id: return n.text
	for n in data.get("staff_memos", []):
		if n.id == id: return n.text
	for n in data.get("notes_env", []):
		if n.id == id: return n.text
	return ""

func _spawn_echo(template_id: String) -> void:
	"""Spawn echo with text substitution"""
	var t: Dictionary = {}
	for et in data.get("echo_templates", []):
		if et.id == template_id:
			t = et
			break
	if t.is_empty(): 
		return
		
	var txt: String = t.text
	txt = txt.replace("{subject_id}", state.run.subject_id)
	txt = txt.replace("{timestamp}", state.run.timestamp)
	txt = txt.replace("{death_type}", state.run.death_type if state.run.death_type != "" else "unknown")
	txt = txt.replace("{sanity}", str(state.sanity))
	txt = txt.replace("{tile_id}", state.run.last_tile)
	emit_signal("echo_spawned", txt)
