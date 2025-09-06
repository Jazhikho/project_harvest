extends Node
## Harvest Logger - Manages run persistence and echo system
## Core feature of Project Harvest - makes failed runs part of future attempts

signal echo_spawned(echo_type: String, position: Vector2)
signal run_logged(run_data: Dictionary)

@export var max_stored_runs: int = 10
@export var echo_spawn_chance: float = 0.8
@export var max_echoes_per_run: int = 3

var save_file_path: String = "user://harvest_log.json"
var run_history: Array[Dictionary] = []

# Echo types that can be spawned
enum EchoType {
	CORPSE,         # Physical remains of previous run
	EFFIGY,         # Scarecrow representation  
	NOTE,           # Written record of previous attempt
	WHISPER,        # Audio echo of past subject
	ARTIFACT,       # Distorted item from previous run
	SHADOW          # Visual ghostly replay
}

func _ready():
	_load_run_history()

func _load_run_history():
	"""Load previous run data from disk"""
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				run_history = json.data.get("runs", [])
				print("Loaded ", run_history.size(), " previous runs from harvest log")
			else:
				print("Failed to parse harvest log JSON")
	else:
		print("No previous harvest log found - starting fresh")

func _save_run_history():
	"""Save run history to disk"""
	var data = {
		"runs": run_history,
		"last_updated": Time.get_datetime_string_from_system()
	}
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("Harvest log saved with ", run_history.size(), " runs")
	else:
		print("Failed to save harvest log")

func log_run_completion(cause: String, death_location: Vector2, final_sanity: int, weird_things_collected: int):
	"""Log a completed run for future echo generation"""
	var run_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"unix_time": Time.get_unix_time_from_system(),
		"cause_of_death": cause,
		"death_location": {
			"x": death_location.x,
			"y": death_location.y
		},
		"final_sanity": final_sanity,
		"weird_things_collected": weird_things_collected,
		"survival_time": _get_current_run_time(),
		"subject_id": _generate_subject_id()
	}
	
	run_history.append(run_data)
	
	# Prune old runs if we exceed the limit
	if run_history.size() > max_stored_runs:
		run_history = run_history.slice(run_history.size() - max_stored_runs)
	
	_save_run_history()
	emit_signal("run_logged", run_data)
	
	print("RUN LOGGED: Subject ", run_data["subject_id"], " - ", cause)

func spawn_echoes_from_previous_runs():
	"""Spawn echoes from previous runs at game start"""
	if run_history.is_empty():
		return
	
	var echoes_spawned = 0
	var maze_manager = get_node("/root/MazeManager")
	
	if not maze_manager:
		return
	
	# Process recent runs (skip the very latest as it would be the current run)
	var runs_to_process = run_history.slice(0, min(5, run_history.size()))
	
	for run_data in runs_to_process:
		if echoes_spawned >= max_echoes_per_run:
			break
			
		if randf() < echo_spawn_chance:
			_spawn_echo_from_run(run_data, maze_manager)
			echoes_spawned += 1

func _spawn_echo_from_run(run_data: Dictionary, maze_manager: Node):
	"""Spawn a specific echo based on run data"""
	var echo_type = _determine_echo_type(run_data)
	var spawn_position = _find_echo_spawn_position(run_data, maze_manager)
	
	if spawn_position == Vector2i(-1, -1):
		return
	
	match echo_type:
		EchoType.CORPSE:
			_spawn_corpse_echo(run_data, spawn_position)
		EchoType.EFFIGY:
			_spawn_effigy_echo(run_data, spawn_position)
		EchoType.NOTE:
			_spawn_note_echo(run_data, spawn_position)
		EchoType.WHISPER:
			_spawn_whisper_echo(run_data, spawn_position)
		EchoType.ARTIFACT:
			_spawn_artifact_echo(run_data, spawn_position)
		EchoType.SHADOW:
			_spawn_shadow_echo(run_data, spawn_position)

func _determine_echo_type(run_data: Dictionary) -> EchoType:
	"""Determine what type of echo to spawn based on run data"""
	match run_data["cause_of_death"]:
		"Consumed":
			return EchoType.CORPSE if randf() < 0.6 else EchoType.EFFIGY
		"Harvested":
			return EchoType.EFFIGY if randf() < 0.7 else EchoType.ARTIFACT
		"Fragmented":
			return EchoType.WHISPER if randf() < 0.8 else EchoType.SHADOW
		"Exchanged":
			return EchoType.SHADOW if randf() < 0.9 else EchoType.NOTE
		_:
			return EchoType.NOTE

func _find_echo_spawn_position(run_data: Dictionary, maze_manager: Node) -> Vector2i:
	"""Find a suitable position to spawn an echo"""
	var maze_size = maze_manager.get_maze_size()
	
	# Try to spawn near death location first
	var death_pos = Vector2i(run_data["death_location"]["x"], run_data["death_location"]["y"])
	
	# Search in expanding radius around death location
	for radius in range(1, 6):
		for attempt in range(10):
			var offset = Vector2i(
				randi_range(-radius, radius),
				randi_range(-radius, radius)
			)
			var pos = death_pos + offset
			
			if _is_valid_echo_position(pos, maze_manager, maze_size):
				return pos
	
	# Fallback to random position
	for attempt in range(20):
		var pos = Vector2i(
			randi_range(5, maze_size.x - 5),
			randi_range(5, maze_size.y - 5)
		)
		if _is_valid_echo_position(pos, maze_manager, maze_size):
			return pos
	
	return Vector2i(-1, -1)

