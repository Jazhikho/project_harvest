extends Node
## Manages weird object effects and atmospheric responses
## Focused solely on weird thing behavior and effects

var _message_bus: Node
var _state_manager: Node
var _item_manager: Node

var _active_weird_effects: Dictionary = {}
var _effect_timers: Dictionary = {}

const WEIRD_EFFECT_DURATION: float = 5.0

func _ready() -> void:
	name = "WeirdThingsManager"
	add_to_group("game_systems")
	call_deferred("_initialize")

func _initialize() -> void:
	"""Initialize connections to core systems"""
	_message_bus = get_node_or_null("/root/MessageBus")
	_state_manager = get_node_or_null("/root/GameStateManager")
	_item_manager = get_node_or_null("/root/ItemManager")
	
	if not _message_bus or not _state_manager or not _item_manager:
		push_error("WeirdThingsManager: Required core systems not found")
		return
	
	_connect_to_events()

func _process(delta: float) -> void:
	"""Update active weird effects"""
	for effect_id in _effect_timers.keys():
		_effect_timers[effect_id] -= delta
		if _effect_timers[effect_id] <= 0.0:
			_end_weird_effect(effect_id)

func trigger_weird_effect(weird_item_id: String, position: Vector2i) -> void:
	"""
	Trigger weird effects when a weird object is collected
	
	@param weird_item_id: ID of the weird item collected
	@param position: Grid position where collection occurred
	"""
	var item_info: Dictionary = _item_manager.get_item_info(weird_item_id)
	if item_info.is_empty():
		return
	
	var effect_type: String = _determine_effect_type(weird_item_id, item_info)
	var effect_intensity: float = _calculate_effect_intensity()
	
	_apply_weird_effect(effect_type, effect_intensity, position)
	_message_bus.emit_event("weird_effect_triggered", [effect_type, effect_intensity, Vector3(position.x, 0, position.y)])

func _determine_effect_type(item_id: String, item_info: Dictionary) -> String:
	"""
	Determine what type of weird effect should occur
	
	@param item_id: Item identifier
	@param item_info: Item definition data
	@return: Effect type string
	"""
	var effect_weights: Dictionary = {
		"reality_distortion": 1.0,
		"whisper_chorus": 1.0,
		"shadow_movement": 1.0,
		"time_skip": 0.5,
		"maze_shift": 0.3
	}
	
	# Modify weights based on item type and current sanity
	var sanity: int = _state_manager.get_state("sanity")
	if sanity < 50:
		effect_weights["whisper_chorus"] *= 2.0
		effect_weights["shadow_movement"] *= 2.0
	
	if sanity < 20:
		effect_weights["time_skip"] *= 3.0
		effect_weights["maze_shift"] *= 2.0
	
	return _select_weighted_effect(effect_weights)

func _select_weighted_effect(weights: Dictionary) -> String:
	"""
	Select random effect based on weights
	
	@param weights: Dictionary of effect_name -> weight
	@return: Selected effect name
	"""
	var total_weight: float = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var roll: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for effect_name in weights:
		current_weight += weights[effect_name]
		if roll <= current_weight:
			return effect_name
	
	return weights.keys()[0]

func _calculate_effect_intensity() -> float:
	"""
	Calculate effect intensity based on game state
	
	@return: Intensity value between 0.0 and 1.0
	"""
	var sanity: int = _state_manager.get_state("sanity")
	var base_intensity: float = 0.3
	var sanity_modifier: float = (100 - sanity) / 100.0 * 0.7
	
	return base_intensity + sanity_modifier

