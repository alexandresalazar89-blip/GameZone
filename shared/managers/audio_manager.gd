extends Node

const GameAudioScopeScript = preload("res://shared/modules/game_audio_scope.gd")

var _game_bus_names: Dictionary = {}
var _game_roots: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func create_scope(game_id: StringName) -> GameAudioScope:
	begin_game(game_id)
	return GameAudioScopeScript.new(self, game_id)


func begin_game(game_id: StringName) -> void:
	var key := str(game_id)
	if _game_roots.has(key):
		return

	var bus_name := "Game_" + key.validate_node_name()
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
	_game_bus_names[key] = bus_name

	var root := Node.new()
	root.name = "Audio_" + key.validate_node_name()
	add_child(root)
	_game_roots[key] = root

	print("[A2][AudioManager] begin game=", key, " bus=", bus_name)


func play_game_stream(
	game_id: StringName,
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> AudioStreamPlayer:
	if stream == null:
		return null

	var key := str(game_id)
	if not _game_roots.has(key):
		begin_game(game_id)

	var root: Node = _game_roots[key]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = _game_bus_names[key]
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


func stop_game_audio(game_id: StringName) -> void:
	var key := str(game_id)
	var root: Node = _game_roots.get(key)
	if root == null:
		return

	for child in root.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()


func end_game(game_id: StringName) -> void:
	var key := str(game_id)
	stop_game_audio(game_id)

	var root: Node = _game_roots.get(key)
	if root != null:
		root.queue_free()
	_game_roots.erase(key)

	var bus_name: String = _game_bus_names.get(key, "")
	if not bus_name.is_empty():
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.remove_bus(bus_index)
	_game_bus_names.erase(key)

	print("[A2][AudioManager] end game=", key)


func active_game_count() -> int:
	return _game_roots.size()


func has_game_scope(game_id: StringName) -> bool:
	return _game_roots.has(str(game_id))
