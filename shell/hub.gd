extends Control

const InputMapBootstrapScript = preload("res://shared/input/input_map_bootstrap.gd")
const InputDeviceTrackerScript = preload("res://shared/input/input_device_tracker.gd")
const WebRuntimeScript = preload("res://shared/web/web_runtime.gd")
const TouchControlsScene = preload("res://shell/touch_controls.tscn")

var _device_tracker: Node
var _web_runtime: WebRuntime
var _touch_controls: TouchControls

var _hub_layer: Control
var _game_layer: Control
var _cards_grid: GridContainer
var _game_host: Control
var _settings_panel: Control
var _hub_status: Label
var _game_title: Label
var _game_status: Label
var _volume_label: Label

var _card_controls: Array[Control] = []
var _card_ids: Array[StringName] = []
var _last_card_id: StringName
var _grid_columns := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputMapBootstrapScript.install_defaults()

	_device_tracker = InputDeviceTrackerScript.new()
	_device_tracker.name = "InputDeviceTracker"
	add_child(_device_tracker)

	_web_runtime = WebRuntimeScript.new()
	_web_runtime.name = "WebRuntime"
	add_child(_web_runtime)

	_build_ui()

	_touch_controls = TouchControlsScene.instantiate() as TouchControls
	add_child(_touch_controls)
	_touch_controls.set_gameplay_enabled(false)

	GameManager.game_loaded.connect(_on_game_loaded)
	GameManager.game_unloaded.connect(_on_game_unloaded)
	GameManager.game_load_failed.connect(_on_game_load_failed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_saved.connect(_on_state_saved)
	GameManager.set_host(_game_host)

	if not GameManager.load_registry():
		_hub_status.text = "Could not load the game registry."
		return

	_populate_game_grid()
	resized.connect(_update_grid_columns)
	_update_grid_columns()
	call_deferred("_focus_first_card")

	print("[A3] A3_BOOT_OK games=", GameManager.get_installed_games().size(), " cards=", _card_controls.size())


func _process(_delta: float) -> void:
	if not GameManager.current_game_id().is_empty():
		if Input.is_action_just_pressed(&"back"):
			print("[A3] BACK_ACTION game=", GameManager.current_game_id())
			GameManager.request_current_game_exit()
		return

	if not _hub_layer.visible:
		return

	var focus_index := _focused_card_index()
	if Input.is_action_just_pressed(&"move_left") and focus_index >= 0:
		_move_card_focus(-1, 0, "move_left")
	elif Input.is_action_just_pressed(&"move_right") and focus_index >= 0:
		_move_card_focus(1, 0, "move_right")
	elif Input.is_action_just_pressed(&"move_up") and focus_index >= 0:
		_move_card_focus(0, -1, "move_up")
	elif Input.is_action_just_pressed(&"move_down") and focus_index >= 0:
		_move_card_focus(0, 1, "move_down")
	elif Input.is_action_just_pressed(&"action_a") and focus_index >= 0:
		_launch_game(_card_ids[focus_index])
	elif Input.is_action_just_pressed(&"back") and _settings_panel.visible:
		_settings_panel.hide()
		_focus_last_card("settings_back")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("07111f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_hub_layer = Control.new()
	_hub_layer.name = "HubLayer"
	_hub_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hub_layer)

	var hub_margin := MarginContainer.new()
	hub_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_margin.add_theme_constant_override("margin_left", 24)
	hub_margin.add_theme_constant_override("margin_top", 18)
	hub_margin.add_theme_constant_override("margin_right", 24)
	hub_margin.add_theme_constant_override("margin_bottom", 22)
	_hub_layer.add_child(hub_margin)

	var hub_column := VBoxContainer.new()
	hub_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_column.add_theme_constant_override("separation", 12)
	hub_margin.add_child(hub_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	hub_column.add_child(header)

	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_box)

	var title := Label.new()
	title.text = "GameZone"
	title.add_theme_font_size_override("font_size", 34)
	heading_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a game"
	subtitle.modulate = Color("93c5fd")
	subtitle.add_theme_font_size_override("font_size", 17)
	heading_box.add_child(subtitle)

	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(130, 48)
	settings_button.pressed.connect(_toggle_settings)
	header.add_child(settings_button)

	_settings_panel = _build_settings_panel()
	_settings_panel.hide()
	hub_column.add_child(_settings_panel)

	_hub_status = Label.new()
	_hub_status.text = "Loading games..."
	_hub_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub_column.add_child(_hub_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hub_column.add_child(scroll)

	_cards_grid = GridContainer.new()
	_cards_grid.name = "GameGrid"
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_grid.add_theme_constant_override("h_separation", 16)
	_cards_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_cards_grid)

	var hint := Label.new()
	hint.text = "Touch a card • Keyboard/gamepad: move + A • Esc/BACK returns to the hub"
	hint.modulate = Color("94a3b8")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub_column.add_child(hint)

	_game_layer = Control.new()
	_game_layer.name = "GameLayer"
	_game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_layer.hide()
	add_child(_game_layer)

	var game_column := VBoxContainer.new()
	game_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_column.add_theme_constant_override("separation", 0)
	_game_layer.add_child(game_column)

	var game_bar := HBoxContainer.new()
	game_bar.custom_minimum_size = Vector2(0, 58)
	game_bar.add_theme_constant_override("separation", 12)
	game_column.add_child(game_bar)

	var back_button := Button.new()
	back_button.text = "← Hub"
	back_button.custom_minimum_size = Vector2(120, 52)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(_request_game_exit)
	game_bar.add_child(back_button)

	_game_title = Label.new()
	_game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 20)
	game_bar.add_child(_game_title)

	_game_status = Label.new()
	_game_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_status.modulate = Color("94a3b8")
	game_bar.add_child(_game_status)

	var game_panel := PanelContainer.new()
	game_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_column.add_child(game_panel)

	_game_host = Control.new()
	_game_host.name = "GameHost"
	_game_host.clip_contents = true
	_game_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_panel.add_child(_game_host)


