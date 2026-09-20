extends SceneTree

func _initialize() -> void:
	var trace := _json("res://games/pacman/b4/ASSET_TRACEABILITY.json")
	var timelines := _json("res://games/pacman/b4/TIMELINE_CATALOG.json")
	if trace.is_empty() or timelines.is_empty():
		_fail("B4 catalogs missing")
		return

	var shapes: Array = trace.get("shapes", [])
	if shapes.size() != 36:
		_fail("expected 36 shapes, got %d" % shapes.size())
		return
	for item in shapes:
		var texture := load(str(item["godot_resource"])) as Texture2D
		if texture == null:
			_fail("shape did not import as Texture2D: %s" % item["godot_resource"])
			return

	var sprites: Array = timelines.get("sprites", [])
	if sprites.size() != 25:
		_fail("expected 25 sprite timelines, got %d" % sprites.size())
		return
	var total_frames := 0
	for sprite in sprites:
		var frames: Array = sprite.get("frames", [])
		var declared := int(sprite.get("declared_frame_count", 0))
		if frames.size() != declared:
			_fail("sprite %s frame mismatch" % sprite.get("character_id"))
			return
		if (sprite.get("depth_snapshots", []) as Array).size() != declared:
			_fail("sprite %s depth snapshot mismatch" % sprite.get("character_id"))
			return
		for frame in frames:
			if load(str(frame["godot_resource"])) as Texture2D == null:
				_fail("sprite frame failed import: %s" % frame["godot_resource"])
				return
		total_frames += frames.size()

	if total_frames != 359:
		_fail("expected 359 raw sprite SVG frames, got %d" % total_frames)
		return

	var pac := _sprite(sprites, 40)
	var snd := _sprite(sprites, 92)
	if int((pac["labels"] as Dictionary).get("Die", -1)) != 6:
		_fail("Pac-Man Die label is not frame 6")
		return
	if int((snd["labels"] as Dictionary).get("EatGhost", -1)) != 6:
		_fail("Snd EatGhost label is not frame 6")
		return

	print("[B4_ASSETS] PASS shapes=36 sprites=25 sprite_frames=359 depth_snapshots=all")
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
	push_error("[B4_ASSETS] FAIL: " + message)
	quit(1)
