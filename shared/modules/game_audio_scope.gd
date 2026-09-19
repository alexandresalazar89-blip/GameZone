extends RefCounted
class_name GameAudioScope

var game_id: StringName
var _manager: Node


func _init(manager: Node, scoped_game_id: StringName) -> void:
	_manager = manager
	game_id = scoped_game_id


func play_stream(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if _manager == null:
		return null
	return _manager.play_game_stream(game_id, stream, volume_db, pitch_scale)


func stop_all() -> void:
	if _manager != null:
		_manager.stop_game_audio(game_id)
