extends Control

const InputMapBootstrapScript = preload("res://shared/input/input_map_bootstrap.gd")
const InputDeviceTrackerScript = preload("res://shared/input/input_device_tracker.gd")
const WebRuntimeScript = preload("res://shared/web/web_runtime.gd")
const TouchControlsScene = preload("res://shell/touch_controls.tscn")

const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"action_a",
	&"action_b",
	&"pause",
	&"back",
]

var _device_tracker: Node
var _web_runtime: Node
var _touch_controls: Control

var _status_label: Label
var _prompt_label: Label
var _actions_label: Label
var _event_label: Label
var _arena: Control
var _token: ColorRect
var _touch_preview_button: Button

var _event_counts := {
	&"action_a": 0,
	&"action_b": 0,
	&"pause": 0,
	&"back": 0,
}
var _status_accumulator := 0.0


func _ready() -> void:
	InputMapBootstrapScript.install_defaults()

	_device_tracker = InputDeviceTrackerScript.new()
	_device_tracker.name = "InputDeviceTracker"
	add_child(_device_tracker)

	_web_runtime = WebRuntimeScript.new()
	_web_runtime.name = "WebRuntime"
	add_child(_web_runtime)

	_build_ui()

	_touch_controls = TouchControlsScene.instantiate()
	add_child(_touch_controls)

	_device_tracker.input_method_changed.connect(_on_input_method_changed)
	_device_tracker.gamepads_changed.connect(_on_gamepads_changed)
	_web_runtime.audio_unlocked.connect(_refresh_status)
	_web_runtime.visibility_changed.connect(_on_visibility_changed)
	_web_runtime.fullscreen_changed.connect(_on_fullscreen_changed)

	_update_prompt(_device_tracker.active_method)
	_refresh_status()
	_update_actions_label()
	print("[A1] A1_BOOT_OK")


func _process(delta: float) -> void:
	_status_accumulator += delta
	if _status_accumulator >= 0.15:
		_status_accumulator = 0.0
		_refresh_status()

	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction.length_squared() > 0.0 and _arena.size.x > 0.0 and _arena.size.y > 0.0:
		_token.position += direction * 220.0 * delta
		var limit := _arena.size - _token.size
		_token.position.x = clampf(_token.position.x, 0.0, maxf(0.0, limit.x))
		_token.position.y = clampf(_token.position.y, 0.0, maxf(0.0, limit.y))

	for action in _event_counts:
		if Input.is_action_just_pressed(action):
			_event_counts[action] += 1
			_event_label.text = "Event counts — A: %d   B: %d   Pause: %d   Back: %d" % [
				_event_counts[&"action_a"],
				_event_counts[&"action_b"],
				_event_counts[&"pause"],
				_event_counts[&"back"],
			]

	_update_actions_label()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("111827")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 220)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "GameZone — A1 Web & Input Diagnostics"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "One InputMap • keyboard • touch • gamepad • single-threaded Web"
	subtitle.modulate = Color("93c5fd")
	column.add_child(subtitle)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 108)
	column.add_child(_status_label)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_prompt_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	column.add_child(button_row)

	var audio_button := Button.new()
	audio_button.text = "Enable / resume audio"
	audio_button.pressed.connect(_web_runtime.unlock_audio_from_user_gesture)
	button_row.add_child(audio_button)

	var fullscreen_button := Button.new()
	fullscreen_button.text = "Toggle fullscreen"
	fullscreen_button.pressed.connect(_web_runtime.toggle_fullscreen_from_user_gesture)
	button_row.add_child(fullscreen_button)

	_touch_preview_button = Button.new()
	_touch_preview_button.text = "Preview touch controls"
	_touch_preview_button.toggle_mode = true
	_touch_preview_button.toggled.connect(_on_touch_preview_toggled)
	button_row.add_child(_touch_preview_button)

	_actions_label = Label.new()
	_actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_actions_label)

	_event_label = Label.new()
	_event_label.text = "Event counts — A: 0   B: 0   Pause: 0   Back: 0"
	column.add_child(_event_label)

	var arena_panel := PanelContainer.new()
	arena_panel.custom_minimum_size = Vector2(0, 230)
	column.add_child(arena_panel)

	_arena = Control.new()
	_arena.clip_contents = true
	arena_panel.add_child(_arena)

	var arena_help := Label.new()
	arena_help.position = Vector2(10, 8)
	arena_help.text = "MOVE TEST: WASD / arrows • left stick / D-pad • on-screen D-pad"
	arena_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(arena_help)

	_token = ColorRect.new()
	_token.color = Color("22c55e")
	_token.size = Vector2(34, 34)
	_token.position = Vector2(40, 70)
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_token)

	var acceptance := Label.new()
	acceptance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acceptance.text = "A1 gate evidence: boot this exact Web build on desktop + physical phone + physical gamepad. Gamepad: press a controller button once so the browser exposes it, then verify hot-swap and all mapped actions."
	acceptance.modulate = Color("d1d5db")
	column.add_child(acceptance)


func _update_actions_label() -> void:
	var parts: Array[String] = []
	for action in ACTIONS:
		var marker := "●" if Input.is_action_pressed(action) else "○"
		parts.append("%s %s" % [marker, action])
	_actions_label.text = "Actions: " + "   ".join(parts)


func _refresh_status() -> void:
	if _status_label == null:
		return
	var gamepads: Array = _device_tracker.get_connected_gamepads()
	var pad_names: Array[String] = []
	for pad in gamepads:
		pad_names.append("%s (#%s)" % [pad.get("name", "Unknown"), pad.get("id", "?")])
	var gamepad_text := "none" if pad_names.is_empty() else ", ".join(pad_names)

	var version_info := Engine.get_version_info()
	var version_text := str(version_info.get("string", version_info.get("full_name", "unknown")))
	var runtime_text := "Web" if OS.has_feature("web") else OS.get_name()
	var viewport_size := get_viewport_rect().size
	_status_label.text = "Godot: %s\nRuntime: %s • single-thread preset • viewport: %dx%d\nTouch capability: %s • active input: %s • gamepads: %s\nAudio unlocked: %s • page hidden: %s • tree paused: %s" % [
		version_text,
		runtime_text,
		int(viewport_size.x),
		int(viewport_size.y),
		DisplayServer.is_touchscreen_available(),
		_device_tracker.active_method,
		gamepad_text,
		_web_runtime.is_audio_unlocked,
		_web_runtime.is_page_hidden,
		get_tree().paused,
	]


func _update_prompt(method: StringName) -> void:
	match method:
		&"gamepad":
			_prompt_label.text = "GAMEPAD: left stick / D-pad = move • A = action A • B = action B • Start = pause • Back = back"
		&"touch":
			_prompt_label.text = "TOUCH: on-screen D-pad = move • A/B • PAUSE • BACK"
		_:
			_prompt_label.text = "KEYBOARD: WASD / arrows = move • Space/Z = A • X/Shift = B • P = pause • Esc = back"


func _on_input_method_changed(method: StringName) -> void:
	_update_prompt(method)
	_refresh_status()


func _on_gamepads_changed(_device_ids: Array) -> void:
	_refresh_status()


func _on_visibility_changed(_hidden: bool) -> void:
	_refresh_status()


func _on_fullscreen_changed(_fullscreen: bool) -> void:
	_refresh_status()


func _on_touch_preview_toggled(enabled: bool) -> void:
	if _touch_controls != null:
		_touch_controls.set_preview_enabled(enabled)
