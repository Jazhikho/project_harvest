# res://scripts/audio/PlayerAudioController.gd
extends Node
class_name PlayerAudioController

@export var walking_path: NodePath = NodePath("Walking")         # AudioStreamPlayer
@export var sprinting_path: NodePath = NodePath("Sprinting")     # AudioStreamPlayer
@export var heart_path: NodePath = NodePath("Heart")             # AudioStreamPlayer
@export var whispers_path: NodePath = NodePath("Whispers")       # AudioStreamPlayer3D

# Footsteps
@export var min_walk_speed: float = 0.2

# Heartbeat
@export var heartbeat_start_sanity: int = 20
@export var heartbeat_min_bpm: float = 60.0
@export var heartbeat_max_bpm: float = 120.0
@export var heartbeat_min_pitch: float = 1.0
@export var heartbeat_max_pitch: float = 1.3
@export var heartbeat_use_looping_stream: bool = true

# Whispers
@export var whispers_start_sanity: int = 40
@export var whispers_gap_min: float = 6.0
@export var whispers_gap_max: float = 14.0
@export var whispers_dur_min: float = 2.0
@export var whispers_dur_max: float = 5.0
@export var whispers_pitch_min: float = 0.95
@export var whispers_pitch_max: float = 1.05
@export var whispers_volume_db: float = -6.0

# AudioManager categories (match your autoload)
@export var category_sfx: String = "sfx"
@export var category_heartbeat: String = "heartbeat"
@export var category_whispers: String = "ambience"

var _walking: AudioStreamPlayer = null
var _sprinting: AudioStreamPlayer = null
var _heart: AudioStreamPlayer = null
var _whispers: AudioStreamPlayer3D = null

var _player: Node = null
var _message_bus: Node = null
var _save_manager: Node = null
var _audio_manager: Node = null

var _heartbeat_active: bool = false
var _last_grounded: bool = false
var _last_sprinting: bool = false
var _last_speed: float = 0.0

# Whispers state
var _whispers_active: bool = false
var _whisper_timer: float = 0.0
var _whisper_playing: bool = false
var _whisper_segment_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_walking = get_node_or_null(walking_path) as AudioStreamPlayer
	_sprinting = get_node_or_null(sprinting_path) as AudioStreamPlayer
	_heart = get_node_or_null(heart_path) as AudioStreamPlayer
	_whispers = get_node_or_null(whispers_path) as AudioStreamPlayer3D

	_player = get_parent()
	if _player != null and _player.has_signal("move_state"):
		_player.connect("move_state", Callable(self, "_on_move_state"))

	_message_bus = get_node_or_null("/root/MessageBus")
	if _message_bus != null and _message_bus.has_signal("sanity_threshold_crossed"):
		_message_bus.connect("sanity_threshold_crossed", Callable(self, "_on_sanity_threshold_crossed"))

	_save_manager = get_node_or_null("/root/SaveManager")
	if _save_manager != null and _save_manager.has_signal("sanity_changed"):
		_save_manager.connect("sanity_changed", Callable(self, "_on_sanity_changed"))

	_audio_manager = get_node_or_null("/root/AudioManager")
	_apply_audio_manager_categories()
	_apply_audio_manager_volume_all()

	if not heartbeat_use_looping_stream and _heart != null:
		_heart.connect("finished", Callable(self, "_on_heart_finished"))

	if _whispers != null:
		_set_volume_db_any(_whispers, whispers_volume_db)

	_rng.randomize()
	_schedule_next_whisper_gap()

func _process(dt: float) -> void:
	_update_whispers(dt)

# ---------- Movement / footsteps ----------
func _on_move_state(speed: float, grounded: bool, sprinting: bool) -> void:
	_last_speed = speed
	_last_grounded = grounded
	_last_sprinting = sprinting
	_update_footsteps()

func _update_footsteps() -> void:
	var moving: bool = _last_grounded and (_last_speed >= min_walk_speed)
	if not moving:
		_stop_any(_walking)
		_stop_any(_sprinting)
		return
	if _last_sprinting:
		_stop_any(_walking)
		_play_any(_sprinting)
	else:
		_stop_any(_sprinting)
		_play_any(_walking)

# ---------- Heartbeat ----------
func _on_sanity_threshold_crossed(_threshold_name: String, value: int, crossed_down: bool) -> void:
	if crossed_down and value <= heartbeat_start_sanity:
		_start_heartbeat(value)
	if crossed_down and value <= whispers_start_sanity:
		_whispers_active = true

func _on_sanity_changed(_old_value: int, new_value: int, _delta: int) -> void:
	if _heartbeat_active:
		_set_heartbeat_rate(new_value)
	if new_value <= whispers_start_sanity:
		_whispers_active = true
	else:
		_whispers_active = false
		_stop_any(_whispers)
		_whisper_playing = false
		_schedule_next_whisper_gap()

func _start_heartbeat(current_sanity: int) -> void:
	if _heart == null:
		return
	if _heartbeat_active:
		return
	_heartbeat_active = true
	_set_heartbeat_rate(current_sanity)
	_play_any(_heart)

func _set_heartbeat_rate(current_sanity: int) -> void:
	var s: float = float(current_sanity)
	if s < 0.0:
		s = 0.0
	if s > float(heartbeat_start_sanity):
		s = float(heartbeat_start_sanity)
	var t: float = 1.0 - (s / float(heartbeat_start_sanity))
	var bpm: float = lerp(heartbeat_min_bpm, heartbeat_max_bpm, t)
	var pitch: float = lerp(heartbeat_min_pitch, heartbeat_max_pitch, t)
	# For a looped whoomp, pitch is enough to suggest tempo change.
	if _heart != null:
		_set_pitch_any(_heart, pitch)

