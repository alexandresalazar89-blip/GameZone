extends GameModule
class_name PacmanGameModule

const NATIVE_SIZE := Vector2i(360, 420)
const FlashFixedClock = preload("res://games/pacman/runtime/flash_fixed_clock.gd")
const InputReader = preload("res://games/pacman/runtime/pacman_input_reader.gd")
const B4AssetCatalog = preload("res://games/pacman/runtime/b4_asset_catalog.gd")
const B4InitialVisual = preload("res://games/pacman/runtime/b4_initial_visual.gd")
const B4VisualScene = preload("res://games/pacman/b4/pacman_b4_visual_scene.gd")

signal flash_enter_frame(tick_index: int)

var flash_clock: PacmanFlashFixedClock
var input_reader: PacmanInputReader
var b4_catalog: PacmanB4AssetCatalog
var b4_visual: PacmanB4InitialVisual
var flash_tick_count := 0
var b4_visual_scene: PacmanB4VisualScene


func _ready() -> void:
	set_process(false)


func start(game_context: GameContext) -> void:
	super.start(game_context)
	flash_clock = FlashFixedClock.new()
	input_reader = InputReader.new()
	input_reader.configure(context)
	flash_tick_count = 0
	if b4_visual_scene == null:
		b4_visual_scene = B4VisualScene.new()
		b4_visual_scene.name = "B4VisualScene"
		add_child(b4_visual_scene)
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
	if b4_visual_scene != null:
		b4_visual_scene.queue_free()
		b4_visual_scene = null
	super.teardown()
