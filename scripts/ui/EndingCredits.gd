extends Control
## Ending Credits - Shows post-game dialogue and credit crawl

const BuildInfoData = preload("res://scripts/utils/BuildInfo.gd")

@export var music_playlist: MusicPlaylist

@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var credits_scroll: ScrollContainer = $CreditsScroll
@onready var credits_text: RichTextLabel = $CreditsScroll/CreditsText
@onready var fade_rect: ColorRect = $FadeRect
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var _credits_started: bool = false
var _architects_maze_finished: bool = false

func _ready() -> void:
	# Start with everything hidden except fade rect
	dialogue_label.modulate.a = 0.0
	credits_scroll.modulate.a = 0.0
	credits_scroll.visible = false
	fade_rect.color = Color.BLACK
	
	# Start the ending sequence
	_start_ending_sequence()

func _start_ending_sequence() -> void:
	"""Start the ending dialogue and credits sequence"""
	# Play Architect's Maze music
	if music_playlist:
		var architects_maze: AudioStream = _get_architects_maze_track()
		if architects_maze:
			audio_player.stream = architects_maze
			audio_player.bus = "Music"
			audio_player.play()
			audio_player.finished.connect(_on_architects_maze_finished)
	
	# Fade in from black
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
	await fade_tween.finished
	
	# Start dialogue sequence
	await _show_dialogue_sequence()
	
	# Start credits
	_start_credits()

func _get_architects_maze_track() -> AudioStream:
	"""Get the Architect's Maze track from the music playlist"""
	if not music_playlist or music_playlist.tracks.is_empty():
		return null
	
	# Architect's Maze is the first track in the playlist
	return music_playlist.tracks[0]

func _show_dialogue_sequence() -> void:
	"""Show the dialogue sequence"""
	# First dialogue - blue text
	dialogue_label.visible = true
	dialogue_label.bbcode_enabled = true
	dialogue_label.text = "[center][color=#4169E1]Dr. Amundsen? You asked to be informed when one of the subject's iterations successfully finished phase 0 trials.[/color][/center]"
	
	var fade_in: Tween = create_tween()
	fade_in.tween_property(dialogue_label, "modulate:a", 1.0, 1.0)
	await fade_in.finished
	
	await get_tree().create_timer(4.0).timeout
	
	# Add red text below
	dialogue_label.text = "[center][color=#4169E1]Dr. Amundsen? You asked to be informed when one of the subject's iterations successfully finished phase 0 trials.[/color]\n\n[color=#DC143C]Ah, excellent. We are ahead of schedule! Harvest the subject and proceed to phase 1, and reset the maze for our next subject.[/color][/center]"
	
	await get_tree().create_timer(5.0).timeout
	
	# Fade out
	var fade_out: Tween = create_tween()
	fade_out.tween_property(dialogue_label, "modulate:a", 0.0, 1.0)
	await fade_out.finished
	
	await get_tree().create_timer(1.0).timeout
	
	# Show second red dialogue
	dialogue_label.modulate.a = 0.0
	dialogue_label.text = "[center][color=#DC143C]Have you enjoyed our little experiment, player? Did you get a thrill sending your iterations to their death? Did you think that you are somehow separate from the little rat you controlled in the maze?[/color][/center]"
	
	var fade_in2: Tween = create_tween()
	fade_in2.tween_property(dialogue_label, "modulate:a", 1.0, 1.0)
	await fade_in2.finished
	
	await get_tree().create_timer(6.0).timeout
	
	# Fade out final dialogue
	var fade_out2: Tween = create_tween()
	fade_out2.tween_property(dialogue_label, "modulate:a", 0.0, 1.0)
	await fade_out2.finished

func _start_credits() -> void:
	"""Start the credit crawl"""
	_credits_started = true
	dialogue_label.visible = false
	credits_scroll.visible = true
	
	credits_text.bbcode_enabled = true
	credits_text.text = BuildInfoData.get_credits_text()
	
	var fade_in: Tween = create_tween()
	fade_in.tween_property(credits_scroll, "modulate:a", 1.0, 1.0)
	await fade_in.finished
	
	await _scroll_credits()

func _scroll_credits() -> void:
	"""Scroll the credits from top to bottom"""
	var scroll_bar: VScrollBar = credits_scroll.get_v_scroll_bar()
	scroll_bar.value = 0.0
	
	var scroll_duration: float = 60.0
	
	var scroll_tween: Tween = create_tween()
	scroll_tween.tween_property(scroll_bar, "value", scroll_bar.max_value, scroll_duration)
	await scroll_tween.finished
	
	await get_tree().create_timer(3.0).timeout
	_return_to_main_menu()

func _on_architects_maze_finished() -> void:
	"""Handle when Architect's Maze music finishes"""
	_architects_maze_finished = true
	_play_random_ending_music()

func _play_random_ending_music() -> void:
	"""Play random music from main theme and Who Am I tracks"""
	if not music_playlist or music_playlist.tracks.size() < 2:
		return
	
	var valid_tracks: Array[AudioStream] = []
	
	if music_playlist.main_theme:
		valid_tracks.append(music_playlist.main_theme)
	
	for i in range(5, min(8, music_playlist.tracks.size())):
		valid_tracks.append(music_playlist.tracks[i])
	
	if valid_tracks.is_empty():
		return
	
	var random_track: AudioStream = valid_tracks[randi() % valid_tracks.size()]
	audio_player.stream = random_track
	audio_player.play()
	audio_player.finished.connect(_play_random_ending_music)

func _return_to_main_menu() -> void:
	"""Fade out and return to main menu"""
	fade_rect.color.a = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 2.0)
	await fade_tween.finished
	
	audio_player.stop()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.load_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/Main.tscn")
