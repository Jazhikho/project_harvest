extends Node3D
## The Watcher - Half-formed duplicate entity that stalks the player
## Appears at edge of vision, causes sanity loss, represents unfinished experiments

@export var spawn_rate_base: float = 0.1  # Base spawn chance per minute
@export var visibility_duration: float = 2.0  # How long Watcher is visible
@export var min_distance_from_player: float = 15.0
@export var max_distance_from_player: float = 25.0
@export var sanity_loss_per_encounter: int = 15

var current_spawn_rate: float = 0.1
var is_active: bool = false
var visibility_timer: float = 0.0
var spawn_timer: float = 0.0
var player_reference: Node3D

# Visual components
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var area_3d: Area3D = $Area3D
@onready var despawn_timer: Timer = $DespawnTimer

# Watcher states
enum WatcherState {
	HIDDEN,
	MANIFESTING,
	VISIBLE,
	DESPAWNING
}

var current_state: WatcherState = WatcherState.HIDDEN

func _ready():
	add_to_group("watcher")
	
	# Initially hidden
	visible = false
	current_state = WatcherState.HIDDEN
	
	# Connect to sanity system
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.sanity_changed.connect(_on_sanity_changed)
	
	# Set up despawn timer
	despawn_timer.wait_time = visibility_duration
	despawn_timer.timeout.connect(_on_despawn_timer_timeout)
	
	# Connect area detection
	area_3d.body_entered.connect(_on_area_entered)

func _process(delta):
	_update_spawn_logic(delta)
	_update_watcher_behavior(delta)

func _update_spawn_logic(delta):
	"""Handle Watcher spawning based on sanity and time"""
	if current_state != WatcherState.HIDDEN:
		return
	
	spawn_timer += delta
	
	# Check for spawn every second
	if spawn_timer >= 1.0:
		spawn_timer = 0.0
		
		# Roll for spawn chance (per minute converted to per second)
		var spawn_chance_per_second = current_spawn_rate / 60.0
		if randf() < spawn_chance_per_second:
			_attempt_spawn()

func _attempt_spawn():
	"""Attempt to spawn the Watcher near the player"""
	var player = _get_player()
	if not player:
		return
	
	var spawn_position = _find_spawn_position(player.global_position)
	if spawn_position != Vector3.INF:
		_manifest_at_position(spawn_position)

func _find_spawn_position(player_pos: Vector3) -> Vector3:
	"""Find a valid position to spawn the Watcher"""
	var maze_manager = get_node("/root/MazeManager")
	if not maze_manager:
		return Vector3.INF
	
	# Try multiple random positions at appropriate distance
	for attempt in range(20):
		var angle = randf() * 2 * PI
		var distance = randf_range(min_distance_from_player, max_distance_from_player)
		
		var spawn_pos = player_pos + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		# Convert to grid position for maze checking
		var grid_pos = Vector2i(
			int(spawn_pos.x / 4.0),  # Assuming 4.0 grid size
			int(spawn_pos.z / 4.0)
		)
		
		# Check if position is valid in maze
		if _is_valid_spawn_position(grid_pos, maze_manager):
			return spawn_pos
	
	return Vector3.INF

func _is_valid_spawn_position(grid_pos: Vector2i, maze_manager: Node) -> bool:
	"""Check if grid position is valid for Watcher spawn"""
	var cell = maze_manager.get_cell(grid_pos.x, grid_pos.y)
	if cell == null:
		return false
	
	# Prefer positions with some openness
	var wall_count = 0
	for wall in ["top", "right", "bottom", "left"]:
		if cell.walls[wall]:
			wall_count += 1
	
	return wall_count < 3  # At least somewhat open

func _manifest_at_position(pos: Vector3):
	"""Manifest the Watcher at the specified position"""
	global_position = pos
	current_state = WatcherState.MANIFESTING
	
	# Start manifestation effect
	_play_manifestation_effect()
	
	# Become visible and start visibility timer
	visible = true
	current_state = WatcherState.VISIBLE
	despawn_timer.start()
	
	print("WATCHER: Manifested at ", pos)

