extends RefCounted
class_name PacmanInputReader

const DIR_NONE := -1
const DIR_UP := 0
const DIR_RIGHT := 1
const DIR_DOWN := 2
const DIR_LEFT := 3

var _context: GameContext


func configure(game_context: GameContext) -> void:
	_context = game_context


func read_direction() -> int:
	if _context == null:
		return DIR_NONE
	if Input.is_action_pressed(_context.action("move_up")):
		return DIR_UP
	if Input.is_action_pressed(_context.action("move_right")):
		return DIR_RIGHT
	if Input.is_action_pressed(_context.action("move_down")):
		return DIR_DOWN
	if Input.is_action_pressed(_context.action("move_left")):
		return DIR_LEFT
	return DIR_NONE
