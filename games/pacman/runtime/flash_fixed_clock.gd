extends RefCounted
class_name PacmanFlashFixedClock

const FPS := 21.0
const STEP_SECONDS := 1.0 / FPS
const EPSILON := 0.000000001

var accumulator_seconds := 0.0
var tick_count := 0


func reset() -> void:
	accumulator_seconds = 0.0
	tick_count = 0


func consume_elapsed(elapsed_seconds: float) -> int:
	accumulator_seconds += maxf(elapsed_seconds, 0.0)
	var emitted := 0
	while accumulator_seconds + EPSILON >= STEP_SECONDS:
		accumulator_seconds -= STEP_SECONDS
		tick_count += 1
		emitted += 1
	return emitted
