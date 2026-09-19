extends Node

const GameSaveScopeScript = preload("res://shared/modules/game_save_scope.gd")
const SAVE_ROOT := "user://gamezone_saves"


func create_scope(game_id: StringName) -> GameSaveScope:
	_ensure_game_dir(game_id)
	return GameSaveScopeScript.new(self, game_id)


func save_game(game_id: StringName, slot: StringName, data: Variant) -> Error:
	var dir_error := _ensure_game_dir(game_id)
	if dir_error != OK:
		return dir_error

	var file := FileAccess.open(_slot_path(game_id, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(data))
	file.close()
	print("[A2][SaveManager] saved game=", game_id, " slot=", slot)
	return OK


func load_game(game_id: StringName, slot: StringName, fallback: Variant = null) -> Variant:
	var path := _slot_path(game_id, slot)
	if not FileAccess.file_exists(path):
		return fallback

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback

	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text)
	return fallback if parsed == null else parsed


func has_slot(game_id: StringName, slot: StringName) -> bool:
	return FileAccess.file_exists(_slot_path(game_id, slot))


func delete_slot(game_id: StringName, slot: StringName) -> Error:
	var path := _slot_path(game_id, slot)
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _ensure_game_dir(game_id: StringName) -> Error:
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return ERR_CANT_OPEN
	return user_dir.make_dir_recursive("gamezone_saves/" + _safe(str(game_id)))


func _slot_path(game_id: StringName, slot: StringName) -> String:
	return "%s/%s/%s.json" % [SAVE_ROOT, _safe(str(game_id)), _safe(str(slot))]


func _safe(value: String) -> String:
	return value.validate_filename().replace(" ", "_")
