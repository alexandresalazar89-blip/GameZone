extends SceneTree

var _hub: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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

	Input.action_press(&"move_right")
	await process_frame
	Input.action_release(&"move_right")
	await process_frame

	var second: StringName = _hub.get_focused_game_id()
	if second.is_empty() or second == first:
		_fail("move_right did not change card focus: first=%s second=%s" % [first, second])
		return
	print("[A3_TEST] FOCUS_NAV_OK first=", first, " second=", second)

	Input.action_press(&"action_a")
	await process_frame
	Input.action_release(&"action_a")
	await process_frame

	if GameManager.current_game_id() != second:
		_fail("action_a did not launch focused game")
		return
	if _hub.is_hub_visible() or not _hub.is_game_visible():
		_fail("game view not active after launch")
		return
	if not _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls not enabled in game state")
		return
	print("[A3_TEST] ACTION_A_LAUNCH_OK id=", second)

	Input.action_press(&"back")
	await process_frame
	Input.action_release(&"back")
	await process_frame

	if not GameManager.current_game_id().is_empty():
		_fail("back did not exit through shell")
		return
	if not _hub.is_hub_visible() or _hub.is_game_visible():
		_fail("hub not restored after back")
		return
	if AudioManager.active_game_count() != 0:
		_fail("audio scope leaked after hub return")
		return
	if _hub.touch_gameplay_enabled():
		_fail("touch gameplay controls remained enabled on hub")
		return
	print("[A3_TEST] BACK_TO_HUB_OK id=", second)

	Input.action_press(&"move_left")
	await process_frame
	Input.action_release(&"move_left")
	await process_frame
	var returned_first: StringName = _hub.get_focused_game_id()
	if returned_first != first:
		_fail("focus did not navigate back to first card")
		return

	Input.action_press(&"action_a")
	await process_frame
	Input.action_release(&"action_a")
	await process_frame
	if GameManager.current_game_id() != first:
		_fail("first game relaunch failed")
		return

	Input.action_press(&"back")
	await process_frame
	Input.action_release(&"back")
	await process_frame
	if not GameManager.current_game_id().is_empty() or AudioManager.active_game_count() != 0:
		_fail("second teardown was not clean")
		return

	print("[A3_TEST] RELAUNCH_TEARDOWN_OK id=", first)
	print("[A3_TEST] HUB_SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("[A3_TEST] FAIL: " + message)
	quit(1)
