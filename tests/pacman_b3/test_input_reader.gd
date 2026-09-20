extends SceneTree

const InputBootstrap = preload("res://shared/input/input_map_bootstrap.gd")
const GameContextScript = preload("res://shared/modules/game_context.gd")
const InputReader = preload("res://games/pacman/runtime/pacman_input_reader.gd")


func _initialize() -> void:
	InputBootstrap.install_defaults()
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var context := GameContextScript.new(&"pacman", viewport, null, null, Callable())
	var reader := InputReader.new()
	reader.configure(context)

	var cases := [
		[&"move_up", InputReader.DIR_UP],
		[&"move_right", InputReader.DIR_RIGHT],
		[&"move_down", InputReader.DIR_DOWN],
		[&"move_left", InputReader.DIR_LEFT],
	]
	for item in cases:
		var action: StringName = item[0]
		var expected: int = item[1]
		Input.action_press(action)
		if reader.read_direction() != expected:
			Input.action_release(action)
			_fail("semantic action %s did not map to direction %d" % [action, expected])
			return
		Input.action_release(action)

	if reader.read_direction() != InputReader.DIR_NONE:
		_fail("reader reported direction with no active action")
		return

	print("[B3_INPUT] PASS shared_actions=move_up,move_right,move_down,move_left")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_INPUT] FAIL: " + message)
	quit(1)
