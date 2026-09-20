extends SceneTree

const Catalog = preload("res://games/pacman/runtime/b4_asset_catalog.gd")
const TimelineVisual = preload("res://games/pacman/runtime/flash_timeline_visual.gd")
const GhostVisual = preload("res://games/pacman/runtime/b4_ghost_visual.gd")


func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_map():
		_fail("asset map failed")
		return

	var pacman := TimelineVisual.new()
	root.add_child(pacman)
	if not pacman.configure_from_catalog(catalog, 40):
		_fail("Pac-Man timeline failed")
		return
	if not pacman.gotoAndPlay(&"Die"):
		_fail("Die label not callable")
		return
	if pacman._currentframe != 6 or not pacman.current_texture_path().ends_with("/DefineSprite_40/6.svg"):
		_fail("Die label did not resolve to raw frame 6")
		return
	pacman.advance_frame()
	if pacman._currentframe != 7 or not pacman.current_texture_path().ends_with("/DefineSprite_40/7.svg"):
		_fail("Die timeline did not advance to frame 7")
		return

	var snd := catalog.sprite_data(92)
	var snd_labels: Dictionary = snd.get("labels", {})
	for pair in [["Chomp1", 2], ["Chomp2", 4], ["EatGhost", 6], ["EatFruit", 19]]:
		if int(snd_labels.get(pair[0], -1)) != int(pair[1]):
			_fail("Snd label mismatch: %s" % pair[0])
			return

	var ghost_tl := catalog.sprite_data(19)
	var depth_frame1: Array = ghost_tl.get("depth_events", {}).get("1", [])
	var depths := []
	for e in depth_frame1:
		if e.get("type") == "place":
			depths.append(int(e.get("depth", -1)))
	if depths != [1, 7]:
		_fail("Ghost frame1 depth reconstruction mismatch: %s" % depths)
		return
	if int(catalog.sprite_data(23).get("frame_count", 0)) != 41:
		_fail("Ghost K/GhKill clone timeline is not 41 frames")
		return

	var ghost := GhostVisual.new()
	root.add_child(ghost)
	if not ghost.configure(catalog, 14483456):
		_fail("ghost visual failed")
		return
	var normal := ghost.body_color()
	if absf(normal.r - 221.0/255.0) > 0.001 or normal.g > 0.001 or normal.b > 0.001:
		_fail("normal red ghost color mismatch: %s" % normal)
		return
	ghost.set_frightened()
	var blue := ghost.body_color()
	if blue.b < 0.99 or absf(blue.g - 51.0/255.0) > 0.01:
		_fail("frightened body color is not source 0x0033ff: %s" % blue)
		return
	if not ghost.eyes_texture_path().ends_with("/DefineSprite_18/1.svg"):
		_fail("frightened PPEyes did not switch to raw sprite 18")
		return

	print("[B4_TIMELINE] PASS Die=6->7 SndLabels=2/4/6/19 GhostDepths=1,7 KFrames=41 frightened=0x0033ff")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B4_TIMELINE] FAIL: " + message)
	quit(1)
