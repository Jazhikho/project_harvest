extends Control
## Ending Credits - Shows post-game dialogue and credit crawl

@export var music_playlist: MusicPlaylist

@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var credits_scroll: ScrollContainer = $CreditsScroll
@onready var credits_text: RichTextLabel = $CreditsScroll/CreditsText
@onready var fade_rect: ColorRect = $FadeRect
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var _dialogue_sequence: int = 0
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
	dialogue_label.text = "[center][color=#4169E1]Dr. Amundsen? You asked to be informed when one of the subject's iterations successfully finished phase 0 trials.[/color]

[color=#DC143C]Ah, excellent. We are ahead of schedule! Harvest the subject and proceed to phase 1, and reset the maze for our next subject.[/color][/center]"
	
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
	
	# Set credits text
	credits_text.bbcode_enabled = true
	credits_text.text = _get_credits_text()
	
	# Fade in credits
	var fade_in: Tween = create_tween()
	fade_in.tween_property(credits_scroll, "modulate:a", 1.0, 1.0)
	await fade_in.finished
	
	# Start scrolling
	await _scroll_credits()

func _scroll_credits() -> void:
	"""Scroll the credits from top to bottom"""
	var scroll_bar: VScrollBar = credits_scroll.get_v_scroll_bar()
	scroll_bar.value = 0.0
	
	# Calculate scroll duration based on content height (about 1 minute total)
	var scroll_duration: float = 60.0
	
	var scroll_tween: Tween = create_tween()
	scroll_tween.tween_property(scroll_bar, "value", scroll_bar.max_value, scroll_duration)
	await scroll_tween.finished
	
	# Credits finished - wait a moment then return to main menu
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
	
	# Tracks to choose from: Main Theme (main_theme) and Who Am I 1-3 (indices 5, 6, 7)
	var valid_tracks: Array[AudioStream] = []
	
	if music_playlist.main_theme:
		valid_tracks.append(music_playlist.main_theme)
	
	# Who Am I tracks are at the end of the playlist
	for i in range(5, min(8, music_playlist.tracks.size())):
		valid_tracks.append(music_playlist.tracks[i])
	
	if valid_tracks.is_empty():
		return
	
	# Pick random track
	var random_track: AudioStream = valid_tracks[randi() % valid_tracks.size()]
	audio_player.stream = random_track
	audio_player.play()
	audio_player.finished.connect(_play_random_ending_music)

func _return_to_main_menu() -> void:
	"""Fade out and return to main menu"""
	# Fade to black
	fade_rect.color.a = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 2.0)
	await fade_tween.finished
	
	# Stop music
	audio_player.stop()
	
	# Return to main menu
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.load_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/Main.tscn")

func _get_credits_text() -> String:
	"""Get the full credits text"""
	return "[center][b]PROJECT HARVEST[/b]
[i]A Walking Nightmare[/i]

[b]═══════════════════════════════════[/b]

[b]CREATED BY[/b]
Christopher B. Del Gesso
Chosen Gaming

[b]═══════════════════════════════════[/b]

[b]DEVELOPMENT[/b]

[b]Lead Developer & Designer[/b]
Christopher B. Del Gesso

[b]Programming[/b]
Christopher B. Del Gesso
with assistance from Anthropic Claude-4 Sonnet

[b]3D Art & Modeling[/b]
Christopher B. Del Gesso

[b]Audio Design[/b]
Christopher B. Del Gesso

[b]Narrative Design[/b]
Christopher B. Del Gesso

[b]═══════════════════════════════════[/b]

[b]TECHNOLOGY[/b]

[b]Game Engine[/b]
Godot Engine 4.4.1
MIT License
https://godotengine.org/

[b]Programming Languages[/b]
GDScript

[b]3D Software[/b]
Blender 4.5.2 - GNU GPL v3
3DS Max 2026 - Student License
Materialize v1.78 - Texture generation

[b]═══════════════════════════════════[/b]

[b]3D MODELS & ASSETS[/b]

