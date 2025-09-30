extends Node
## Audio Manager - Handles audio bus management and sound playback
## Simplified to focus only on audio functionality, settings delegated to SettingsManager

var _theme_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_use_a: bool = true
var _music_playlist: Resource = null   # expect your MusicPlaylist resource
var _music_last_index: int = -1
var _music_crossfade_seconds: float = 2.5
var _music_gap_min: float = 0.5
var _music_gap_max: float = 2.0
var _music_gap_timer: Timer = null
var _music_fade_tween: Tween = null

var _message_bus: Node

# Audio bus management
var _audio_buses: Dictionary = {
	"Master": 0,
	"Music": -1,
	"SFX": -1
}

func _enter_tree() -> void:
	randomize()
	_ensure_core_buses()

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

## set_bus_volume(bus_name, value_0_to_1)
func set_bus_volume(bus_name: String, value: float) -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		_ensure_core_buses()
		idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			push_warning("AudioManager: Unknown audio bus '%s'", bus_name)
			return false
	var clamped: float = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))
	return true

## get_bus_volume(bus_name) -> 0..1
func get_bus_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		_ensure_core_buses()
		idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

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

func setup_music_buses() -> void:
	"""Ensure Music and SFX buses exist before playback."""
	_ensure_audio_buses()
	# Nothing else here; your _ensure_audio_buses already handles creation.

func set_music_playlist(playlist: Resource) -> void:
	"""
	Assign a MusicPlaylist resource that exposes:
	- Array[AudioStream] tracks
	- Optional Array[float] weights
	- bool avoid_immediate_repeat
	- func pick_random_index(last_index: int) -> int
	"""
	_music_playlist = playlist
	_music_last_index = -1

func configure_music_timing(crossfade_seconds: float, gap_min_seconds: float, gap_max_seconds: float) -> void:
	if crossfade_seconds < 0.0:
		crossfade_seconds = 0.0
	_music_crossfade_seconds = crossfade_seconds

	if gap_min_seconds < 0.0:
		gap_min_seconds = 0.0
	if gap_max_seconds < gap_min_seconds:
		gap_max_seconds = gap_min_seconds
	_music_gap_min = gap_min_seconds
	_music_gap_max = gap_max_seconds

func play_ambient_loop(stream: AudioStream, volume_db: float) -> void:
	_ensure_audio_buses()

	if _ambient_player == null or not is_instance_valid(_ambient_player):
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.name = "AmbientLoop"
		if AudioServer.get_bus_index("Music") != -1:
			_ambient_player.bus = "Music"
		else:
			_ambient_player.bus = "Master"
		get_tree().root.add_child(_ambient_player)

	_ambient_player.stream = stream
	_ambient_player.volume_db = volume_db

	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = true

	if not _ambient_player.playing:
		_ambient_player.play()

func start_music() -> void:
	if _music_playlist == null:
		push_warning("AudioManager.start_music: playlist is null.")
		return
	if not _music_playlist.has_method("pick_random_index"):
		push_error("AudioManager.start_music: playlist missing pick_random_index().")
		return
	var tracks: Array = _music_playlist.get("tracks")
	if tracks == null or tracks.is_empty():
		push_warning("AudioManager.start_music: playlist has no tracks.")
		return

	_ensure_audio_buses()

	if _music_a == null or not is_instance_valid(_music_a):
		_music_a = AudioStreamPlayer.new()
		_music_a.name = "MusicA"
		if AudioServer.get_bus_index("Music") != -1:
			_music_a.bus = "Music"
		else:
			_music_a.bus = "Master"
		get_tree().root.add_child(_music_a)

	if _music_b == null or not is_instance_valid(_music_b):
		_music_b = AudioStreamPlayer.new()
		_music_b.name = "MusicB"
		if AudioServer.get_bus_index("Music") != -1:
			_music_b.bus = "Music"
		else:
			_music_b.bus = "Master"
		get_tree().root.add_child(_music_b)

	if _music_gap_timer == null or not is_instance_valid(_music_gap_timer):
		_music_gap_timer = Timer.new()
		_music_gap_timer.one_shot = true
		get_tree().root.add_child(_music_gap_timer)
		_music_gap_timer.timeout.connect(_on_music_gap_timeout)

	_play_next_track(true)

func stop_music() -> void:
	"""Stop music playback and clear timers/tweens."""
	if _music_gap_timer and is_instance_valid(_music_gap_timer):
		_music_gap_timer.stop()

	if _music_fade_tween and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()

	if _music_a and is_instance_valid(_music_a) and _music_a.playing:
		_music_a.stop()
	if _music_b and is_instance_valid(_music_b) and _music_b.playing:
		_music_b.stop()

