extends SceneTree

const VisualScene = preload("res://games/pacman/b4/pacman_b4_visual_scene.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360,420)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var visual := VisualScene.new()
	viewport.add_child(visual)
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.get_width() != 360 or image.get_height() != 420:
		push_error("[B4_RENDER] invalid render image")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/pacman_b4"))
	var err := image.save_png("res://artifacts/pacman_b4/imported_opening.png")
	if err != OK:
		push_error("[B4_RENDER] save_png failed: %s" % err)
		quit(1)
		return
	print("[B4_RENDER] PASS path=artifacts/pacman_b4/imported_opening.png size=360x420")
	quit(0)
