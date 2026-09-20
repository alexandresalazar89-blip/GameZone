extends RefCounted
class_name PacmanB4AssetCatalog

const MAP_PATH := "res://games/pacman/B4_ASSET_MAP.json"

var data: Dictionary = {}
var _shape_by_id: Dictionary = {}
var _sprite_by_id: Dictionary = {}
var _sound_by_id: Dictionary = {}
var _font_by_id: Dictionary = {}
var _text_by_id: Dictionary = {}


func load_map(path: String = MAP_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("[B4][Catalog] missing asset map: " + path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[B4][Catalog] invalid asset map JSON")
		return false
	data = parsed
	_shape_by_id.clear()
	_sprite_by_id.clear()
	_sound_by_id.clear()
	_font_by_id.clear()
	_text_by_id.clear()
	for item in data.get("shapes", []):
		_shape_by_id[int(item.get("id", -1))] = item
	for item in data.get("sprites", []):
		_sprite_by_id[int(item.get("id", -1))] = item
	for item in data.get("sounds", []):
		_sound_by_id[int(item.get("id", -9999))] = item
	for item in data.get("fonts", []):
		_font_by_id[int(item.get("id", -1))] = item
	for item in data.get("texts", []):
		_text_by_id[int(item.get("id", -1))] = item
	return true


func native_stage() -> Vector2i:
	var v: Array = data.get("native_stage", [360, 420])
	return Vector2i(int(v[0]), int(v[1]))


func shape_ids() -> Array:
	var ids := _shape_by_id.keys()
	ids.sort()
	return ids


func sprite_ids() -> Array:
	var ids := _sprite_by_id.keys()
	ids.sort()
	return ids


func sound_ids() -> Array:
	var ids := _sound_by_id.keys()
	ids.sort()
	return ids


func text_ids() -> Array:
	var ids := _text_by_id.keys()
	ids.sort()
	return ids


func shape_texture(character_id: int) -> Texture2D:
	var item: Dictionary = _shape_by_id.get(character_id, {})
	if item.is_empty():
		return null
	return load(str(item.get("raw_source", ""))) as Texture2D


func sprite_data(character_id: int) -> Dictionary:
	return _sprite_by_id.get(character_id, {})


func sprite_frame_texture(character_id: int, frame: int) -> Texture2D:
	var item := sprite_data(character_id)
	if item.is_empty():
		return null
	for frame_item in item.get("frames", []):
		if int(frame_item.get("frame", -1)) == frame:
			return load(str(frame_item.get("raw_source", ""))) as Texture2D
	return null


func sprite_frame_path(character_id: int, frame: int) -> String:
	var item := sprite_data(character_id)
	for frame_item in item.get("frames", []):
		if int(frame_item.get("frame", -1)) == frame:
			return str(frame_item.get("raw_source", ""))
	return ""


func sound_stream(sound_id: int) -> AudioStream:
	var item: Dictionary = _sound_by_id.get(sound_id, {})
	if item.is_empty():
		return null
	return load(str(item.get("raw_source", ""))) as AudioStream


func sound_data(sound_id: int) -> Dictionary:
	return _sound_by_id.get(sound_id, {})


func font_resource(font_id: int) -> Font:
	var item: Dictionary = _font_by_id.get(font_id, {})
	if item.is_empty():
		return null
	if bool(item.get("fallback", false)):
		return ThemeDB.fallback_font
	return load(str(item.get("raw_source", ""))) as Font


func font_data(font_id: int) -> Dictionary:
	return _font_by_id.get(font_id, {})


func text_data(text_id: int) -> Dictionary:
	return _text_by_id.get(text_id, {})


func create_text_label(text_id: int) -> Label:
	var item := text_data(text_id)
	if item.is_empty():
		return null
	var label := Label.new()
	label.name = "Text_%d" % text_id
	label.text = str(item.get("text", ""))
	var font_id := item.get("font_id", null)
	if font_id != null:
		var font := font_resource(int(font_id))
		if font != null:
			label.add_theme_font_override("font", font)
	return label


func main_visual_texture() -> Texture2D:
	var item: Dictionary = data.get("main_visual", {})
	return load(str(item.get("raw_source", ""))) as Texture2D
