extends Control

@onready var backpack_icon: TextureRect = $HBoxContainer/BackpackHint/Icon
@onready var flashlight_icon: TextureRect = $HBoxContainer/FlashlightHint/Icon
@onready var journal_icon: TextureRect = $HBoxContainer/JournalHint/Icon

func _ready() -> void:
	# Make sure this stays on top and doesn't interfere with mouse
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load the icon textures
	_load_icons()
	
	# Optional: Add a semi-transparent background panel
	_add_background()

func _load_icons() -> void:
	"""Load the thumbnail icons"""
	# Try to load backpack/inventory icon
	var backpack_texture: Texture2D = _try_load_texture([
		"res://assets/thumbnails/backpack.png",
		"res://assets/thumbnails/inventory.png",
		"res://assets/thumbnails/bag.png"
	])
	if backpack_texture:
		backpack_icon.texture = backpack_texture
	
	# Load flashlight icon
	var flashlight_texture: Texture2D = load("res://assets/thumbnails/flashlight.png")
	if flashlight_texture:
		flashlight_icon.texture = flashlight_texture
	
	# Load journal icon
	var journal_texture: Texture2D = load("res://assets/thumbnails/journal.png")
	if journal_texture:
		journal_icon.texture = journal_texture

func _try_load_texture(paths: Array) -> Texture2D:
	"""Try to load texture from multiple possible paths"""
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _add_background() -> void:
	"""Add a semi-transparent background panel behind the hints"""
	var bg: Panel = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create a semi-transparent style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	bg.add_theme_stylebox_override("panel", style)
	
	# Add it as the first child (behind everything)
	add_child(bg)
	move_child(bg, 0)

func show_hints() -> void:
	visible = true

func hide_hints() -> void:
	visible = false

# Optional: Fade in/out animations
func fade_in(duration: float = 0.3) -> void:
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)

func fade_out(duration: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(func(): visible = false)
