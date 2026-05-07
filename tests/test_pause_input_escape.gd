extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	_assert_escape_is_mapped_to_pause_action()

	if _failed:
		printerr("test_pause_input_escape: FAIL")
		quit(1)
		return

	print("test_pause_input_escape: PASS")
	quit(0)

func _assert_escape_is_mapped_to_pause_action() -> void:
	var has_escape_binding: bool = false
	var has_p_binding: bool = false
	for event in InputMap.action_get_events("pause"):
		if event is InputEventKey:
			var key_event: InputEventKey = event
			if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
				has_escape_binding = true
			if key_event.physical_keycode == KEY_P:
				has_p_binding = true
	if not has_escape_binding:
		_fail("Expected pause action to include Escape mapping")
	elif has_p_binding:
		_fail("Expected pause action to exclude P mapping")

func _fail(message: String) -> void:
	_failed = true
	printerr(message)
