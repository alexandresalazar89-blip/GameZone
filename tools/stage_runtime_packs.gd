extends SceneTree

const REGISTRY_PATH := "res://games/registry.json"
const WEB_ROOT := "res://build/web"


func _initialize() -> void:
	var ok := _stage_all()
	quit(0 if ok else 1)


func _stage_all() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[A4_PACK_STAGE] invalid registry JSON")
		return false

	var games: Array = parsed.get("games", [])
	var staged := 0
	for entry_variant in games:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("source", "tree")) != "pack":
			continue
		if not _stage_entry(entry):
			return false
		staged += 1

	print("[A4_PACK_STAGE] ALL_PACKS_STAGED_OK count=", staged)
	return staged > 0


func _stage_entry(entry: Dictionary) -> bool:
	var game_id := str(entry.get("id", ""))
	var local_path := str(entry.get("local_path", ""))
	var pack_url := str(entry.get("pack_url", ""))

	if game_id.is_empty() or local_path.is_empty() or pack_url.is_empty():
		push_error("[A4_PACK_STAGE] incomplete pack registry entry: " + JSON.stringify(entry))
		return false
	if pack_url.begins_with("http://") or pack_url.begins_with("https://"):
		push_error("[A4_PACK_STAGE] absolute pack_url cannot be staged into Pages artifact: " + pack_url)
		return false

	var source_abs := ProjectSettings.globalize_path(local_path)
	if not FileAccess.file_exists(source_abs):
		push_error("[A4_PACK_STAGE] local pack missing id=%s path=%s" % [game_id, local_path])
		return false

	var relative_target := pack_url.trim_prefix("./").trim_prefix("/")
	var target_res := WEB_ROOT.path_join(relative_target)
	var target_abs := ProjectSettings.globalize_path(target_res)
	var target_dir_abs := target_abs.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(target_dir_abs)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("[A4_PACK_STAGE] cannot create target dir id=%s error=%d" % [game_id, mkdir_error])
		return false

	var copy_error := DirAccess.copy_absolute(source_abs, target_abs)
	if copy_error != OK:
		push_error("[A4_PACK_STAGE] copy failed id=%s error=%d" % [game_id, copy_error])
		return false

	var source_size := FileAccess.get_file_as_bytes(source_abs).size()
	var target_size := FileAccess.get_file_as_bytes(target_abs).size()
	if source_size <= 0 or target_size != source_size:
		push_error("[A4_PACK_STAGE] size mismatch id=%s source=%d target=%d" % [game_id, source_size, target_size])
		return false

	print("[A4_PACK_STAGE] PACK_STAGED id=", game_id, " bytes=", target_size, " url=", pack_url)
	return true
