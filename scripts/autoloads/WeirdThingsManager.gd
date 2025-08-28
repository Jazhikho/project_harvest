extends Node
## Weird Things Manager - Handles mysterious artifacts and their effects
## Ported from JavaScript weirdThings.js

signal weird_thing_collected(type: String, position: Vector2i)
signal weird_effect_triggered(effect_type: String)

@export var min_weird_things: int = 5
@export var max_weird_things: int = 10

# Weird thing types and their properties
enum WeirdThingType {
	DOLL,           # Creepy children's doll
	MUSIC_BOX,      # Haunted music box
	MIRROR,         # Fractured mirror shard
	SYMBOL,         # Occult symbol carved in wood
	POCKET_WATCH,   # Stopped antique pocket watch
	NOTE,           # Research note from Dr. Amundsen
	PHOTO           # Distorted family photograph
}

var weird_things: Array[Dictionary] = []
var collected_count: int = 0

# Weird thing data definitions
var weird_thing_data = {
	WeirdThingType.DOLL: {
		"name": "Porcelain Doll",
		"description": "A child's doll with cracked porcelain face and missing eyes",
		"messages": [
			"The doll's hollow eyes seem to follow your movement...",
			"Its cracked smile whispers secrets of forgotten children...",
			"Tiny fingers point toward your inevitable harvest..."
		],
		"effects": ["screen_flicker", "sanity_loss"]
	},
	
	WeirdThingType.MUSIC_BOX: {
		"name": "Music Box",
		"description": "An ornate music box that plays a haunting lullaby",
		"messages": [
			"The melody echoes memories that aren't your own...",
			"Each note pulls you deeper into the maze's embrace...", 
			"The song speaks of subjects who danced their last dance..."
		],
		"effects": ["audio_distortion", "maze_shift", "sanity_loss"]
	},
	
	WeirdThingType.MIRROR: {
		"name": "Mirror Shard",
		"description": "A fragment of broken mirror that reflects impossible things",
		"messages": [
			"Your reflection shows someone... different...",
			"In the mirror, you see yourself from another run...",
			"The glass whispers: 'You've been here before...'"
		],
		"effects": ["visual_distortion", "fog_lift", "sanity_loss"]
	},
	
	WeirdThingType.SYMBOL: {
		"name": "Harvest Symbol",
		"description": "An occult symbol carved into weathered wood",
		"messages": [
			"The symbol burns itself into your memory...",
			"Ancient marks that predate human understanding...",
			"Dr. Amundsen's research made manifest in wood and pain..."
		],
		"effects": ["stalker_activation", "maze_distortion", "sanity_loss"]
	},
	
	WeirdThingType.POCKET_WATCH: {
		"name": "Stopped Watch",
		"description": "An antique pocket watch frozen at 11:47",
		"messages": [
			"Time stopped when the first subject was harvested...",
			"The hands point to the moment of your arrival...",
			"Past, present, future - all harvest the same subjects..."
		],
		"effects": ["time_distortion", "echo_spawn", "sanity_loss"]
	},
	
	WeirdThingType.NOTE: {
		"name": "Research Note",
		"description": "A fragment of Dr. Amundsen's experimental documentation",
		"messages": [
			"'Subject shows promising signs of fragmentation...' -A",
			"'The maze responds to psychological pressure...' -Dr. Amundsen",
			"'Each run yields better harvest data...' -A"
		],
		"effects": ["lore_reveal", "overseer_activation", "sanity_loss"]
	},
	
	WeirdThingType.PHOTO: {
		"name": "Family Photo",
		"description": "A distorted family photograph with faces you almost recognize",
		"messages": [
			"The faces shift when you're not looking directly...",
			"Is that... your family? From which timeline?",
			"They're calling your name from inside the photograph..."
		],
		"effects": ["identity_crisis", "watcher_spawn", "sanity_loss"]
	}
}

func _ready():
	# Connect to other systems
	await get_tree().process_frame

func place_weird_things():
	"""Place weird things randomly throughout the maze"""
	weird_things.clear()
	collected_count = 0
	
	var maze_manager = get_node("/root/MazeManager")
	if not maze_manager:
		return
	
	var maze_size = maze_manager.get_maze_size()
	var placement_count = randi_range(min_weird_things, max_weird_things)
	
	for i in range(placement_count):
		var weird_thing = _create_random_weird_thing()
		var position = _find_valid_placement_position(maze_manager, maze_size)
		
		if position != Vector2i(-1, -1):
			weird_thing["position"] = position
			weird_things.append(weird_thing)

func _create_random_weird_thing() -> Dictionary:
	"""Create a random weird thing with properties"""
	var type = randi() % WeirdThingType.size()
	var data = weird_thing_data[type]
	
	return {
		"type": type,
		"name": data["name"],
		"description": data["description"],
		"messages": data["messages"],
		"effects": data["effects"],
		"collected": false,
		"position": Vector2i(-1, -1)
	}

func _find_valid_placement_position(maze_manager: Node, maze_size: Vector2i) -> Vector2i:
	"""Find a valid position to place a weird thing"""
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		var x = randi_range(2, maze_size.x - 3)
		var y = randi_range(2, maze_size.y - 3)
		var pos = Vector2i(x, y)
		
		# Check if position is not blocked and not too close to other weird things
		if _is_position_valid_for_placement(pos, maze_manager):
			return pos
		
		attempts += 1
	
	return Vector2i(-1, -1)  # Failed to find valid position

