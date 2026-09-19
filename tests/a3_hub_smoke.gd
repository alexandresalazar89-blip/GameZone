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

	await process_frame
	await process_frame

	if _hub.get_game_card_count() != 2:
		_fail("expected 2 registry cards, got %d" % _hub.get_game_card_count())
		return

	var ids: Array[StringName] = _hub.get_game_card_ids()
	if not ids.has(&"stub_wide") or not ids.has(&"stub_tall"):
		_fail("registry cards missing: %s" % [ids])
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

	await _pulse_action(&"move_right")

	var second: StringName = _hub.get_focused_game_id()
	if second.is_empty() or second == first:
		_fail("move_right did not change card focus: first=%s second=%s" % [first, second])
		return
	print("[A3_TEST] FOCUS_NAV_OK first=", first, " second=", second)

	await _pulse_action(&"action_a")

	if _game_manager.call("current_game_id") != second:
		_fail("action_a did not launch focused game")
		return
	if _hub.is_hub_visible() or not _hub.is_game_visible():
		_fail("game view not active after launch")
		return
	if not _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls not enabled in game state")
		return
	print("[A3_TEST] ACTION_A_LAUNCH_OK id=", second)

	await _pulse_action(&"back")

	var current_after_back: StringName = _game_manager.call("current_game_id")
	if not current_after_back.is_empty():
		_fail("back did not exit through shell")
		return
	if not _hub.is_hub_visible() or _hub.is_game_visible():
		_fail("hub not restored after back")
		return
	if int(_audio_manager.call("active_game_count")) != 0:
		_fail("audio scope leaked after hub return")
		return
	if _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls remained enabled on hub")
		return
	print("[A3_TEST] BACK_TO_HUB_OK id=", second)

	await _pulse_action(&"move_left")
	var returned_first: StringName = _hub.get_focused_game_id()
	if returned_first != first:
		_fail("focus did not navigate back to first card")
		return

	await _pulse_action(&"action_a")
	if _game_manager.call("current_game_id") != first:
		_fail("first game relaunch failed")
		return

	await _pulse_action(&"back")
	var current_final: StringName = _game_manager.call("current_game_id")
	if not current_final.is_empty() or int(_audio_manager.call("active_game_count")) != 0:
		_fail("second teardown was not clean")
		return

	print("[A3_TEST] RELAUNCH_TEARDOWN_OK id=", first)
	print("[A3_TEST] HUB_SMOKE_OK")
	quit(0)


func _pulse_action(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame

	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _fail(message: String) -> void:
	push_error("[A3_TEST] FAIL: " + message)
	quit(1)
