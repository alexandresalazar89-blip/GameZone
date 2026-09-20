extends SceneTree

const FlashMovieClip = preload("res://games/pacman/runtime/flash_movie_clip.gd")


func _initialize() -> void:
	var pacman := FlashMovieClip.new()
	pacman.configure_timeline(59, {"Die": 6})
	root.add_child(pacman)

	pacman._x = 123.5
	pacman._y = 87.25
	pacman._visible = false
	if pacman.position != Vector2(123.5, 87.25) or pacman.visible:
		_fail("_x/_y/_visible semantics failed")
		return

	pacman._visible = true
	if not pacman.gotoAndPlay(&"Die") or pacman._currentframe != 6 or not pacman.is_playing():
		_fail("gotoAndPlay(Die) failed")
		return
	if not pacman.gotoAndStop(1) or pacman._currentframe != 1 or pacman.is_playing():
		_fail("gotoAndStop(1) failed")
		return

	var snd := FlashMovieClip.new()
	snd.configure_timeline(20, {"Chomp1": 2, "Chomp2": 4, "EatGhost": 6, "EatFruit": 19})
	root.add_child(snd)
	if not snd.gotoAndPlay(&"EatGhost") or snd._currentframe != 6:
		_fail("real Snd label EatGhost did not resolve to frame 6")
		return

	var ghost_container := FlashMovieClip.new()
	root.add_child(ghost_container)
	var ghost1 := FlashMovieClip.new()
	var eyes1 := FlashMovieClip.new()
	ghost_container.attachMovie(1, ghost1)
	ghost_container.attachMovie("K1", eyes1)
	if ghost_container.child(1) != ghost1 or ghost_container.child("K1") != eyes1:
		_fail("Ghost[g] / Ghost[K+g] keyed child semantics failed")
		return

	print("[B3_MOVIECLIP] PASS x=", pacman._x, " y=", pacman._y, " Die=6 EatGhost=6 keyed_children=2")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_MOVIECLIP] FAIL: " + message)
	quit(1)
