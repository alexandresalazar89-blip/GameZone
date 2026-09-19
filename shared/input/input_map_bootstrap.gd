extends RefCounted
class_name InputMapBootstrap

const DEADZONE := 0.35
const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"action_a",
	&"action_b",
	&"pause",
	&"back",
]


static func install_defaults() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		else:
			InputMap.action_set_deadzone(action, DEADZONE)

	_add_key(&"move_up", KEY_W)
	_add_key(&"move_up", KEY_UP)
	_add_key(&"move_down", KEY_S)
	_add_key(&"move_down", KEY_DOWN)
	_add_key(&"move_left", KEY_A)
	_add_key(&"move_left", KEY_LEFT)
	_add_key(&"move_right", KEY_D)
	_add_key(&"move_right", KEY_RIGHT)

	_add_key(&"action_a", KEY_SPACE)
	_add_key(&"action_a", KEY_Z)
	_add_key(&"action_b", KEY_X)
	_add_key(&"action_b", KEY_SHIFT)
	_add_key(&"pause", KEY_P)
	_add_key(&"back", KEY_ESCAPE)

	_add_joy_button(&"move_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button(&"move_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)

	_add_joy_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)

	_add_joy_button(&"action_a", JOY_BUTTON_A)
	_add_joy_button(&"action_b", JOY_BUTTON_B)
	_add_joy_button(&"pause", JOY_BUTTON_START)
	_add_joy_button(&"back", JOY_BUTTON_BACK)

	print("[A1] InputMap ready: ", ACTIONS)


static func _add_key(action: StringName, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_joy_button(action: StringName, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_joy_axis(action: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
