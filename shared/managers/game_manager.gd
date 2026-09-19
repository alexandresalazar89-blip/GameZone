extends Node

signal registry_loaded(game_count: int)
signal game_loaded(game_id: StringName, metadata: GameMetadata)
signal game_unloaded(game_id: StringName)
signal game_load_failed(game_id: StringName, reason: String)
signal score_changed(game_id: StringName, value: int)
signal state_saved(game_id: StringName, data: Variant)

const GameContextScript = preload("res://shared/modules/game_context.gd")
const DEFAULT_REGISTRY := "res://games/registry.json"

var _host: Control
var _metadata_by_id: Dictionary = {}

var _current_metadata: GameMetadata
var _current_module: GameModule
var _current_context: GameContext
var _current_viewport: SubViewport
var _render_layer: Control
var _render_texture: TextureRect

var _audio_manager: Node
var _save_manager: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_manager = get_node_or_null("/root/AudioManager")
	_save_manager = get_node_or_null("/root/SaveManager")


func configure_services(audio_manager: Node, save_manager: Node) -> void:
	_audio_manager = audio_manager
	_save_manager = save_manager


func set_host(host: Control) -> void:
	if host == _host:
		return
	unload_current_game()
	_host = host


func load_registry(path: String = DEFAULT_REGISTRY) -> bool:
	_metadata_by_id.clear()
	if not FileAccess.file_exists(path):
		push_error("[A2][GameManager] registry missing: " + path)
		return false

	var parsed := JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[A2][GameManager] invalid registry JSON")
		return false

	var games: Array = parsed.get("games", [])
	for item in games:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var metadata_path: String = item.get("metadata", "")
		if metadata_path.is_empty():
			continue
		var metadata := ResourceLoader.load(metadata_path) as GameMetadata
		if metadata == null or not metadata.is_valid():
			push_error("[A2][GameManager] invalid metadata: " + metadata_path)
			continue
		_metadata_by_id[str(metadata.id)] = metadata

	registry_loaded.emit(_metadata_by_id.size())
	print("[A2][GameManager] registry games=", _metadata_by_id.size())
	return not _metadata_by_id.is_empty()


func get_installed_games() -> Array:
	var result: Array = []
	for metadata in _metadata_by_id.values():
		result.append(metadata)
	result.sort_custom(func(a: GameMetadata, b: GameMetadata) -> bool: return a.title < b.title)
	return result


func has_game(game_id: StringName) -> bool:
	return _metadata_by_id.has(str(game_id))


func launch(game_id: StringName) -> bool:
	var key := str(game_id)
	if _host == null:
		return _fail(game_id, "No shell host registered.")
	if _audio_manager == null or _save_manager == null:
		return _fail(game_id, "Shared services are not configured.")
	if not _metadata_by_id.has(key):
		return _fail(game_id, "Game is not registered: " + key)

	unload_current_game()

	var metadata: GameMetadata = _metadata_by_id[key]
	var instance := metadata.entry_scene.instantiate()
	if not instance is GameModule:
		instance.free()
		return _fail(game_id, "Entry scene root must extend GameModule.")

	_current_metadata = metadata
	_current_module = instance as GameModule
	_create_render_surface(metadata.native_size)
	_current_viewport.add_child(_current_module)

	var audio_scope: GameAudioScope = _audio_manager.create_scope(metadata.id)
	var save_scope: GameSaveScope = _save_manager.create_scope(metadata.id)
	_current_context = GameContextScript.new(
		metadata.id,
		_current_viewport,
		audio_scope,
		save_scope,
		Callable(self, "_on_context_exit")
	)

	_current_module.game_exited.connect(_on_module_exit)
	_current_module.score_changed.connect(_on_score_changed)
	_current_module.state_saved.connect(_on_state_saved)
	_current_module.start(_current_context)

	print("[A2][GameManager] launch id=", metadata.id, " native=", metadata.native_size)
	game_loaded.emit(metadata.id, metadata)
	return true


func pause_current_game() -> void:
	if _current_module != null:
		_current_module.pause()


func resume_current_game() -> void:
	if _current_module != null:
		_current_module.resume()


func unload_current_game() -> void:
	if _current_module == null and _current_viewport == null:
		return

	var old_id: StringName = _current_metadata.id if _current_metadata != null else StringName()

	if _current_module != null:
		_current_module.teardown()

	if _audio_manager != null and not old_id.is_empty():
		_audio_manager.end_game(old_id)

	if _current_viewport != null:
		_current_viewport.queue_free()
	if _render_layer != null:
		_render_layer.queue_free()

	_current_metadata = null
	_current_module = null
	_current_context = null
	_current_viewport = null
	_render_layer = null
	_render_texture = null

	print("[A2][GameManager] unload id=", old_id)
	if not old_id.is_empty():
		game_unloaded.emit(old_id)


func current_game_id() -> StringName:
	return _current_metadata.id if _current_metadata != null else StringName()


func current_context() -> GameContext:
	return _current_context


func current_native_size() -> Vector2i:
	return _current_metadata.native_size if _current_metadata != null else Vector2i.ZERO


func current_viewport_size() -> Vector2i:
	return _current_viewport.size if _current_viewport != null else Vector2i.ZERO


func get_render_metrics() -> Dictionary:
	var native := current_native_size()
	var host_size := _host.size if _host != null else Vector2.ZERO
	var display_size := Vector2.ZERO

	if native.x > 0 and native.y > 0 and host_size.x > 0.0 and host_size.y > 0.0:
		var scale_factor := minf(host_size.x / float(native.x), host_size.y / float(native.y))
		display_size = Vector2(native) * scale_factor

	return {
		"native_size": native,
		"host_size": host_size,
		"display_size": display_size,
		"letterbox": display_size != host_size,
	}


func _create_render_surface(native_size: Vector2i) -> void:
	_render_layer = Control.new()
	_render_layer.name = "GameRenderLayer"
	_render_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(_render_layer)

	var background := ColorRect.new()
	background.name = "LetterboxBackground"
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_layer.add_child(background)

	_current_viewport = SubViewport.new()
	_current_viewport.name = "GameViewport"
	_current_viewport.size = native_size
	_current_viewport.disable_3d = true
	_current_viewport.gui_disable_input = true
	_current_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_current_viewport)

	_render_texture = TextureRect.new()
	_render_texture.name = "GameTexture"
	_render_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_render_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_render_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_texture.texture = _current_viewport.get_texture()
	_render_layer.add_child(_render_texture)


func _on_context_exit() -> void:
	unload_current_game()


func _on_module_exit() -> void:
	unload_current_game()


func _on_score_changed(value: int) -> void:
	if _current_metadata != null:
		score_changed.emit(_current_metadata.id, value)


func _on_state_saved(data: Variant) -> void:
	if _current_metadata != null:
		state_saved.emit(_current_metadata.id, data)


func _fail(game_id: StringName, reason: String) -> bool:
	push_error("[A2][GameManager] " + reason)
	game_load_failed.emit(game_id, reason)
	return false
