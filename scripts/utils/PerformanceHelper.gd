extends RefCounted
## PerformanceHelper - Utilities for performance optimization
## Provides common performance patterns and optimizations
## Follows KISS principle with simple, focused optimization methods

class_name PerformanceHelper

# Object pooling for frequently created/destroyed objects
static var _object_pools: Dictionary = {}

# Cached calculations
static var _calculation_cache: Dictionary = {}
static var _max_cache_size: int = 1000

# Performance monitoring
static var _performance_metrics: Dictionary = {}

# Object pooling methods
static func get_pooled_object(type: String, create_func: Callable) -> Object:
	"""
	Get object from pool or create new one
	
	@param type: Type identifier for the pool
	@param create_func: Function to create new object if pool is empty
	@return: Object from pool or newly created
	"""
	if not _object_pools.has(type):
		_object_pools[type] = []
	
	var pool = _object_pools[type]
	
	if pool.size() > 0:
		return pool.pop_back()
	else:
		return create_func.call()

static func return_to_pool(type: String, object: Object) -> void:
	"""
	Return object to pool for reuse
	
	@param type: Type identifier for the pool
	@param object: Object to return to pool
	"""
	if not _object_pools.has(type):
		_object_pools[type] = []
	
	# Reset object if it has a reset method
	if object.has_method("reset"):
		object.reset()
	
	_object_pools[type].append(object)

static func clear_pool(type: String) -> void:
	"""
	Clear specific object pool
	
	@param type: Type identifier for the pool to clear
	"""
	if _object_pools.has(type):
		_object_pools[type].clear()

static func clear_all_pools() -> void:
	"""Clear all object pools"""
	_object_pools.clear()

# Caching methods
static func get_cached_calculation(key: String, calculate_func: Callable) -> Variant:
	"""
	Get cached calculation result or compute and cache it
	
	@param key: Cache key
	@param calculate_func: Function to compute value if not cached
	@return: Cached or computed value
	"""
	if _calculation_cache.has(key):
		return _calculation_cache[key]
	
	var result = calculate_func.call()
	
	# Manage cache size
	if _calculation_cache.size() >= _max_cache_size:
		_clear_oldest_cache_entries()
	
	_calculation_cache[key] = result
	return result

static func invalidate_cache(key: String) -> void:
	"""
	Invalidate specific cache entry
	
	@param key: Cache key to invalidate
	"""
	_calculation_cache.erase(key)

static func clear_cache() -> void:
	"""Clear all cached calculations"""
	_calculation_cache.clear()

static func _clear_oldest_cache_entries() -> void:
	"""Clear oldest cache entries to manage memory"""
	var keys = _calculation_cache.keys()
	var remove_count = keys.size() / 4  # Remove 25% of entries
	
	for i in range(remove_count):
		_calculation_cache.erase(keys[i])

# Performance monitoring
static func start_performance_timer(operation: String) -> void:
	"""
	Start timing an operation
	
	@param operation: Name of the operation to time
	"""
	_performance_metrics[operation] = {
		"start_time": Time.get_ticks_usec(),
		"count": _performance_metrics.get(operation, {}).get("count", 0) + 1
	}

static func end_performance_timer(operation: String) -> float:
	"""
	End timing an operation and return duration
	
	@param operation: Name of the operation to stop timing
	@return: Duration in milliseconds
	"""
	if not _performance_metrics.has(operation):
		push_warning("PerformanceHelper: Timer not found for operation: %s" % operation)
		return 0.0
	
	var end_time = Time.get_ticks_usec()
	var start_time = _performance_metrics[operation]["start_time"]
	var duration_ms = (end_time - start_time) / 1000.0
	
	# Update metrics
	var metrics = _performance_metrics[operation]
	metrics["last_duration"] = duration_ms
	metrics["total_duration"] = metrics.get("total_duration", 0.0) + duration_ms
	metrics["average_duration"] = metrics["total_duration"] / metrics["count"]
	
	return duration_ms

static func get_performance_metrics(operation: String) -> Dictionary:
	"""
	Get performance metrics for an operation
	
	@param operation: Name of the operation
	@return: Performance metrics dictionary
	"""
	return _performance_metrics.get(operation, {})

