extends RefCounted
const Loader = preload("res://scripts/vrm_loader.gd")
const USER_DIR := "user://avatars"
const SAMPLE := "res://avatars/Godette.vrm"

static func incoming_dir() -> String:
	if OS.has_feature("android"):
		return "/storage/emulated/0/Android/data/jp.yomiplush.foamhaven/files/avatars"
	return ProjectSettings.globalize_path(USER_DIR)

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"path": "", "name": "ぬいぐるみの手"}, {"path": SAMPLE, "name": "Godette（サンプル）"}]
	var directories := [ProjectSettings.globalize_path(USER_DIR)]
	if incoming_dir() != directories[0]:
		directories.append(incoming_dir())
	for directory in directories:
		DirAccess.make_dir_recursive_absolute(directory)
		var dir := DirAccess.open(directory)
		if dir == null:
			continue
		var names := dir.get_files()
		names.sort()
		for filename in names:
			if filename.get_extension().to_lower() == "vrm":
				result.append({"path": directory.path_join(filename), "name": filename.get_basename().left(55)})
	return result

static func import_copy(path: String) -> Dictionary:
	if path == SAMPLE or path.begins_with(ProjectSettings.globalize_path(USER_DIR) + "/"):
		return {"path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Loader.MAX_BYTES:
		return {"error": "ファイルを開けませんでした（上限128MB）。"}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var inspected := Loader.inspect_bytes(bytes)
	if inspected.has("error"):
		return inspected
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var digest := hash.finish().hex_encode().left(12)
	var filename := path.get_file().get_basename().validate_filename().left(38)
	if path.begins_with("content:") or filename.is_empty():
		filename = "Avatar"
	var dir := ProjectSettings.globalize_path(USER_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return {"error": "アバターの保存先を作れませんでした。"}
	var destination := dir.path_join(filename + "-" + digest + ".vrm")
	if not FileAccess.file_exists(destination):
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if output == null:
			return {"error": "アバターを保存できませんでした。"}
		output.store_buffer(bytes)
		var error := output.get_error()
		output.close()
		if error != OK:
			return {"error": "アバターの保存に失敗しました。"}
	return {"path": destination}
