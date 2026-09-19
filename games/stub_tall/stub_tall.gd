extends GameModule

const NATIVE_SIZE := Vector2(240, 320)
var score := 100
var pause_presses := 0
var _tone: AudioStreamWAV

@onready var marker: ColorRect = $Marker
@onready var status: Label = $Status


func start(game_context: GameContext) -> void:
	super.start(game_context)
	_tone = _make_tone(660.0)
	var saved: Variant = context.saves.load_slot(&"contract_probe", {})
	if saved is Dictionary:
		score = int(saved.get("score", 100))
	_update_status("started")


func _process(delta: float) -> void:
	if context == null:
		return

	var direction := Input.get_vector(
		context.action("move_left"),
		context.action("move_right"),
		context.action("move_up"),
		context.action("move_down")
	)
	marker.position += direction * 125.0 * delta
	var limit := Vector2(NATIVE_SIZE) - marker.size
	marker.position.x = clampf(marker.position.x, 0.0, limit.x)
	marker.position.y = clampf(marker.position.y, 52.0, limit.y)

	if Input.is_action_just_pressed(context.action("action_a")):
		score += 10
		publish_score(score)
		context.audio.play_stream(_tone, -16.0)
		_update_status("A -> score")

	if Input.is_action_just_pressed(context.action("action_b")):
		var data := {"owner": "stub_tall", "score": score}
		context.saves.save_slot(&"contract_probe", data)
		publish_saved_state(data)
		_update_status("B -> saved")

	if Input.is_action_just_pressed(context.action("pause")):
		pause_presses += 1
		_update_status("pause action")


func teardown() -> void:
	super.teardown()


func _update_status(event: String) -> void:
	status.text = "score=%d  pause=%d  last=%s\nB saves slot 'Same slot name, isolated in stub_tall namespace" % [
		score,
		pause_presses,
		event,
	]


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
