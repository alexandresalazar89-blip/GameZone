extends RefCounted
class_name GameContext

const INPUT_ACTIONS := {
	"move_up": &"move_up",
	"move_down": &"move_down",
	"move_left": &"move_left",
	"move_right": &"move_right",
	"action_a": &"action_a",
	"action_b": &"action_b",
	"pause": &"pause",
	"back": &"back",
}

var game_id: StringName
var render_viewport: SubViewport
var audio: GameAudioScope
var saves: GameSaveScope
var input_actions: Dictionary = INPUT_ACTIONS.duplicate(true)

var _exit_callback: Callable


func _init(
	scoped_game_id: StringName,
	viewport: SubViewport,
	audio_scope: GameAudioScope,
	save_scope: GameSaveScope,
	exit_callback: Callable
) -> void:
	game_id = scoped_game_id
	render_viewport = viewport
	audio = audio_scope
	saves = save_scope
	_exit_callback = exit_callback


func action(name: String) -> StringName:
	return input_actions.get(name, StringName())


func exit() -> void:
	if _exit_callback.is_valid():
		_exit_callback.call()
