extends RefCounted
class_name GameSaveScope

var game_id: StringName
var _manager: Node


func _init(manager: Node, scoped_game_id: StringName) -> void:
	_manager = manager
	game_id = scoped_game_id


func save_slot(slot: StringName, data: Variant) -> Error:
	if _manager == null:
		return ERR_UNCONFIGURED
	return _manager.save_game(game_id, slot, data)


func load_slot(slot: StringName, fallback: Variant = null) -> Variant:
	if _manager == null:
		return fallback
	return _manager.load_game(game_id, slot, fallback)


func has_slot(slot: StringName) -> bool:
	return _manager != null and _manager.has_slot(game_id, slot)


func delete_slot(slot: StringName) -> Error:
	if _manager == null:
		return ERR_UNCONFIGURED
	return _manager.delete_slot(game_id, slot)
