extends SceneTree

const AudioManagerScript = preload("res://shared/managers/audio_manager.gd")
const SaveManagerScript = preload("res://shared/managers/save_manager.gd")
const GameManagerScript = preload("res://shared/managers/game_manager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string("res://games/registry.json")
	if registry_text.contains('"id": "pacman"') or registry_text.contains("games/pacman/metadata.tres"):
		_fail("Pac-Man entered permanent registry before B6")
		return
	var p := "user://pacman_b4_registry.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version":2,"games":[{"source":"tree","metadata":"res://games/pacman/metadata.tres"}]}))
	f.close()

	var audio := AudioManagerScript.new()
	var saves := SaveManagerScript.new()
	var gm := GameManagerScript.new()
	root.add_child(audio); root.add_child(saves); root.add_child(gm)
	gm.configure_services(audio, saves)
	var host := Control.new(); host.size = Vector2(1000,600); root.add_child(host); gm.set_host(host)
	if not gm.load_registry(p) or not gm.launch(&"pacman"):
		_fail("temporary Pac-Man launch failed")
		return
	if gm.current_viewport_size() != Vector2i(360,420):
		_fail("SubViewport is not 360x420")
		return
	var module := gm.current_context().render_viewport.get_child(0)
	var visual := module.get_node_or_null("B4VisualScene")
	if visual == null:
		_fail("B4 visual scene is not running inside GameModule")
		return
	var positions: Dictionary = visual.character_flash_positions()
	if positions["Pacman"] != Vector2(186,294) or positions["Ghost1"] != Vector2(180,150):
		_fail("source start positions changed")
		return
	gm.unload_current_game()
	await process_frame
	print("[B4_MODULE] PASS native=360x420 keep_aspect=true visual_inside_module=true registry_permanent_unchanged=true")
	quit(0)

func _fail(message: String) -> void:
	push_error("[B4_MODULE] FAIL: " + message)
	quit(1)