func _apply_weird_effect(effect_type: String, intensity: float, position: Vector2i) -> void:
	"""
	Apply the weird effect
	
	@param effect_type: Type of effect to apply
	@param intensity: Effect intensity (0.0 to 1.0)
	@param position: Grid position of effect origin
	"""
	var effect_id: String = "%s_%d" % [effect_type, Time.get_ticks_msec()]
	
	_active_weird_effects[effect_id] = {
		"type": effect_type,
		"intensity": intensity,
		"position": position,
		"start_time": Time.get_ticks_msec()
	}
	
	_effect_timers[effect_id] = WEIRD_EFFECT_DURATION
	
	match effect_type:
		"reality_distortion":
			_trigger_reality_distortion(intensity, position)
		"whisper_chorus":
			_trigger_whisper_chorus(intensity, position)
		"shadow_movement":
			_trigger_shadow_movement(intensity, position)
		"time_skip":
			_trigger_time_skip(intensity)
		"maze_shift":
			_trigger_maze_shift(position)

func _trigger_reality_distortion(intensity: float, position: Vector2i) -> void:
	"""
	Trigger visual reality distortion effect
	
	@param intensity: Effect strength
	@param position: Origin position
	"""
	_message_bus.emit_event("screen_effect_requested", ["distortion", WEIRD_EFFECT_DURATION, intensity])
	_message_bus.emit_event("notification_requested", ["Reality bends unnaturally around you...", 3.0, 2])

func _trigger_whisper_chorus(intensity: float, position: Vector2i) -> void:
	"""
	Trigger whisper sound effects
	
	@param intensity: Effect strength
	@param position: Origin position
	"""
	var whisper_messages: Array[String] = [
		"You've been here before...",
		"The harvest remembers...",
		"Another one for the collection...",
		"Dr. A is watching...",
		"The maze knows your thoughts..."
	]
	
	var message: String = whisper_messages[randi() % whisper_messages.size()]
	_message_bus.emit_event("notification_requested", [message, 4.0, 1])

func _trigger_shadow_movement(intensity: float, position: Vector2i) -> void:
	"""
	Trigger shadow movement in peripheral vision
	
	@param intensity: Effect strength
	@param position: Origin position
	"""
	_message_bus.emit_event("screen_effect_requested", ["shadow_movement", WEIRD_EFFECT_DURATION * 0.5, intensity])
	_message_bus.emit_event("notification_requested", ["Something moves in your peripheral vision...", 2.0, 1])

func _trigger_time_skip(intensity: float) -> void:
	"""
	Trigger time skip effect (brief blackout)
	
	@param intensity: Effect strength
	"""
	_message_bus.emit_event("screen_effect_requested", ["fade_black", 1.0, intensity])
	_message_bus.emit_event("notification_requested", ["Time seems to slip away...", 3.0, 2])

func _trigger_maze_shift(position: Vector2i) -> void:
	"""
	Trigger localized maze shift
	
	@param position: Center of shift
	"""
	_message_bus.emit_event("maze_shift_triggered", [position, 2, []])
	_message_bus.emit_event("notification_requested", ["The walls rearrange themselves...", 4.0, 2])

func _end_weird_effect(effect_id: String) -> void:
	"""
	End a weird effect
	
	@param effect_id: Effect identifier to end
	"""
	if effect_id in _active_weird_effects:
		_active_weird_effects.erase(effect_id)
	
	if effect_id in _effect_timers:
		_effect_timers.erase(effect_id)

func get_active_effects() -> Array:
	"""
	Get list of currently active weird effects
	
	@return: Array of effect data dictionaries
	"""
	return _active_weird_effects.values()

func _connect_to_events() -> void:
	"""Connect to MessageBus events"""
	_message_bus.item_collected.connect(_on_item_collected)
	_message_bus.game_started.connect(_on_game_started)

func _on_item_collected(item_id: String, collector: Node3D, tile_pos: Vector2i) -> void:
	"""Handle item collection to check for weird objects"""
	var item_info: Dictionary = _item_manager.get_item_info(item_id)
	if item_info.get("category", "") == "weird_objects":
		trigger_weird_effect(item_id, tile_pos)
		_message_bus.emit_event("weird_thing_collected", [item_id, tile_pos, item_info.get("effects", {})])

func _on_game_started() -> void:
	"""Reset weird effects for new game"""
	_active_weird_effects.clear()
	_effect_timers.clear()
