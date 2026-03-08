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

var game_paused: bool = false
var inventory_open: bool = false
var journal_open: bool = false

func _ready() -> void:
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	if inventory_ui:
		inventory_ui.closed.connect(_on_inventory_closed)
	if journal_ui:
		journal_ui.closed.connect(_on_journal_closed)
	call_deferred("_initialize_game")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_terminate_subject("Force Quit")
		await _fade_out_game_audio_and_wait(1.0)
		get_tree().quit()

func _initialize_game() -> void:
	var tile_manager = get_node_or_null("/root/TileManager")
	if tile_manager and tile_manager.has_method("initialize_game_tiles"):
		tile_manager.initialize_game_tiles()
	var message_bus = get_node_or_null("/root/MessageBus")
	if message_bus:
		message_bus.emit_event("game_started", [])
		if message_bus.has_signal("player_died"):
			message_bus.player_died.connect(_on_player_died)
		message_bus.connect_event("open_inventory_to_item", _on_open_inventory_to_item)
		message_bus.connect_event("open_journal_to_note", _on_open_journal_to_note)
		message_bus.connect_event("screen_effect_requested", _on_screen_effect_requested)
	await get_tree().create_timer(0.1).timeout
	if tile_manager:
		var start_tile = $MazeContainer/StartTile
		if start_tile:
			tile_manager._spawn_tile_connections(start_tile, Vector2i(0, 0))
		else:
			push_error("GameController: Start tile not found!")
	_start_game_audio()
	fade_in()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not game_paused and not journal_open:
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") and not game_paused and not inventory_open:
		toggle_journal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not inventory_open and not journal_open:
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	game_paused = !game_paused
	if game_paused:
		pause_menu.visible = true
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_menu.show_menu()
	else:
		pause_menu.visible = false
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		call_deferred("_ensure_resume_mouse_capture")

func toggle_inventory() -> void:
	inventory_open = !inventory_open
	get_tree().paused = inventory_open
	if inventory_open:
		inventory_ui.show_inventory()
	else:
		inventory_ui.hide_inventory()
		var player = get_node_or_null("/root/Game/Player")
		if player and player.has_method("ensure_mouse_capture_state"):
			player.ensure_mouse_capture_state()

func _on_resume_requested() -> void:
	toggle_pause()

func _ensure_resume_mouse_capture() -> void:
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()

func toggle_journal() -> void:
	journal_open = !journal_open
	get_tree().paused = journal_open
	if journal_open:
		journal_ui.show_journal()
	else:
		journal_ui.hide_journal()
		var player = get_node_or_null("/root/Game/Player")
		if player and player.has_method("ensure_mouse_capture_state"):
			player.ensure_mouse_capture_state()

func _on_inventory_closed() -> void:
	inventory_open = false
	get_tree().paused = false
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()

func _on_journal_closed() -> void:
	journal_open = false
	get_tree().paused = false
	var player = get_node_or_null("/root/Game/Player")
	if player and player.has_method("ensure_mouse_capture_state"):
		player.ensure_mouse_capture_state()

func _on_open_inventory_to_item(item_id: String) -> void:
	if not inventory_open:
		inventory_open = true
		get_tree().paused = true
		inventory_ui.show_inventory_with_item(item_id)

func _on_open_journal_to_note(note_id: String) -> void:
	if not journal_open:
		journal_open = true
		get_tree().paused = true
		journal_ui.show_journal_with_note(note_id)

func _on_screen_effect_requested(effect_type: String, duration: float, intensity: float) -> void:
	match effect_type:
		"fade_black":
			var tween: Tween = create_tween()
			tween.tween_property(fade_rect, "color:a", intensity, duration)
		"fade_in":
			var tween: Tween = create_tween()
			tween.tween_property(fade_rect, "color:a", 0.0, duration)
		_:
			push_warning("GameController: Unknown screen effect type: %s" % effect_type)

func _on_main_menu_requested() -> void:
	_terminate_subject("Abandoned")
	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	get_tree().paused = false
	SceneManager.load_main_menu()

func _on_quit_requested() -> void:
	_terminate_subject("Terminated")
	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	get_tree().paused = false
	SceneManager.load_death_screen("Terminated")

func _terminate_subject(cause: String) -> void:
	var message_bus = get_node_or_null("/root/MessageBus")
	var state_manager = get_node_or_null("/root/GameStateManager")
	if message_bus and state_manager:
		var current_pos = state_manager.get_state("current_tile_position")
		var death_data = {"voluntary": true, "cause": cause}
		message_bus.emit_event("player_died", [cause, current_pos, death_data])
		if cause == "Terminated":
			SaveManager.record_death()

func fade_in() -> void:
	var tween = create_tween()
	fade_rect.color.a = 1.0
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _on_player_died(cause: String, death_position: Vector2i, death_data: Dictionary) -> void:
	trigger_death(cause)

func trigger_death(death_type: String) -> void:
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if inventory_ui:
		inventory_ui.visible = false
	fade_out()
	await _fade_out_game_audio_and_wait(1.5)
	SceneManager.load_death_screen(death_type)

func _fade_out_game_audio_and_wait(seconds: float) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	await am.stop_all_game_audio_fade(seconds)

func _start_game_audio() -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		push_error("GameController: AudioManager autoload not found.")
		return
	if audio_manager.has_method("stop_theme_fade"):
		await audio_manager.stop_theme_fade(0.5)
	if audio_manager.has_method("setup_music_buses"):
		audio_manager.setup_music_buses()
	elif audio_manager.has_method("_ensure_core_buses"):
		audio_manager._ensure_core_buses()
	var ambient_stream: AudioStream = null
	if sfx_library is SFX and sfx_library.ambient is AudioStream:
		ambient_stream = sfx_library.ambient
	if ambient_stream != null:
		if audio_manager.has_method("play_ambient_loop"):
			audio_manager.play_ambient_loop(ambient_stream, -10.0)
		else:
			push_error("GameController: AudioManager.play_ambient_loop(AudioStream, float) missing.")
	else:
		push_error("GameController: No ambient stream set. Assign SFX.tres -> 'ambient' in the inspector.")
	if music_playlist is MusicPlaylist and music_playlist.tracks.size() > 0:
		if audio_manager.has_method("set_music_playlist"):
			audio_manager.set_music_playlist(music_playlist)
		else:
			push_error("GameController: AudioManager.set_music_playlist(MusicPlaylist) missing.")
		if audio_manager.has_method("configure_music_timing"):
			audio_manager.configure_music_timing(2.5, 0.5, 2.0)
		if audio_manager.has_method("start_music"):
			audio_manager.start_music()
		else:
			push_error("GameController: AudioManager.start_music() missing.")
	else:
		push_error("GameController: music_playlist is empty or not assigned in the inspector.")

func debug_force_show_minimized_hints() -> void:
	if control_hints and control_hints.has_method("force_show_minimized_hints"):
		control_hints.force_show_minimized_hints()
	else:
		push_error("GameController: ControlsUI not found or missing force_show_minimized_hints method")
