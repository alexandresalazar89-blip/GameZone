extends SceneTree

const FlashHitShape = preload("res://games/pacman/runtime/flash_hit_shape.gd")


func _initialize() -> void:
	var a := FlashHitShape.new()
	var b := FlashHitShape.new()
	root.add_child(a)
	root.add_child(b)

	a.set_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(20, 0), Vector2(0, 20)
	]))
	b.set_polygon(PackedVector2Array([
		Vector2(20, 20), Vector2(20, 5), Vector2(5, 20)
	]))

	# Bounding boxes overlap from 5..20, but the actual triangles do not.
	if a.hitTest(b):
		_fail("shape-level hitTest regressed to bounding-box behavior")
		return

	b.position = Vector2(-8, -8)
	if not a.hitTest(b):
		_fail("overlapping Hit polygons returned false")
		return

	b.position = Vector2(100, 100)
	if a.hitTest(b):
		_fail("separated Hit polygons returned true")
		return

	print("[B3_HITTEST] PASS polygon_overlap=true separated=false bbox_false_positive_rejected=true")
	quit(0)


func _fail(message: String) -> void:
	push_error("[B3_HITTEST] FAIL: " + message)
	quit(1)
