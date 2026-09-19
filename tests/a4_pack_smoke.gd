extends SceneTree

const InputBootstrap = preload("res://shared/input/input_map_bootstrap.gd")

var _game_manager: Node
var _audio_manager: Node
var _save_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.install_defaults()
	_game_manager = root.get_node_or_null("GameManager")
	_audio_manager = root.get_node_or_null("AudioManager")
	_save_manager = root.get_node_or_null("SaveManager")
	if _game_manager == null or _audio_manager == null or _save_manager == null:
		_fail("autoload managers not available")
		return

	var packed_metadata_path := "res://games/stub_packed/metadata.tres"
	if ResourceLoader.exists(packed_metadata_path):
		_fail("packed target exists before resource pack load; proof would be invalid")
		return
	print("[A4_TEST] PACK_TARGET_ABSENT_BEFORE_LOAD_OK")

	if not bool(_game_manager.call("load_registry")):
		_fail("registry failed")
		return

	var before: Array = _game_manager.call("get_installed_games")
	if before.size() != 2:
		_fail("expected only 2 in-tree games before loading packs, got %d" % before.size())
		return

	var packs_ok: bool = await _game_manager.call("load_registered_packs")
	if not packs_ok:
		_fail("runtime pack load failed")
		return
	if int(_game_manager.call("get_loaded_pack_count")) != 1:
		_fail("expected exactly one loaded pack")
		return
	if not bool(_game_manager.call("is_pack_loaded", &"stub_packed")):
		_fail("stub_packed not marked loaded")
		return
	if not ResourceLoader.exists(packed_metadata_path):
		_fail("packed target still absent after load_resource_pack")
		return

	var installed: Array = _game_manager.call("get_installed_games")
	if installed.size() != 3:
		_fail("expected 3 installed games after pack load, got %d" % installed.size())
		return
	print("[A4_TEST] PACK_RUNTIME_LOAD_OK games=3 packs=1")

	var host := Control.new()
	host.name = "A4Host"
	host.size = Vector2(1000, 600)
	root.add_child(host)
	_game_manager.call("set_host", host)

	if not bool(_game_manager.call("launch", &"stub_packed")):
		_fail("packed game launch failed")
		return
	await process_frame

	if _game_manager.call("current_viewport_size") != Vector2i(256, 192):
		_fail("packed viewport changed")
		return

	var metrics: Dictionary = _game_manager.call("get_render_metrics")
	var display_size: Vector2 = metrics.get("display_size", Vector2.ZERO)
	if absf(display_size.x - 800.0) > 0.1 or absf(display_size.y - 600.0) > 0.1:
		_fail("packed keep-aspect display unexpected: %s" % display_size)
		return
	if not bool(metrics.get("letterbox", false)):
		_fail("packed game expected letterbox on 1000x600 host")
		return
	print("[A4_TEST] PACK_KEEP_ASPECT_OK native=256x192 display=", display_size)

	var slot := &"a4_shared_slot"
	var context: GameContext = _game_manager.call("current_context")
	if context == null:
		_fail("packed context missing")
		return
	if context.saves.save_slot(slot, {"owner": "stub_packed", "value": 300}) != OK:
		_fail("packed save failed")
		return
	if int(_audio_manager.call("active_game_count")) != 1:
		_fail("packed audio scope missing")
		return

	_game_manager.call("request_current_game_exit")
	await process_frame
	if not StringName(_game_manager.call("current_game_id")).is_empty():
		_fail("packed exit did not unload")
		return
	if int(_audio_manager.call("active_game_count")) != 0:
		_fail("packed audio scope leaked")
		return
	print("[A4_TEST] PACK_EXIT_CLEAN_OK")

	if not bool(_game_manager.call("launch", &"stub_packed")):
		_fail("packed relaunch failed")
		return
	await process_frame
	_game_manager.call("request_current_game_exit")
	await process_frame
	if int(_audio_manager.call("active_game_count")) != 0:
		_fail("packed relaunch audio leaked")
		return
	print("[A4_TEST] PACK_RELAUNCH_OK")

	for game_id in [&"stub_tall", &"stub_wide"]:
		if not bool(_game_manager.call("launch", game_id)):
			_fail("tree game launch failed: " + str(game_id))
			return
		await process_frame
		var tree_context: GameContext = _game_manager.call("current_context")
		if tree_context == null:
			_fail("tree context missing: " + str(game_id))
			return
		if tree_context.saves.save_slot(slot, {"owner": str(game_id), "value": 100}) != OK:
			_fail("tree save failed: " + str(game_id))
			return
		_game_manager.call("request_current_game_exit")
		await process_frame
		if int(_audio_manager.call("active_game_count")) != 0:
			_fail("tree audio scope leaked: " + str(game_id))
			return

	var packed_saved: Variant = _save_manager.call("load_game", &"stub_packed", slot, {})
	var tall_saved: Variant = _save_manager.call("load_game", &"stub_tall", slot, {})
	var wide_saved: Variant = _save_manager.call("load_game", &"stub_wide", slot, {})
	if packed_saved.get("owner", "") != "stub_packed":
		_fail("packed save namespace bleed")
		return
	if tall_saved.get("owner", "") != "stub_tall":
		_fail("tall save namespace bleed")
		return
	if wide_saved.get("owner", "") != "stub_wide":
		_fail("wide save namespace bleed")
		return

	_save_manager.call("delete_slot", &"stub_packed", slot)
	_save_manager.call("delete_slot", &"stub_tall", slot)
	_save_manager.call("delete_slot", &"stub_wide", slot)

	print("[A4_TEST] SAVE_NAMESPACE_ALL_GAMES_OK")
	print("[A4_TEST] ALL_GAMES_CYCLE_OK")
	print("[A4_TEST] PLATFORM_ACCEPTANCE_SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("[A4_TEST] FAIL: " + message)
	quit(1)
