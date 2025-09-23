extends Node
## FinalGateAudio
## Plays SFX in response to the gate's sfx_request/gate_unlocked signals.
## The gate never touches audio; this node owns it.

@export_node_path("AudioStreamPlayer3D") var unlock_player_path: NodePath
@export var unlock_stream: AudioStream

@onready var _gate: Node = get_parent()
@onready var _unlock_player: AudioStreamPlayer3D = get_node_or_null(unlock_player_path) as AudioStreamPlayer3D

func _ready() -> void:
	"""Subscribe to the gate's events."""
	if _gate != null and _gate.has_signal("sfx_request"):
		_gate.connect("sfx_request", _on_sfx_request)
	if _gate != null and _gate.has_signal("gate_unlocked"):
		_gate.connect("gate_unlocked", _on_gate_unlocked)

func _on_sfx_request(kind: String) -> void:
	"""Map requests to players/streams. Currently only 'unlock' matters."""
	if kind == "unlock":
		_play_unlock()

func _on_gate_unlocked(_payload: Dictionary) -> void:
	"""Safety net to ensure unlock SFX fires once even if mapping changes."""
	_play_unlock()

func _play_unlock() -> void:
	"""Play the unlock sound from this node."""
	if _unlock_player != null:
		if unlock_stream != null:
			_unlock_player.stream = unlock_stream
		_unlock_player.play()
