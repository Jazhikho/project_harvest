class_name CollisionHelper
## Collision Helper - Centralized collision layer management
## Ensures all collision layers are properly configured

# Collision layer constants (matching project.godot layer numbers)
const LAYER_PLAYER: int = 1 # Player character
const LAYER_ENTITIES: int = 2 # Enemies, effigies, NPCs
const LAYER_WALLS: int = 3 # Maze walls, barriers
const LAYER_OBJECTS: int = 4 # Collectible items
const LAYER_PUZZLE_OBJECTS: int = 5 # Puzzle interaction objects

# Collision masks (bit flags for what each layer should collide with)
const MASK_PLAYER: int = (1 << (LAYER_ENTITIES - 1)) + (1 << (LAYER_WALLS - 1)) + (1 << (LAYER_OBJECTS - 1)) + (1 << (LAYER_PUZZLE_OBJECTS - 1))
const MASK_ENTITIES: int = (1 << (LAYER_PLAYER - 1)) + (1 << (LAYER_WALLS - 1)) + (1 << (LAYER_ENTITIES - 1))
const MASK_WALLS: int = (1 << (LAYER_PLAYER - 1)) + (1 << (LAYER_ENTITIES - 1))
const MASK_OBJECTS: int = (1 << (LAYER_PLAYER - 1))
const MASK_PUZZLE_OBJECTS: int = (1 << (LAYER_PLAYER - 1))

static func setup_player_collision(player: CharacterBody3D) -> void:
	"""Setup collision for player character"""
	player.collision_layer = LAYER_PLAYER
	player.collision_mask = MASK_PLAYER

static func setup_entity_collision(entity: CharacterBody3D) -> void:
	"""Setup collision for enemy entities"""
	entity.collision_layer = LAYER_ENTITIES
	entity.collision_mask = MASK_ENTITIES

static func setup_wall_collision(wall: StaticBody3D) -> void:
	"""Setup collision for walls and barriers"""
	wall.collision_layer = LAYER_WALLS
	wall.collision_mask = MASK_WALLS

static func setup_item_collision(item: RigidBody3D) -> void:
	"""Setup collision for collectible items"""
	item.collision_layer = LAYER_OBJECTS
	item.collision_mask = MASK_OBJECTS

static func setup_puzzle_collision(puzzle_object: StaticBody3D) -> void:
	"""Setup collision for puzzle interaction objects"""
	puzzle_object.collision_layer = LAYER_PUZZLE_OBJECTS
	puzzle_object.collision_mask = MASK_PUZZLE_OBJECTS

static func setup_pickup_area(area: Area3D) -> void:
	"""Setup Area3D for item pickup detection"""
	area.collision_layer = 0 # Areas don't need to be on a layer
	area.collision_mask = 1 << (LAYER_PLAYER - 1) # Only detect player

static func setup_interaction_raycast(query: PhysicsRayQueryParameters3D) -> void:
	"""Setup raycast for player interaction"""
	# Layer 4 in editor = bit 3 = value 8
	query.collision_mask = 8

static func setup_visibility_raycast(query: PhysicsRayQueryParameters3D) -> void:
	"""Setup raycast for line-of-sight checks"""
	query.collision_mask = 1 << (LAYER_WALLS - 1) # Only walls block visibility

static func get_layer_name(layer: int) -> String:
	"""Get human-readable name for collision layer"""
	match layer:
		LAYER_PLAYER: return "Player"
		LAYER_ENTITIES: return "Entities"
		LAYER_WALLS: return "Walls"
		LAYER_OBJECTS: return "Objects"
		LAYER_PUZZLE_OBJECTS: return "Puzzle Objects"
		_: return "Unknown (%d)" % layer

static func debug_print_collision_setup() -> void:
	"""Print debug info about collision layer configuration"""
