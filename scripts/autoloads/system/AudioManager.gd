extends Node

func _ready():
	# Create audio buses if they don't exist
	_ensure_audio_buses()

func _ensure_audio_buses():
	# Check and create Music bus
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
		AudioServer.set_bus_send(1, "Master")
	
	# Check and create SFX bus
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")
		AudioServer.set_bus_send(2, "Master")

func set_bus_volume(bus_name: String, volume: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))
		
		# Save setting
		SaveManager.save_data.settings[bus_name + "_volume"] = volume
		SaveManager.save_game()

func get_bus_volume(bus_name: String) -> float:
	var saved_vol = SaveManager.save_data.settings.get(bus_name + "_volume", 1.0)
	return saved_vol
