extends Node
## Audio Manager - Handles audio bus management and sound playback
## Simplified to focus only on audio functionality, settings delegated to SettingsManager

var _message_bus: Node

# Audio bus management
var _audio_buses: Dictionary = {
	"Master": 0,
	"Music": -1,
	"SFX": -1
}

func _ready() -> void:
	name = "AudioManager"
	add_to_group("core_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize audio system"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_ensure_audio_buses()
	
	# Connect to settings events after ensuring buses exist
	if _message_bus and _message_bus.has_signal("setting_changed"):
		_message_bus.connect_event("setting_changed", _on_setting_changed)
	elif _message_bus:
		# Wait for SettingsManager to be ready
		call_deferred("_connect_to_settings")

func _ensure_audio_buses() -> void:
	"""Create audio buses if they don't exist"""
	# Check and create Music bus
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
		AudioServer.set_bus_send(1, "Master")
		_audio_buses["Music"] = 1
	else:
		_audio_buses["Music"] = AudioServer.get_bus_index("Music")
	
	# Check and create SFX bus
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")
		AudioServer.set_bus_send(2, "Master")
		_audio_buses["SFX"] = 2
	else:
		_audio_buses["SFX"] = AudioServer.get_bus_index("SFX")

func set_bus_volume(bus_name: String, volume: float) -> bool:
	"""
	Set volume for an audio bus
	
	@param bus_name: Name of the audio bus
	@param volume: Volume level (0.0 to 1.0)
	@return: True if volume was set successfully
	"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Unknown audio bus '%s'" % bus_name)
		return false
	
	# Clamp volume to valid range
	volume = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))
	
	return true

func get_bus_volume(bus_name: String) -> float:
	"""
	Get volume for an audio bus
	
	@param bus_name: Name of the audio bus
	@return: Current volume level (0.0 to 1.0)
	"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Unknown audio bus '%s'" % bus_name)
		return 1.0
	
	var volume_db = AudioServer.get_bus_volume_db(bus_idx)
	return db_to_linear(volume_db)

func play_sound_2d(sound_path: String, bus: String = "SFX") -> AudioStreamPlayer2D:
	"""
	Play a 2D sound effect
	
	@param sound_path: Path to audio resource
	@param bus: Audio bus to play on
	@return: AudioStreamPlayer2D node or null if failed
	"""
	if not FileAccess.file_exists(sound_path):
		push_warning("AudioManager: Sound file not found: %s" % sound_path)
		return null
	
	var audio_stream = load(sound_path) as AudioStream
	if not audio_stream:
		push_error("AudioManager: Failed to load audio stream: %s" % sound_path)
		return null
	
	var player = AudioStreamPlayer2D.new()
	player.stream = audio_stream
	player.bus = bus
	
	# Add to scene tree
	get_tree().current_scene.add_child(player)
	player.play()
	
	# Auto-remove when finished
	player.finished.connect(player.queue_free)
	
	return player

func play_sound_3d(sound_path: String, position: Vector3, bus: String = "SFX") -> AudioStreamPlayer3D:
	"""
	Play a 3D positional sound effect
	
	@param sound_path: Path to audio resource
	@param position: 3D world position
	@param bus: Audio bus to play on
	@return: AudioStreamPlayer3D node or null if failed
	"""
	if not FileAccess.file_exists(sound_path):
		push_warning("AudioManager: Sound file not found: %s" % sound_path)
		return null
	
	var audio_stream = load(sound_path) as AudioStream
	if not audio_stream:
		push_error("AudioManager: Failed to load audio stream: %s" % sound_path)
		return null
	
	var player = AudioStreamPlayer3D.new()
	player.stream = audio_stream
	player.bus = bus
	player.global_position = position
	
	# Add to scene tree
	get_tree().current_scene.add_child(player)
	player.play()
	
	# Auto-remove when finished
	player.finished.connect(player.queue_free)
	
	return player

func stop_all_sounds_on_bus(bus_name: String) -> void:
	"""
	Stop all sounds playing on a specific bus
	
	@param bus_name: Name of the audio bus
	"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	
	# This is a simplified approach - in a full implementation,
	# you'd track active players and stop them individually
	AudioServer.set_bus_volume_db(bus_idx, -80.0)  # Mute
	await get_tree().process_frame
	set_bus_volume(bus_name, get_bus_volume(bus_name))  # Restore volume

func _connect_to_settings() -> void:
	"""Connect to settings events after SettingsManager is ready"""
	if _message_bus and _message_bus.has_signal("setting_changed"):
		_message_bus.connect_event("setting_changed", _on_setting_changed)

func _on_setting_changed(category: String, key: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle settings changes from SettingsManager"""
	if category != "audio":
		return
	
	match key:
		"master_volume":
			set_bus_volume("Master", new_value)
		"music_volume":
			set_bus_volume("Music", new_value)
		"sfx_volume":
			set_bus_volume("SFX", new_value)
