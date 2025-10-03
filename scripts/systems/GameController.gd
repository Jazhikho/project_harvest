extends Node3D

@onready var pause_menu = $UI/PauseMenu
@onready var inventory_ui = $UI/InventoryUI
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var animation_player = $TransitionLayer/AnimationPlayer
@onready var journal_ui = $UI/JournalUI
@onready var control_hints = $UI/ControlsUI
@onready var narrative_ui = $UI/NarrativeUI
@export var music_playlist: MusicPlaylist
@export var sfx_library: SFX

var game_paused = false
var inventory_open = false
var journal_open = false

func _ready():
	# Connect signals
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	
	if inventory_ui:
		inventory_ui.closed.connect(_on_inventory_closed)

	if journal_ui:
		journal_ui.closed.connect(_on_journal_closed)
	
	# IMPORTANT: Trigger initial tile generation after scene is fully loaded
	call_deferred("_initialize_game")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_terminate_subject("Force Quit")
		await _fade_out_game_audio_and_wait(1.0)
		get_tree().quit()

func _initialize_game():
	var tile_manager = get_node_or_null("/root/TileManager")
	if tile_manager and tile_manager.has_method("initialize_game_tiles"):
		tile_manager.initialize_game_tiles()
	# Make sure MessageBus knows game started
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus:
		message_bus.emit_event("game_started", [])
		
		# Connect to player death events
		if message_bus.has_signal("player_died"):
			message_bus.player_died.connect(_on_player_died)
		
		# Connect to item inspection events
		message_bus.connect_event("open_inventory_to_item", _on_open_inventory_to_item)
		message_bus.connect_event("open_journal_to_note", _on_open_journal_to_note)
		
		# Connect to screen effect events
		message_bus.connect_event("screen_effect_requested", _on_screen_effect_requested)
	
	# Give TileManager a moment to finish initialization
	await get_tree().create_timer(0.1).timeout
	
	# Force initial tile connections
	if tile_manager:
		# Get the start tile
		var start_tile = $MazeContainer/StartTile
		if start_tile:
			# Force spawn connections from start tile
			tile_manager._spawn_tile_connections(start_tile, Vector2i(0, 0))
		else:
			push_error("GameController: Start tile not found!")
			
	_start_game_audio()
	
	# Fade in as the final step of initialization
	fade_in()

func _input(event):
	# Inventory takes priority over pause
	if event.is_action_pressed("inventory") and not game_paused:
		toggle_inventory()
		return
	
	if event.is_action_pressed("journal") and not game_paused:
		toggle_journal()
		return
	
	# Only allow pause if inventory isn't open
	if event.is_action_pressed("ui_cancel") and not inventory_open and not journal_open and not game_paused:
		toggle_pause()

func toggle_pause():
	game_paused = !game_paused
	
	if game_paused:
		# Pausing - hide menu and set mouse visible
		pause_menu.visible = true
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_menu.show_menu()
	else:
		# Unpausing - hide menu first, then set pause state
		pause_menu.visible = false
		get_tree().paused = false
		# Set mouse capture immediately
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Ensure player's mouse capture state is synchronized after a frame
		call_deferred("_ensure_resume_mouse_capture")

func toggle_inventory():
	inventory_open = !inventory_open
	get_tree().paused = inventory_open
	
	if inventory_open:
		inventory_ui.show_inventory()
	else:
		inventory_ui.hide_inventory()
		# Ensure player's mouse capture state is synchronized
		var player = get_node_or_null("/root/Game/Player")
		if player and player.has_method("ensure_mouse_capture_state"):
			player.ensure_mouse_capture_state()

func _on_resume_requested():
	toggle_pause()

func _ensure_resume_mouse_capture():
	"""Ensure mouse capture is properly set after resuming from pause"""
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()
	
func toggle_journal():
	journal_open = !journal_open
	get_tree().paused = journal_open
	
	if journal_open:
		journal_ui.show_journal()
	else:
		journal_ui.hide_journal()
		# Ensure player's mouse capture state is synchronized
		var player = get_node_or_null("/root/Game/Player")
		if player and player.has_method("ensure_mouse_capture_state"):
			player.ensure_mouse_capture_state()

func _on_inventory_closed():
	inventory_open = false
	get_tree().paused = false
	# Ensure player's mouse capture state is synchronized
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()

func _on_journal_closed():
	journal_open = false
	get_tree().paused = false
	# Ensure player's mouse capture state is synchronized
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()

func _on_open_inventory_to_item(item_id: String) -> void:
	"""Open inventory and focus on a specific item"""
	if not inventory_open:
		inventory_open = true
		get_tree().paused = true
		inventory_ui.show_inventory_with_item(item_id)