func _on_music_gap_timeout() -> void:
	_play_next_track(false)

func _play_next_track(is_initial: bool) -> void:
	if _music_playlist == null:
		return
	var tracks: Array = _music_playlist.get("tracks")
	if tracks == null or tracks.is_empty():
		return

	var next_index: int = -1

	# First track: force random start
	if is_initial:
		next_index = _choose_random_index(tracks, _music_last_index, true)
	else:
		# Prefer playlist logic if it exists
		if _music_playlist.has_method("pick_random_index"):
			next_index = _music_playlist.call("pick_random_index", _music_last_index)
		# Fallback to our random picker if playlist didn’t return something valid
		if next_index == null or next_index < 0 or next_index >= tracks.size():
			next_index = _choose_random_index(tracks, _music_last_index, false)

	if next_index < 0 or next_index >= tracks.size():
		return
	_music_last_index = next_index

	var target: AudioStreamPlayer = null
	var other: AudioStreamPlayer = null
	if _music_use_a:
		target = _music_a
		other = _music_b
	else:
		target = _music_b
		other = _music_a

	var stream: AudioStream = tracks[next_index]
	target.stream = stream
	target.volume_db = -10.0

	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = false

	target.play()

	if _music_fade_tween != null and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()

	if is_initial:
		target.volume_db = -6.0
	else:
		_music_fade_tween.tween_property(target, "volume_db", -6.0, _music_crossfade_seconds)

	if other != null and is_instance_valid(other) and other.playing and not is_initial:
		_music_fade_tween.parallel().tween_property(other, "volume_db", -40.0, _music_crossfade_seconds)
		_music_fade_tween.tween_callback(Callable(other, "stop"))

	_music_use_a = not _music_use_a
	target.finished.connect(_schedule_music_gap_once, CONNECT_ONE_SHOT)

func _schedule_music_gap_once() -> void:
	var wait_time: float = randf_range(_music_gap_min, _music_gap_max)
	if _music_gap_timer != null and is_instance_valid(_music_gap_timer):
		_music_gap_timer.start(wait_time)

## play_theme_loop
## Purpose: Loop a theme on the Music bus, waiting until player is in the tree.
func play_theme_loop(stream: AudioStream, volume_db: float = -8.0) -> void:
	if stream == null:
		return

	# Ensure buses exist
	_ensure_core_buses()

	# Ensure player exists and is added
	if _theme_player == null or not is_instance_valid(_theme_player):
		_theme_player = AudioStreamPlayer.new()
		_theme_player.name = "ThemePlayer"
		_theme_player.bus = "Music"
		add_child(_theme_player)

	# Wait until it's actually in the scene tree
	if not _theme_player.is_inside_tree():
		await _theme_player.tree_entered
		# one more frame for safety if someone adds and immediately plays
		await get_tree().process_frame

	# Ensure loop on stream if supported
	if stream.has_method("set_loop"):
		stream.call("set_loop", true)
	elif "loop" in stream:
		stream.loop = true

	_theme_player.stop()
	_theme_player.stream = stream
	_theme_player.volume_db = volume_db
	_theme_player.play()

func stop_theme() -> void:
	"""
	Stop the theme music if it is playing.
	"""
	if _theme_player != null and is_instance_valid(_theme_player):
		if _theme_player.playing:
			_theme_player.stop()

func stop_ambient_loop() -> void:
	"""
	Stop the ambient bed (e.g., Corn.ogg) if it is playing.
	"""
	if _ambient_player != null and is_instance_valid(_ambient_player):
		if _ambient_player.playing:
			_ambient_player.stop()

func _fade_out_player(node: Node, seconds: float, target_db: float) -> Tween:
	if node == null:
		return null
	if not is_instance_valid(node):
		return null
	if not node.has_method("is_playing"):
		return null
	if not node.is_playing():
		return null
	var tween: Tween = create_tween()
	tween.tween_property(node, "volume_db", target_db, seconds)
	return tween

