extends Control
class_name TouchControls

var _bindings := {
	"Up": &"move_up",
	"Down": &"move_down",
	"Left": &"move_left",
	"Right": &"move_right",
	"ActionA": &"action_a",
	"ActionB": &"action_b",
	"Pause": &"pause",
	"Back": &"back",
}
var _pressed_actions: Dictionary = {}
var _default_touch_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_touch_visible = DisplayServer.is_touchscreen_available()
	visible = _default_touch_visible

	for node_name in _bindings:
		var button := find_child(node_name, true, false) as Button
		if button == null:
			push_error("[A1] Missing touch button: " + node_name)
			continue
		button.focus_mode = Control.FOCUS_NONE
		var action: StringName = _bindings[node_name]
		button.button_down.connect(_press_action.bind(action))
		button.button_up.connect(_release_action.bind(action))

	print("[A1] Touch controls available=", _default_touch_visible)


func set_preview_enabled(enabled: bool) -> void:
	visible = _default_touch_visible or enabled
	if not visible:
		release_all()


func release_all() -> void:
	for action in _pressed_actions.keys():
		Input.action_release(action)
	_pressed_actions.clear()


func _press_action(action: StringName) -> void:
	if _pressed_actions.has(action):
		return
	_pressed_actions[action] = true
	Input.action_press(action, 1.0)


func _release_action(action: StringName) -> void:
	if not _pressed_actions.has(action):
		return
	_pressed_actions.erase(action)
	Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
