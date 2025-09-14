extends RefCounted
## ErrorHandler - Standardized error handling and validation utilities
## Provides consistent error reporting and validation patterns
## Follows KISS principle with simple, focused error handling methods

class_name ErrorHandler

# Error severity levels
enum Severity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

# Common error types
enum ErrorType {
	SYSTEM_NOT_FOUND,
	INVALID_PARAMETER,
	FILE_NOT_FOUND,
	INITIALIZATION_FAILED,
	VALIDATION_FAILED,
	RESOURCE_ERROR
}

# Static methods for consistent error handling
static func log_error(source: String, message: String, severity: Severity = Severity.ERROR) -> void:
	"""
	Log error with consistent formatting
	
	@param source: Name of the source (class/method)
	@param message: Error message
	@param severity: Error severity level
	"""
	var formatted_message = "%s: %s" % [source, message]
	
	match severity:
		Severity.INFO:
			pass
		Severity.WARNING:
			push_warning("[WARNING] %s" % formatted_message)
		Severity.ERROR:
			push_error("[ERROR] %s" % formatted_message)
		Severity.CRITICAL:
			push_error("[CRITICAL] %s" % formatted_message)

static func validate_node_reference(node: Node, node_name: String, source: String) -> bool:
	"""
	Validate node reference with standardized error reporting
	
	@param node: Node to validate
	@param node_name: Name of the node for error reporting
	@param source: Source requesting validation
	@return: True if node is valid
	"""
	if not node:
		log_error(source, "Required node '%s' not found" % node_name, Severity.ERROR)
		return false
	
	if not is_instance_valid(node):
		log_error(source, "Node '%s' is not valid (freed?)" % node_name, Severity.ERROR)
		return false
	
	return true

static func validate_parameter(value: Variant, param_name: String, expected_type: Variant.Type, source: String) -> bool:
	"""
	Validate parameter type with error reporting
	
	@param value: Value to validate
	@param param_name: Parameter name for error reporting
	@param expected_type: Expected type
	@param source: Source requesting validation
	@return: True if parameter is valid
	"""
	if typeof(value) != expected_type:
		log_error(source, "Parameter '%s' has invalid type. Expected %s, got %s" % [
			param_name, 
			type_string(expected_type),
			type_string(typeof(value))
		], Severity.ERROR)
		return false
	
	return true

static func validate_range(value: float, min_val: float, max_val: float, param_name: String, source: String) -> bool:
	"""
	Validate numeric range with error reporting
	
	@param value: Value to validate
	@param min_val: Minimum allowed value
	@param max_val: Maximum allowed value
	@param param_name: Parameter name for error reporting
	@param source: Source requesting validation
	@return: True if value is in range
	"""
	if value < min_val or value > max_val:
		log_error(source, "Parameter '%s' out of range. Expected [%f, %f], got %f" % [
			param_name, min_val, max_val, value
		], Severity.ERROR)
		return false
	
	return true

static func validate_file_exists(file_path: String, source: String) -> bool:
	"""
	Validate file exists with error reporting
	
	@param file_path: Path to file
	@param source: Source requesting validation
	@return: True if file exists
	"""
	if not FileAccess.file_exists(file_path):
		log_error(source, "File not found: %s" % file_path, Severity.ERROR)
		return false
	
	return true

static func validate_array_not_empty(array: Array, array_name: String, source: String) -> bool:
	"""
	Validate array is not empty
	
	@param array: Array to validate
	@param array_name: Array name for error reporting
	@param source: Source requesting validation
	@return: True if array is not empty
	"""
	if array.is_empty():
		log_error(source, "Array '%s' is empty" % array_name, Severity.ERROR)
		return false
	
	return true

static func validate_dictionary_has_key(dict: Dictionary, key: String, dict_name: String, source: String) -> bool:
	"""
	Validate dictionary contains required key
	
	@param dict: Dictionary to validate
	@param key: Required key
	@param dict_name: Dictionary name for error reporting
	@param source: Source requesting validation
	@return: True if key exists
	"""
	if not dict.has(key):
		log_error(source, "Dictionary '%s' missing required key: %s" % [dict_name, key], Severity.ERROR)
		return false
	
	return true

static func handle_system_initialization_error(system_name: String, source: String) -> void:
	"""
	Handle system initialization failure with standardized error
	
	@param system_name: Name of the system that failed
	@param source: Source attempting initialization
	"""
	log_error(source, "Failed to initialize system: %s" % system_name, Severity.CRITICAL)

static func handle_resource_load_error(resource_path: String, source: String) -> void:
	"""
	Handle resource loading failure
	
	@param resource_path: Path to resource that failed to load
	@param source: Source attempting to load resource
	"""
	log_error(source, "Failed to load resource: %s" % resource_path, Severity.ERROR)

static func create_error_result(error_type: ErrorType, message: String) -> Dictionary:
	"""
	Create standardized error result dictionary
	
	@param error_type: Type of error
	@param message: Error message
	@return: Error result dictionary
	"""
	return {
		"success": false,
		"error_type": error_type,
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	}

static func create_success_result(data: Variant = null) -> Dictionary:
	"""
	Create standardized success result dictionary
	
	@param data: Optional data to include
	@return: Success result dictionary
	"""
	var result = {
		"success": true,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if data != null:
		result["data"] = data
	
	return result

# Utility functions
static func get_error_type_name(error_type: ErrorType) -> String:
	"""Get human-readable error type name"""
	match error_type:
		ErrorType.SYSTEM_NOT_FOUND: return "System Not Found"
		ErrorType.INVALID_PARAMETER: return "Invalid Parameter"
		ErrorType.FILE_NOT_FOUND: return "File Not Found"
		ErrorType.INITIALIZATION_FAILED: return "Initialization Failed"
		ErrorType.VALIDATION_FAILED: return "Validation Failed"
		ErrorType.RESOURCE_ERROR: return "Resource Error"
		_: return "Unknown Error"

static func get_severity_name(severity: Severity) -> String:
	"""Get human-readable severity name"""
	match severity:
		Severity.INFO: return "Info"
		Severity.WARNING: return "Warning"
		Severity.ERROR: return "Error"
		Severity.CRITICAL: return "Critical"
		_: return "Unknown"