func _build_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var settings_title := Label.new()
	settings_title.text = "Settings"
	settings_title.add_theme_font_size_override("font_size", 20)
	column.add_child(settings_title)

	_volume_label = Label.new()
	_volume_label.text = "Master volume: 100%"
	column.add_child(_volume_label)

	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 100.0
	volume.step = 1.0
	volume.value = 100.0
	volume.custom_minimum_size = Vector2(240, 42)
	volume.value_changed.connect(_on_master_volume_changed)
	column.add_child(volume)

	var fullscreen := Button.new()
	fullscreen.text = "Toggle fullscreen"
	fullscreen.custom_minimum_size = Vector2(200, 44)
	fullscreen.pressed.connect(_toggle_fullscreen)
	column.add_child(fullscreen)

	var remap := Label.new()
	remap.text = "Input remapping: placeholder — BL-002"
	remap.modulate = Color("94a3b8")
	column.add_child(remap)

	return panel


func _populate_game_grid() -> void:
	for child in _cards_grid.get_children():
		child.queue_free()
	_card_controls.clear()
	_card_ids.clear()

	var games: Array = GameManager.get_installed_games()
	for metadata_variant in games:
		var metadata := metadata_variant as GameMetadata
		if metadata == null:
			continue
		var card := _create_game_card(metadata)
		_cards_grid.add_child(card)
		_card_controls.append(card)
		_card_ids.append(metadata.id)

	_hub_status.text = "%d games installed" % _card_controls.size()


func _create_game_card(metadata: GameMetadata) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "GameCard_" + str(metadata.id)
	card.custom_minimum_size = Vector2(260, 260)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_entered.connect(_on_card_focus_entered.bind(card, metadata.id))
	card.focus_exited.connect(_on_card_focus_exited.bind(card))
	card.gui_input.connect(_on_card_gui_input.bind(metadata.id, card))

	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c2f")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("26364f")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var thumb_frame := PanelContainer.new()
	thumb_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	thumb_frame.custom_minimum_size = Vector2(220, 132)
	thumb_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(thumb_frame)

	if metadata.thumbnail != null:
		var texture := TextureRect.new()
		texture.texture = metadata.thumbnail
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_frame.add_child(texture)
	else:
		var fallback := ColorRect.new()
		fallback.color = Color("18283f")
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_frame.add_child(fallback)

	var game_title := Label.new()
	game_title.text = metadata.title
	game_title.add_theme_font_size_override("font_size", 21)
	game_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(game_title)

	var ratio := Label.new()
	ratio.text = "%d × %d" % [metadata.native_size.x, metadata.native_size.y]
	ratio.modulate = Color("94a3b8")
	ratio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(ratio)

	var play := Button.new()
	play.text = "Play"
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(0, 44)
	play.pressed.connect(_launch_game.bind(metadata.id))
	column.add_child(play)

	return card


func _update_grid_columns() -> void:
	if _cards_grid == null:
		return
	var width := size.x
	var columns := 3
	if width < 650.0:
		columns = 1
	elif width < 1100.0:
		columns = 2
	columns = mini(columns, maxi(1, _card_controls.size()))
	if columns != _grid_columns:
		_grid_columns = columns
		_cards_grid.columns = columns
		print("[A3] GRID columns=", columns, " width=", int(width))


func _focused_card_index() -> int:
	var owner := get_viewport().gui_get_focus_owner()
	for index in range(_card_controls.size()):
		if _card_controls[index] == owner:
			return index
	return -1