func _is_position_valid_for_placement(pos: Vector2i, maze_manager: Node) -> bool:
	"""Check if a position is valid for weird thing placement"""
	# Check if not too close to existing weird things
	for thing in weird_things:
		var distance = pos.distance_to(thing["position"])
		if distance < 3.0:  # Minimum distance between weird things
			return false
	
	# Check if position is accessible (not fully walled)
	var cell = maze_manager.get_cell(pos.x, pos.y)
	if cell == null:
		return false
	
	# Prefer open areas
	var wall_count = 0
	for wall in ["top", "right", "bottom", "left"]:
		if cell.walls[wall]:
			wall_count += 1
	
	return wall_count < 3  # At least one open direction

func check_collection_at_position(grid_pos: Vector2i) -> Dictionary:
	"""Check if there's a weird thing to collect at given position"""
	for thing in weird_things:
		if thing["position"] == grid_pos and not thing["collected"]:
			return thing
	
	return {}

func collect_weird_thing(thing: Dictionary):
	"""Collect a weird thing and trigger its effects"""
	if thing.is_empty() or thing["collected"]:
		return
	
	thing["collected"] = true
	collected_count += 1
	
	# Show message
	var message = thing["messages"][randi() % thing["messages"].size()]
	_show_weird_message(message)
	
	# Apply effects
	for effect in thing["effects"]:
		_apply_weird_effect(effect, thing)
	
	emit_signal("weird_thing_collected", thing["type"], thing["position"])

func _show_weird_message(message: String):
	"""Display weird thing collection message"""
	print("WEIRD THING: ", message)
	
	# TODO: Connect to UI system
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("show_weird_message"):
		ui_manager.show_weird_message(message, 4.0)

func _apply_weird_effect(effect_type: String, thing: Dictionary):
	"""Apply the specific effect of a weird thing"""
	emit_signal("weird_effect_triggered", effect_type)
	
	match effect_type:
		"screen_flicker":
			_trigger_screen_flicker()
		
		"sanity_loss":
			var sanity_manager = get_node("/root/SanityManager")
			if sanity_manager:
				sanity_manager.apply_sanity_loss_event("weird_thing")
		
		"maze_shift":
			var maze_manager = get_node("/root/MazeManager")
			if maze_manager:
				maze_manager.shift_maze_section()
		
		"visual_distortion":
			_trigger_visual_distortion()
		
		"fog_lift":
			_trigger_fog_lift()
		
		"stalker_activation":
			_activate_stalker()
		
		"maze_distortion":
			_trigger_maze_distortion(thing["position"])
		
		"audio_distortion":
			_trigger_audio_distortion()
		
		"time_distortion":
			_trigger_time_distortion()
		
		"echo_spawn":
			_trigger_echo_spawn()
		
		"lore_reveal":
			_trigger_lore_reveal()
		
		"overseer_activation":
			_activate_overseer()
		
		"identity_crisis":
			_trigger_identity_crisis()
		
		"watcher_spawn":
			_spawn_watcher()

func _trigger_screen_flicker():
	"""Trigger screen flicker effect"""
	# TODO: Implement visual flicker
	print("EFFECT: Screen flickers ominously...")

func _trigger_visual_distortion():
	"""Trigger visual distortion effect"""
	# TODO: Implement chromatic aberration or similar
	print("EFFECT: Reality distorts around you...")

func _trigger_fog_lift():
	"""Temporarily lift fog of war"""
	# TODO: Implement fog lifting
	print("EFFECT: The fog lifts momentarily, revealing hidden paths...")

func _activate_stalker():
	"""Activate or summon the stalker entity"""
	var stalker = get_tree().get_first_node_in_group("stalker")
	if stalker and stalker.has_method("activate"):
		stalker.activate()
	print("EFFECT: Something dark stirs in the maze...")

func _trigger_maze_distortion(center: Vector2i):
	"""Trigger localized maze distortion"""
	var maze_manager = get_node("/root/MazeManager")
	if maze_manager:
		# Multiple shifts around the weird thing location
		for i in range(3):
			maze_manager.shift_maze_section()

func _trigger_audio_distortion():
	"""Trigger audio distortion effects"""
	# TODO: Implement audio distortion
	print("EFFECT: Haunting melody echoes through the corn...")

func _trigger_time_distortion():
	"""Trigger time distortion effects"""
	# TODO: Implement time-related visual effects
	print("EFFECT: Time seems to slow and stutter...")

func _trigger_echo_spawn():
	"""Trigger spawning of harvest echoes"""
	var harvest_logger = get_node("/root/HarvestLogger")
	if harvest_logger and harvest_logger.has_method("spawn_immediate_echo"):
		harvest_logger.spawn_immediate_echo()

func _trigger_lore_reveal():
	"""Reveal additional lore information"""
	# TODO: Add to lore database
	print("EFFECT: Dr. Amundsen's research becomes clearer...")

func _activate_overseer():
	"""Activate overseer eye surveillance"""
	var overseer = get_tree().get_first_node_in_group("overseer")
	if overseer and overseer.has_method("increase_surveillance"):
		overseer.increase_surveillance()

func _trigger_identity_crisis():
	"""Trigger identity-related effects"""
	# TODO: Implement doppelganger effects
	print("EFFECT: Your reflection doesn't match your movements...")

func _spawn_watcher():
	"""Spawn a watcher entity"""
	var watcher = get_tree().get_first_node_in_group("watcher")
	if watcher and watcher.has_method("force_spawn"):
		watcher.force_spawn()

# Public API
func get_collected_count() -> int:
	return collected_count

func get_total_placed() -> int:
	return weird_things.size()

func get_weird_things_in_area(center: Vector2i, radius: int) -> Array:
	"""Get all weird things within a certain radius"""
	var nearby_things = []
	for thing in weird_things:
		if thing["position"].distance_to(center) <= radius:
			nearby_things.append(thing)
	return nearby_things
