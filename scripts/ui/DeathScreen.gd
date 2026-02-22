extends Control

var dr_amundsen_quotes: Array[String] = [
	"\"The maze remembers... even if you don't.\" - Dr. Amundsen",
	"\"Every death teaches us something new about fear.\" - Dr. Amundsen",
	"\"How fascinating... your heart rate peaked at exactly 187 BPM before cessation.\" - Dr. Amundsen",
	"\"Subject exhibited remarkable resilience before final breakdown.\" - Dr. Amundsen",
	"\"The corn whispers their names... all of them.\" - Dr. Amundsen",
	"\"Another data point for my research. How... delightful.\" - Dr. Amundsen",
	"\"Another subject lost to the patterns. The data is exquisite.\" - Dr. Amundsen",
	"\"You lasted longer than predicted. The variables are shifting.\" - Dr. Amundsen",
	"\"Death is merely a transition state in my experiment.\" - Dr. Amundsen"
]

@onready var death_reason_label = get_node_or_null("Panel/VBoxContainer/DeathReason")
@onready var quote_label = get_node_or_null("Panel/VBoxContainer/Quote")
@onready var time_label = get_node_or_null("Panel/VBoxContainer/StatsContainer/TimeLabel")
@onready var tiles_label = get_node_or_null("Panel/VBoxContainer/StatsContainer/TilesLabel")
@onready var collectibles_label = get_node_or_null("Panel/VBoxContainer/StatsContainer/CollectiblesLabel")
@onready var fade_rect = get_node_or_null("FadeRect")
@onready var quit_dialog = get_node_or_null("QuitConfirmDialog")

var death_type: String = ""

func _ready() -> void:
	# Check if all nodes exist
	if not death_reason_label:
		push_error("DeathScreen: death_reason_label not found!")
	if not quote_label:
		push_error("DeathScreen: quote_label not found!")
	if not time_label:
		push_error("DeathScreen: time_label not found!")
	if not tiles_label:
		push_error("DeathScreen: tiles_label not found!")
	if not collectibles_label:
		push_error("DeathScreen: collectibles_label not found!")
	
	# Set quote if available
	if quote_label:
		quote_label.text = dr_amundsen_quotes[randi() % dr_amundsen_quotes.size()]
	
	# Set death reason if available
	if death_reason_label:
		match death_type:
			"sanity", "Fragmented":
				death_reason_label.text = "MIND SHATTERED"
			"entity", "Consumed":
				death_reason_label.text = "CONSUMED"
			"trap", "Ensnared":
				death_reason_label.text = "ENSNARED"
			"Terminated":
				death_reason_label.text = "SUBJECT TERMINATED"
				if quote_label:
					quote_label.text = "\"Premature termination... how disappointing.\" - Dr. Amundsen"
			"Abandoned":
				death_reason_label.text = "EXPERIMENT ABANDONED"
				if quote_label:
					quote_label.text = "\"Another subject lost to cowardice.\" - Dr. Amundsen"
			"Harvested":
				death_reason_label.text = "HARVESTED"
				if quote_label:
					quote_label.text = "\"Welcome to the collection.\" - Dr. Amundsen"
			_:
				death_reason_label.text = "LOST FOREVER"
	
	# Display stats
	_update_stats()
	
	# Fade in
	fade_in()

func _update_stats():
	"""Update the stats display"""
	# Get data from GameStateManager for current run stats
	var state_manager = get_node_or_null("/root/GameStateManager")
	var save_manager = get_node_or_null("/root/SaveManager")
	
	var time_played: float = 0.0
	var tiles: int = 0
	var collectibles: int = 0
	
	# Get time from GameDirector session data
	var game_director = get_node_or_null("/root/GameDirector")
	if game_director and game_director.has_method("get_session_duration"):
		time_played = game_director.get_session_duration()
	elif state_manager:
		# Fallback: calculate from run data start time
		var run_data = state_manager.get_state("run_data")
		if run_data and run_data.has("start_time"):
			time_played = Time.get_unix_time_from_system() - run_data.start_time
	elif save_manager and save_manager.save_data:
		# Final fallback: use saved time from previous run
		time_played = save_manager.save_data.get("time_played", 0.0)
	
	# Get tiles explored from GameStateManager
	if state_manager:
		tiles = state_manager.get_state("tiles_explored")
	elif save_manager and save_manager.save_data:
		# Fallback: use saved tiles from previous run
		tiles = save_manager.save_data.get("tiles_explored", 0)
	
	# Get collectibles from SaveManager
	if save_manager and save_manager.save_data:
		collectibles = save_manager.save_data.get("collectibles", []).size()
	
	var minutes = int(time_played / 60)
	var seconds = int(time_played) % 60
	
	# Update labels only if they exist
	if time_label:
		time_label.text = "Time Survived: %02d:%02d" % [minutes, seconds]
	
	if tiles_label:
		tiles_label.text = "Tiles Explored: %d" % tiles
	
	if collectibles_label:
		collectibles_label.text = "Collectibles Found: %d" % collectibles

func fade_in():
	if not fade_rect:
		return
		
	var tween = create_tween()
	fade_rect.color.a = 1.0
	tween.tween_property(fade_rect, "color:a", 0.0, 1.0)

func _on_continue_pressed():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.record_death()
	
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
		await tween.finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.load_game_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_quit_pressed():
	if quit_dialog:
		quit_dialog.popup_centered()
	else:
		_on_quit_confirmed()

func _on_quit_confirmed():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.record_death()
	
	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
		await tween.finished
	else:
		await get_tree().create_timer(0.5).timeout
	
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.load_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
