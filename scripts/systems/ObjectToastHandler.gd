extends Node
## Object Toast Handler - Manages toast messages for interactable tile objects
## Follows the same pattern as NarrativeUI for consistency

const INTERACTIONS_PATH: String = "res://data/object_interactions.json"

var _interactions_data: Dictionary = {}
var _message_bus: Node
var _narrative_ui: Node

func _ready() -> void:
	"""Initialize the toast handler system"""
	name = "ObjectToastHandler"
	add_to_group("toast_systems")
	
	_load_interactions_data()
	
	# Connect to systems (deferred to ensure they exist)
	call_deferred("_connect_to_systems")

func _load_interactions_data() -> void:
	"""Load object interactions from JSON file"""
	if not FileAccess.file_exists(INTERACTIONS_PATH):
		push_error("ObjectToastHandler: object_interactions.json not found at %s" % INTERACTIONS_PATH)
		return
	
	var file: FileAccess = FileAccess.open(INTERACTIONS_PATH, FileAccess.READ)
	if not file:
		push_error("ObjectToastHandler: Failed to open object_interactions.json")
		return
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("ObjectToastHandler: Failed to parse object_interactions.json - %s" % json.get_error_message())
		return
	
	_interactions_data = json.data
	print("ObjectToastHandler: Loaded interactions data with %d entries" % _interactions_data.get("interactions", {}).size())

func _connect_to_systems() -> void:
	"""Connect to MessageBus (NarrativeUI will be found lazily when needed)"""
	print("ObjectToastHandler: _connect_to_systems called")
	
	_message_bus = get_node_or_null("/root/MessageBus")
	if not _message_bus:
		push_error("ObjectToastHandler: MessageBus not found")
		return
	
	print("ObjectToastHandler: MessageBus found")
	
	# Don't search for NarrativeUI yet - it won't exist until Game scene loads
	# We'll find it lazily when first needed
	
	# Connect to object interaction event
	_message_bus.connect_event("object_interacted", _on_object_interacted)
	print("ObjectToastHandler: Connected to MessageBus events")

func _on_object_interacted(object_id: String, interaction_count: int, object_node: Node3D) -> void:
	"""
	Handle object interaction event and display appropriate toast
	
	@param object_id: Unique identifier of the interacted object
	@param interaction_count: How many times this object has been interacted with
	@param object_node: The node that was interacted with
	"""
	print("ObjectToastHandler: Received object_interacted event for '%s' (count: %d)" % [object_id, interaction_count])
	
	if not _interactions_data.has("interactions"):
		push_error("ObjectToastHandler: No interactions data loaded")
		return
	
	var interactions: Dictionary = _interactions_data.interactions
	if not interactions.has(object_id):
		push_warning("ObjectToastHandler: No interaction data found for object_id '%s'" % object_id)
		return
	
	var interaction_data: Dictionary = interactions[object_id]
	var message_text: String = ""
	var duration: float = interaction_data.get("seconds", 4.0)
	
	# Handle both single message and multiple messages format
	if interaction_data.has("messages"):
		# Multiple messages - select randomly
		var messages: Array = interaction_data.messages
		if messages.is_empty():
			push_error("ObjectToastHandler: Empty messages array for object_id '%s'" % object_id)
			return
		
		# Randomly select a message
		var message_index: int = randi() % messages.size()
		message_text = messages[message_index]
	elif interaction_data.has("text"):
		# Single message
		message_text = interaction_data.text
	else:
		push_error("ObjectToastHandler: No 'text' or 'messages' field for object_id '%s'" % object_id)
		return
	
	# Queue the message through NarrativeUI
	_queue_toast(message_text, duration)

func _find_narrative_ui() -> bool:
	"""
	Lazily find NarrativeUI in the scene tree
	
	@return: True if NarrativeUI was found
	"""
	if _narrative_ui and is_instance_valid(_narrative_ui):
		return true
	
	# Try multiple search methods
	_narrative_ui = get_node_or_null("/root/Game/UI/NarrativeUI")
	
	if not _narrative_ui:
		# Search all nodes named NarrativeUI
		var narrative_nodes: Array = []
		for node in get_tree().get_nodes_in_group("ui_manager"):
			if node.name == "NarrativeUI":
				narrative_nodes.append(node)
		
		if narrative_nodes.is_empty():
			# Broad search - find any node called NarrativeUI
			var root: Window = get_tree().root
			narrative_nodes = _find_nodes_by_name(root, "NarrativeUI")
		
		if not narrative_nodes.is_empty():
			_narrative_ui = narrative_nodes[0]
	
	if _narrative_ui:
		print("ObjectToastHandler: Found NarrativeUI at: %s" % _narrative_ui.get_path())
		return true
	else:
		push_error("ObjectToastHandler: NarrativeUI not found in scene tree")
		return false

func _find_nodes_by_name(node: Node, search_name: String) -> Array:
	"""
	Recursively search for nodes by name
	
	@param node: Starting node to search from
	@param search_name: Name to search for
	@return: Array of matching nodes
	"""
	var results: Array = []
	
	if node.name == search_name:
		results.append(node)
	
	for child in node.get_children():
		results.append_array(_find_nodes_by_name(child, search_name))
	
	return results

func _queue_toast(text: String, duration: float) -> void:
	"""
	Queue a toast message through NarrativeUI
	
	@param text: The message text to display
	@param duration: How long to display the message
	"""
	print("ObjectToastHandler: _queue_toast called with text: '%s', duration: %.1f" % [text.substr(0, 50), duration])
	
	# Lazily find NarrativeUI if we don't have it yet
	if not _find_narrative_ui():
		push_error("ObjectToastHandler: Cannot queue toast - NarrativeUI not available")
		return
	
	print("ObjectToastHandler: NarrativeUI found, checking for _queue_message method...")
	
	if not _narrative_ui.has_method("_queue_message"):
		push_error("ObjectToastHandler: NarrativeUI does not have _queue_message method")
		print("ObjectToastHandler: Available methods: ", _narrative_ui.get_method_list().map(func(m): return m.name))
		return
	
	print("ObjectToastHandler: Calling _narrative_ui._queue_message()")
	print("ObjectToastHandler: NarrativeUI visible=%s, modulate.a=%.2f" % [_narrative_ui.visible, _narrative_ui.modulate.a])
	
	# Call NarrativeUI's queue method directly
	_narrative_ui._queue_message(text, duration)
	
	print("ObjectToastHandler: _queue_message call completed")

# Public API for debugging/testing

func reload_interactions_data() -> void:
	"""Reload interactions data from file (useful for testing)"""
	_load_interactions_data()

func get_interaction_data(object_id: String) -> Dictionary:
	"""
	Get interaction data for a specific object
	
	@param object_id: The object ID to look up
	@return: Dictionary with interaction data, or empty dict if not found
	"""
	if not _interactions_data.has("interactions"):
		return {}
	
	return _interactions_data.interactions.get(object_id, {})

func has_interaction_data(object_id: String) -> bool:
	"""
	Check if interaction data exists for an object
	
	@param object_id: The object ID to check
	@return: True if data exists
	"""
	if not _interactions_data.has("interactions"):
		return false
	
	return _interactions_data.interactions.has(object_id)
