extends Node
## Event Manager - Unified event system for Project Harvest
## Integrates EventDirector concepts with existing architecture
## Handles all cross-system communication and event processing

# Core EventDirector signals
signal note_shown(id: String, text: String)
signal speech_played(id: String, text: String)
signal pickup_spawned(id: String)
signal pickup_given(id: String)
signal entity_spawned(kind: String)
signal puzzle_started(id: String)
signal sanity_changed(value: int)
signal exit_opened(id: String)
signal run_logged(summary: String)
signal echo_spawned(text: String)
signal ui_glitch(mode: String)
signal cutscene_requested(name: String)
signal run_ended(mode: String)

# Additional signals for manager integration
signal weird_thing_collected(type: String, position: Vector2i)
signal weird_effect_triggered(effect_type: String)
signal maze_shift_requested()
signal tile_entered(tile_id: String)
signal interaction_triggered(tile_id: String, target_id: String)

var data: Dictionary
var state := {
	"sanity": 100,
	"flags": {},
	"inventory": {},
	"visited_once": {},
	"visited_per_run": {},
	"run": {
		"subject_id": "S-" + str(randi() % 1000),
		"last_tile": "",
		"death_type": "",
		"timestamp": "",
		"sanity": 100
	}
}

# Manager references
var game_director: Node
var sanity_manager: Node
var harvest_logger: Node
var weird_things_manager: Node
var tile_manager: Node

func _ready() -> void:
	randomize()
	load_content("res://data/events.json")
	await get_tree().process_frame
	_initialize_manager_connections()

func _initialize_manager_connections():
	"""Connect to existing manager systems"""
	game_director = get_node_or_null("/root/GameDirector")
	sanity_manager = get_node_or_null("/root/SanityManager")
	harvest_logger = get_node_or_null("/root/HarvestLogger") 
	weird_things_manager = get_node_or_null("/root/WeirdThingsManager")
	tile_manager = get_node_or_null("/root/TileManager")
	
	# Connect our signals to managers
	if sanity_manager:
		sanity_changed.connect(sanity_manager._on_event_sanity_changed)
	if harvest_logger:
		run_logged.connect(harvest_logger._on_event_run_logged)
		echo_spawned.connect(harvest_logger._on_event_echo_spawned)
	if weird_things_manager:
		pickup_spawned.connect(weird_things_manager._on_event_pickup_spawned)
		pickup_given.connect(weird_things_manager._on_event_pickup_given)
	if tile_manager:
		maze_shift_requested.connect(tile_manager._on_event_maze_shift)

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

# ===== STATE MANAGEMENT =====

func set_timestamp(ts: String) -> void:
	state.run.timestamp = ts

func set_sanity(v: int) -> void:
	state.sanity = clampi(v, data.constants.sanity_floor, data.constants.sanity_max)
	state.run.sanity = state.sanity
	emit_signal("sanity_changed", state.sanity)

func adjust_sanity(delta: int) -> void:
	set_sanity(state.sanity + delta)

func has_flag(f: String) -> bool:
	return state.flags.get(f, false)

func set_flag(f: String, v: bool = true) -> void:
	state.flags[f] = v

func has_pickup(id: String) -> bool:
	return state.inventory.get(id, false)

func give_pickup(id: String) -> void:
	state.inventory[id] = true
	emit_signal("pickup_given", id)
	
	# Apply pickup effects from events.json
	for p in data.pickups:
		if p.id == id:
			if p.effects.has("sanity_delta"):
				adjust_sanity(p.effects.sanity_delta)
			if p.effects.has("sanity_over_time"):
				set_flag("sanity_drain_active", true)
			if p.effects.has("flags_set"):
				for fl in p.effects.flags_set:
					set_flag(fl)
			if p.effects.has("watcher_bias"):
				set_flag("watcher_bias", true)
			break

func spawn_pickup(id: String) -> void:
	emit_signal("pickup_spawned", id)

# ===== CONTENT DISPLAY =====

func show_note(id: String) -> void:
	var text := _lookup_note_text(id)
	if text != "":
		emit_signal("note_shown", id, text)

func show_speech(id: String) -> void:
	var t: String = data.speeches.get(id, "")
	if t != "":
		emit_signal("speech_played", id, t)

func spawn_entity(kind: String) -> void:
	emit_signal("entity_spawned", kind)

func open_exit(exit_id: String) -> void:
	emit_signal("exit_opened", exit_id)

func start_puzzle(pid: String) -> void:
	emit_signal("puzzle_started", pid)

# ===== TILE AND INTERACTION EVENTS =====

