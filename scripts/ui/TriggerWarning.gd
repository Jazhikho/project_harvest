extends Control

## TriggerWarning
## Purpose: Displays a content warning before the main menu loads
## Handles user choice to continue or exit the game

# UI References
@onready var continue_button: Button = $WarningContainer/ButtonContainer/ContinueButton
@onready var quit_button: Button = $WarningContainer/ButtonContainer/QuitButton
@onready var fade_rect: ColorRect = $FadeRect

# Scene transition constants
const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/Main.tscn"
const FADE_DURATION: float = 1.0

func _ready() -> void:
	# Set up initial state
	fade_rect.color = Color(0, 0, 0, 1)
	continue_button.grab_focus()
	
	# Start fade-in animation
	call_deferred("_fade_in")

## _fade_in
## Purpose: Fade in the trigger warning screen
## @return void
func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween.finished

## _fade_out
## Purpose: Fade out the trigger warning screen before transitioning
## @return void
func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished

## _on_continue_pressed
## Purpose: Handle user choosing to continue after reading warning
## @return void
func _on_continue_pressed() -> void:
	await _fade_out()
	_load_main_menu()

## _on_quit_pressed
## Purpose: Handle user choosing to exit the game
## @return void
func _on_quit_pressed() -> void:
	await _fade_out()
	get_tree().quit()

## _load_main_menu
## Purpose: Load the main menu scene
## @return void
func _load_main_menu() -> void:
	var error: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error("Failed to load main menu scene: " + str(error))
		get_tree().quit()

## _input
## Purpose: Handle additional input for accessibility
## @param event: InputEvent - The input event to process
## @return void
func _input(event: InputEvent) -> void:
	# Allow Enter/Space to continue, Escape to quit
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_continue_pressed()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_quit_pressed()