func _on_heart_finished() -> void:
	if _heartbeat_active:
		_play_any(_heart)

# ---------- Whispers ----------
func _update_whispers(dt: float) -> void:
	if _whispers == null:
		return
	if not _whispers_active:
		return

	_whisper_timer -= dt
	if _whisper_timer <= 0.0:
		if _whisper_playing:
			_whisper_playing = false
			_stop_any(_whispers)
			_schedule_next_whisper_gap()
		else:
			_start_whisper_burst()

	if _whisper_playing:
		var drift: float = _rng.randf_range(-0.01, 0.01)
		var next_pitch: float = clamp(_whispers.pitch_scale + drift, whispers_pitch_min, whispers_pitch_max)
		_set_pitch_any(_whispers, next_pitch)

func _start_whisper_burst() -> void:
	_whisper_playing = true
	_whisper_segment_time = _rng.randf_range(whispers_dur_min, whispers_dur_max)
	_whisper_timer = _whisper_segment_time
	var p: float = _rng.randf_range(whispers_pitch_min, whispers_pitch_max)
	_set_pitch_any(_whispers, p)
	_apply_audio_manager_volume(_whispers, category_whispers, whispers_volume_db)
	_play_any(_whispers)

func _schedule_next_whisper_gap() -> void:
	var gap: float = _rng.randf_range(whispers_gap_min, whispers_gap_max)
	_whisper_timer = gap

# ---------- AudioManager integration ----------
func _apply_audio_manager_categories() -> void:
	if _audio_manager == null:
		return
	# Adapter 1: AudioManager.apply_bus(node, category)
	if _audio_manager.has_method("apply_bus"):
		if _walking != null:
			_audio_manager.call("apply_bus", _walking, category_sfx)
		if _sprinting != null:
			_audio_manager.call("apply_bus", _sprinting, category_sfx)
		if _heart != null:
			_audio_manager.call("apply_bus", _heart, category_heartbeat)
		if _whispers != null:
			_audio_manager.call("apply_bus", _whispers, category_whispers)
	# Adapter 2: get_bus_name(category) and set .bus manually
	elif _audio_manager.has_method("get_bus_name"):
		var sfx_bus: String = _safe_bus_name(category_sfx)
		var heart_bus: String = _safe_bus_name(category_heartbeat)
		var whisp_bus: String = _safe_bus_name(category_whispers)
		if _walking != null:
			_walking.bus = sfx_bus
		if _sprinting != null:
			_sprinting.bus = sfx_bus
		if _heart != null:
			_heart.bus = heart_bus
		if _whispers != null:
			_whispers.bus = whisp_bus

	if _audio_manager.has_signal("volumes_updated"):
		_audio_manager.connect("volumes_updated", Callable(self, "_on_volumes_updated"))

func _on_volumes_updated() -> void:
	_apply_audio_manager_volume_all()

func _apply_audio_manager_volume_all() -> void:
	_apply_audio_manager_volume(_walking, category_sfx, 0.0)
	_apply_audio_manager_volume(_sprinting, category_sfx, 0.0)
	_apply_audio_manager_volume(_heart, category_heartbeat, 0.0)
	_apply_audio_manager_volume(_whispers, category_whispers, whispers_volume_db)

func _apply_audio_manager_volume(node: Node, category: String, local_offset_db: float) -> void:
	if node == null:
		return
	var db: float = local_offset_db
	if _audio_manager != null:
		if _audio_manager.has_method("get_category_db"):
			var v: Variant = _audio_manager.call("get_category_db", category)
			if typeof(v) == TYPE_FLOAT:
				db += float(v)
		elif _audio_manager.has_method("get_volume_db"):
			var v2: Variant = _audio_manager.call("get_volume_db", category)
			if typeof(v2) == TYPE_FLOAT:
				db += float(v2)
	_set_volume_db_any(node, db)

func _safe_bus_name(category: String) -> String:
	var name: String = "Master"
	if _audio_manager != null and _audio_manager.has_method("get_bus_name"):
		var v: Variant = _audio_manager.call("get_bus_name", category)
		if typeof(v) == TYPE_STRING:
			name = String(v)
	return name

# ---------- Generic helpers for 2D/3D players ----------
func _play_any(node: Node) -> void:
	if node == null:
		return
	if node is AudioStreamPlayer:
		var p2d: AudioStreamPlayer = node as AudioStreamPlayer
		if not p2d.playing:
			p2d.play()
	elif node is AudioStreamPlayer3D:
		var p3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		if not p3d.playing:
			p3d.play()

func _stop_any(node: Node) -> void:
	if node == null:
		return
	if node is AudioStreamPlayer:
		var p2d: AudioStreamPlayer = node as AudioStreamPlayer
		if p2d.playing:
			p2d.stop()
	elif node is AudioStreamPlayer3D:
		var p3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		if p3d.playing:
			p3d.stop()

func _set_pitch_any(node: Node, pitch: float) -> void:
	if node == null:
		return
	if node is AudioStreamPlayer:
		var p2d: AudioStreamPlayer = node as AudioStreamPlayer
		p2d.pitch_scale = pitch
	elif node is AudioStreamPlayer3D:
		var p3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		p3d.pitch_scale = pitch

func _set_volume_db_any(node: Node, db: float) -> void:
	if node == null:
		return
	if node is AudioStreamPlayer:
		var p2d: AudioStreamPlayer = node as AudioStreamPlayer
		p2d.volume_db = db
	elif node is AudioStreamPlayer3D:
		var p3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		p3d.volume_db = db
