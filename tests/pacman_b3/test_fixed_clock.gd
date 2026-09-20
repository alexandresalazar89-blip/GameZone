extends SceneTree

const Clock = preload("res://games/pacman/runtime/flash_fixed_clock.gd")


func _initialize() -> void:
	var clock := Clock.new()
	for _i in range(420):
		clock.consume_elapsed(1.0 / 420.0)
	if clock.tick_count != 21:
		_fail("expected 21 ticks after 1 second, got %d" % clock.tick_count)
		return
	for _i in range(420):
		clock.consume_elapsed(1.0 / 420.0)
	if clock.tick_count != 42:
		_fail("expected 42 ticks after 2 seconds, got %d" % clock.tick_count)
		return
	if absf(Clock.STEP_SECONDS - (1.0 / 21.0)) > 0.000000001:
		_fail("step is not 1/21 second")
		return
	print("[B3_CLOCK] PASS fps=21 step_ms=", Clock.STEP_SECONDS * 1000.0, " ticks=", clock.tick_count)
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_CLOCK] FAIL: " + message)
	quit(1)
