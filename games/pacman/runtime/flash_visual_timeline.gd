extends "res://games/pacman/runtime/flash_movie_clip.gd"
class_name PacmanFlashVisualTimeline

var _frame_entries: Array = []
var _frame_sprite: Sprite2D


func configure_visual(total_frames: int, labels: Dictionary, frame_entries: Array) -> void:
	configure_timeline(total_frames, labels)
	_frame_entries = frame_entries.duplicate(true)
	if _frame_sprite == null:
		_frame_sprite = Sprite2D.new()
		_frame_sprite.name = "FrameTexture"
		_frame_sprite.centered = false
		add_child(_frame_sprite)
	_sync_frame()


func gotoAndPlay(target: Variant) -> bool:
	var ok := super.gotoAndPlay(target)
	if ok:
		_sync_frame()
	return ok


func gotoAndStop(target: Variant) -> bool:
	var ok := super.gotoAndStop(target)
	if ok:
		_sync_frame()
	return ok


func advance_frame() -> void:
	var before := _currentframe
	super.advance_frame()
	if _currentframe != before:
		_sync_frame()


func current_resource_path() -> String:
	if _currentframe < 1 or _currentframe > _frame_entries.size():
		return ""
	return str(_frame_entries[_currentframe - 1].get("godot_resource", ""))


func current_origin() -> Vector2:
	if _currentframe < 1 or _currentframe > _frame_entries.size():
		return Vector2.ZERO
	var geometry: Dictionary = _frame_entries[_currentframe - 1].get("geometry", {})
	var origin: Array = geometry.get("origin", [0.0, 0.0])
	return Vector2(float(origin[0]), float(origin[1]))


func _sync_frame() -> void:
	if _frame_sprite == null or _currentframe < 1 or _currentframe > _frame_entries.size():
		return
	var path := current_resource_path()
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("[B4][VisualTimeline] failed to load frame texture: " + path)
		return
	_frame_sprite.texture = texture
	_frame_sprite.position = -current_origin()