[b]Animpic POLY[/b]
Farm Pack & Lite Halloween Pack
Standard License (purchased 2025)
Corn stalks, well, scarecrow, environmental props

[b]Sketchfab Contributors (CC Attribution)[/b]

[b]Samy Belaloui[/b] - Low Poly Skeleton
[b]yomans[/b] - Key model
[b]Bill Nguyen[/b] - Gargoyle
[b]Cat O[/b] - Gargoyle
[b]JacksonMGB[/b] - Photogrammetry Gargoyle Statue
[b]BunQuest[/b] - Altar
[b]Scary[/b] - Low Poly Brazier
[b]ClintonAbbott Art[/b] - Low Poly Dead Tree
[b]Sousinho[/b] - Paper debris
[b]Kirrek[/b] - Broken Glass
[b]AnishRoyalinc[/b] - Gate apocalyptic rusty
[b]Psychopete696[/b] - CORN MAZE-01
[b]kimmy.k[/b] - Low Poly Mobile Phone
[b]donnichols[/b] - Flashlight
[b]mohitnuslusion[/b] - Vintage Pocket Watch
[b]SCANIMATE_IO[/b] - PB153 Notebook Low
[b]Aoerchemix[/b] - Pirate Coin
[b]TwilightFox[/b] - Old Soviet Backpack
[b]3D History[/b] - 49 Star Flag
[b]Errlatte[/b] - Anubis bible

[b]Virtual Museums of Malopolska[/b]
Pocket watch - CC0 Public Domain

[b]═══════════════════════════════════[/b]

[b]TEXTURES & MATERIALS[/b]

[b]AmbientCG[/b]
Foliage003, Bark006, Lava002, Rock032, Wood035
CC0 License - Public Domain
https://ambientcg.com/

[b]Poly Haven[/b]
Mealie Road HDRI environment
by Greg Zaal
CC0 License - Public Domain
https://polyhaven.com/

[b]OpenAI GPT-5[/b]
Corn textures
Pumpkin, Flannel textures
Effigy concept designs

[b]IMGonline.com.ua[/b]
Seamless texture processing
https://www.imgonline.com.ua/

[b]Materialize v1.78[/b]
PBR texture generation
by Bounding Box Software
http://www.boundingboxsoftware.com/materialize/

[b]═══════════════════════════════════[/b]

[b]AUDIO[/b]

[b]Original Compositions[/b]
Christopher B. Del Gesso
with assistance from ElevenLabs
- Project Harvest Main Theme
- Architect's Maze
- High Tension
- Hymn of the Echoes
- The Effigy's Theme
- The Stalker's Theme
- Who Am I (In the Cornfield) 1, 2, 3

[b]Sound Effects[/b]
Christopher B. Del Gesso
- Custom environmental audio
- Gameplay sound effects

[b]Freesound.org Contributors[/b]
Scream sound effects:
- Klangkobold - Panic-stricken screaming
- missozzy - Female scream
- Yin_Yang_Jake007 - Loud Female Scream
- marc3122 - Male Screams
All licensed under Creative Commons 0

[b]═══════════════════════════════════[/b]

[b]SPECIAL THANKS[/b]

[b]Family & Support[/b]
Sarrah - For unwavering support and belief
Dawn - For encouragement and family support
The Del Gesso Family - For believing in this project

[b]Academic Support[/b]
Lindenwood University
Professor Ben Fulcher
GAM56800: Game Development Course

[b]Community[/b]
The Godot community for excellent documentation
Open source contributors who made this possible
All the creators of the free assets used in this project

[b]═══════════════════════════════════[/b]

[b]DEDICATION[/b]

This game is dedicated to Jeri
You will be remembered

[b]═══════════════════════════════════[/b]

[b]© 2025 Christopher B. Del Gesso[/b]
[b]Chosen Gaming[/b]
[b]All rights reserved[/b]

Thank you for playing PROJECT HARVEST

[b]═══════════════════════════════════[/b][/center]"
