extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var result = preload("res://scripts/vrm_loader.gd").load_model("res://avatars/Godette.vrm")
	if result.has("error"):
		printerr(result.error)
		quit(1)
		return
	var model: Node3D = result.model
	root.add_child(model)
	model.print_tree_pretty()
	var skeleton: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	print("META ", model.get("vrm_meta"))
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) in ["Head", "LeftEye", "RightEye", "Hips", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightHand"]:
			print(skeleton.get_bone_name(i), " ", skeleton.get_bone_global_rest(i))
	await process_frame
	model.queue_free()
	await process_frame
	quit()