func on_tile_enter(tile_id: String) -> void:
	"""Process tile entry - core game loop integration point"""
	state.run.last_tile = tile_id
	emit_signal("tile_entered", tile_id)
	
	# Get tile data from events.json
	var tile: Dictionary = data.tiles.get(tile_id, {})
	if tile.is_empty(): 
		return
	
	# Apply entry effects
	for eff in tile.get("entry_effects", []):
		_apply_action(eff)
	
	# Process on_enter events with conditions
	_process_events(tile.get("events", []), "on_enter")

func on_interact(tile_id: String, target_id: String = "") -> void:
	"""Handle interaction events"""
	emit_signal("interaction_triggered", tile_id, target_id)
	
	var tile: Dictionary = data.tiles.get(tile_id, {})
	if tile.is_empty(): 
		return
		
	_process_events(tile.get("events", []), "interact")

func on_movement(distance_m: float) -> void:
	"""Handle movement-based random events"""
	for ev in data.get("random_events", []):
		if ev.trigger == "movement" and distance_m >= float(ev.meters):
			if _check_conditions(ev.conditions):
				_apply_actions(ev.actions)

func on_timer(second_tick: int) -> void:
	"""Handle timer-based random events"""
	for ev in data.get("random_events", []):
		if ev.trigger == "timer" and (second_tick % int(ev.seconds) == 0):
			if _check_conditions(ev.conditions):
				_apply_actions(ev.actions)

func on_puzzle_result(pid: String, success: bool) -> void:
	"""Handle puzzle completion results"""
	var p: Dictionary = _find_puzzle(pid)
	if p.is_empty(): 
		return
		
	var actions: Array = p.on_success if success else p.on_failure
	_apply_actions(actions)

func on_use_exit(exit_id: String) -> void:
	"""Handle exit usage"""
	var ex: Dictionary = _find_exit(exit_id)
	if ex.is_empty(): 
		return
		
	_apply_actions(ex.on_use)

# ===== WEIRD THINGS INTEGRATION =====

func on_weird_thing_collected(weird_type: String, position: Vector2i) -> void:
	"""Handle weird thing collection through event system"""
	emit_signal("weird_thing_collected", weird_type, position)
	
	# Convert weird thing type to pickup ID and process
	var pickup_id = _weird_type_to_pickup_id(weird_type)
	if pickup_id != "":
		give_pickup(pickup_id)

func trigger_weird_effect(effect_type: String, _context: Dictionary = {}) -> void:
	"""Trigger weird thing effects through action system"""
	emit_signal("weird_effect_triggered", effect_type)
	
	# Convert effect to standardized actions
	match effect_type:
		"screen_flicker":
			_apply_action({"action": "ui_glitch", "mode": "screen_flicker"})
		"sanity_loss":
			_apply_action({"action": "adjust_sanity", "amount": -5})
		"maze_shift":
			emit_signal("maze_shift_requested")
		"echo_spawn":
			_spawn_echo("echo_run")
		_:
			# Handle other effects through action system
			_apply_action({"action": "weird_effect", "type": effect_type})

# ===== EVENT PROCESSING ENGINE =====

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
			give_pickup(String(a.get("id", "")))
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
			# Bridge to existing weird effects for gradual migration
			emit_signal("weird_effect_triggered", String(a.get("type", "")))
		_:
			# Unknown action; log for debugging
			print("EventManager: Unknown action '", a.get("action", ""), "'")

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

func _find_puzzle(pid: String) -> Dictionary:
	"""Find puzzle by ID"""
	for p in data.get("puzzles", []):
		if p.id == pid: return p
	return {}

func _find_exit(eid: String) -> Dictionary:
	"""Find exit by ID"""  
	for e in data.get("exits", []):
		if e.id == eid: return e
	return {}

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

func _log_harvest(outcome: String) -> void:
	"""Log harvest outcome"""
	var summary := "Subject %s harvested at %s | outcome=%s | sanity=%d | tile=%s" % [
		state.run.subject_id, state.run.timestamp, outcome, state.sanity, state.run.last_tile
	]
	emit_signal("run_logged", summary)

func _weird_type_to_pickup_id(weird_type: String) -> String:
	"""Convert WeirdThingType enum to pickup ID"""
	# This will be used during migration to bridge the two systems
	match weird_type:
		"MIRROR": return "mirror_shard"
		"NOTE": return "research_note"
		"SYMBOL": return "harvest_symbol"
		"POCKET_WATCH": return "time_fragment"
		_: return ""

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

func reset_run_state() -> void:
	"""Reset state for new run"""
	state.visited_per_run.clear()
	state.run.subject_id = "S-" + str(randi() % 1000)
	state.run.last_tile = ""
	state.run.death_type = ""
	state.run.sanity = state.sanity
