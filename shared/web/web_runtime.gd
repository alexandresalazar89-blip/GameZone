extends Node
class_name WebRuntime

signal audio_unlocked
signal visibility_changed(hidden: bool)
signal fullscreen_changed(fullscreen: bool)

var is_audio_unlocked := false
var is_page_hidden := false

var _paused_by_visibility := false
var _unlock_player: AudioStreamPlayer
var _document = null
var _visibility_callback = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_unlock_player()
	_install_web_visibility_hook()
	print("[A1] WebRuntime ready; web=", OS.has_feature("web"))


func _exit_tree() -> void:
	if OS.has_feature("web") and _document != null and _visibility_callback != null:
		_document.removeEventListener("visibilitychange", _visibility_callback)


func _input(event: InputEvent) -> void:
	if is_audio_unlocked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		unlock_audio_from_user_gesture()
	elif event is InputEventMouseButton and event.pressed:
		unlock_audio_from_user_gesture()
	elif event is InputEventScreenTouch and event.pressed:
		unlock_audio_from_user_gesture()
	elif event is InputEventJoypadButton and event.pressed:
		unlock_audio_from_user_gesture()


func unlock_audio_from_user_gesture() -> void:
	if is_audio_unlocked:
		return

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, false)

	_unlock_player.play()
	is_audio_unlocked = true
	print("[A1] AUDIO_UNLOCKED")
	audio_unlocked.emit()


func toggle_fullscreen_from_user_gesture() -> void:
	var current := DisplayServer.window_get_mode()
	var is_fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("[A1] Fullscreen -> false")
		fullscreen_changed.emit(false)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[A1] Fullscreen -> true")
		fullscreen_changed.emit(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_apply_visibility_pause(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_apply_visibility_pause(false)


func _create_unlock_player() -> void:
	_unlock_player = AudioStreamPlayer.new()
	_unlock_player.name = "AudioUnlockProbe"
	_unlock_player.volume_db = -80.0

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.stereo = false
	var bytes := PackedByteArray()
	for _i in range(64):
		bytes.append(128)
	stream.data = bytes
	_unlock_player.stream = stream
	add_child(_unlock_player)


func _install_web_visibility_hook() -> void:
	if not OS.has_feature("web"):
		return
	_document = JavaScriptBridge.get_interface("document")
	if _document == null:
		return
	_visibility_callback = JavaScriptBridge.create_callback(_on_web_visibility_change)
	_document.addEventListener("visibilitychange", _visibility_callback)
	is_page_hidden = bool(_document.hidden)
	print("[A1] Browser visibility hook installed; hidden=", is_page_hidden)


func _on_web_visibility_change(_args: Array) -> void:
	if _document == null:
		return
	_apply_visibility_pause(bool(_document.hidden))


func _apply_visibility_pause(hidden: bool) -> void:
	if is_page_hidden == hidden and hidden == _paused_by_visibility:
		return

	is_page_hidden = hidden
	if hidden:
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_visibility = true
	else:
		if _paused_by_visibility:
			get_tree().paused = false
		_paused_by_visibility = false

	print("[A1] Visibility hidden=", hidden, " tree_paused=", get_tree().paused)
	visibility_changed.emit(hidden)
