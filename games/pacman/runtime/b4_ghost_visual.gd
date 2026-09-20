extends Node2D
class_name PacmanB4GhostVisual

var _catalog: PacmanB4AssetCatalog
var _body: Sprite2D
var _eyes: Sprite2D
var _normal_rgb := 0


func configure(catalog: PacmanB4AssetCatalog, rgb_value: int) -> bool:
	_catalog = catalog
	_normal_rgb = rgb_value

	_body = Sprite2D.new()
	_body.name = "Shape"
	_body.centered = true
	_body.texture = catalog.sprite_frame_texture(14, 1)
	if _body.texture == null:
		push_error("[B4][GhostVisual] missing body sprite 14")
		return false
	add_child(_body)

	_eyes = Sprite2D.new()
	_eyes.name = "Eyes"
	_eyes.centered = true
	_eyes.texture = catalog.sprite_frame_texture(16, 1)
	if _eyes.texture == null:
		push_error("[B4][GhostVisual] missing eyes sprite 16")
		return false
	# Sprite 16 standalone export places its registration point 0.5 px below
	# texture center. The Flash parent placement is y=-1.95, hence -2.45 here.
	_eyes.position = Vector2(0.0, -2.45)
	add_child(_eyes)

	set_normal()
	return true


func set_normal() -> void:
	if _body == null or _eyes == null:
		return
	_body.self_modulate = _flash_rgb(_normal_rgb)
	_eyes.texture = _catalog.sprite_frame_texture(16, 1)
	_eyes.self_modulate = Color.WHITE
	_eyes.position = Vector2(0.0, -2.45)


func set_frightened() -> void:
	if _body == null or _eyes == null:
		return
	# Source: c.setRGB(13311) = 0x0033ff and PPEyes is sprite 18.
	_body.self_modulate = _flash_rgb(13311)
	_eyes.texture = _catalog.sprite_frame_texture(18, 1)
	_eyes.self_modulate = Color.WHITE
	# Sprite 18 export registration is 0.25 px above its texture center while
	# Flash frame 2 places PPEyes at y=+0.25 px from Ghost origin.
	_eyes.position = Vector2.ZERO


func body_color() -> Color:
	return _body.self_modulate if _body != null else Color.TRANSPARENT


func eyes_texture_path() -> String:
	if _eyes == null or _eyes.texture == null:
		return ""
	for sid in [16, 18]:
		if _catalog.sprite_frame_texture(sid, 1) == _eyes.texture:
			return _catalog.sprite_frame_path(sid, 1)
	return ""


func _flash_rgb(value: int) -> Color:
	return Color8((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff, 255)
