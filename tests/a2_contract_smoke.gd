extends SceneTree

const InputBootstrap = preload("res://shared/input/input_map_bootstrap.gd")
const AudioManagerScript = preload("res://shared/managers/audio_manager.gd")
const SaveManagerScript = preload("res://shared/managers/save_manager.gd")
const GameManagerScript = preload("res://shared/managers/game_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.install_defaults()

	var audio_manager := AudioManagerScript.new()
	audio_manager.name = "TestAudioManager"
	root.add_child(audio_manager)

	var save_manager := SaveManagerScript.new()
	save_manager.name = "TestSaveManager"
	root.add_child(save_manager)

	var game_manager := GameManagerScript.new()
	game_manager.name = "TestGameManager"
	root.add_child(game_manager)
	game_manager.configure_services(audio_manager, save_manager)

	var host := Control.new()
	host.name = "TestHost"
	host.size = Vector2(1000, 600)
	root.add_child(host)
	game_manager.set_host(host)

	if not game_manager.load_registry():
		_fail("registry failed")
		return

	var installed := game_manager.get_installed_games()
	if installed.size() != 2:
		_fail("expected 2 registered games, got %d" % installed.size())
		return
	print("[A2_TEST] REGISTRY_OK count=2")

	if not game_manager.launch(&"stub_wide"):
		_fail("stub_wide launch failed")
		return
	await process_frame

	if game_manager.current_game_id() != &"stub_wide":
		_fail("stub_wide not current")
		return
	if game_manager.current_viewport_size() != Vector2i(320, 180):
		_fail("stub_wide viewport changed: %s" % game_manager.current_viewport_size())
		return
	if game_manager.current_context() == null:
		_fail("stub_wide context missing")
		return
	if not audio_manager.has_game_scope(&"stub_wide"):
		_fail("stub_wide audio scope missing")
		return

	var wide_metrics := game_manager.get_render_metrics()
	var wide_display: Vector2 = wide_metrics.get("display_size", Vector2.ZERO)
	if absf(wide_display.x - 1000.0) > 0.1 or absf(wide_display.y - 562.5) > 0.1:
		_fail("wide keep-aspect size unexpected: %s" % wide_display)
		return

	var wide_save := {"owner": "stub_wide", "value": 11}
	if game_manager.current_context().saves.save_slot(&"a2_isolation_probe", wide_save) != OK:
		_fail("stub_wide save failed")
		return
	print("[A2_TEST] WIDE_VIEWPORT_OK 320x180 display=", wide_display)

	game_manager.unload_current_game()
	await process_frame
	if audio_manager.has_game_scope(&"stub_wide"):
		_fail("stub_wide audio scope leaked")
		return
	print("[A2_TEST] AUDIO_SCOPE_TEARDOWN_OK wide")

	if not game_manager.launch(&"stub_tall"):
		_fail("stub_tall launch failed")
		return
	await process_frame

	if game_manager.current_viewport_size() != Vector2i(240, 320):
		_fail("stub_tall viewport changed: %s" % game_manager.current_viewport_size())
		return

	var tall_metrics := game_manager.get_render_metrics()
	var tall_display: Vector2 = tall_metrics.get("display_size", Vector2.ZERO)
	if absf(tall_display.x - 450.0) > 0.1 or absf(tall_display.y - 600.0) > 0.1:
		_fail("tall keep-aspect size unexpected: %s" % tall_display)
		return

	var tall_save := {"owner": "stub_tall", "value": 22}
	if game_manager.current_context().saves.save_slot(&"a2_isolation_probe", tall_save) != OK:
		_fail("stub_tall save failed")
		return

	var loaded_wide = save_manager.load_game(&"stub_wide", &"a2_isolation_probe", {})
	var loaded_tall = save_manager.load_game(&"stub_tall", &"a2_isolation_probe", {})
	if loaded_wide.get("owner", "") != "stub_wide" or loaded_tall.get("owner", "") != "stub_tall":
		_fail("save namespace bleed: wide=%s tall=%s" % [loaded_wide, loaded_tall])
		return
	print("[A2_TEST] TALL_VIEWPORT_OK 240x320 display=", tall_display)
	print("[A2_TEST] SAVE_NAMESPACE_OK same-slot different-game")

	game_manager.current_context().exit()
	await process_frame
	if not game_manager.current_game_id().is_empty():
		_fail("context.exit did not unload game")
		return
	if audio_manager.active_game_count() != 0:
		_fail("audio scope leaked after context.exit")
		return

	save_manager.delete_slot(&"stub_wide", &"a2_isolation_probe")
	save_manager.delete_slot(&"stub_tall", &"a2_isolation_probe")
	print("[A2_TEST] CONTEXT_EXIT_OK")
	print("[A2_TEST] CONTRACT_SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("[A2_TEST] FAIL: " + message)
	quit(1)
