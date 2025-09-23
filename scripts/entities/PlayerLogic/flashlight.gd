# res://scripts/items/FlashlightController.gd
extends SpotLight3D
class_name FlashlightController

# Timing
@export var auto_on_time: float = 180.0
@export var battery_min_seconds: int = 60
@export var battery_max_seconds: int = 300

# Flicker thresholds (seconds remaining)
@export var flicker_soft_threshold: int = 60
@export var flicker_hard_threshold: int = 10

# Sanity drain when dark after auto_on_time
@export var sanity_drain_per_sec: float = 1.0

# Optional manual toggle
@export var toggle_action: String = "flashlight_toggle"

# Toast texts
@export var toast_auto_on: String = "It's getting dark. Thank goodness I have this flashlight."
@export var toast_soft: String = "The flashlight is starting to sputter…"
@export var toast_hard: String = "The flashlight is dying…"
@export var toast_dead: String = "The flashlight is dead."

# Light ramp
@export var ramp_speed: float = 8.0
@export var on_energy: float = 350.0
@export var off_energy: float = 0.0

# Internals
var _message_bus: Node = null
var _save_manager: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _game_time: float = 0.0
var _battery_capacity: float = 0.0
var _battery_remaining: float = 0.0
var _auto_on_fired: bool = false
var _soft_toast_fired: bool = false
var _hard_toast_fired: bool = false
var _dead_toast_fired: bool = false

var _user_requested_on: bool = false
var _is_dead: bool = false

# Flicker state
var _flicker_timer: float = 0.0
var _flicker_interval: float = 0.0
var _flicker_off_time: float = 0.0
var _flicker_is_off: bool = false

# Sanity batching
var _sanity_fractional: float = 0.0

func _ready() -> void:
	_message_bus = get_node_or_null("/root/MessageBus")
	_save_manager = get_node_or_null("/root/SaveManager")

	_rng.randomize()

	# Roll battery between min and max (inclusive)
	var span: int = battery_max_seconds - battery_min_seconds
	if span < 0:
		span = 0
	var rolled_offset: int = _rng.randi_range(0, span)
	var rolled: int = battery_min_seconds + rolled_offset
	_battery_capacity = float(rolled)
	_battery_remaining = _battery_capacity

	# Start dark
	visible = false
	light_energy = off_energy
	_user_requested_on = false
	_is_dead = false

	_reset_flicker_schedule()

func _process(dt: float) -> void:
	_game_time += dt

	# Optional manual toggle
	if toggle_action != "" and Input.is_action_just_pressed(toggle_action):
		_handle_manual_toggle()

	# Auto-on at 3 minutes once
	if not _auto_on_fired and _game_time >= auto_on_time:
		_auto_on_fired = true
		_user_requested_on = true
		turn_on()
		_toast(toast_auto_on)

	# Battery drains only while actually emitting
	var emitting: bool = _is_actively_emitting()
	if emitting and not _is_dead:
		_battery_remaining -= dt
		if _battery_remaining <= 0.0:
			_battery_remaining = 0.0
			_is_dead = true
			_user_requested_on = false
			turn_off()
			_toast_once_dead()

	# Flicker behavior near empty
	if not _is_dead:
		_update_flicker(dt)

	# Sanity drain when dark after auto-on time
	_update_dark_sanity(dt)

	# Smooth visual energy
	_update_energy(dt)

func _handle_manual_toggle() -> void:
	if _is_dead:
		return
	_user_requested_on = not _user_requested_on
	if _user_requested_on:
		turn_on()
	else:
		turn_off()

func turn_on() -> void:
	visible = true

func turn_off() -> void:
	visible = false

func _is_actively_emitting() -> bool:
	if not _user_requested_on:
		return false
	if _is_dead:
		return false
	if _flicker_is_off:
		return false
	return true

func _update_flicker(dt: float) -> void:
	var remaining: float = _battery_remaining

	# Threshold toasts
	if remaining <= float(flicker_soft_threshold) and not _soft_toast_fired:
		_soft_toast_fired = true
		_toast(toast_soft)
	if remaining <= float(flicker_hard_threshold) and not _hard_toast_fired:
		_hard_toast_fired = true
		_toast(toast_hard)

	# Above soft: no flicker
	if remaining > float(flicker_soft_threshold):
		_flicker_is_off = false
		_flicker_timer = 0.0
		_flicker_interval = 0.0
		_flicker_off_time = 0.0
		return

	_flicker_timer += dt

	if remaining > float(flicker_hard_threshold):
		# Soft flicker
		if _flicker_interval <= 0.0:
			_flicker_interval = _rng.randf_range(0.8, 1.6)
			_flicker_off_time = _rng.randf_range(0.04, 0.12)
		if _flicker_timer >= _flicker_interval:
			_flicker_timer = 0.0
			_flicker_is_off = true
		elif _flicker_is_off and _flicker_timer >= _flicker_off_time:
			_flicker_is_off = false
	else:
		# Hard flicker
		if _flicker_interval <= 0.0:
			_flicker_interval = _rng.randf_range(0.4, 0.9)
			_flicker_off_time = _rng.randf_range(0.15, 0.45)
		var hard_t: float = 1.0 - clamp(remaining / float(flicker_hard_threshold), 0.0, 1.0)
		var extra_off: float = hard_t * 0.6
		if _flicker_timer >= _flicker_interval:
			_flicker_timer = 0.0
			_flicker_is_off = true
		elif _flicker_is_off and _flicker_timer >= (_flicker_off_time + extra_off):
			_flicker_is_off = false

func _update_energy(dt: float) -> void:
	var target: float = off_energy
	if _is_actively_emitting():
		target = on_energy
	light_energy = lerp(light_energy, target, clamp(ramp_speed * dt, 0.0, 1.0))

func _update_dark_sanity(dt: float) -> void:
	if _game_time < auto_on_time:
		return

	var dark: bool = true
	if _is_actively_emitting():
		dark = false

	if not dark:
		_sanity_fractional = 0.0
		return

	_sanity_fractional += sanity_drain_per_sec * dt
	var whole: int = int(floor(_sanity_fractional))
	if whole >= 1:
		_sanity_fractional -= float(whole)
		_apply_sanity_delta(-whole)

func _apply_sanity_delta(points: int) -> void:
	if _save_manager != null and _save_manager.has_method("modify_sanity"):
		_save_manager.call("modify_sanity", points)

func _toast(text: String) -> void:
	if _message_bus != null and _message_bus.has_method("emit_event"):
		_message_bus.call("emit_event", "ui_toast_show", [text])

func _toast_once_dead() -> void:
	if _dead_toast_fired:
		return
	_dead_toast_fired = true
	_toast(toast_dead)

func _reset_flicker_schedule() -> void:
	_flicker_timer = 0.0
	_flicker_interval = 0.0
	_flicker_off_time = 0.0
	_flicker_is_off = false
