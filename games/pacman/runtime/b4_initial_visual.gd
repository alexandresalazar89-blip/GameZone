extends Node2D
class_name PacmanB4InitialVisual

const GhostVisual = preload("res://games/pacman/runtime/b4_ghost_visual.gd")

var catalog: PacmanB4AssetCatalog
var background: Sprite2D
var ghosts: Array[PacmanB4GhostVisual] = []


func build(asset_catalog: PacmanB4AssetCatalog) -> bool:
	catalog = asset_catalog
	var texture := catalog.main_visual_texture()
	if texture == null:
		push_error("[B4][InitialVisual] missing raw frame-4 visual")
		return false

	background = Sprite2D.new()
	background.name = "RawFrame4"
	background.centered = false
	background.texture = texture
	background.position = Vector2.ZERO
	background.z_index = 0
	add_child(background)

	var state: Dictionary = catalog.data.get("initial_visual_state", {})
	for ghost_item in state.get("ghosts", []):
		var ghost := GhostVisual.new()
		ghost.name = "Ghost_%d" % int(ghost_item.get("index", 0))
		if not ghost.configure(catalog, int(ghost_item.get("rgb", 0))):
			ghost.free()
			return false
		var p: Array = ghost_item.get("position", [0, 0])
		ghost.position = Vector2(float(p[0]), float(p[1]))
		ghost.z_index = 100 + int(ghost_item.get("index", 0))
		add_child(ghost)
		ghosts.append(ghost)

	return ghosts.size() == 4


func set_all_frightened(enabled: bool) -> void:
	for ghost in ghosts:
		if enabled:
			ghost.set_frightened()
		else:
			ghost.set_normal()


func ghost_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ghost in ghosts:
		out.append(ghost.position)
	return out
