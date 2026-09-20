extends SceneTree

const TextFactory = preload("res://games/pacman/b4/pacman_text_factory.gd")

func _initialize() -> void:
	var texts := _json("res://games/pacman/b4/TEXT_CATALOG.json")
	var sounds := _json("res://games/pacman/b4/SOUND_CATALOG.json")
	if (texts.get("texts", []) as Array).size() != 27:
		_fail("expected 27 text definitions")
		return
	var fonts: Array = texts.get("fonts", [])
	if fonts.size() != 3:
		_fail("expected three font definitions")
		return
	var imported := 0
	var fallback_ok := false
	for font in fonts:
		var path := str(font.get("godot_resource", ""))
		if not path.is_empty():
			if load(path) as Font == null:
				_fail("font failed import: " + path)
				return
			imported += 1
		elif int(font.get("character_id", -1)) == 49 and int(font.get("glyph_count", -1)) == 0:
			fallback_ok = true
	if imported != 2 or not fallback_ok:
		_fail("font accounting/fallback mismatch")
		return

	var factory := TextFactory.new()
	var score := factory.create_label(84, "0")
	if score.text != "0" or factory.font_for_id(21) == null:
		_fail("score text field/font 21 reconstruction failed")
		return
	if factory.font_for_id(49) != ThemeDB.fallback_font:
		_fail("Arial zero-glyph fallback is not scoped to fallback font")
		return

	var entries: Array = sounds.get("sounds", [])
	if entries.size() != 13 or (sounds.get("stream_files", []) as Array).size() != 1:
		_fail("expected 13 discrete sounds + 1 stream")
		return
	for sound in entries:
		if load(str(sound["godot_resource"])) as AudioStream == null:
			_fail("sound failed import: %s" % sound["godot_resource"])
			return
	var stream: Dictionary = (sounds["stream_files"] as Array)[0]
	if load(str(stream["godot_resource"])) as AudioStream == null:
		_fail("stream wav failed import")
		return

	if not _has_label_trigger(entries, 88, "Chomp1") or not _has_label_trigger(entries, 89, "Chomp2"):
		_fail("chomp sound label mapping missing")
		return
	if not _has_label_trigger(entries, 90, "EatGhost") or not _has_label_trigger(entries, 91, "EatFruit"):
		_fail("eat sound label mapping missing")
		return
	if not _has_preceding_label(entries, 85, "NewGame") or not _has_preceding_label(entries, 86, "Killed"):
		_fail("intro/killed timeline sound mapping missing")
		return

	print("[B4_TEXT_AUDIO] PASS texts=27 fonts=2+ArialFallback sounds=13+1stream labels=Chomp1,Chomp2,EatGhost,EatFruit,NewGame,Killed")
	quit(0)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _entry(entries: Array, id: int) -> Dictionary:
	for item in entries:
		if int(item.get("character_id", -1)) == id:
			return item
	return {}


func _has_label_trigger(entries: Array, id: int, label: String) -> bool:
	for trig in (_entry(entries, id).get("timeline_triggers", []) as Array):
		if label in (trig.get("frame_labels", []) as Array):
			return true
	return false


func _has_preceding_label(entries: Array, id: int, label: String) -> bool:
	for trig in (_entry(entries, id).get("timeline_triggers", []) as Array):
		if str(trig.get("nearest_preceding_label", "")) == label:
			return true
	return false


func _fail(message: String) -> void:
	push_error("[B4_TEXT_AUDIO] FAIL: " + message)
	quit(1)
