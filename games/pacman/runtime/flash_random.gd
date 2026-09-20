extends RefCounted
class_name PacmanFlashRandom

var _rng := RandomNumberGenerator.new()


func _init(seed_value: Variant = null) -> void:
	if seed_value == null:
		_rng.randomize()
	else:
		_rng.seed = int(seed_value)


func seed_fixed(seed_value: int) -> void:
	_rng.seed = seed_value


func random(n: int) -> int:
	if n <= 0:
		return 0
	return mini(int(floor(_rng.randf() * float(n))), n - 1)


func not_random(n: int) -> bool:
	return random(n) == 0
