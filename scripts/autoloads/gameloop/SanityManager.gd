extends BaseManager
## Manages sanity system and psychological effects
## Responds to sanity changes and triggers appropriate effects

var _passive_decay_timer: float = 0.0
var _last_sanity_value: int = GameConstants.MAX_SANITY
var _sanity_thresholds: Dictionary = {
	"critical": GameConstants.SANITY_THRESHOLD_CRITICAL,
	"low": GameConstants.SANITY_THRESHOLD_LOW,
	"normal": GameConstants.SANITY_THRESHOLD_MEDIUM,
	"high": GameConstants.SANITY_THRESHOLD_HIGH
}

var _current_effects: Array = []

const PASSIVE_DECAY_INTERVAL: float = 30.0
const PASSIVE_DECAY_AMOUNT: int = 1

func _ready() -> void:
	name = "SanityManager"
	add_to_group("game_systems")
	require_systems(["MessageBus", "GameStateManager"])
	super._ready()

func _initialize_manager() -> void:
	"""Initialize connections to core systems"""
	_connect_to_events()
	_last_sanity_value = _state_manager.get_state("sanity")

func _process(delta: float) -> void:
	"""Handle passive sanity decay"""
	_passive_decay_timer += delta
	
	if _passive_decay_timer >= PASSIVE_DECAY_INTERVAL:
		_passive_decay_timer = 0.0
		_apply_passive_decay()

func apply_sanity_loss(cause: String, base_amount: int, position: Vector3 = Vector3.ZERO) -> void:
	"""
	Apply sanity loss from specific cause
	
	@param cause: Reason for sanity loss
	@param base_amount: Base amount of sanity to lose
	@param position: World position where loss occurred
	"""
	var final_amount: int = _calculate_sanity_loss(cause, base_amount)
	
	_state_manager.modify_sanity(-final_amount)
	
	emit_event("sanity_effect_triggered", [cause, float(final_amount) / float(GameConstants.MAX_SANITY)])

func _calculate_sanity_loss(cause: String, base_amount: int) -> int:
	"""
	Calculate final sanity loss based on cause
	
	@param cause: Cause of sanity loss
	@param base_amount: Base loss amount
	@return: Final calculated loss amount
	"""
	# Simple sanity loss calculation without dynamic multipliers
	return base_amount

func _apply_passive_decay() -> void:
	"""Apply gradual sanity decay over time"""
	var current_sanity: int = _state_manager.get_state("sanity")
	
	# Decay is slower at high sanity, slightly faster at low sanity (more gradual progression)
	var decay_amount: int = PASSIVE_DECAY_AMOUNT
	if current_sanity > GameConstants.SANITY_THRESHOLD_HIGH:
		decay_amount = int(decay_amount * 0.75)
	elif current_sanity < GameConstants.SANITY_THRESHOLD_LOW:
		decay_amount = int(decay_amount * 1.2)
	elif current_sanity < GameConstants.SANITY_THRESHOLD_MEDIUM:
		decay_amount = int(decay_amount * 1.1)
	
	
	_state_manager.modify_sanity(-decay_amount)

func _apply_sanity_effects(old_sanity: int, new_sanity: int) -> void:
	"""
	Apply visual and gameplay effects based on sanity level
	
	@param old_sanity: Previous sanity value
	@param new_sanity: Current sanity value
	"""
	var intensity: float = 1.0 - (float(new_sanity) / float(GameConstants.MAX_SANITY))

func _handle_threshold_crossed(threshold_name: String, new_value: int, crossed_down: bool) -> void:
	"""
	Handle crossing sanity thresholds
	
	@param threshold_name: Name of threshold crossed
	@param new_value: Current sanity value
	@param crossed_down: True if crossed from higher to lower
	"""
	if not crossed_down:
		return # Only handle crossing down for now
	
	match threshold_name:
		"critical":
			_enter_critical_state()
		"low":
			_enter_low_state()
		"normal":
			_exit_high_state()

func _enter_critical_state() -> void:
	"""Handle entering critical sanity state"""
	emit_event("notification_requested", ["The maze feels hungry.", 3.0, 2])

func _enter_low_state() -> void:
	"""Handle entering low sanity state"""
	emit_event("notification_requested", ["The shadows seem to move on their own...", 3.0, 2])

func _exit_high_state() -> void:
	"""Handle exiting high sanity state"""
	emit_event("notification_requested", ["Something feels wrong...", 2.0, 1])

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
	return float(get_current_sanity()) / float(GameConstants.MAX_SANITY)

func get_sanity_spawn_rate(_entity_type: String) -> float:
	"""Legacy API retained for compatibility with existing callers."""
	return 0.0

func is_sanity_critical() -> bool:
	"""
	Check if sanity is at critical level
	
	@return: True if sanity is critical
	"""
	return get_current_sanity() <= _sanity_thresholds.critical

func _connect_to_events() -> void:
	"""Connect to MessageBus events (game_started/game_ended from BaseManager)"""
	_message_bus.sanity_changed.connect(_on_sanity_changed)
	_message_bus.sanity_threshold_crossed.connect(_on_sanity_threshold_crossed)
	_message_bus.weird_effect_triggered.connect(_on_weird_effect_triggered)
	_message_bus.sanity_delta_requested.connect(_on_sanity_delta_requested)

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity value changes"""
	_apply_sanity_effects(old_value, new_value)
	_last_sanity_value = new_value
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_update_sanity_audio"):
		player._update_sanity_audio()

func _on_sanity_threshold_crossed(threshold_name: String, value: int, crossed_down: bool) -> void:
	"""Handle sanity threshold crossings"""
	_handle_threshold_crossed(threshold_name, value, crossed_down)

func _on_weird_effect_triggered(effect_type: String, intensity: float, position: Vector3) -> void:
	"""Handle weird effects that may cause sanity loss"""
	match effect_type:
		"reality_distortion":
			apply_sanity_loss("reality_distortion", int(5 + intensity * 10))
		"whisper_chorus":
			apply_sanity_loss("whispers", int(3 + intensity * 7))

func _on_sanity_delta_requested(delta: int, source: String) -> void:
	"""
	Handle sanity delta requests from other systems (like effigy drain)
	
	@param delta: Amount of sanity to change (positive or negative)
	@param source: Source of the sanity change request
	"""
	_state_manager.modify_sanity(delta)
	emit_event("sanity_effect_triggered", [source, float(abs(delta)) / float(GameConstants.MAX_SANITY)])

func _on_game_started() -> void:
	"""Reset sanity effects for new game"""
	_current_effects.clear()
	_passive_decay_timer = 0.0
	_last_sanity_value = GameConstants.MAX_SANITY
