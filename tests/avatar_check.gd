extends SceneTree
const Rig = preload("res://scripts/avatar_rig.gd")
const Loader = preload("res://scripts/vrm_loader.gd")
var failed := false
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("AVATAR_CHECK_FAILED: ", message)
func run():
	var rig := Rig.new()
	root.add_child(rig)
	var model_path := "res://avatars/Godette.vrm"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--model="):
			model_path = argument.trim_prefix("--model=")
	check(rig.load_avatar(model_path), "model must load")
	if not rig.is_loaded():
		quit(1)
		return
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))
	var hands: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-0.24, 1.16, -0.30)), Transform3D(Basis.IDENTITY, Vector3(0.24, 1.16, -0.30))]
	var tracked: Array[bool] = [true, true]
	rig.update_pose(head, hands, tracked, 1.0 / 90.0)
	for i in 2:
		var name := "LeftHand" if i == 0 else "RightHand"
		var actual: Transform3D = rig.hand_world_frame(i)
		print("PALM_ERROR: ", name, " ", actual.origin.distance_to(hands[i].origin))
		check(actual.origin.distance_to(hands[i].origin) < 0.025, "palm follows its own controller")
		check(actual.basis.y.dot(hands[i].basis.y) > 0.999, "back of hand follows controller top")
		check(actual.basis.z.dot(hands[i].basis.z) > 0.999, "fingers follow controller forward")
	var first_person_count := 0
	var hidden_count := 0
	for mesh in rig.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.layers & 1:
			first_person_count += 1
		if not mesh.layers & 1 and mesh.layers & (1 << 19):
			hidden_count += 1
	check(first_person_count > 0 and hidden_count > 0, "head and first-person body use separate layers")
	for frame in 180:
		head.basis = Basis.from_euler(Vector3(-0.7, sin(frame * 0.02) * 0.6, 0))
		head.origin.y = 0.8 # Seated on the floor.
		hands[0].origin = Vector3(-0.2, 0.5, -0.35)
		hands[1].origin = Vector3(0.2, 0.5, -0.35)
		rig.update_pose(head, hands, tracked, 1.0 / 90.0)
		var eye := rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(rig.bones.Head) * rig.eye_from_head)
		check(eye.distance_to(head.origin) < 0.001, "eyes follow seated and rotating head")
		for bone in rig.skeleton.get_bone_count():
			check(rig.skeleton.get_bone_global_pose(bone).is_finite(), "pose must stay finite")
	var old_model := rig.model
	check(not rig.load_avatar("res://project.godot"), "non-VRM must fail")
	check(rig.model == old_model, "failed load must preserve old model")
	check(Loader.inspect_bytes(PackedByteArray([1, 2, 3])).has("error"), "truncated file must fail")
	check(not rig.load_avatar("user://missing-avatar.vrm"), "missing file must fail")
	check(rig.model == old_model, "missing file must preserve old model")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--vrm1="):
			check(rig.load_avatar(argument.trim_prefix("--vrm1=")), "VRM 1.0 fixture must load")
			rig.update_pose(head, hands, tracked, 1.0 / 90.0)
			check(rig.skeleton.get_bone_global_pose(rig.bones.Head).is_finite(), "VRM 1.0 pose remains finite")
	rig.unload_avatar()
	check(not rig.is_loaded(), "unload restores default hands")
	rig.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("AVATAR_CHECK_OK: VRM import, first-person layers, grip IK, seated eyes, invalid-file rollback")
	quit(1 if failed else 0)
