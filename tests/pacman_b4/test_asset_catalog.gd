extends SceneTree

const Catalog = preload("res://games/pacman/runtime/b4_asset_catalog.gd")


func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_map():
		_fail("asset map failed to load")
		return
	if catalog.native_stage() != Vector2i(360, 420):
		_fail("native stage mismatch: %s" % catalog.native_stage())
		return

	if catalog.shape_ids().size() != 36:
		_fail("expected 36 shapes")
		return
	for sid in catalog.shape_ids():
		if catalog.shape_texture(int(sid)) == null:
			_fail("shape %s failed to import as Texture2D" % sid)
			return

	if catalog.sprite_ids().size() != 25:
		_fail("expected 25 sprite timelines")
		return
	var frame_total := 0
	for sid in catalog.sprite_ids():
		var item := catalog.sprite_data(int(sid))
		var frames: Array = item.get("frames", [])
		frame_total += frames.size()
		if frames.size() != int(item.get("frame_count", -1)):
			_fail("sprite %s frame count mismatch" % sid)
			return
		for frame_item in frames:
			var frame := int(frame_item.get("frame", -1))
			if catalog.sprite_frame_texture(int(sid), frame) == null:
				_fail("sprite %s frame %d failed texture import" % [sid, frame])
				return
	if frame_total != 359:
		_fail("expected 359 sprite SVG frames, got %d" % frame_total)
		return

	if catalog.sound_ids().size() != 14:
		_fail("expected 14 sound streams")
		return
	for sid in catalog.sound_ids():
		if catalog.sound_stream(int(sid)) == null:
			_fail("sound %s failed AudioStream import" % sid)
			return

	for fid in [21, 43]:
		var fd := catalog.font_data(fid)
		if bool(fd.get("fallback", true)):
			_fail("embedded font %d incorrectly marked fallback" % fid)
			return
		if catalog.font_resource(fid) == null:
			_fail("embedded font %d failed import" % fid)
			return
	var arial := catalog.font_data(49)
	if int(arial.get("glyph_count", -1)) != 0 or not bool(arial.get("fallback", false)):
		_fail("font 49 zero-glyph fallback policy missing")
		return
	if catalog.font_resource(49) == null:
		_fail("font 49 fallback unavailable")
		return

	if catalog.text_ids().size() != 27:
		_fail("expected 27 text definitions")
		return
	for tid in catalog.text_ids():
		var item := catalog.text_data(int(tid))
		if not str(item.get("raw_source", "")).begins_with("res://games/pacman/decompiled/texts/"):
			_fail("text %s missing raw traceability" % tid)
			return
		var label := catalog.create_text_label(int(tid))
		if label == null:
			_fail("text %s could not be reconstructed" % tid)
			return
		label.free()

	print("[B4_ASSETS] PASS shapes=36 sprites=25 sprite_frames=359 sounds=14 fonts=2+fallback49 texts=27")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B4_ASSETS] FAIL: " + message)
	quit(1)