func _on_open_journal_to_note(note_id: String) -> void:
	"""Open journal and focus on a specific note"""
	if not journal_open:
		journal_open = true
		get_tree().paused = true
		journal_ui.show_journal_with_note(note_id)

func _on_screen_effect_requested(effect_type: String, duration: float, intensity: float) -> void:
	"""Handle screen effect requests from MessageBus"""
	match effect_type:
		"fade_black":
			# Create custom fade with specified duration
			var tween: Tween = create_tween()
			tween.tween_property(fade_rect, "color:a", intensity, duration)
		"fade_in":
			var tween: Tween = create_tween()
			tween.tween_property(fade_rect, "color:a", 0.0, duration)
		_:
			push_warning("GameController: Unknown screen effect type: %s" % effect_type)

func _on_main_menu_requested():
	_terminate_subject("Abandoned")
	# Start visual fade and audio fade together; wait on audio before scene swap
	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	get_tree().paused = false
	SceneManager.load_main_menu()

func _on_quit_requested():
	_terminate_subject("Terminated")
	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	get_tree().paused = false
	SceneManager.load_death_screen("Terminated")


func _terminate_subject(cause: String):
	"""Handle subject termination for quit/main menu"""
	var message_bus = get_node_or_null("/root/MessageBus")
	var state_manager = get_node_or_null("/root/GameStateManager")
	
	if message_bus and state_manager:
		var current_pos = state_manager.get_state("current_tile_position")
		var death_data = {
			"voluntary": true,
			"cause": cause
		}
		message_bus.emit_event("player_died", [cause, current_pos, death_data])
		
		# Also save/record the death
		if cause == "Terminated":
			SaveManager.record_death()

func fade_in():
	var tween = create_tween()
	fade_rect.color.a = 1.0
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _on_player_died(cause: String, death_position: Vector2i, death_data: Dictionary):
	"""Handle player death event from MessageBus"""
	trigger_death(cause)

func trigger_death(death_type: String):
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if inventory_ui:
		inventory_ui.visible = false

	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	SceneManager.load_death_screen(death_type)

func _fade_out_game_audio_and_wait(seconds: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	await am.stop_all_game_audio_fade(seconds)

## _start_game_audio
## Purpose: Start looping ambient and randomized music using exported resources and AudioManager.
## @return void.
func _start_game_audio() -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		push_error("GameController: AudioManager autoload not found.")
		return

	# If a menu theme is still playing, fade it out first.
	if audio_manager.has_method("stop_theme_fade"):
		await audio_manager.stop_theme_fade(0.5)

	# Ensure buses are present before anything touches volumes/players.
	if audio_manager.has_method("setup_music_buses"):
		audio_manager.setup_music_buses()
	elif audio_manager.has_method("_ensure_core_buses"):
		audio_manager._ensure_core_buses()

	# 1) Ambient loop from SFX resource
	var ambient_stream: AudioStream = null
	if sfx_library is SFX and sfx_library.ambient is AudioStream:
		ambient_stream = sfx_library.ambient

	if ambient_stream != null:
		# Use the correct method name that exists in AudioManager
		if audio_manager.has_method("play_ambient_loop"):
			audio_manager.play_ambient_loop(ambient_stream, -10.0)
		else:
			push_error("GameController: AudioManager.play_ambient_loop(AudioStream, float) missing.")
	else:
		push_error("GameController: No ambient stream set. Assign SFX.tres -> 'ambient' in the inspector.")

	# 2) Music playlist from resource
	if music_playlist is MusicPlaylist and music_playlist.tracks.size() > 0:
		if audio_manager.has_method("set_music_playlist"):
			audio_manager.set_music_playlist(music_playlist)
		else:
			push_error("GameController: AudioManager.set_music_playlist(MusicPlaylist) missing.")

		# Configure crossfade/gap if available.
		if audio_manager.has_method("configure_music_timing"):
			# crossfade_seconds, gap_min_seconds, gap_max_seconds
			audio_manager.configure_music_timing(2.5, 0.5, 2.0)

		if audio_manager.has_method("start_music"):
			audio_manager.start_music()
		else:
			push_error("GameController: AudioManager.start_music() missing.")
	else:
		push_error("GameController: music_playlist is empty or not assigned in the inspector.")

## debug_force_show_minimized_hints
## Purpose: Debug method to force show minimized hints
## @return void.
func debug_force_show_minimized_hints() -> void:
	print("GameController: Debug - Force showing minimized hints")
	if control_hints and control_hints.has_method("force_show_minimized_hints"):
		control_hints.force_show_minimized_hints()
	else:
		print("GameController: ERROR - ControlsUI not found or missing force_show_minimized_hints method")
