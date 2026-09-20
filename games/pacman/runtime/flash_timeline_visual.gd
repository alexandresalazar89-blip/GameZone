extends PacmanFlashMovieClip
class_name PacmanFlashTimelineVisual

var character_id := -1
var _catalog: PacmanB4AssetCatalog
var _frame_paths: Dictionary = {}
var _visual: Sprite2D


func configure_from_catalog(catalog: PacmanB4AssetCatalog, sprite_id: int) -> bool:
	_catalog = catalog
	character_id = sprite_id
	var item := catalog.sprite_data(sprite_id)
	if item.is_empty():
		push_error("[B4][TimelineVisual] missing sprite %d" % sprite_id)
		return false

	var labels: Dictionary = item.get("labels", {})
	configure_timeline(int(item.get("frame_count", 1)), labels)

	_frame_paths.clear()
	for frame_item in item.get("frames", []):
		_frame_paths[int(frame_item.get("frame", -1))] = str(frame_item.get("raw_source", ""))

	if _visual == null:
		_visual = Sprite2D.new()
		_visual.name = "FrameVisual"
		_visual.centered = true
		add_child(_visual)

	_sync_visual()
	return true


func gotoAndPlay(target: Variant) -> bool:
	var ok := super.gotoAndPlay(target)
	if ok:
		_sync_visual()
	return ok


func gotoAndStop(target: Variant) -> bool:
	var ok := super.gotoAndStop(target)
	if ok:
		_sync_visual()
	return ok


func advance_frame() -> void:
	super.advance_frame()
	_sync_visual()


func current_texture_path() -> String:
	return str(_frame_paths.get(_currentframe, ""))


func current_texture() -> Texture2D:
	return _visual.texture if _visual != null else null


func _sync_visual() -> void:
	if _visual == null:
		return
	var path := current_texture_path()
	if path.is_empty():
		_visual.texture = null
		return
	_visual.texture = load(path) as Texture2D
