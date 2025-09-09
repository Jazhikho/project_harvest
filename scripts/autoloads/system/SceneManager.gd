extends Node

const GAME_SCENE = "res://scenes/game/Game.tscn"
const MAIN_MENU = "res://scenes/ui/MainMenu.tscn"
const DEATH_SCREEN = "res://scenes/ui/DeathScreen.tscn"

func load_game_scene():
	get_tree().change_scene_to_file(GAME_SCENE)

func load_main_menu():
	get_tree().change_scene_to_file(MAIN_MENU)

func load_death_screen(death_type: String):
	print("SceneManager: Loading death screen for cause: ", death_type)
	
	# Store the death type in a temporary singleton or global
	var death_scene = load(DEATH_SCREEN)
	if death_scene:
		var instance = death_scene.instantiate()
		instance.death_type = death_type
		
		# Clear current scene and add death screen
		get_tree().current_scene.queue_free()
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
	else:
		push_error("SceneManager: Failed to load death screen")
