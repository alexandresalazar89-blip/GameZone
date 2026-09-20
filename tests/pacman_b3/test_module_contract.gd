extends SceneTree

const AudioManagerScript = preload("res://shared/managers/audio_manager.gd")
const SaveManagerScript = preload("res://shared/managers/save_manager.gd")
const GameManagerScript = preload("res://shared/managers/game_manager.gd")
const PacmanModuleScript = preload("res://games/pacman/pacman_game_module.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry_text := FileAccess.get_file_as_string("res://games/registry.json")
	if registry_text.contains("res://games/pacman/metadata.tres") or registry_text.contains('"id": "pacman"'):
		_fail("Pac-Man was added to permanent registry before B6")
		return

	var registry_path := "user://pacman_b3_registry.json"
	var file := FileAccess.open(registry_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": 2,
		"games": [{"source": "tree", "metadata": "res://games/pacman/metadata.tres"}]
	}))
	file.close()

	var audio_manager := AudioManagerScript.new()
	var save_manager := SaveManagerScript.new()
	var game_manager := GameManagerScript.new()
	root.add_child(audio_manager)
	root.add_child(save_manager)
	root.add_child(game_manager)
	game_manager.configure_services(audio_manager, save_manager)

	var host := Control.new()
	host.size = Vector2(1000, 600)
	root.add_child(host)
	game_manager.set_host(host)

	if not game_manager.load_registry(registry_path):
		_fail("temporary B3 registry failed")
		return
	var games := game_manager.get_installed_games()
	if games.size() != 1 or games[0].id != &"pacman":
		_fail("temporary registry did not expose only Pac-Man")
		return
	if not game_manager.launch(&"pacman"):
		_fail("PacmanGameModule launch through GameManager failed")
		return

	if game_manager.current_viewport_size() != Vector2i(360, 420):
		_fail("native SubViewport is not 360x420: %s" % game_manager.current_viewport_size())
		return
	var metrics := game_manager.get_render_metrics()
	var display: Vector2 = metrics["display_size"]
	if absf(display.x - 514.2857) > 0.1 or absf(display.y - 600.0) > 0.1:
		_fail("keep-aspect display unexpected: %s" % display)
		return
	if not bool(metrics["letterbox"]):
		_fail("expected pillarbox/keep-aspect in 1000x600 host")
		return

	var context: GameContext = game_manager.current_context()
	var module := context.render_viewport.get_child(0) as PacmanGameModule
	if module == null:
		_fail("entry scene root is not PacmanGameModule")
		return
	var before := module.flash_tick_count
	module._process(1.0)
	if module.flash_tick_count - before != 21:
		_fail("PacmanGameModule did not dispatch 21 fixed enterFrame ticks")
		return

	game_manager.unload_current_game()
	await process_frame
	if audio_manager.active_game_count() != 0:
		_fail("audio scope leaked after GameManager unload")
		return

	print("[B3_MODULE] PASS native=360x420 display=", display, " fixed_ticks=21 registry_permanent_unchanged=true")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_MODULE] FAIL: " + message)
	quit(1)
