extends SceneTree

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


func _initialize() -> void:
	var bootstrap = load("res://shared/input/input_map_bootstrap.gd")
	if bootstrap == null:
		_fail("input_map_bootstrap.gd failed to load")
		return

	bootstrap.install_defaults()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			_fail("missing InputMap action: " + str(action))
			return
		if InputMap.action_get_events(action).is_empty():
			_fail("InputMap action has no physical bindings: " + str(action))
			return

	var touch_scene := load("res://shell/touch_controls.tscn")
	if touch_scene == null:
		_fail("touch_controls.tscn failed to load")
		return

	var main_scene := load("res://shell/main.tscn")
	if main_scene == null:
		_fail("shell/main.tscn failed to load")
		return

	print("[A1_TEST] ACTIONS_OK count=", ACTIONS.size())
	print("[A1_TEST] TOUCH_SCENE_OK")
	print("[A1_TEST] MAIN_SCENE_OK")
	print("[A1_TEST] HEADLESS_SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("[A1_TEST] FAIL: " + message)
	quit(1)