func _play_manifestation_effect():
	"""Play visual/audio effects for Watcher manifestation"""
	# TODO: Add particle effects, distortion, audio
	
	# Start with low opacity and fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.7, 0.5)

func _update_watcher_behavior(delta):
	"""Update Watcher behavior based on current state"""
	match current_state:
		WatcherState.VISIBLE:
			_update_visible_behavior(delta)
		WatcherState.DESPAWNING:
			_update_despawn_behavior(delta)

func _update_visible_behavior(delta):
	"""Behavior while Watcher is visible"""
	var player = _get_player()
	if not player:
		return
	
	# Look towards player
	look_at(player.global_position, Vector3.UP)
	
	# Subtle movement/floating
	global_position.y += sin(Time.get_time_from_start() * 2.0) * 0.02
	
	# Check if player is looking at Watcher
	if _is_player_looking_at_watcher(player):
		_trigger_sanity_loss()

func _is_player_looking_at_watcher(player: Node3D) -> bool:
	"""Check if player is looking directly at the Watcher"""
	var player_camera = player.get_node("Camera3D")
	if not player_camera:
		return false
	
	var to_watcher = (global_position - player_camera.global_position).normalized()
	var camera_forward = -player_camera.global_transform.basis.z.normalized()
	
	var dot_product = to_watcher.dot(camera_forward)
	return dot_product > 0.7  # Within field of view

func _trigger_sanity_loss():
	"""Trigger sanity loss when player sees Watcher"""
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		sanity_manager.apply_sanity_loss_event("watcher_encounter", sanity_loss_per_encounter)
	
	# Despawn after being seen
	_start_despawn()

func _start_despawn():
	"""Begin despawning process"""
	if current_state != WatcherState.VISIBLE:
		return
	
	current_state = WatcherState.DESPAWNING
	despawn_timer.stop()
	
	# Fade out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_complete_despawn)

func _update_despawn_behavior(delta):
	"""Handle despawning behavior"""
	# Visual distortion effects could go here
	pass

func _complete_despawn():
	"""Complete the despawn process"""
	visible = false
	current_state = WatcherState.HIDDEN
	modulate.a = 1.0  # Reset for next spawn

func _on_despawn_timer_timeout():
	"""Handle automatic despawn after visibility duration"""
	if current_state == WatcherState.VISIBLE:
		_start_despawn()

func _on_area_entered(body):
	"""Handle player getting too close to Watcher"""
	if body.is_in_group("player"):
		_trigger_sanity_loss()
		_start_despawn()

func _on_sanity_changed(new_sanity: int):
	"""React to player sanity changes"""
	var sanity_manager = get_node("/root/SanityManager")
	if sanity_manager:
		set_spawn_rate(sanity_manager.get_sanity_spawn_rate("watcher"))

func _get_player() -> Node3D:
	"""Get reference to player"""
	if not player_reference:
		player_reference = get_tree().get_first_node_in_group("player")
	return player_reference

# Public API
func set_spawn_rate(rate: float):
	"""Set the spawn rate for this Watcher"""
	current_spawn_rate = rate

func force_spawn():
	"""Force immediate Watcher spawn (triggered by weird things)"""
	if current_state == WatcherState.HIDDEN:
		_attempt_spawn()

func is_currently_visible() -> bool:
	"""Check if Watcher is currently visible"""
	return current_state == WatcherState.VISIBLE

# Configuration for different Watcher types
func configure_as_aggressive():
	"""Configure as more aggressive Watcher variant"""
	sanity_loss_per_encounter = 25
	visibility_duration = 3.0
	min_distance_from_player = 10.0

func configure_as_subtle():
	"""Configure as subtle Watcher variant"""
	sanity_loss_per_encounter = 8
	visibility_duration = 1.0
	max_distance_from_player = 30.0
