extends Node3D
## Random Whispers - Plays whisper sounds at random locations and intervals
## Used in Whispering Hollow to create an eerie atmosphere

class_name RandomWhispers

## Minimum time between whispers (in seconds)
@export var min_interval: float = 5.0

## Maximum time between whispers (in seconds)
@export var max_interval: float = 15.0

## Maximum distance from center point where whispers can spawn
@export var spawn_radius: float = 8.0

## Height range for whisper spawn points (min Y offset)
@export var min_height: float = 0.5

## Height range for whisper spawn points (max Y offset)
@export var max_height: float = 2.5

## Maximum distance player can hear whispers from
@export var max_hearing_distance: float = 15.0

## Volume of whispers in dB
@export var volume_db: float = -10.0

# Internal state
var _sfx_resource: Resource
var _timer: Timer
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _pool_size: int = 3
var _rng: RandomNumberGenerator

func _ready() -> void:
	"""Initialize the random whisper system"""
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	
	# Load SFX resource
	call_deferred("_initialize_systems")
	
	# Create audio player pool
	_create_audio_pool()
	
	# Setup timer for random whispers
	_setup_timer()

func _initialize_systems() -> void:
	"""Load the SFX resource containing whisper sounds"""
	_sfx_resource = load("res://data/SFX.tres")
	
	if not _sfx_resource:
		push_error("RandomWhispers: Failed to load SFX resource")
		return
	
	if not _sfx_resource.whispers or _sfx_resource.whispers.size() == 0:
		push_error("RandomWhispers: No whisper sounds found in SFX resource")
		return

func _create_audio_pool() -> void:
	"""Create a pool of AudioStreamPlayer3D nodes for playing whispers"""
	for i: int in range(_pool_size):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "WhisperPlayer" + str(i)
		player.max_distance = max_hearing_distance
		player.volume_db = volume_db
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 2.0
		add_child(player)
		_audio_pool.append(player)

func _setup_timer() -> void:
	"""Setup timer for triggering random whispers"""
	_timer = Timer.new()
	_timer.name = "WhisperTimer"
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	
	# Start the first whisper
	_schedule_next_whisper()

func _exit_tree() -> void:
	"""Cleanup when node is removed from scene tree"""
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
	
	for player: AudioStreamPlayer3D in _audio_pool:
		if is_instance_valid(player) and player.playing:
			player.stop()

func _schedule_next_whisper() -> void:
	"""Schedule the next whisper at a random interval"""
	var wait_time: float = _rng.randf_range(min_interval, max_interval)
	_timer.start(wait_time)

func _on_timer_timeout() -> void:
	"""Handle timer timeout - play a random whisper at a random location"""
	_play_random_whisper()
	_schedule_next_whisper()

func _play_random_whisper() -> void:
	"""Play a random whisper sound at a random location"""
	if not _sfx_resource or not _sfx_resource.whispers or _sfx_resource.whispers.size() == 0:
		return
	
	# Find an available player from the pool
	var player: AudioStreamPlayer3D = _get_available_player()
	if not player:
		return
	
	# Select random whisper sound
	var whisper_index: int = _rng.randi_range(0, _sfx_resource.whispers.size() - 1)
	var whisper_sound: AudioStream = _sfx_resource.whispers[whisper_index]
	
	# Generate random position
	var random_pos: Vector3 = _generate_random_position()
	
	# Position the player and play the sound
	player.global_position = random_pos
	player.stream = whisper_sound
	player.play()

func _get_available_player() -> AudioStreamPlayer3D:
	"""Get an available audio player from the pool"""
	for player: AudioStreamPlayer3D in _audio_pool:
		if not player.playing:
			return player
	
	# If all players are busy, return the first one anyway
	return _audio_pool[0]

func _generate_random_position() -> Vector3:
	"""Generate a random position within the spawn radius"""
	var angle: float = _rng.randf_range(0.0, TAU)
	var distance: float = _rng.randf_range(0.0, spawn_radius)
	var height: float = _rng.randf_range(min_height, max_height)
	
	var x: float = cos(angle) * distance
	var z: float = sin(angle) * distance
	
	return global_position + Vector3(x, height, z)
