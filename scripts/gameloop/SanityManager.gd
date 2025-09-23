extends Node
## Simplified Sanity Manager - Core sanity tracking only
## Handles sanity loss, passive decay, and threshold detection

var _message_bus: Node
var _state_manager: Node
var _player: Node

var _passive_decay_timer: float = 0.0
var _game_time_timer: float = 0.0
var _last_sanity_value: int = 100

var _sanity_thresholds: Dictionary = {
	"critical": 20,
	"low": 40,
	"normal": 60,
	"high": 80
}

const PASSIVE_DECAY_INTERVAL: float = 30.0
const PASSIVE_DECAY_AMOUNT: int = 1
const DECAY_START_DELAY: float = 180.0 # 3 minutes

func _ready() -> void:
	name = "SanityManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/SaveManager")
	_player = get_tree().get_first_node_in_group("player")
	
	if not _message_bus or not _state_manager:
		push_error("SanityManager: Required core systems not found")
		return
	
	_connect_to_events()
	_last_sanity_value = _state_manager.get_state("sanity")

func _process(delta: float) -> void:
	"""Handle passive sanity decay with conditions"""
	_game_time_timer += delta
	_passive_decay_timer += delta
	
	# Only start decay after 3 minutes AND if flashlight is off
	if _game_time_timer >= DECAY_START_DELAY and _should_apply_passive_decay():
		if _passive_decay_timer >= PASSIVE_DECAY_INTERVAL:
			_passive_decay_timer = 0.0
			_apply_passive_decay()

func _should_apply_passive_decay() -> bool:
	"""Check if passive decay should apply (flashlight off)"""
	if not _player:
		return true # Default to decay if no player found
	
	return not _player.flashlight_enabled

func apply_sanity_loss(cause: String, base_amount: int, position: Vector3 = Vector3.ZERO) -> void:
	"""
	Apply sanity loss from specific cause
	
	@param cause: Reason for sanity loss
	@param base_amount: Base amount of sanity to lose
	@param position: World position where loss occurred
	"""
	var final_amount: int = _calculate_sanity_loss(cause, base_amount)
	
	_state_manager.modify_sanity(-final_amount)
	
	# Emit simple sanity effect event (let other systems handle messaging/effects)
	_message_bus.emit_event("sanity_effect_triggered", [cause, final_amount / 100.0])

func _calculate_sanity_loss(cause: String, base_amount: int) -> int:
	"""
	Calculate final sanity loss based on cause and current state
	
	@param cause: Cause of sanity loss
	@param base_amount: Base loss amount
	@return: Final calculated loss amount
	"""
	var multiplier: float = 1.0
	var current_sanity: int = _state_manager.get_state("sanity")
	
	# Sanity loss accelerates at low sanity
	if current_sanity < 50:
		multiplier *= 1.1
	if current_sanity < 20:
		multiplier *= 1.2
	
	# Cause-specific multipliers
	match cause:
		"entity_encounter":
			multiplier *= 1.3
	
	return int(base_amount * multiplier)

func _apply_passive_decay() -> void:
	"""Apply gradual sanity decay over time"""
	var current_sanity: int = _state_manager.get_state("sanity")
	
	# Decay is slower at high sanity, faster at low sanity
	var decay_amount: int = PASSIVE_DECAY_AMOUNT
	if current_sanity < 50:
		decay_amount = int(decay_amount * 1.5)
	if current_sanity > 80:
		decay_amount = int(decay_amount * 0.5)
	
	_state_manager.modify_sanity(-decay_amount)

func _check_threshold_crossings(old_value: int, new_value: int) -> void:
	"""Check if sanity crossed any thresholds and emit events"""
	for threshold_name in _sanity_thresholds:
		var threshold_value = _sanity_thresholds[threshold_name]
		
		# Check if crossed down (old >= threshold, new < threshold)
		if old_value >= threshold_value and new_value < threshold_value:
			_message_bus.emit_event("sanity_threshold_crossed", [threshold_name, new_value, true])
		
		# Check if crossed up (old < threshold, new >= threshold)
		elif old_value < threshold_value and new_value >= threshold_value:
			_message_bus.emit_event("sanity_threshold_crossed", [threshold_name, new_value, false])

func get_current_sanity() -> int:
	"""
	Get current sanity value
	
	@return: Current sanity (0-100)
	"""
	return _state_manager.get_state("sanity")

func get_sanity_ratio() -> float:
	"""
	Get sanity as ratio (0.0 to 1.0)
	
	@return: Sanity ratio
	"""
	return get_current_sanity() / 100.0

func is_sanity_critical() -> bool:
	"""
	Check if sanity is at critical level
	
	@return: True if sanity is critical
	"""
	return get_current_sanity() <= _sanity_thresholds.critical

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.sanity_changed.connect(_on_sanity_changed)
	_message_bus.sanity_threshold_crossed.connect(_on_sanity_threshold_crossed)
	_message_bus.sanity_effect_triggered.connect(_on_weird_effect_triggered)
	_message_bus.game_started.connect(_on_game_started)

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity value changes"""
	_check_threshold_crossings(old_value, new_value)
	_last_sanity_value = new_value

func _on_sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool) -> void:
	"""Handle sanity threshold crossings - let other systems handle effects"""
	pass # Other systems can listen to this event

func _on_weird_effect_triggered(effect_type: String, intensity: float, position: Vector3) -> void:
	"""Handle weird effects that may cause sanity loss"""
	match effect_type:
		"reality_distortion":
			apply_sanity_loss("reality_distortion", int(5 + intensity * 10))
		"whisper_chorus":
			apply_sanity_loss("whispers", int(3 + intensity * 7))

func _on_game_started() -> void:
	"""Reset sanity effects for new game"""
	_passive_decay_timer = 0.0
	_game_time_timer = 0.0
	_last_sanity_value = 100