static func reset_performance_metrics() -> void:
	"""Reset all performance metrics"""
	_performance_metrics.clear()

# Memory optimization
static func optimize_array_memory(array: Array) -> void:
	"""
	Optimize array memory usage by removing null/invalid entries
	
	@param array: Array to optimize
	"""
	for i in range(array.size() - 1, -1, -1):
		var item = array[i]
		if item == null or (item is Object and not is_instance_valid(item)):
			array.remove_at(i)

static func optimize_dictionary_memory(dict: Dictionary) -> void:
	"""
	Optimize dictionary memory usage by removing null/invalid values
	
	@param dict: Dictionary to optimize
	"""
	var keys_to_remove: Array[Variant] = []
	
	for key in dict.keys():
		var value = dict[key]
		if value == null or (value is Object and not is_instance_valid(value)):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		dict.erase(key)

# Batch processing utilities
static func process_in_batches(items: Array, batch_size: int, process_func: Callable, delay_between_batches: float = 0.0) -> void:
	"""
	Process array items in batches to avoid frame drops
	
	@param items: Items to process
	@param batch_size: Number of items to process per batch
	@param process_func: Function to call for each item
	@param delay_between_batches: Delay between batches in seconds
	"""
	var batches = []
	
	# Split into batches
	for i in range(0, items.size(), batch_size):
		var batch = items.slice(i, min(i + batch_size, items.size()))
		batches.append(batch)
	
	# Process batches
	for batch in batches:
		for item in batch:
			process_func.call(item)
		
		if delay_between_batches > 0.0:
			await Engine.get_main_loop().create_timer(delay_between_batches).timeout

# Distance and visibility optimizations
static func is_within_screen_bounds(position: Vector3, camera: Camera3D, margin: float = 0.0) -> bool:
	"""
	Check if 3D position is within screen bounds (frustum culling)
	
	@param position: World position to check
	@param camera: Camera to check against
	@param margin: Additional margin around screen bounds
	@return: True if position is visible
	"""
	if not camera:
		return false
	
	var screen_pos = camera.unproject_position(position)
	var viewport_size = camera.get_viewport().get_visible_rect().size
	
	return screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and \
		   screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin

static func get_distance_squared(pos1: Vector3, pos2: Vector3) -> float:
	"""
	Get squared distance (faster than distance for comparisons)
	
	@param pos1: First position
	@param pos2: Second position
	@return: Squared distance
	"""
	var diff = pos1 - pos2
	return diff.dot(diff)

static func is_within_distance_squared(pos1: Vector3, pos2: Vector3, max_distance_squared: float) -> bool:
	"""
	Check if positions are within distance using squared distance (faster)
	
	@param pos1: First position
	@param pos2: Second position
	@param max_distance_squared: Maximum squared distance
	@return: True if within distance
	"""
	return get_distance_squared(pos1, pos2) <= max_distance_squared

# Update rate limiting
static func should_update_this_frame(object_id: int, update_interval: int) -> bool:
	"""
	Determine if object should update this frame based on staggered updates
	
	@param object_id: Unique identifier for the object
	@param update_interval: Update interval in frames
	@return: True if object should update this frame
	"""
	return (Engine.get_process_frames() + object_id) % update_interval == 0

# Resource management
static func preload_resources(resource_paths: Array[String]) -> Dictionary:
	"""
	Preload resources and return dictionary of loaded resources
	
	@param resource_paths: Array of resource paths to preload
	@return: Dictionary mapping paths to loaded resources
	"""
	var loaded_resources = {}
	
	for path in resource_paths:
		var resource = load(path)
		if resource:
			loaded_resources[path] = resource
		else:
			push_warning("PerformanceHelper: Failed to preload resource: %s" % path)
	
	return loaded_resources

# Utility for reducing string allocations
static var _string_builder: Array[String] = []

static func build_string(parts: Array[String]) -> String:
	"""
	Build string from parts without intermediate allocations
	
	@param parts: String parts to concatenate
	@return: Concatenated string
	"""
	_string_builder.clear()
	_string_builder.append_array(parts)
	return "".join(_string_builder)
