extends Node

signal registry_loaded(game_count: int)
signal registry_ready(game_count: int, pack_count: int)
signal pack_download_started(game_id: StringName, url: String)
signal pack_downloaded(game_id: StringName, url: String, byte_count: int)
signal pack_loaded(game_id: StringName, metadata: GameMetadata)
signal game_loaded(game_id: StringName, metadata: GameMetadata)
signal game_unloaded(game_id: StringName)
signal game_load_failed(game_id: StringName, reason: String)
signal score_changed(game_id: StringName, value: int)
signal state_saved(game_id: StringName, data: Variant)

const GameContextScript = preload("res://shared/modules/game_context.gd")
const DEFAULT_REGISTRY := "res://games/registry.json"
const PACK_USER_DIR := "user://gamezone_packs"

var _host: Control
var _metadata_by_id: Dictionary = {}
var _pack_entries: Array[Dictionary] = []
var _loaded_pack_ids: Dictionary = {}

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
	_pack_entries.clear()
	_loaded_pack_ids.clear()

	if not FileAccess.file_exists(path):
		push_error("[A4][GameManager] registry missing: " + path)
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[A4][GameManager] invalid registry JSON")
		return false

	var games: Array = parsed.get("games", [])
	for item_variant in games:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = item_variant
		var source := str(item.get("source", "tree"))
		if source == "pack":
			_pack_entries.append(item.duplicate(true))
			continue

		var metadata_path := str(item.get("metadata", ""))
		if metadata_path.is_empty():
			continue
		_register_metadata(metadata_path, &"")

	registry_loaded.emit(_metadata_by_id.size())
	print("[A4][GameManager] registry tree_games=", _metadata_by_id.size(), " pack_entries=", _pack_entries.size())
	return not _metadata_by_id.is_empty() or not _pack_entries.is_empty()


func load_registered_packs() -> bool:
	var all_ok := true
	for entry in _pack_entries:
		var ok: bool = await _load_pack_entry(entry)
		if not ok:
			all_ok = false

	registry_ready.emit(_metadata_by_id.size(), _loaded_pack_ids.size())
	print("[A4] REGISTRY_READY games=", _metadata_by_id.size(), " packs=", _loaded_pack_ids.size())
	return all_ok


func get_installed_games() -> Array:
	var result: Array = []
	for metadata in _metadata_by_id.values():
		result.append(metadata)
	result.sort_custom(func(a: GameMetadata, b: GameMetadata) -> bool: return a.title < b.title)
	return result


func get_loaded_pack_count() -> int:
	return _loaded_pack_ids.size()


func is_pack_loaded(game_id: StringName) -> bool:
	return _loaded_pack_ids.has(str(game_id))


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


func request_current_game_exit() -> bool:
	if _current_module == null:
		return false
	var game_id := current_game_id()
	print("[A3][GameManager] GAME_EXIT_REQUEST id=", game_id)
	_current_module.request_exit()
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


func _load_pack_entry(entry: Dictionary) -> bool:
	var game_id := StringName(str(entry.get("id", "")))
	var pack_key := str(game_id)
	var metadata_path := str(entry.get("metadata", ""))

	if game_id.is_empty() or metadata_path.is_empty():
		push_error("[A4] invalid pack entry: " + JSON.stringify(entry))
		return false

	if _loaded_pack_ids.has(pack_key):
		return true

	var pack_file := ""
	if OS.has_feature("web"):
		pack_file = await _download_pack_for_web(game_id, str(entry.get("pack_url", "")))
	else:
		var local_path := str(entry.get("local_path", ""))
		if local_path.is_empty():
			push_error("[A4] local_path missing for pack " + pack_key)
			return false
		pack_file = ProjectSettings.globalize_path(local_path)
		if not FileAccess.file_exists(pack_file):
			push_error("[A4] local pack missing id=%s path=%s" % [pack_key, pack_file])
			return false
		print("[A4] PACK_LOCAL_OK id=", game_id, " path=", local_path, " bytes=", FileAccess.get_file_as_bytes(pack_file).size())

	if pack_file.is_empty():
		return false

	var load_ok := ProjectSettings.load_resource_pack(pack_file, false)
	if not load_ok:
		push_error("[A4] load_resource_pack failed id=%s file=%s" % [pack_key, pack_file])
		return false

	var metadata := ResourceLoader.load(metadata_path) as GameMetadata
	if metadata == null or not metadata.is_valid():
		push_error("[A4] packed metadata invalid id=%s metadata=%s" % [pack_key, metadata_path])
		return false

	if not game_id.is_empty() and metadata.id != game_id:
		push_error("[A4] packed id mismatch registry=%s metadata=%s" % [game_id, metadata.id])
		return false

	_metadata_by_id[pack_key] = metadata
	_loaded_pack_ids[pack_key] = true
	print("[A4] PACK_LOAD_OK id=", game_id, " metadata=", metadata_path, " entry_scene=", metadata.entry_scene.resource_path)
	pack_loaded.emit(game_id, metadata)
	return true


