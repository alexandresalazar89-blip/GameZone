extends Control

const InputMapBootstrapScript = preload("res://shared/input/input_map_bootstrap.gd")
const InputDeviceTrackerScript = preload("res://shared/input/input_device_tracker.gd")
const WebRuntimeScript = preload("res://shared/web/web_runtime.gd")
const TouchControlsScene = preload("res://shell/touch_controls.tscn")

var _device_tracker: Node
var _web_runtime: Node
var _host: Control
var _button_row: HBoxContainer
var _status: Label
var _metrics: Label
var _touch_controls: Control


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

	GameManager.game_loaded.connect(_on_game_loaded)
	GameManager.game_unloaded.connect(_on_game_unloaded)
	GameManager.game_load_failed.connect(_on_game_load_failed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_saved.connect(_on_state_saved)
	GameManager.set_host(_host)

	if not GameManager.load_registry():
		_status.text = "Registry failed to load."
		return

	_populate_games()
	print("[A2] A2_BOOT_OK games=", GameManager.get_installed_games().size())
	call_deferred("_launch_default")


func _process(_delta: float) -> void:
	var metrics := GameManager.get_render_metrics()
	var native: Vector2i = metrics.get("native_size", Vector2i.ZERO)
	var host_size: Vector2 = metrics.get("host_size", Vector2.ZERO)
	var display_size: Vector2 = metrics.get("display_size", Vector2.ZERO)
	_metrics.text = "active=%s | native=%dx%d | host=%dx%d | displayed=%dx%d | keep-aspect letterbox=%s | input=%s" % [
		str(GameManager.current_game_id()),
		native.x,
		native.y,
		int(host_size.x),
		int(host_size.y),
		int(display_size.x),
		int(display_size.y),
		metrics.get("letterbox", false),
		str(_device_tracker.active_method),
	]


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0b1020")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "GameZone — A2 Module Contract Harness"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Registry-driven modules • isolated SubViewport • native aspect preserved"
	subtitle.modulate = Color("93c5fd")
	column.add_child(subtitle)

	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 8)
	column.add_child(_button_row)

	var exit_button := Button.new()
	exit_button.text = "Exit current"
	exit_button.pressed.connect(GameManager.unload_current_game)
	_button_row.add_child(exit_button)

	_status = Label.new()
	_status.text = "Loading registry..."
	column.add_child(_status)

	_metrics = Label.new()
	_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_metrics)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(280, 300)
	column.add_child(panel)

	_host = Control.new()
	_host.name = "GameHost"
	_host.clip_contents = true
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_host)

	var help := Label.new()
	help.text = "Games use shared actions only. A=score+beep, B=save, Pause=count, Back=exit."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)


func _populate_games() -> void:
	for metadata in GameManager.get_installed_games():
		var button := Button.new()
		button.text = "Play " + metadata.title
		button.pressed.connect(_launch.bind(metadata.id))
		_button_row.add_child(button)


func _launch_default() -> void:
	var games := GameManager.get_installed_games()
	if not games.is_empty():
		_launch(games[0].id)


func _launch(game_id: StringName) -> void:
	GameManager.launch(game_id)


func _on_game_loaded(game_id: StringName, metadata: GameMetadata) -> void:
	_status.text = "Loaded %s v%s — %s" % [game_id, metadata.version, metadata.controls_text]


func _on_game_unloaded(game_id: StringName) -> void:
	_status.text = "Unloaded %s — choose another registered module." % game_id


func _on_game_load_failed(game_id: StringName, reason: String) -> void:
	_status.text = "LOAD FAILED %s: %s" % [game_id, reason]


func _on_score_changed(game_id: StringName, value: int) -> void:
	_status.text = "%s score_changed -> %d" % [game_id, value]


func _on_state_saved(game_id: StringName, data: Variant) -> void:
	_status.text = "%s state_saved -> %s" % [game_id, JSON.stringify(data)]