func _move_card_focus(dx: int, dy: int, source: String) -> void:
	if _card_controls.is_empty():
		return
	var index := _focused_card_index()
	if index < 0:
		_focus_card_index(0, source)
		return

	var columns := maxi(1, _grid_columns)
	var row := index / columns
	var column := index % columns
	var target_row := row + dy
	var target_column := column + dx

	if dx != 0:
		var candidate := index + dx
		if candidate < 0:
			candidate = _card_controls.size() - 1
		elif candidate >= _card_controls.size():
			candidate = 0
		_focus_card_index(candidate, source)
		return

	var max_row := (_card_controls.size() - 1) / columns
	target_row = clampi(target_row, 0, max_row)
	var target := target_row * columns + target_column
	if target >= _card_controls.size():
		target = _card_controls.size() - 1
	if target < 0:
		target = 0
	_focus_card_index(target, source)


func _focus_card_index(index: int, source: String) -> void:
	if index < 0 or index >= _card_controls.size():
		return
	_card_controls[index].grab_focus()
	_last_card_id = _card_ids[index]
	print("[A3] FOCUS game=", _last_card_id, " index=", index, " via=", source)


func _focus_first_card() -> void:
	if not _card_controls.is_empty():
		_focus_card_index(0, "boot")


func _focus_last_card(source: String) -> void:
	var index := _card_ids.find(_last_card_id)
	if index < 0:
		index = 0
	_focus_card_index(index, source)


func _on_card_focus_entered(card: Control, game_id: StringName) -> void:
	card.modulate = Color("ffffff")
	_last_card_id = game_id


func _on_card_focus_exited(card: Control) -> void:
	card.modulate = Color("d9e3f0")


func _on_card_gui_input(event: InputEvent, game_id: StringName, card: Control) -> void:
	var activate := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		activate = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		activate = touch_event.pressed

	if activate and _hub_layer.visible and GameManager.current_game_id().is_empty():
		card.grab_focus()
		_last_card_id = game_id
		print("[A3] CARD_TOUCH game=", game_id)
		_launch_game(game_id)


func _launch_game(game_id: StringName) -> void:
	if not GameManager.current_game_id().is_empty():
		return
	_last_card_id = game_id
	print("[A3] LAUNCH_REQUEST game=", game_id)
	if not GameManager.launch(game_id):
		_hub_status.text = "Could not launch %s." % game_id


func _request_game_exit() -> void:
	if not GameManager.current_game_id().is_empty():
		GameManager.request_current_game_exit()


func _on_game_loaded(game_id: StringName, metadata: GameMetadata) -> void:
	_hub_layer.hide()
	_game_layer.show()
	_game_title.text = metadata.title
	_game_status.text = "BACK / Esc = Hub"
	_touch_controls.set_gameplay_enabled(true)
	print("[A3] GAME_RUNNING id=", game_id, " native=", metadata.native_size)


func _on_game_unloaded(game_id: StringName) -> void:
	_touch_controls.set_gameplay_enabled(false)
	_game_layer.hide()
	_hub_layer.show()
	_hub_status.text = "Returned from %s — ready." % game_id
	_focus_last_card("hub_return")
	print("[A3] HUB_RETURN from=", game_id, " audio_scopes=", AudioManager.active_game_count())


func _on_game_load_failed(game_id: StringName, reason: String) -> void:
	_touch_controls.set_gameplay_enabled(false)
	_game_layer.hide()
	_hub_layer.show()
	_hub_status.text = "Launch failed for %s: %s" % [game_id, reason]
	print("[A3] LAUNCH_FAILED id=", game_id, " reason=", reason)


func _on_score_changed(game_id: StringName, value: int) -> void:
	_game_status.text = "%s score %d" % [game_id, value]


func _on_state_saved(game_id: StringName, _data: Variant) -> void:
	_game_status.text = "%s saved" % game_id


func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	if not _settings_panel.visible:
		_focus_last_card("settings_close")


func _on_master_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	var linear := value / 100.0
	AudioServer.set_bus_mute(bus, linear <= 0.001)
	if linear > 0.001:
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear))
	_volume_label.text = "Master volume: %d%%" % int(value)
	print("[A3] MASTER_VOLUME value=", int(value))


func _toggle_fullscreen() -> void:
	_web_runtime.toggle_fullscreen_from_user_gesture()


func get_game_card_count() -> int:
	return _card_controls.size()


func get_game_card_ids() -> Array[StringName]:
	return _card_ids.duplicate()


func get_focused_game_id() -> StringName:
	var index := _focused_card_index()
	return _card_ids[index] if index >= 0 else StringName()


func is_hub_visible() -> bool:
	return _hub_layer != null and _hub_layer.visible


func is_game_visible() -> bool:
	return _game_layer != null and _game_layer.visible


func touch_gameplay_enabled() -> bool:
	return _touch_controls != null and _touch_controls.is_gameplay_enabled()
