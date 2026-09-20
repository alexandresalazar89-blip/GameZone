extends Node2D
class_name PacmanFlashMovieClip

var _x: float:
	get:
		return position.x
	set(value):
		position.x = value

var _y: float:
	get:
		return position.y
	set(value):
		position.y = value

var _visible: bool:
	get:
		return visible
	set(value):
		visible = value

var _currentframe := 1

var _total_frames := 1
var _labels: Dictionary = {}
var _playing := true
var _children_by_key: Dictionary = {}


func configure_timeline(total_frames: int, labels: Dictionary = {}) -> void:
	_total_frames = maxi(total_frames, 1)
	_labels = labels.duplicate(true)
	_currentframe = clampi(_currentframe, 1, _total_frames)


func gotoAndPlay(target: Variant) -> bool:
	var frame := _resolve_frame(target)
	if frame <= 0:
		return false
	_currentframe = frame
	_playing = true
	return true


func gotoAndStop(target: Variant) -> bool:
	var frame := _resolve_frame(target)
	if frame <= 0:
		return false
	_currentframe = frame
	_playing = false
	return true


func is_playing() -> bool:
	return _playing


func advance_frame() -> void:
	if not _playing:
		return
	_currentframe += 1
	if _currentframe > _total_frames:
		_currentframe = 1


func attachMovie(key: Variant, clip: PacmanFlashMovieClip) -> PacmanFlashMovieClip:
	if clip == null:
		return null
	if clip.get_parent() != self:
		add_child(clip)
	_children_by_key[key] = clip
	return clip


func child(key: Variant) -> PacmanFlashMovieClip:
	return _children_by_key.get(key) as PacmanFlashMovieClip


func _resolve_frame(target: Variant) -> int:
	if typeof(target) == TYPE_INT or typeof(target) == TYPE_FLOAT:
		return clampi(int(target), 1, _total_frames)

	var label := str(target)
	if _labels.has(label):
		return clampi(int(_labels[label]), 1, _total_frames)

	push_error("[B3][FlashMovieClip] unknown frame label: " + label)
	return -1
