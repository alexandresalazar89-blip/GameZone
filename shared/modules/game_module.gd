extends Node2D
class_name GameModule

signal game_exited
signal score_changed(value: int)
signal state_saved(data: Variant)

var context: GameContext
var started := false


func start(game_context: GameContext) -> void:
	context = game_context
	started = true


func pause() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT


func teardown() -> void:
	started = false
	context = null


func request_exit() -> void:
	game_exited.emit()


func publish_score(value: int) -> void:
	score_changed.emit(value)


func publish_saved_state(data: Variant) -> void:
	state_saved.emit(data)