func stop_music_fade(seconds: float) -> void:
	var tweens: Array[Tween] = []

	if _music_gap_timer != null and is_instance_valid(_music_gap_timer):
		_music_gap_timer.stop()

	if _music_a != null and is_instance_valid(_music_a) and _music_a.playing:
		var t1: Tween = _fade_out_player(_music_a, seconds, -80.0)
		if t1 != null:
			tweens.append(t1)
	if _music_b != null and is_instance_valid(_music_b) and _music_b.playing:
		var t2: Tween = _fade_out_player(_music_b, seconds, -80.0)
		if t2 != null:
			tweens.append(t2)

	for t in tweens:
		await t.finished

	if _music_a != null and is_instance_valid(_music_a):
		if _music_a.playing:
			_music_a.stop()
		_music_a.volume_db = -6.0
	if _music_b != null and is_instance_valid(_music_b):
		if _music_b.playing:
			_music_b.stop()
		_music_b.volume_db = -6.0

func stop_ambient_loop_fade(seconds: float) -> void:
	if _ambient_player == null or not is_instance_valid(_ambient_player) or not _ambient_player.playing:
		return
	var tween: Tween = _fade_out_player(_ambient_player, seconds, -80.0)
	if tween != null:
		await tween.finished
	if _ambient_player.playing:
		_ambient_player.stop()
	_ambient_player.volume_db = -8.0

## stop_theme_fade
## Purpose: Fade out theme safely, only tween if there's something to tween.
func stop_theme_fade(seconds: float = 1.0) -> void:
	if _theme_player == null or not is_instance_valid(_theme_player):
		return
	if not _theme_player.playing:
		return

	if seconds <= 0.0:
		_theme_player.volume_db = -80.0
		_theme_player.stop()
		return

	var start_db: float = _theme_player.volume_db
	var tween: Tween = create_tween()
	tween.tween_property(_theme_player, "volume_db", -80.0, seconds)
	await tween.finished
	_theme_player.stop()
	_theme_player.volume_db = start_db

## stop_all_game_audio_fade
## Purpose: Fade out all active game audio players safely. Only tween when there is work.
## @param seconds: Fade duration in seconds.
## @return void (awaitable).
func stop_all_game_audio_fade(seconds: float = 1.0) -> void:
	# Collect all players you actually use. Adjust as needed for your manager.
	var players: Array[AudioStreamPlayer] = []
	if _theme_player != null and is_instance_valid(_theme_player):
		players.append(_theme_player)
	if _ambient_player != null and is_instance_valid(_ambient_player):
		players.append(_ambient_player)
	# If you have dedicated music players, add them here:
	# for p in _music_players: players.append(p)

	# Filter to only those that are currently playing.
	var playing_players: Array[AudioStreamPlayer] = []
	for p in players:
		if p.playing:
			playing_players.append(p)

	# If nothing is playing or invalid duration, just stop and return.
	if playing_players.is_empty() or seconds <= 0.0:
		for p in playing_players:
			p.stop()
		return

	var tween: Tween = create_tween()
	var tweener_count: int = 0

	for p in playing_players:
		# Some players might already be near silence; still fade for consistency.
		tween.tween_property(p, "volume_db", -80.0, seconds)
		tweener_count += 1

	# If somehow no tweeners got added, exit without stepping the tween.
	if tweener_count == 0:
		for p in playing_players:
			p.stop()
		return

	await tween.finished

	# Stop and restore volumes for next start.
	for p in playing_players:
		p.stop()
		# Optional: reset to a sane default; you may store last-known db per player.
		p.volume_db = -8.0

# ---------- Bus helpers ----------
## _ensure_bus
## Purpose: Create a bus if missing and set optional send target.
## @param name: Bus name.
## @param send_to: Upstream bus or "" to leave default.
## @return int: Bus index.
func _ensure_bus(name: String, send_to: String) -> int:
	var idx: int = AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, name)
		if send_to != "":
			AudioServer.set_bus_send(idx, send_to)
	return idx

## _ensure_core_buses
## Purpose: Ensure Master/Music/SFX exist and route to Master.
func _ensure_core_buses() -> void:
	_ensure_bus("Master", "")
	_ensure_bus("Music", "Master")
	_ensure_bus("SFX", "Master")

## _choose_random_index
## Purpose: pick a random index; optionally avoid repeating last_index when possible.
## @param tracks: Array of AudioStream
## @param last_index: last played index or -1
## @param allow_repeat: if true, ignore last_index
## @return int
func _choose_random_index(tracks: Array, last_index: int, allow_repeat: bool) -> int:
	var count: int = tracks.size()
	if count <= 0:
		return -1
	
	# First pick or repeats allowed: uniform choice
	if allow_repeat or count == 1 or last_index < 0:
		return randi() % count
	
	# Pick uniformly from all except last_index, without loops
	var idx: int = randi() % (count - 1)
	if idx >= last_index:
		idx += 1
	return idx
