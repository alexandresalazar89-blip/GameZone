extends Node
class_name InputDeviceTracker

signal input_method_changed(method: StringName)
signal gamepads_changed(device_ids: Array)

const KEYBOARD_MOUSE := &"keyboard_mouse"
const TOUCH := &"touch"
const GAMEPAD := &"gamepad"

var active_method: StringName = KEYBOARD_MOUSE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.is_touchscreen_available():
		active_method = TOUCH
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_emit_gamepads()
	print("[A1] Initial input method: ", active_method)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			_set_active_method(GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= 0.55:
			_set_active_method(GAMEPAD)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_set_active_method(TOUCH)
	elif event is InputEventScreenDrag:
		_set_active_method(TOUCH)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			_set_active_method(KEYBOARD_MOUSE)
	elif event is InputEventMouseButton:
		if event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			_set_active_method(KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.relative.length_squared() > 4.0:
			_set_active_method(KEYBOARD_MOUSE)


func get_connected_gamepads() -> Array:
	var result: Array = []
	for id in Input.get_connected_joypads():
		result.append({
			"id": id,
			"name": Input.get_joy_name(id),
			"info": Input.get_joy_info(id),
		})
	return result


func _set_active_method(method: StringName) -> void:
	if active_method == method:
		return
	active_method = method
	print("[A1] Input method -> ", active_method)
	input_method_changed.emit(active_method)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var name := Input.get_joy_name(device) if connected else "<disconnected>"
	print("[A1] Joypad connection: id=", device, " connected=", connected, " name=", name)
	_emit_gamepads()
	if connected:
		_set_active_method(GAMEPAD)
	elif Input.get_connected_joypads().is_empty() and active_method == GAMEPAD:
		_set_active_method(TOUCH if DisplayServer.is_touchscreen_available() else KEYBOARD_MOUSE)


func _emit_gamepads() -> void:
	gamepads_changed.emit(Input.get_connected_joypads())
