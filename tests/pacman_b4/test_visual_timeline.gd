extends SceneTree

const VisualTimeline = preload("res://games/pacman/runtime/flash_visual_timeline.gd")

func _initialize() -> void:
	var catalog := _json("res://games/pacman/b4/TIMELINE_CATALOG.json")
	var pac := _sprite(catalog.get("sprites", []), 40)
	if pac.is_empty():
		_fail("sprite 40 missing")
		return
	var clip := VisualTimeline.new()
	root.add_child(clip)
	clip.configure_visual(int(pac["declared_frame_count"]), pac["labels"], pac["frames"])
	if not clip.gotoAndPlay(&"Die"):
		_fail("gotoAndPlay(Die) failed")
		return
	if clip._currentframe != 6 or not clip.current_resource_path().ends_with("/6.svg"):
		_fail("Die label did not resolve to raw frame 6")
		return
	var before := clip.current_resource_path()
	clip.advance_frame()
	if clip._currentframe != 7 or clip.current_resource_path() == before:
		_fail("visual timeline did not advance from frame 6 to 7")
		return
	var origin := clip.current_origin()
	if origin == Vector2.ZERO:
		_fail("FFDec Flash origin was not preserved")
		return

	var ghost := _sprite(catalog.get("sprites", []), 19)
	var gh := VisualTimeline.new()
	root.add_child(gh)
	gh.configure_visual(int(ghost["declared_frame_count"]), ghost["labels"], ghost["frames"])
	if not gh.gotoAndStop(2) or not gh.current_resource_path().ends_with("/2.svg"):
		_fail("frightened ghost raw frame 2 is not addressable")
		return
	print("[B4_TIMELINE] PASS Die=6->7 origin=", origin, " frightened_frame=2")
	quit(0)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _sprite(items: Array, id: int) -> Dictionary:
	for item in items:
		if int(item.get("character_id", -1)) == id:
			return item
	return {}


func _fail(message: String) -> void:
	push_error("[B4_TIMELINE] FAIL: " + message)
	quit(1)