func _is_valid_echo_position(pos: Vector2i, maze_manager: Node, maze_size: Vector2i) -> bool:
	"""Check if position is valid for echo spawning"""
	if pos.x < 0 or pos.x >= maze_size.x or pos.y < 0 or pos.y >= maze_size.y:
		return false
	
	var cell = maze_manager.get_cell(pos.x, pos.y)
	if cell == null:
		return false
	
	# Prefer accessible areas
	var wall_count = 0
	for wall in ["top", "right", "bottom", "left"]:
		if cell.walls[wall]:
			wall_count += 1
	
	return wall_count < 4  # Not completely enclosed

func _spawn_corpse_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn a corpse echo from a consumed subject"""
	var echo_data = {
		"type": "corpse",
		"position": position,
		"subject_id": run_data["subject_id"],
		"timestamp": run_data["timestamp"],
		"message": "The remains of Subject " + str(run_data["subject_id"]) + " - consumed " + run_data["timestamp"]
	}
	
	# TODO: Instantiate 3D corpse model
	print("ECHO SPAWNED: Corpse of ", run_data["subject_id"], " at ", position)
	emit_signal("echo_spawned", "corpse", Vector2(position.x, position.y))

func _spawn_effigy_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn a scarecrow effigy representing a harvested subject"""
	var echo_data = {
		"type": "effigy", 
		"position": position,
		"subject_id": run_data["subject_id"],
		"message": "Scarecrow effigy - Subject " + str(run_data["subject_id"]) + " harvested for the collection"
	}
	
	# TODO: Instantiate scarecrow model
	print("ECHO SPAWNED: Effigy of ", run_data["subject_id"], " at ", position)
	emit_signal("echo_spawned", "effigy", Vector2(position.x, position.y))

func _spawn_note_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn a note echo containing previous run information"""
	var note_text = _generate_note_text(run_data)
	
	var echo_data = {
		"type": "note",
		"position": position,
		"text": note_text,
		"subject_id": run_data["subject_id"]
	}
	
	# TODO: Instantiate note pickup
	print("ECHO SPAWNED: Note from ", run_data["subject_id"], " at ", position)
	emit_signal("echo_spawned", "note", Vector2(position.x, position.y))

func _generate_note_text(run_data: Dictionary) -> String:
	"""Generate note text based on previous run data"""
	var templates = [
		"Day X - I can hear them in the corn. The walls won't stop moving. -Subject Y",
		"Found Z strange objects today. Each one makes the whispers louder. -Y", 
		"The maze remembers everything. I've been here before, haven't I? -Subject Y",
		"Dr. A is watching. Always watching. The harvest approaches. -Y",
		"Sanity holding at Z%. But the shadows are getting closer. -Subject Y"
	]
	
	var template = templates[randi() % templates.size()]
	template = template.replace("Y", str(run_data["subject_id"]))
	template = template.replace("Z", str(run_data["weird_things_collected"]))
	
	return template

func _spawn_whisper_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn an audio whisper echo"""
	var whisper_text = _generate_whisper_text(run_data)
	
	# TODO: Implement spatial audio whisper
	print("ECHO SPAWNED: Whisper '", whisper_text, "' at ", position)
	emit_signal("echo_spawned", "whisper", Vector2(position.x, position.y))

func _generate_whisper_text(run_data: Dictionary) -> String:
	"""Generate whisper text for audio echoes"""
	var whispers = [
		"Subject " + str(run_data["subject_id"]) + " logged: " + run_data["timestamp"] + " - outcome: " + run_data["cause_of_death"],
		"You've been here before...",
		"The harvest remembers...",
		"Subject " + str(run_data["subject_id"]) + " - another addition to the collection..."
	]
	
	return whispers[randi() % whispers.size()]

func _spawn_artifact_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn a distorted artifact from previous run"""
	# TODO: Implement artifact spawning
	print("ECHO SPAWNED: Artifact from ", run_data["subject_id"], " at ", position)
	emit_signal("echo_spawned", "artifact", Vector2(position.x, position.y))

func _spawn_shadow_echo(run_data: Dictionary, position: Vector2i):
	"""Spawn a shadowy replay of previous subject"""
	# TODO: Implement shadow figure
	print("ECHO SPAWNED: Shadow of ", run_data["subject_id"], " at ", position)
	emit_signal("echo_spawned", "shadow", Vector2(position.x, position.y))

func spawn_immediate_echo():
	"""Spawn an echo immediately (triggered by weird things)"""
	if not run_history.is_empty():
		var recent_run = run_history[-1]
		var maze_manager = get_node("/root/MazeManager")
		if maze_manager:
			_spawn_echo_from_run(recent_run, maze_manager)

func _get_current_run_time() -> float:
	"""Get how long the current run has lasted"""
	# TODO: Track run start time
	return 0.0

func _generate_subject_id() -> String:
	"""Generate a unique subject ID for this run"""
	var timestamp = Time.get_unix_time_from_system()
	return "S" + str(timestamp % 100000)

# Public API
func get_run_count() -> int:
	return run_history.size()

func get_last_run_data() -> Dictionary:
	if run_history.is_empty():
		return {}
	return run_history[-1]

func clear_harvest_log():
	"""Clear all stored run data (for testing)"""
	run_history.clear()
	_save_run_history()

# EventManager integration
func _on_event_run_logged(summary: String):
	"""Handle run logging from EventManager"""
	print("HarvestLogger: Run logged via EventManager - ", summary)

func _on_event_echo_spawned(text: String):
	"""Handle echo spawning from EventManager"""
	print("HarvestLogger: Echo spawned via EventManager - ", text)
	# For now, just print the echo text
	# TODO: Implement proper echo visualization
