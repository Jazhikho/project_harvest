extends Node

const SAVE_PATH = "user://save_data.sav"

var save_data = {
	"time_played": 0.0,
	"deaths": 0,
	"collectibles": [],
	"run_active": false,
	"last_position": Vector3.ZERO,
	"settings": {}
}

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

func record_death():
	save_data.deaths += 1
	save_data.run_active = false
	save_game()
