extends Node2D
class_name PacmanFlashHitShape

var _polygon := PackedVector2Array()


func set_polygon(points: PackedVector2Array) -> void:
	_polygon = points.duplicate()


func world_polygon() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in _polygon:
		result.append(global_transform * point)
	return result


func hitTest(other: PacmanFlashHitShape) -> bool:
	if other == null or _polygon.size() < 3 or other._polygon.size() < 3:
		return false
	var overlap := Geometry2D.intersect_polygons(world_polygon(), other.world_polygon())
	return not overlap.is_empty()
