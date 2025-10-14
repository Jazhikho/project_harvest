extends Node3D
## Random Crow Sounds - Plays crow sounds at random intervals from a specific location
## Attach to trees or other objects in the scene

class_name RandomCrowSounds

## Minimum time between crow calls (in seconds)
@export var min_interval: float = 5.0

## Maximum time between crow calls (in seconds)
@export var max_interval: float = 10.0

## Maximum distance player can hear crows from
@export var max_hearing_distance: float = 40.0

## Volume of crow sounds in dB
@export var volume_db: float = 20.0

## Height offset from parent position where sound originates
@export var height_offset: float = 3.0

# Internal state
var _sfx_resource: Resource
var _timer: Timer
var _audio_player: AudioStreamPlayer3D
var _rng: RandomNumberGenerator

func _ready() -> void:
	"""Initialize the random crow sound system"""
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	
	# Load SFX resource
	call_deferred("_initialize_systems")
	
	# Create audio player
	_create_audio_player()
	
	# Setup timer for random crow sounds
	_setup_timer()

func _initialize_systems() -> void:
	"""Load the SFX resource containing crow sounds"""
	_sfx_resource = load("res://data/SFX.tres")
	
	if not _sfx_resource:
		push_error("RandomCrowSounds: Failed to load SFX resource")
		return
	
	if not _sfx_resource.crows or _sfx_resource.crows.size() == 0:
		push_error("RandomCrowSounds: No crow sounds found in SFX resource")
		return
	
	print("RandomCrowSounds: Initialized with %d crow sounds" % _sfx_resource.crows.size())

func _create_audio_player() -> void:
	"""Create an AudioStreamPlayer3D node for playing crow sounds"""
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "CrowSoundPlayer"
	_audio_player.max_distance = max_hearing_distance
	_audio_player.volume_db = volume_db
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_audio_player.unit_size = 3.0
	_audio_player.position = Vector3(0, height_offset, 0)
	add_child(_audio_player)

func _setup_timer() -> void:
	"""Setup timer for triggering random crow sounds"""
	_timer = Timer.new()
	_timer.name = "CrowTimer"
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	
	# Start the first crow call
	_schedule_next_crow_call()

func _exit_tree() -> void:
	"""Cleanup when node is removed from scene tree"""
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
	
	if _audio_player and is_instance_valid(_audio_player):
		if _audio_player.playing:
			_audio_player.stop()

func _schedule_next_crow_call() -> void:
	"""Schedule the next crow call at a random interval"""
	var wait_time: float = _rng.randf_range(min_interval, max_interval)
	_timer.start(wait_time)

func _on_timer_timeout() -> void:
	"""Handle timer timeout - play a random crow sound"""
	_play_random_crow_sound()
	_schedule_next_crow_call()

func _play_random_crow_sound() -> void:
	"""Play a random crow sound"""
	if not _sfx_resource or not _sfx_resource.crows or _sfx_resource.crows.size() == 0:
		return
	
	if _audio_player.playing:
		return
	
	# Select random crow sound
	var crow_index: int = _rng.randi_range(0, _sfx_resource.crows.size() - 1)
	var crow_sound: AudioStream = _sfx_resource.crows[crow_index]
	
	# Play the sound
	_audio_player.stream = crow_sound
	_audio_player.play()
	
	print("RandomCrowSounds: Playing crow sound at %s" % global_position)
