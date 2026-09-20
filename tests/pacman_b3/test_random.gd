extends SceneTree

const FlashRandom = preload("res://games/pacman/runtime/flash_random.gd")


func _initialize() -> void:
	var a := FlashRandom.new(123456789)
	var b := FlashRandom.new(123456789)
	for _i in range(128):
		var va := a.random(600)
		var vb := b.random(600)
		if va != vb:
			_fail("fixed seed sequence diverged")
			return
		if va < 0 or va >= 600:
			_fail("random(600) escaped Flash range: %d" % va)
			return

	for n in [1, 2, 3, 7, 600]:
		var r := FlashRandom.new(42 + n)
		for _i in range(256):
			var value := r.random(n)
			if value < 0 or value >= n:
				_fail("random(%d) returned %d" % [n, value])
				return

	var c := FlashRandom.new(98765)
	var d := FlashRandom.new(98765)
	for _i in range(128):
		if c.not_random(3) != (d.random(3) == 0):
			_fail("!random(n) semantics are not random(n)==0")
			return

	print("[B3_RANDOM] PASS seeded_repeatable=true range=[0,n-1] not_random=1/n_semantics")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_RANDOM] FAIL: " + message)
	quit(1)
