extends Node2D
class_name PacmanB4VisualScene

const STAGE_SIZE := Vector2i(360, 420)
const GHOST_ORIGIN := Vector2(9.0, 9.35)

const OPENING_FRAME := "res://games/pacman/decompiled/frames/4.svg"
const GHOSTS := [
	{"name": "Ghost1", "path": "res://games/pacman/b4/derived/ghost_red.svg", "position": Vector2(180, 150)},
	{"name": "Ghost2", "path": "res://games/pacman/b4/derived/ghost_pink.svg", "position": Vector2(180, 192)},
	{"name": "Ghost3", "path": "res://games/pacman/b4/derived/ghost_cyan.svg", "position": Vector2(156, 192)},
	{"name": "Ghost4", "path": "res://games/pacman/b4/derived/ghost_orange.svg", "position": Vector2(204, 192)},
]


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	var stage := Sprite2D.new()
	stage.name = "OpeningFrame4"
	stage.centered = false
	stage.position = Vector2.ZERO
	stage.texture = load(OPENING_FRAME) as Texture2D
	if stage.texture == null:
		push_error("[B4] failed to load raw opening frame: " + OPENING_FRAME)
	add_child(stage)

	var ghosts := Node2D.new()
	ghosts.name = "InitialGhosts"
	add_child(ghosts)
	for info in GHOSTS:
		var sprite := Sprite2D.new()
		sprite.name = str(info["name"])
		sprite.centered = false
		sprite.texture = load(str(info["path"])) as Texture2D
		sprite.position = Vector2(info["position"]) - GHOST_ORIGIN
		if sprite.texture == null:
			push_error("[B4] failed to load derived ghost: " + str(info["path"]))
		ghosts.add_child(sprite)


func character_flash_positions() -> Dictionary:
	return {
		"Pacman": Vector2(186, 294),
		"Ghost1": Vector2(180, 150),
		"Ghost2": Vector2(180, 192),
		"Ghost3": Vector2(156, 192),
		"Ghost4": Vector2(204, 192),
	}


func source_traceability() -> Dictionary:
	return {
		"stage": "games/pacman/decompiled/frames/4.svg",
		"Pacman": "games/pacman/decompiled/sprites/DefineSprite_40/1.svg (already placed in raw frame 4)",
		"Ghost1": "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/1.svg -> b4/derived/ghost_red.svg",
		"Ghost2": "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/1.svg -> b4/derived/ghost_pink.svg",
		"Ghost3": "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/1.svg -> b4/derived/ghost_cyan.svg",
		"Ghost4": "games/pacman/decompiled/sprites/DefineSprite_19_Ghost/1.svg -> b4/derived/ghost_orange.svg",
	}
