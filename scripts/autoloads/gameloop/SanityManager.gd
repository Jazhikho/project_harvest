extends Node
## Manages sanity system and psychological effects
## Responds to sanity changes and triggers appropriate effects

var _message_bus: Node
var _state_manager: Node

var _passive_decay_timer: float = 0.0
var _last_sanity_value: int = 100
var _sanity_thresholds: Dictionary = {
	"critical": 20,
	"low": 40, 
	"normal": 60,
	"high": 80
}

var _current_effects: Array = []

const PASSIVE_DECAY_INTERVAL: float = 30.0
const PASSIVE_DECAY_AMOUNT: int = 1

func _ready() -> void:
	name = "SanityManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not _message_bus or not _state_manager:
		push_error("SanityManager: Required core systems not found")
		return
	
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
	var message: String = _get_sanity_loss_message(cause, final_amount)
	
	_state_manager.modify_sanity(-final_amount)
	
	if not message.is_empty():
		_message_bus.emit_event("notification_requested", [message, 3.0, 1])
	
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
		multiplier *= 1.2
	if current_sanity < 20:
		multiplier *= 1.5
	
	# Certain causes are more severe at different sanity levels
	match cause:
		"weird_object":
			if current_sanity < 30:
				multiplier *= 1.5
		"entity_encounter":
			multiplier *= 1.3
		"maze_shift":
			if current_sanity > 60:
				multiplier *= 0.7
	
	return int(base_amount * multiplier)

func _get_sanity_loss_message(cause: String, amount: int) -> String:
	"""
	Get appropriate message for sanity loss
	
	@param cause: Cause of loss
	@param amount: Amount lost
	@return: Message to display
	"""
	match cause:
		"weird_object":
			return "Your mind reels as you touch the cursed object..."
		"entity_encounter":
			return "Terror grips your heart..."
		"maze_shift":
			return "Reality bends unnaturally around you..."
		"isolation":
			return "The endless maze weighs on your psyche..."
		"whispers":
			return "The voices grow louder in your head..."
		_:
			return "Your sanity deteriorates..."

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

func _apply_sanity_effects(old_sanity: int, new_sanity: int) -> void:
	"""
	Apply visual and gameplay effects based on sanity level
	
	@param old_sanity: Previous sanity value
	@param new_sanity: Current sanity value
	"""
	var intensity: float = 1.0 - (new_sanity / 100.0)
	
	# Visual effects
	if new_sanity < 60:
		_message_bus.emit_event("screen_effect_requested", ["desaturate", -1, intensity * 0.3])
	
	if new_sanity < 40:
		_message_bus.emit_event("screen_effect_requested", ["chromatic_aberration", -1, intensity * 0.2])
	
	if new_sanity < 20:
		_message_bus.emit_event("screen_effect_requested", ["screen_shake", 1.0, intensity * 0.5])

func _handle_threshold_crossed(threshold_name: String, new_value: int, crossed_down: bool) -> void:
	"""
	Handle crossing sanity thresholds
	
	@param threshold_name: Name of threshold crossed
	@param new_value: Current sanity value
	@param crossed_down: True if crossed from higher to lower
	"""
	if not crossed_down:
		return  # Only handle crossing down for now
	
	match threshold_name:
		"critical":
			_enter_critical_state()
		"low":
			_enter_low_state()
		"normal":
			_exit_high_state()

func _enter_critical_state() -> void:
	"""Handle entering critical sanity state"""
	_message_bus.emit_event("notification_requested", ["Your grip on reality weakens...", 4.0, 3])
	_message_bus.emit_event("screen_effect_requested", ["vignette", -1, 0.7])
	
	# Increase entity spawn rates
	_message_bus.emit_event("entity_spawned", ["watcher", null, Vector3.ZERO])

func _enter_low_state() -> void:
	"""Handle entering low sanity state"""
	_message_bus.emit_event("notification_requested", ["The shadows seem to move on their own...", 3.0, 2])

func _exit_high_state() -> void:
	"""Handle exiting high sanity state"""
	_message_bus.emit_event("notification_requested", ["Something feels wrong...", 2.0, 1])

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
	_message_bus.weird_effect_triggered.connect(_on_weird_effect_triggered)
	_message_bus.game_started.connect(_on_game_started)

func _on_sanity_changed(old_value: int, new_value: int, delta: int) -> void:
	"""Handle sanity value changes"""
	_apply_sanity_effects(old_value, new_value)
	_last_sanity_value = new_value

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

func _on_game_started() -> void:
	"""Reset sanity effects for new game"""
	_current_effects.clear()
	_passive_decay_timer = 0.0
	_last_sanity_value = 100