func _download_pack_for_web(game_id: StringName, relative_url: String) -> String:
	if relative_url.is_empty():
		push_error("[A4] pack_url missing for " + str(game_id))
		return ""

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("[A4] cannot open user://")
		return ""
	var mkdir_error := dir.make_dir_recursive("gamezone_packs")
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("[A4] cannot create pack dir error=%d" % mkdir_error)
		return ""

	var resolved_url := _resolve_web_url(relative_url)
	var user_path := PACK_USER_DIR.path_join(str(game_id) + ".pck")
	var request := HTTPRequest.new()
	request.name = "PackDownload_" + str(game_id)
	request.accept_gzip = false
	add_child(request)

	print("[A4] PACK_HTTP_BEGIN id=", game_id, " url=", resolved_url, " target=", user_path)
	pack_download_started.emit(game_id, resolved_url)

	var request_error := request.request(resolved_url)
	if request_error != OK:
		request.queue_free()
		push_error("[A4] HTTP request failed id=%s error=%d" % [game_id, request_error])
		return ""

	var response: Array = await request.request_completed
	var result_code := int(response[0])
	var http_code := int(response[1])
	var body: PackedByteArray = response[3]
	request.queue_free()

	if result_code != HTTPRequest.RESULT_SUCCESS or http_code < 200 or http_code >= 300:
		push_error("[A4] PACK_HTTP_FAIL id=%s result=%d http=%d" % [game_id, result_code, http_code])
		return ""
	if body.is_empty():
		push_error("[A4] PACK_HTTP_FAIL id=%s http=%d empty_body=true" % [game_id, http_code])
		return ""

	var file := FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		push_error("[A4] cannot open virtual pack file for write id=%s error=%d" % [game_id, FileAccess.get_open_error()])
		return ""
	file.store_buffer(body)
	file.flush()
	file.close()

	var absolute_path := ProjectSettings.globalize_path(user_path)
	var persisted_size := FileAccess.get_file_as_bytes(user_path).size()
	if persisted_size != body.size():
		push_error("[A4] virtual pack write mismatch id=%s http_bytes=%d file_bytes=%d" % [game_id, body.size(), persisted_size])
		return ""

	print("[A4] PACK_HTTP_OK id=", game_id, " status=", http_code, " bytes=", body.size(), " file=", user_path)
	print("[A4] PACK_VFS_WRITE_OK id=", game_id, " bytes=", persisted_size, " file=", user_path)
	pack_downloaded.emit(game_id, resolved_url, body.size())
	return absolute_path


func _resolve_web_url(relative_url: String) -> String:
	if relative_url.begins_with("http://") or relative_url.begins_with("https://"):
		return relative_url

	var document = JavaScriptBridge.get_interface("document")
	if document == null:
		return relative_url

	var base_uri := str(document.baseURI)
	var slash := base_uri.rfind("/")
	if slash < 0:
		return relative_url
	return base_uri.substr(0, slash + 1) + relative_url.trim_prefix("./")


func _register_metadata(metadata_path: String, expected_id: StringName) -> bool:
	var metadata := ResourceLoader.load(metadata_path) as GameMetadata
	if metadata == null or not metadata.is_valid():
		push_error("[A4][GameManager] invalid metadata: " + metadata_path)
		return false
	if not expected_id.is_empty() and metadata.id != expected_id:
		push_error("[A4][GameManager] metadata id mismatch expected=%s actual=%s" % [expected_id, metadata.id])
		return false
	_metadata_by_id[str(metadata.id)] = metadata
	return true


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
	request_current_game_exit()


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
