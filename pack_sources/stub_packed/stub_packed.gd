extends GameModule

const NATIVE_SIZE := Vector2(256, 192)
var score := 500
var pause_presses := 0
var _tone: AudioStreamWAV
var _marker: ColorRect
var _status: Label


func start(game_context: GameContext) -> void:
	super.start(game_context)
	_marker = get_node_or_null("Marker") as ColorRect
	_status = get_node_or_null("Status") as Label
	_tone = _make_tone(550.0)

	var saved: Variant = context.saves.load_slot(&"contract_probe", {})
	if saved is Dictionary:
		score = int(saved.get("score", 500))

	_update_status("runtime PCK started")
	print("[A4_PACK_GAME] START id=", context.game_id)


func _process(delta: float) -> void:
	if context == null:
		return

	var direction := Input.get_vector(
		context.action("move_left"),
		context.action("move_right"),
		context.action("move_up"),
		context.action("move_down")
	)

	if _marker != null:
		_marker.position += direction * 105.0 * delta
		var limit := Vector2(NATIVE_SIZE) - _marker.size
		_marker.position.x = clampf(_marker.position.x, 0.0, limit.x)
		_marker.position.y = clampf(_marker.position.y, 48.0, limit.y)

	if Input.is_action_just_pressed(context.action("action_a")):
		score += 5
		publish_score(score)
		context.audio.play_stream(_tone, -16.0)
		_update_status("A -> packed audio")

	if Input.is_action_just_pressed(context.action("action_b")):
		var data := {"owner": "stub_packed", "score": score}
		context.saves.save_slot(&"contract_probe", data)
		publish_saved_state(data)
		_update_status("B -> packed save")

	if Input.is_action_just_pressed(context.action("pause")):
		pause_presses += 1
		_update_status("pause action")

	if Input.is_action_just_pressed(context.action("back")):
		context.exit()


func teardown() -> void:
	print("[A4_PACK_GAME] TEARDOWN")
	super.teardown()


func _update_status(event: String) -> void:
	if _status == null:
		return
	_status.text = "score=%d  pause=%d\n%s\nloaded from runtime .pck" % [score, pause_presses, event]


func _make_tone(frequency: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.stereo = false
	var bytes := PackedByteArray()
	for i in range(320):
		var sample := 128 + int(sin(TAU * frequency * float(i) / 8000.0) * 24.0)
		bytes.append(clampi(sample, 0, 255))
	stream.data = bytes
	return stream
