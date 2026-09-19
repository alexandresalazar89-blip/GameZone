extends SceneTree

var _hub: Control
var _game_manager: Node
var _audio_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_manager = root.get_node_or_null("GameManager")
	_audio_manager = root.get_node_or_null("AudioManager")
	if _game_manager == null or _audio_manager == null:
		_fail("autoload managers not available")
		return

	var packed := load("res://shell/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene failed to load")
		return

	_hub = packed.instantiate() as Control
	if _hub == null:
		_fail("hub failed to instantiate")
		return
	root.add_child(_hub)

	for _i in range(120):
		await process_frame
		if _hub.get_game_card_count() >= 3:
			break

	if _hub.get_game_card_count() != 3:
		_fail("expected 3 registry cards after pack load, got %d" % _hub.get_game_card_count())
		return

	var ids: Array[StringName] = _hub.get_game_card_ids()
	for expected_id in [&"stub_wide", &"stub_tall", &"stub_packed"]:
		if not ids.has(expected_id):
			_fail("registry card missing: %s ids=%s" % [expected_id, ids])
			return

	if not _hub.is_hub_visible() or _hub.is_game_visible():
		_fail("hub/game visibility incorrect at boot")
		return
	if _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls enabled while on hub")
		return
	print("[A3_TEST] GRID_REGISTRY_OK ids=", ids)

	var first: StringName = _hub.get_focused_game_id()
	if first.is_empty():
		_fail("no initial Godot focus owner on game cards")
		return

	await _tap_key(KEY_RIGHT)

	var second: StringName = _hub.get_focused_game_id()
	if second.is_empty() or second == first:
		_fail("keyboard move_right did not change card focus: first=%s second=%s" % [first, second])
		return
	print("[A3_TEST] KEYBOARD_FOCUS_NAV_OK first=", first, " second=", second)

	await _tap_key(KEY_SPACE)

	if _game_manager.call("current_game_id") != second:
		_fail("keyboard action_a did not launch focused game")
		return
	if _hub.is_hub_visible() or not _hub.is_game_visible():
		_fail("game view not active after keyboard launch")
		return
	if not _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls not enabled in game state")
		return
	print("[A3_TEST] KEYBOARD_ACTION_A_LAUNCH_OK id=", second)

	await _tap_key(KEY_ESCAPE)

	var current_after_back: StringName = _game_manager.call("current_game_id")
	if not current_after_back.is_empty():
		_fail("keyboard back did not exit through shell")
		return
	if not _hub.is_hub_visible() or _hub.is_game_visible():
		_fail("hub not restored after keyboard back")
		return
	if int(_audio_manager.call("active_game_count")) != 0:
		_fail("audio scope leaked after keyboard hub return")
		return
	if _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls remained enabled on hub")
		return
	print("[A3_TEST] KEYBOARD_BACK_TO_HUB_OK id=", second)

	await _tap_joy(JOY_BUTTON_DPAD_LEFT)

	var returned_first: StringName = _hub.get_focused_game_id()
	if returned_first != first:
		_fail("gamepad D-pad left did not navigate back to first card")
		return
	print("[A3_TEST] GAMEPAD_FOCUS_NAV_EMULATION_OK id=", returned_first)

	await _tap_joy(JOY_BUTTON_A)

	if _game_manager.call("current_game_id") != first:
		_fail("gamepad A did not launch focused game")
		return

	await _tap_joy(JOY_BUTTON_BACK)

	var current_final: StringName = _game_manager.call("current_game_id")
	if not current_final.is_empty() or int(_audio_manager.call("active_game_count")) != 0:
		_fail("gamepad BACK teardown was not clean")
		return

	print("[A3_TEST] GAMEPAD_ACTIONS_EMULATION_OK id=", first)
	print("[A3_TEST] RELAUNCH_TEARDOWN_OK id=", first)
	print("[A3_TEST] HUB_SMOKE_OK")
	quit(0)


func _tap_key(keycode: int) -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame

	var released := InputEventKey.new()
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _tap_joy(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	pressed.pressure = 1.0
	Input.parse_input_event(pressed)
	await process_frame

	var released := InputEventJoypadButton.new()
	released.device = 0
	released.button_index = button_index
	released.pressed = false
	released.pressure = 0.0
	Input.parse_input_event(released)
	await process_frame


func _fail(message: String) -> void:
	push_error("[A3_TEST] FAIL: " + message)
	quit(1)
