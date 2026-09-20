extends GameModule
class_name PacmanGameModule

const NATIVE_SIZE := Vector2i(360, 420)
const FlashFixedClock = preload("res://games/pacman/runtime/flash_fixed_clock.gd")
const InputReader = preload("res://games/pacman/runtime/pacman_input_reader.gd")

signal flash_enter_frame(tick_index: int)

var flash_clock: PacmanFlashFixedClock
var input_reader: PacmanInputReader
var flash_tick_count := 0


func _ready() -> void:
	set_process(false)


func start(game_context: GameContext) -> void:
	super.start(game_context)
	flash_clock = FlashFixedClock.new()
	input_reader = InputReader.new()
	input_reader.configure(context)
	flash_tick_count = 0
	set_process(true)


func _process(delta: float) -> void:
	if not started or flash_clock == null:
		return
	var ticks := flash_clock.consume_elapsed(delta)
	for _i in range(ticks):
		_flash_enter_frame_tick()


func _flash_enter_frame_tick() -> void:
	# B3 intentionally contains no Pac-Man gameplay. B5 will port frame_6 here.
	flash_tick_count += 1
	flash_enter_frame.emit(flash_tick_count)


func teardown() -> void:
	set_process(false)
	flash_clock = null
	input_reader = null
	super.teardown()
