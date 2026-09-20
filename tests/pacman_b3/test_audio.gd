extends SceneTree

const AudioManagerScript = preload("res://shared/managers/audio_manager.gd")
const FlashMovieClip = preload("res://games/pacman/runtime/flash_movie_clip.gd")
const FlashAudioClip = preload("res://games/pacman/runtime/flash_audio_clip.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := AudioManagerScript.new()
	manager.name = "B3AudioManager"
	root.add_child(manager)

	var game_id := &"pacman_b3_audio_test"
	var scope: GameAudioScope = manager.create_scope(game_id)
	var snd := FlashMovieClip.new()
	snd.configure_timeline(20, {"Chomp1": 2, "Chomp2": 4, "EatGhost": 6, "EatFruit": 19})
	root.add_child(snd)

	var stream := load("res://games/pacman/decompiled/sounds/90.mp3") as AudioStream
	if stream == null:
		_fail("extracted EatGhost sound 90.mp3 failed to load")
		return

	var audio := FlashAudioClip.new()
	audio.configure(snd, scope, {"EatGhost": stream})
	var player := audio.gotoAndPlay(&"EatGhost")
	if player == null:
		_fail("EatGhost trigger did not create AudioStreamPlayer")
		return
	if snd._currentframe != 6:
		_fail("EatGhost label did not land on source frame 6")
		return

	var expected_bus := "Game_" + str(game_id).validate_node_name()
	if player.bus != expected_bus or AudioServer.get_bus_index(expected_bus) < 0:
		_fail("sound was not routed to scoped game bus: %s" % player.bus)
		return
	if manager.active_game_count() != 1:
		_fail("audio scope not active after trigger")
		return

	manager.end_game(game_id)
	await process_frame
	await process_frame
	if manager.active_game_count() != 0:
		_fail("audio scope leaked after exit")
		return
	if AudioServer.get_bus_index(expected_bus) >= 0:
		_fail("game audio bus survived teardown")
		return
	if is_instance_valid(player) and player.playing:
		_fail("player remained audible after teardown")
		return

	print("[B3_AUDIO] PASS label=EatGhost asset=90.mp3 bus=", expected_bus, " teardown_silence=true")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_AUDIO] FAIL: " + message)
	quit(1)
