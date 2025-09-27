extends Node

const SAVE_PATH = "user://save_data.sav"

var save_data = {
	"time_played": 0.0,
	"deaths": 0,
	"collectibles": [],
	"run_active": false,
	"last_position": Vector3.ZERO,
	"permanent_tiles": {},
	"event_flags": [],
	"settings": {}
}

func _ready():
	# Connect to game events to manage run state
	call_deferred("_connect_to_events")

func _connect_to_events():
	"""Connect to MessageBus events"""
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus:
		if message_bus.has_signal("game_started"):
			message_bus.game_started.connect(_on_game_started)

func _on_game_started():
	"""Handle game start event"""
	start_run()

func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

func load_game():
	if has_save_data():
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		save_data = file.get_var()
		file.close()

func delete_save():
	if has_save_data():
		DirAccess.remove_absolute(SAVE_PATH)
	_reset_save_data()

func _reset_save_data():
	save_data = {
		"time_played": 0.0,
		"deaths": 0,
		"collectibles": [],
		"run_active": false,
		"last_position": Vector3.ZERO,
		"settings": {}
	}

func start_run():
	"""Mark a run as active and save the state"""
	save_data.run_active = true
	save_game()

func record_death():
	save_data.deaths += 1
	save_data.run_active = false
	save_game()
