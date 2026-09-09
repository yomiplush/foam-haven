extends "res://scripts/haven.gd"
## Runs the actual app with isolated preferences: -- --smoke-test.
var failures: Array[String] = []

func verify(condition: bool, message: String):
	if not condition:
		failures.append(message)
		printerr("DREAM_CHECK_FAILED: ", message)

func _smoke_test():
	await get_tree().process_frame
	set_process(false)
	for destination in [2, 3, 4]:
		_switch_world(destination)
		for height in [0.48, 0.8, 1.1, 1.75]:
			camera.position = Vector3(2.8, height, -1.4)
			var tracked_pose := camera.transform
			_recenter()
			for sample in 40:
				clock = sample * 13.0
				_update_floating_layout()
				var bottom := bubble.position.y - FloatingLayout.support_height(FloatingLayout.OUTER_AXES * (1.0+FloatingLayout.MAX_DEFORMATION), outer_bubble.basis.orthonormalized()) - 0.08
				verify(bottom - world.position.y >= FloatingLayout.FLOOR_CLEARANCE, "tilted/deformed membrane clears floor at every seated height")
			verify(camera.transform == tracked_pose, "floating layout never writes tracked camera")
			verify(absf(world.position.x-camera.position.x) < 0.001, "recenter preserves wall clearance")
		await get_tree().process_frame
	camera.position = Vector3(0,0.8,0)
	_switch_world(MR_WORLD)
	verify(scene_index == MR_WORLD and world.get_child_count() == 0, "MR excludes virtual floors and walls")
	menu_open = false
	_update_ui()
	verify(bubble.visible and outer_bubble.visible, "MR wraps you in the enclosing membrane once the menu closes")
	var initial_origin := origin.transform
	_toggle_drift()
	for frame in 180:
		_process(1.0/90.0)
	verify(origin.transform == initial_origin, "MR controls never drift the physical viewpoint")
	verify(garden.toys.size() == 12, "MR starts with a bounded balloon garden")
	var hands: Array[Vector3] = [Vector3(-5,2,0), Vector3(5,2,0)]
	var tracking: Array[bool] = [false, false]
	var grips: Array[float] = [0.0,0.0]
	for seed_value in range(1, 31):
		garden.populate(camera.global_transform, true, seed_value)
		for frame in 90:
			garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
		for toy in garden.toys:
			verify(toy.node.position.is_finite(), "random layout stays finite")
			verify(toy.node.global_position.y - toy.radius*2.7 >= 0.099, "balloons and ribbons float above floor")
			verify(toy.node.global_position.distance_to(camera.global_position) >= toy.radius+0.24, "balloons leave breathing room around the head")
	var toy: Dictionary = garden.toys[0]
	hands[0] = toy.node.global_position + Vector3(toy.radius*0.6,0,0)
	tracking[0] = true
	garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
	grips[0] = 1.0
	garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
	verify(toy.holder == 0, "left hand can grab a nearby balloon")
	hands[0] += Vector3(-0.1,0.12,0)
	for frame in 45:
		garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
	verify(toy.squeeze > 0.25, "held balloon visibly compresses")
	verify(toy.node.global_position.distance_to(hands[0]+toy.offset) < 0.001, "held balloon follows hand without lag")
	garden.clear_interaction()
	garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
	verify(toy.holder == -1, "focus/menu release cannot re-grab while grip stays held")
	tracking[0] = false
	for frame in 270:
		garden.step(1.0/90.0, camera.global_position, hands, tracking, grips, true)
	verify(absf(toy.squeeze) < 0.001, "rubber settles after release")
	for i in 30:
		garden.spawn(Vector3(0,1.4,-0.6), Vector3.FORWARD)
	verify(garden.toys.size() == FloatingGarden.MAX_BALLOONS, "repeated spawning respects Quest geometry cap")
	# A non-passthrough runtime must leave rendering unchanged when asked for MR.
	var prior_background := environment.background_mode
	var prior_alpha := get_viewport().transparent_bg
	verify(not MixedReality.apply(null,get_viewport(),environment,true), "unsupported MR is rejected")
	verify(environment.background_mode == prior_background and get_viewport().transparent_bg == prior_alpha, "unsupported MR cannot leave a black transparent world")
	_switch_world(3)
	verify(scene_index == 3 and not get_viewport().transparent_bg, "VR restoration clears MR alpha")
	for language in I18n.LANG_CODES:
		I18n.set_lang(language)
		_update_ui()
		for control in menu.buttons:
			var rect: Rect2 = control.get_global_rect()
			verify(rect.end.x <= menu_pixels.x and rect.end.y <= menu_pixels.y, "six-language controls fit their panel")
		verify(menu.scene_buttons.size() == 6, "all languages expose MR")
	if failures.is_empty():
		print("DREAM_CHECK_OK: floor clearance, tilted shells, MR transitions, 30 random layouts, grabbing, focus release, spring settling, geometry cap, six languages")
	soundscape.shutdown()
	mirror.shutdown()
	get_tree().quit(0 if failures.is_empty() else 1)
