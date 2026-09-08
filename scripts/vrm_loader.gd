extends RefCounted
## Runtime-only importer. Models are data, and replacement is transactional.
const Vrm0 = preload("res://addons/vrm/vrm_extension.gd")
const Vrm1 = preload("res://addons/vrm/1.0/VRMC_vrm.gd")
const Mtoon = preload("res://addons/vrm/1.0/VRMC_materials_mtoon.gd")
const Emissive = preload("res://addons/vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd")
const Spring = preload("res://addons/vrm/1.0/VRMC_springBone.gd")
const Constraint = preload("res://addons/vrm/1.0/VRMC_node_constraint.gd")
const MAX_BYTES := 128 * 1024 * 1024

static func inspect_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 20 or bytes.size() > MAX_BYTES:
		return {"error": I18n.t("err_vrm_size")}
	if bytes.decode_u32(0) != 0x46546c67 or bytes.decode_u32(4) != 2 or bytes.decode_u32(8) != bytes.size():
		return {"error": I18n.t("err_not_vrm")}
	var length := int(bytes.decode_u32(12))
	if bytes.decode_u32(16) != 0x4e4f534a or length > bytes.size() - 20:
		return {"error": I18n.t("err_corrupt")}
	var json: Variant = JSON.parse_string(bytes.slice(20, 20 + length).get_string_from_utf8())
	if not json is Dictionary:
		return {"error": I18n.t("err_no_info")}
	var extensions: Dictionary = json.get("extensions", {})
	if not extensions.has("VRM") and not extensions.has("VRMC_vrm"):
		return {"error": I18n.t("err_vrm_version")}
	for kind in ["buffers", "images"]:
		for item in json.get(kind, []):
			var uri: String = item.get("uri", "")
			if not uri.is_empty() and not uri.begins_with("data:"):
				return {"error": I18n.t("err_no_image")}
	return {"version": "1.0" if extensions.has("VRMC_vrm") else "0.x"}

static func load_model(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": I18n.t("err_open_again")}
	if file.get_length() > MAX_BYTES:
		return {"error": I18n.t("err_too_big")}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var result := inspect_bytes(bytes)
	if result.has("error"):
		return result
	var doc := GLTFDocument.new()
	var extensions: Array[GLTFDocumentExtension] = [Vrm0.new(), Vrm1.new(), Constraint.new(), Spring.new(), Emissive.new(), Mtoon.new()]
	for extension in extensions:
		GLTFDocument.register_gltf_document_extension(extension, true)
	var state := GLTFState.new()
	state.set_additional_data(&"vrm/head_hiding_method", 3) # BothLayers, keep facial bindings valid
	state.set_additional_data(&"vrm/first_person_layers", 1)
	state.set_additional_data(&"vrm/third_person_layers", 1 << 19)
	var error := doc.append_from_buffer(bytes, "", state, 8)
	var model: Node3D = null
	if error == OK:
		model = doc.generate_scene(state)
	for extension in extensions:
		GLTFDocument.unregister_gltf_document_extension(extension)
	if model == null:
		return {"error": I18n.t("err_load_avatar")}
	result.model = model
	return result
