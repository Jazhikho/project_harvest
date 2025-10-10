@tool
extends MultiMeshInstance3D
class_name CornTileMultiMesh

# ----------------------------
# Exports
# ----------------------------

## How many stalks per square meter (e.g., 5 = 5 stalks/m²)
@export var stalks_per_meter: int = 1

## Tile dimensions in meters (width x depth)
@export var tile_size: Vector2 = Vector2(1.0, 1.0)

## Random scale variation (0.8 to 1.2 means ±20% size variation)
@export var min_uniform_scale: float = 0.8
@export var max_uniform_scale: float = 1.2

## Toggle this to regenerate in the editor
@export var rebuild_now: bool = false

## Seed for consistent random placement (0 = random seed each time)
@export var random_seed: int = 42

# ----------------------------
# Internal state
# ----------------------------

var _has_generated: bool = false

# ----------------------------
# Internal helpers (first)
# ----------------------------

## _calculate_instance_count
## Purpose: Calculate total stalks needed based on tile size and density.
## Returns: int count of instances.
func _calculate_instance_count() -> int:
	var area: float = tile_size.x * tile_size.y
	return int(area * float(stalks_per_meter))

## _populate_grid_with_jitter
## Purpose: Fill instance transforms using grid-based placement with random jitter for even spacing.
## @param mm: MultiMesh to modify.
## Returns: void.
func _populate_grid_with_jitter(mm: MultiMesh) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	
	var half_width: float = tile_size.x * 0.5
	var half_depth: float = tile_size.y * 0.5
	var count: int = mm.instance_count
	
	if count <= 0:
		return
	
	var grid_size: int = int(ceil(sqrt(float(count))))
	var cell_width: float = tile_size.x / float(grid_size)
	var cell_depth: float = tile_size.y / float(grid_size)
	var jitter_amount: float = 0.3
	
	var idx: int = 0
	for grid_z: int in range(grid_size):
		for grid_x: int in range(grid_size):
			if idx >= count:
				break
			
			var cell_center_x: float = (float(grid_x) + 0.5) * cell_width - half_width
			var cell_center_z: float = (float(grid_z) + 0.5) * cell_depth - half_depth
			
			var jitter_x: float = rng.randf_range(-cell_width * jitter_amount, cell_width * jitter_amount)
			var jitter_z: float = rng.randf_range(-cell_depth * jitter_amount, cell_depth * jitter_amount)
			
			var x: float = cell_center_x + jitter_x
			var z: float = cell_center_z + jitter_z
			var y: float = 0.0
			
			var instance_basis: Basis = Basis.IDENTITY
			var yaw: float = rng.randf_range(0.0, TAU)
			instance_basis = instance_basis.rotated(Vector3.UP, yaw)
			
			var s: float = lerp(min_uniform_scale, max_uniform_scale, rng.randf())
			instance_basis = instance_basis.scaled(Vector3(s, s, s))
			
			var xf: Transform3D = Transform3D(instance_basis, Vector3(x, y, z))
			mm.set_instance_transform(idx, xf)
			
			idx += 1
		
		if idx >= count:
			break

## _apply_custom_aabb
## Purpose: Expand culling so stalks stay visible (corn is ~3m tall).
## @param mm: MultiMesh to modify.
## Returns: void.
func _apply_custom_aabb(mm: MultiMesh) -> void:
	var half_width: float = tile_size.x * 0.5
	var half_depth: float = tile_size.y * 0.5
	var height: float = 3.5
	var size: Vector3 = Vector3(tile_size.x, height, tile_size.y)
	var aabb: AABB = AABB(Vector3(-half_width, 0.0, -half_depth), size)
	mm.custom_aabb = aabb

# ----------------------------
# Public API
# ----------------------------

## generate
## Purpose: Populate the MultiMesh per export settings using the mesh set in the Inspector.
## Returns: void.
func generate() -> void:
	if multimesh == null:
		push_error("%s: Assign a MultiMesh in the Inspector." % name)
		return
	
	if multimesh.mesh == null:
		push_error("%s: Assign a mesh to the MultiMesh in the Inspector." % name)
		return

	if stalks_per_meter <= 0:
		push_error("%s: 'stalks_per_meter' must be > 0." % name)
		return
	
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		push_error("%s: 'tile_size' must be positive." % name)
		return

	multimesh.instance_count = _calculate_instance_count()
	_populate_grid_with_jitter(multimesh)
	_apply_custom_aabb(multimesh)
	_has_generated = true

## _ready
## Purpose: Generate at runtime once. In editor, wait for manual toggle.
## Returns: void.
func _ready() -> void:
	if not Engine.is_editor_hint() and not _has_generated:
		generate()

## _process
## Purpose: Allow manual rebuilds in the editor by toggling 'rebuild_now'.
## @param delta: frame time.
## Returns: void.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() and rebuild_now:
		rebuild_now = false
		_has_generated = false
		generate()
