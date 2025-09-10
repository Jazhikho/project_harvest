class_name CollisionHelper
## Collision Helper - Centralized collision layer management
## Ensures all collision layers are properly configured

# Collision layer constants (matching project.godot layer numbers)
const LAYER_PLAYER: int = 1          # Player character
const LAYER_ENTITIES: int = 2        # Enemies, effigies, NPCs  
const LAYER_WALLS: int = 3           # Maze walls, barriers (layer 3 in project.godot)
const LAYER_OBJECTS: int = 4         # Collectible items
const LAYER_PUZZLE_OBJECTS: int = 5  # Puzzle interaction objects

# Collision masks (bit flags for what each layer should collide with)
const MASK_PLAYER: int = (1 << (LAYER_ENTITIES-1)) + (1 << (LAYER_WALLS-1)) + (1 << (LAYER_OBJECTS-1)) + (1 << (LAYER_PUZZLE_OBJECTS-1))
const MASK_ENTITIES: int = (1 << (LAYER_PLAYER-1)) + (1 << (LAYER_WALLS-1))
const MASK_WALLS: int = (1 << (LAYER_PLAYER-1)) + (1 << (LAYER_ENTITIES-1))
const MASK_OBJECTS: int = (1 << (LAYER_PLAYER-1))
const MASK_PUZZLE_OBJECTS: int = (1 << (LAYER_PLAYER-1))

static func setup_player_collision(player: CharacterBody3D) -> void:
	"""Setup collision for player character"""
	player.collision_layer = LAYER_PLAYER
	player.collision_mask = MASK_PLAYER
	print("CollisionHelper: Configured player collision (Layer: %d, Mask: %d)" % [LAYER_PLAYER, MASK_PLAYER])

static func setup_entity_collision(entity: CharacterBody3D) -> void:
	"""Setup collision for enemy entities"""
	entity.collision_layer = LAYER_ENTITIES
	entity.collision_mask = MASK_ENTITIES
	print("CollisionHelper: Configured entity collision (Layer: %d, Mask: %d)" % [LAYER_ENTITIES, MASK_ENTITIES])

static func setup_wall_collision(wall: StaticBody3D) -> void:
	"""Setup collision for walls and barriers"""
	wall.collision_layer = LAYER_WALLS
	wall.collision_mask = MASK_WALLS
	print("CollisionHelper: Configured wall collision (Layer: %d, Mask: %d)" % [LAYER_WALLS, MASK_WALLS])

static func setup_item_collision(item: RigidBody3D) -> void:
	"""Setup collision for collectible items"""
	item.collision_layer = LAYER_OBJECTS
	item.collision_mask = MASK_OBJECTS
	print("CollisionHelper: Configured item collision (Layer: %d, Mask: %d)" % [LAYER_OBJECTS, MASK_OBJECTS])

static func setup_puzzle_collision(puzzle_object: StaticBody3D) -> void:
	"""Setup collision for puzzle interaction objects"""
	puzzle_object.collision_layer = LAYER_PUZZLE_OBJECTS
	puzzle_object.collision_mask = MASK_PUZZLE_OBJECTS
	print("CollisionHelper: Configured puzzle collision (Layer: %d, Mask: %d)" % [LAYER_PUZZLE_OBJECTS, MASK_PUZZLE_OBJECTS])

static func setup_pickup_area(area: Area3D) -> void:
	"""Setup Area3D for item pickup detection"""
	area.collision_layer = 0  # Areas don't need to be on a layer
	area.collision_mask = LAYER_PLAYER  # Only detect player
	print("CollisionHelper: Configured pickup area (Layer: 0, Mask: %d)" % LAYER_PLAYER)

static func setup_interaction_raycast(query: PhysicsRayQueryParameters3D) -> void:
	"""Setup raycast for player interaction"""
	query.collision_mask = LAYER_OBJECTS + LAYER_PUZZLE_OBJECTS

static func setup_visibility_raycast(query: PhysicsRayQueryParameters3D) -> void:
	"""Setup raycast for line-of-sight checks"""
	query.collision_mask = LAYER_WALLS  # Only walls block visibility
	print("CollisionHelper: Configured visibility raycast (Mask: %d)" % LAYER_WALLS)

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
	print("=== COLLISION LAYER DEBUG ===")
	print("Layer 1 (Player): %d" % LAYER_PLAYER)
	print("Layer 2 (Entities): %d" % LAYER_ENTITIES)
	print("Layer 3 (Walls): %d" % LAYER_WALLS)
	print("Layer 4 (Objects): %d" % LAYER_OBJECTS)
	print("Layer 5 (Puzzle Objects): %d" % LAYER_PUZZLE_OBJECTS)
	print("Player Mask: %d (collides with: Entities, Walls, Objects, Puzzles)" % MASK_PLAYER)
	print("Entity Mask: %d (collides with: Player, Walls)" % MASK_ENTITIES)
	print("==============================")
