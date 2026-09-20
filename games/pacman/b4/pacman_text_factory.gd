extends RefCounted
class_name PacmanB4TextFactory

const CATALOG_PATH := "res://games/pacman/b4/TEXT_CATALOG.json"

var _catalog: Dictionary = {}
var _fonts: Dictionary = {}
var _texts: Dictionary = {}


func _init() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_catalog = parsed
	for item in _catalog.get("fonts", []):
		_fonts[int(item.get("character_id", -1))] = item
	for item in _catalog.get("texts", []):
		_texts[int(item.get("character_id", -1))] = item


func create_label(text_id: int, initial_text: String = "") -> Label:
	var info: Dictionary = _texts.get(text_id, {})
	var label := Label.new()
	label.name = "Text_%d" % text_id
	label.text = initial_text if not initial_text.is_empty() else str(info.get("content", ""))
	var font_id_value: Variant = info.get("font_id", null)
	if font_id_value != null:
		var font := font_for_id(int(font_id_value))
		if font != null:
			label.add_theme_font_override("font", font)
	return label


func font_for_id(font_id: int) -> Font:
	var info: Dictionary = _fonts.get(font_id, {})
	var resource_path := str(info.get("godot_resource", ""))
	if not resource_path.is_empty():
		return load(resource_path) as Font
	if font_id == 49:
		return ThemeDB.fallback_font
	return null


func text_info(text_id: int) -> Dictionary:
	return (_texts.get(text_id, {}) as Dictionary).duplicate(true)
