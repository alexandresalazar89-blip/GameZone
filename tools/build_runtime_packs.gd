extends SceneTree

const REGISTRY_PATH := "res://games/registry.json"
const ALLOWED_EXTENSIONS := ["gd", "tscn", "tres"]


func _initialize() -> void:
	var ok := _build_all()
	quit(0 if ok else 1)


func _build_all() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[A4_PACK_BUILD] invalid registry JSON")
		return false

	var games: Array = parsed.get("games", [])
	var built := 0
	for entry_variant in games:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("source", "tree")) != "pack":
			continue
		if not _build_entry(entry):
			return false
		built += 1

	print("[A4_PACK_BUILD] ALL_PACKS_OK count=", built)
	return built > 0


func _build_entry(entry: Dictionary) -> bool:
	var game_id := str(entry.get("id", ""))
	var source_rel := str(entry.get("build_source", ""))
	var mount := str(entry.get("mount", ""))
	var output_res := str(entry.get("local_path", ""))

	if game_id.is_empty() or source_rel.is_empty() or mount.is_empty() or output_res.is_empty():
		push_error("[A4_PACK_BUILD] incomplete pack registry entry: " + JSON.stringify(entry))
		return false

	var source_abs := ProjectSettings.globalize_path("res://" + source_rel.trim_prefix("res://"))
	var output_abs := ProjectSettings.globalize_path(output_res)
	var files: Array[String] = []
	_collect_files(source_abs, "", files)
	files.sort()

	if files.is_empty():
		push_error("[A4_PACK_BUILD] no source files for " + game_id)
		return false

	var packer := PCKPacker.new()
	var start_error := packer.pck_start(output_abs)
	if start_error != OK:
		push_error("[A4_PACK_BUILD] pck_start failed id=%s error=%d" % [game_id, start_error])
		return false

	for relative_path in files:
		var source_file := source_abs.path_join(relative_path)
		var target_file := mount.path_join(relative_path)
		var add_error := packer.add_file(target_file, source_file)
		if add_error != OK:
			push_error("[A4_PACK_BUILD] add_file failed id=%s file=%s error=%d" % [game_id, relative_path, add_error])
			return false

	var flush_error := packer.flush(true)
	if flush_error != OK:
		push_error("[A4_PACK_BUILD] flush failed id=%s error=%d" % [game_id, flush_error])
		return false

	var byte_count := FileAccess.get_file_as_bytes(output_abs).size()
	print("[A4_PACK_BUILD] PACK_BUILT id=", game_id, " files=", files.size(), " bytes=", byte_count, " output=", output_res)
	return byte_count > 0


func _collect_files(base_abs: String, relative_dir: String, output: Array[String]) -> void:
	var current_abs := base_abs if relative_dir.is_empty() else base_abs.path_join(relative_dir)
	var dir := DirAccess.open(current_abs)
	if dir == null:
		push_error("[A4_PACK_BUILD] cannot open source dir: " + current_abs)
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var relative_path := name if relative_dir.is_empty() else relative_dir.path_join(name)
		if dir.current_is_dir():
			_collect_files(base_abs, relative_path, output)
			continue

		if ALLOWED_EXTENSIONS.has(name.get_extension().to_lower()):
			output.append(relative_path)
	dir.list_dir_end()
