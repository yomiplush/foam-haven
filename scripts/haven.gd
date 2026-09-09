extends Node3D

const Worlds = preload("res://scripts/worlds.gd")
const HavenMenu = preload("res://scripts/haven_menu.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const AvatarRig = preload("res://scripts/avatar_rig.gd")
const AvatarLibrary = preload("res://scripts/avatar_library.gd")
const AvatarMirror = preload("res://scripts/avatar_mirror.gd")
const BubbleMotion = preload("res://scripts/bubble_motion.gd")
const FloatingLayout = preload("res://scripts/floating_layout.gd")
const FloatingGarden = preload("res://scripts/floating_garden.gd")
const MixedReality = preload("res://scripts/mixed_reality.gd")
const HandInput = preload("res://scripts/hand_input.gd")
const MR_WORLD := 5
var worlds = Worlds.new()
var world: Node3D
var environment: Environment
var sun: DirectionalLight3D
var origin: XROrigin3D
var camera: XRCamera3D
var controllers: Array[XRController3D] = []
var xr: XRInterface
var xr_active := false
var focused := true
var clock := 0.0
var next_performance_log := 10.0
var drift_clock := 0.0
var drift := false
var scene_index := 3
var balloon_mode := false
var membrane_visible := true
var sound_on := true
var bubble: MeshInstance3D
var bubble_mat: ShaderMaterial
var outer_bubble: MeshInstance3D
var outer_mat: ShaderMaterial
var press_depth := [0.0, 0.0]
var press_velocity := [0.0, 0.0]
var outer_press_depth := [0.0, 0.0]
var outer_press_velocity := [0.0, 0.0]
var goo := [0.0, 0.0]
var goo_velocity := [0.0, 0.0]
var haptic_clock := [0.0, 0.0]
var press_target := [0.0, 0.0]
var press_points := [Vector3(-0.5, 0, -0.8).normalized(), Vector3(0.5, 0, -0.8).normalized()]
var pressing := [false, false]
var desktop_press := false
var previous_rub_points := [Vector3.ZERO, Vector3.ZERO]
var previous_rub_depth := [0.0, 0.0]
var bubble_anchor := Vector3(0, 1.35, 0)
var bubble_radius := 0.76
var menu: Node3D
var menu_open := true
var menu_size := HavenMenu.SIZE
var menu_pixels := HavenMenu.PIXELS
var pointer_ray: MeshInstance3D
var pointer_dot: MeshInstance3D
var controller_visuals: Array[Node3D] = []
var chest_ribbon: Node3D
# Per-side input resolved each frame from a Touch controller or, when the
# controller is set down, from the Quest optical hand tracker.
var side_tracked := [false, false]
var side_controller := [false, false]
var side_handed := [false, false]
var side_pos := [Vector3.ZERO, Vector3.ZERO]
var side_palm_tr := [Transform3D.IDENTITY, Transform3D.IDENTITY]
var side_origin := [Vector3.ZERO, Vector3.ZERO]
var side_dir := [Vector3.ZERO, Vector3.ZERO]
var side_basis := [Basis.IDENTITY, Basis.IDENTITY]
var side_grip := [0.0, 0.0]
var side_pinch := [0.0, 0.0]
var prev_pinch := [0.0, 0.0]
var pinch_edge := [false, false]
var pinch_started := [-9.0, -9.0]
var pinch_ignore := 0.0
var hand_joints := [{}, {}]
var next_hand_log := 0.0
var fade_mat: StandardMaterial3D
var fade_surface: MeshInstance3D
var transitioning := false
var soundscape: Node
var ripple := 0.0
var touch_cooldown := 0.0
var spawn_cooldown := 0.0
var spawned: Array[Dictionary] = []
var pointer_controller := 1
var demo_mode := false
var stroll_offset := Vector3.ZERO
var stroll_velocity := Vector3.ZERO
var avatar: Node3D
var avatar_grips: Array[XRController3D] = []
var avatar_loading := false
var avatar_picker: FileDialog
var mirror: Node3D
var calibration_pending := false
var garden: Node3D
var mr_membrane := true
var mr_motion := true
var last_vr_world := 3
var mr_preview := false
var wrist_ribbons := true
var ribbons: Array[Node3D] = []

func _ready():
	demo_mode = "--capture" in OS.get_cmdline_user_args()
	mr_preview = demo_mode or "--smoke-test" in OS.get_cmdline_user_args() or "--mr-preview" in OS.get_cmdline_user_args()
	_load_preferences()
	_make_rig()
	_make_environment()
	_make_bubble()
	_make_menu()
	_make_audio()
	_make_avatar_system()
	garden = FloatingGarden.new()
	add_child(garden)
	garden.configure(worlds)
	garden.touched.connect(_garden_touched)
	_switch_world(scene_index)
	_place_menu()
	_update_ui()
	if demo_mode:
		_capture_scenes.call_deferred()
	elif "--smoke-test" in OS.get_cmdline_user_args():
		_smoke_test.call_deferred()
	else:
		_restore_avatar.call_deferred()
	if "--mr" in OS.get_cmdline_user_args():
		_switch_world(MR_WORLD)

func _make_rig():
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.05
	camera.set_cull_mask_value(20, false)
	camera.far = 180.0
	origin.add_child(camera)
	xr = XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		xr_active = true
		print("FOAM_XR_INITIALIZED: ", xr.get_name())
		get_viewport().use_xr = true
		xr.connect("session_begun", _configure_xr_quality)
		xr.connect("refresh_rate_changed", func(rate: float): print("FOAM_REFRESH_HZ: ", rate))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if xr.has_signal("session_focussed"):
			xr.connect("session_focussed", _focus_gained)
			xr.connect("session_visible", _focus_lost)
			xr.connect("session_stopping", _focus_lost)
		if xr.has_signal("pose_recentered"):
			xr.connect("pose_recentered", _recenter)
	else:
		camera.position = Vector3(0, 1.6, 0)
		camera.fov = 80
	for i in 2:
		var c := XRController3D.new()
		c.tracker = "left_hand" if i == 0 else "right_hand"
		c.pose = "aim"
		origin.add_child(c)
		controllers.append(c)
		c.button_pressed.connect(_controller_button.bind(i))
		var visual := Node3D.new()
		c.add_child(visual)
		_make_plush_paw(visual, i)
		controller_visuals.append(visual)
	pointer_dot = worlds.sphere(self, Vector3.ZERO, Vector3.ONE * 0.008, worlds.material(Color("c1fff0"), 0.8), 16)
	pointer_dot.visible = false
	pointer_dot.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pointer_dot.material_override.no_depth_test = true
	pointer_dot.material_override.render_priority = 110
	var ray_mat := worlds.material(Color(0.67, 0.9, 0.8, 0.28))
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pointer_ray = worlds.tube(self, Vector3.ZERO, Vector3.UP, 0.0012, ray_mat)
	pointer_ray.visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	fade_mat = StandardMaterial3D.new()
	fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_mat.no_depth_test = true
	fade_mat.render_priority = 127
	fade_mat.albedo_color = Color(0.025, 0.045, 0.08, 0)
	fade_surface = worlds.mesh_node(camera, quad, Vector3(0, 0, -0.08), Vector3.ONE, fade_mat)
	fade_surface.hide()

func _configure_xr_quality():
	if not xr_active:
		return
	var rates: Array = xr.get_available_display_refresh_rates()
	if 90.0 in rates:
		xr.set_display_refresh_rate(90.0)
	Engine.physics_ticks_per_second = 90
	print("FOAM_QUALITY: requested_hz=90 available=", rates, " msaa=4 foveation=dynamic/high")

func _make_environment():
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var e := WorldEnvironment.new()
	e.environment = environment
	add_child(e)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -32, 0)
	sun.light_color = Color("ffe5d0")
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 22.0
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 1.2
	sun.shadow_opacity = 0.32
	add_child(sun)

func _switch_world(index: int):
	index = posmod(index, 6)
	if index == MR_WORLD and not MixedReality.supported(xr):
		if not mr_preview:
			if is_instance_valid(menu):
				menu.status.text = I18n.t("mr_unavailable")
			if is_instance_valid(world):
				return
			index = last_vr_world
		else:
			print("FOAM_MR_PREVIEW: synthetic background; no camera passthrough")
	if not (index == MR_WORLD and mr_preview and not MixedReality.supported(xr)):
		if not MixedReality.apply(xr, get_viewport(), environment, index == MR_WORLD):
			menu.status.text = I18n.t("mr_unavailable")
			return
	scene_index = index
	if scene_index != MR_WORLD:
		last_vr_world = scene_index
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	for entry in spawned:
		entry.node.queue_free()
	spawned.clear()
	world = worlds.build(scene_index)
	add_child(world)
	var palette_index := mini(scene_index, 4)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = [Color("073750"), Color("737ea9"), Color("8a92b1"), Color("b7a4ba"), Color("b8a6df")][palette_index]
	sky_mat.sky_horizon_color = [Color("348d9f"), Color("f8c8b5"), Color("f9dacc"), Color("ffe1c5"), Color("ffe0ef")][palette_index]
	sky_mat.ground_bottom_color = [Color("092d43"), Color("9c91ba"), Color("c3adc5"), Color("b9a4a5"), Color("e7b6d7")][palette_index]
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.sky_curve = 0.22
	var sky_resource := Sky.new()
	sky_resource.sky_material = sky_mat
	environment.sky = sky_resource
	environment.ambient_light_color = [Color("75bdc9"), Color("e6cddd"), Color("e4d1dc"), Color("ffe1ce"), Color("f5deef")][palette_index]
	environment.ambient_light_energy = 0.40 if scene_index >= 2 else 0.52
	sun.light_energy = 0.60 if scene_index >= 2 else 0.85
	# Analytic floor contact shadows stay soft and stable in both eyes. Avoid
	# re-rendering the entire toy collection into a mobile shadow map.
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-48, -155, 0) if scene_index >= 2 else Vector3(-36,-32,0)
	sun.light_color = [Color("ccebe4"), Color("ffe1c3"), Color("ffe2c4"), Color("ffe5cf"), Color("fff1df")][palette_index]
	environment.fog_enabled = scene_index == 0
	environment.fog_light_color = Color("256f86")
	environment.fog_density = 0.011
	environment.fog_sky_affect = 0.45
	origin.position = Vector3.ZERO
	stroll_offset = Vector3.ZERO
	stroll_velocity = Vector3.ZERO
	drift_clock = 0.0
	drift = false
	_recenter()
	if is_instance_valid(mirror) and mirror.enabled:
		mirror.place(camera.global_transform)
	_update_audio()
	_update_ui()

func _make_bubble():
	bubble_mat = ShaderMaterial.new()
	bubble_mat.shader = load("res://shaders/soap.gdshader")
	bubble_mat.set_shader_parameter("opacity", 0.85)
	bubble_mat.set_shader_parameter("gel", 1.0)
	bubble = worlds.sphere(self, bubble_anchor, FloatingLayout.INNER_AXES, bubble_mat, 96, 32)
	bubble.name = "YourBubble"
	outer_mat = bubble_mat.duplicate()
	outer_mat.set_shader_parameter("shell_layer", 1.0)
	outer_bubble = worlds.sphere(self, bubble_anchor, FloatingLayout.OUTER_AXES, outer_mat, 96, 32)
	outer_bubble.name = "ThickTransparentOuterMembrane"

func _make_menu():
	menu = HavenMenu.new()
	add_child(menu)
	menu.action_requested.connect(_menu_action)

func _menu_action(action: StringName, index: int):
	if not focused or transitioning or avatar_loading:
		return
	soundscape.play_confirm()
	match action:
		&"travel": _travel(index)
		&"mode": _toggle_mode()
		&"skin": _toggle_skin()
		&"drift": _toggle_drift()
		&"sound": _toggle_sound()
		&"lang_changed":
			_save_preferences()
			_update_ui()
		&"close": _toggle_menu()
		&"avatar_open", &"avatar_refresh": _show_avatars()
		&"avatar_select":
			if index >= 0 and index < menu.avatar_entries.size():
				_load_avatar_file(menu.avatar_entries[index].path)
		&"avatar_import": _choose_avatar_file()
		&"avatar_calibrate": _calibrate_avatar()
		&"avatar_recenter":
			avatar.calibrate(camera.global_transform)
			mirror.place(camera.global_transform)
			menu.avatar_note.text = I18n.t("note_eye_centered")
		&"mirror": _toggle_mirror()
		&"ribbons":
			wrist_ribbons = not wrist_ribbons
			_save_preferences()
			_update_ui()
		&"expression":
			avatar.gentle_expression = not avatar.gentle_expression
			_save_avatar()
			_update_ui()
		&"avatar_smaller", &"avatar_larger":
			avatar.size_multiplier = clampf(avatar.size_multiplier + (-0.05 if action == &"avatar_smaller" else 0.05), 0.5, 1.5)
			avatar.calibrate(camera.global_transform)
			_save_avatar()
			menu.avatar_note.text = I18n.tf("note_size_pct", [roundi(avatar.size_multiplier * 100)])

func _place_menu():
	var forward := -camera.global_basis.z
	forward.y = 0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	menu.global_position = camera.global_position + forward * 1.30 + Vector3(0, -0.08, 0)
	menu.look_at(menu.global_position + forward, Vector3.UP)

func _update_ui():
	if not is_instance_valid(menu):
		return
	var skin_visible := mr_membrane if scene_index == MR_WORLD else membrane_visible
	menu.update_state(scene_index, balloon_mode, skin_visible, mr_motion if scene_index == MR_WORLD else drift, sound_on)
	menu.update_mr_support(MixedReality.supported(xr) or mr_preview)
	if is_instance_valid(avatar) and is_instance_valid(mirror):
		menu.update_avatar_tools(mirror.enabled, wrist_ribbons, avatar.gentle_expression)
	bubble_mat.set_shader_parameter("latex", 1.0 if balloon_mode else 0.0)
	outer_mat.set_shader_parameter("latex", 1.0 if balloon_mode else 0.0)
	for mat in [bubble_mat, outer_mat]:
		mat.set_shader_parameter("tint", Color("ff80b5") if balloon_mode else Color("b8f0ff"))
	bubble.visible = skin_visible and not menu_open
	outer_bubble.visible = bubble.visible

func _make_audio():
	soundscape = Soundscape.new()
	add_child(soundscape)

func _update_audio():
	soundscape.select(scene_index, sound_on, focused)

func _clear_interaction():
	desktop_press = false
	pressing.fill(false)
	press_target.fill(0.0)
	_set_hover(null)
	pointer_dot.visible = false
	pointer_ray.visible = false
	if is_instance_valid(garden):
		garden.clear_interaction()
func _toggle_mode():
	balloon_mode = not balloon_mode
	_update_ui()
	_save_preferences()

func _toggle_skin():
	_clear_interaction()
	if scene_index == MR_WORLD:
		mr_membrane = not mr_membrane
	else:
		membrane_visible = not membrane_visible
	_update_ui()
	_save_preferences()

func _toggle_drift():
	if transitioning or not focused:
		return
	if scene_index == MR_WORLD:
		mr_motion = not mr_motion
		garden.floating = mr_motion
		_update_ui()
		_save_preferences()
		return
	if not drift and menu_open:
		_toggle_menu()
	drift = not drift
	_update_ui()

func _toggle_sound():
	sound_on = not sound_on
	_update_audio()
	_update_ui()
	_save_preferences()

func _toggle_menu():
	menu_open = not menu_open
	_clear_interaction()
	menu.show_menu(menu_open)
	if menu_open:
		drift = false
		_place_menu()
	_update_ui()

func _travel(index: int):
	if transitioning or index == scene_index:
		return
	if index == MR_WORLD and not MixedReality.supported(xr) and not mr_preview:
		menu.status.text = I18n.t("mr_unavailable")
		return
	transitioning = true
	fade_surface.show()
	_clear_interaction()
	drift = false
	var tween := create_tween()
	tween.tween_property(fade_mat, "albedo_color:a", 1.0, 0.35)
	await tween.finished
	_switch_world(index)
	_recenter()
	_save_preferences()
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(fade_mat, "albedo_color:a", 0.0, 0.55)
	await tween.finished
	transitioning = false
	fade_surface.hide()

func _recenter(rebuild_garden: bool = true):
	# Never alter the runtime's tracked head pose. Move the enclosing sphere instead.
	bubble_anchor = camera.position + stroll_offset - Vector3(0, 0.25, 0)
	bubble.position = origin.position - stroll_offset + bubble_anchor
	outer_bubble.position = bubble.position
	_update_floating_layout()
	if rebuild_garden and is_instance_valid(garden):
		garden.populate(camera.global_transform, scene_index == MR_WORLD)
		garden.floating = mr_motion if scene_index == MR_WORLD else true
	if menu_open:
		_place_menu()
	if rebuild_garden and is_instance_valid(mirror) and mirror.enabled:
		mirror.place(camera.global_transform)

func _update_floating_layout():
	var orientation := FloatingLayout.shell_basis(clock)
	bubble.basis = orientation.scaled_local(FloatingLayout.INNER_AXES)
	outer_bubble.basis = orientation.scaled_local(FloatingLayout.OUTER_AXES)
	if is_instance_valid(world) and scene_index != MR_WORLD:
		world.position = Vector3(bubble_anchor.x, FloatingLayout.scenery_height(bubble_anchor.y), bubble_anchor.z)

func _garden_touched(hand: int, strength: float):
	if xr_active and side_controller[hand]:
		controllers[hand].trigger_haptic_pulse("haptic", 0.0, 0.10 + strength * 0.22, 0.09, 0.0)

func _focus_lost():
	focused = false
	_clear_interaction()
	drift = false
	_update_audio()
	_update_ui()
	if is_instance_valid(mirror):
		mirror.update_reflection(camera.global_transform, xr, origin.global_transform, false)

func _focus_gained():
	focused = true
	print("FOAM_SESSION_FOCUSED")
	drift = false
	_recenter(scene_index != MR_WORLD or clock < 1.2)
	_update_audio()
	_update_ui()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(soundscape):
		_focus_lost()
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(soundscape) and not xr_active:
		_focus_gained()

func _controller_button(action: StringName, hand: int):
	if not focused or transitioning:
		return
	pointer_controller = hand
	match action:
		"ax_button": _toggle_drift()
		"by_button", "menu_button": _toggle_menu()
		"primary_click": _recenter()
		"trigger_click":
			_update_pointer(hand)
			if menu_open:
				_activate_hover()
			else:
				_spawn_bubble(controllers[hand].global_position, -controllers[hand].global_basis.z)

func _hand_tracker(i: int) -> XRHandTracker:
	if not xr_active:
		return null
	var tracker := XRServer.get_tracker("/user/hand_tracker/left" if i == 0 else "/user/hand_tracker/right")
	if tracker is XRHandTracker:
		return tracker
	return null

## Resolve what each hand is doing this frame. A tracked Touch controller
## always wins; when it is set down the Quest hand tracker takes over with
## pinch/grasp gestures read straight from the finger joints.
func _sync_hands():
	for i in 2:
		side_controller[i] = xr_active and controllers[i].get_has_tracking_data()
		pinch_edge[i] = false
		side_pinch[i] = 0.0
		if side_controller[i]:
			var frame: Transform3D = controllers[i].global_transform
			side_tracked[i] = true
			side_handed[i] = false
			side_pos[i] = frame.origin
			side_palm_tr[i] = frame
			side_origin[i] = frame.origin
			side_dir[i] = -frame.basis.z
			side_basis[i] = frame.basis.orthonormalized()
			side_grip[i] = controllers[i].get_float("grip")
			prev_pinch[i] = 0.0
		else:
			side_tracked[i] = false
			side_handed[i] = false
			var tracker := _hand_tracker(i)
			if tracker == null:
				continue
			var joints := HandInput.world_joints(origin, tracker)
			if joints.is_empty():
				continue
			side_tracked[i] = true
			side_handed[i] = true
			hand_joints[i] = joints
			var aim := HandInput.aim_pose(joints)
			side_pos[i] = HandInput.touch_point(joints)
			side_palm_tr[i] = HandInput.avatar_frame(joints, i == 0)
			side_origin[i] = aim.origin
			side_dir[i] = aim.dir
			side_basis[i] = aim.basis
			side_grip[i] = HandInput.grasp(joints)
			side_pinch[i] = HandInput.pinch(joints)
			if side_pinch[i] > 0.6 and prev_pinch[i] <= 0.6:
				pinch_edge[i] = true
		prev_pinch[i] = side_pinch[i]
	if xr_active and (side_handed[0] or side_handed[1]) and clock >= next_hand_log:
		next_hand_log = clock + 15.0
		print("FOAM_HAND: left=", side_handed[0], " right=", side_handed[1], " lp=", side_palm_tr[0].origin, " rp=", side_palm_tr[1].origin)

## Discrete actions have no controller buttons in hand mode, so gestures stand
## in: a single pinch selects or makes a bubble; pinching both hands at once
## re-opens the menu. Controller clicks keep their normal buttons.
func _hand_pinch_actions(delta: float):
	if not xr_active or not (side_handed[0] or side_handed[1]):
		pinch_ignore = 0.0
		return
	pinch_ignore = maxf(0.0, pinch_ignore - delta)
	var fresh: Array[int] = []
	for i in 2:
		if pinch_edge[i]:
			pinch_started[i] = clock
			fresh.append(i)
	# Two pinches that land close together open the menu again. The second hand
	# joining an ongoing pinch counts too, so no single-pinch action fires.
	if not menu_open and pinch_ignore <= 0.0 and fresh.size() > 0:
		for hand in fresh:
			var other := 1 - hand
			if side_handed[other] and side_pinch[other] > 0.6 and clock - pinch_started[other] <= 0.35:
				pinch_ignore = 0.45
				for j in fresh:
					pinch_edge[j] = false
				_toggle_menu()
				return
	if fresh.size() == 1 and pinch_ignore <= 0.0:
		var hand: int = fresh[0]
		pointer_controller = hand
		_update_pointer(hand)
		if menu_open:
			_activate_hover()
		else:
			_spawn_bubble(side_origin[hand], side_dir[hand])

func _process(delta: float):
	if not focused:
		return
	clock += delta
	if OS.has_feature("android") and clock >= next_performance_log:
		next_performance_log = clock + 15.0
		print("FOAM_PERF: world=", scene_index, " fps=", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " mirror=", mirror.enabled, " mr=", scene_index == MR_WORLD)
	worlds.update(clock)
	origin.position -= stroll_offset
	if drift and not transitioning and scene_index != MR_WORLD:
		drift_clock += delta
		# Bounded 8 cm vertical, 5 cm lateral drift; no camera rotation or forced travel.
		origin.position = Vector3(sin(drift_clock * 0.14) * 0.05, sin(drift_clock * 0.22) * 0.08, 0)
	var stick := Vector2.ZERO
	if not menu_open and not transitioning and scene_index != MR_WORLD:
		if xr_active and controllers[0].get_has_tracking_data():
			stick = controllers[0].get_vector2("primary")
		elif not xr_active:
			stick = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
		_step_stroll(delta, stick)
	else:
		stroll_velocity = Vector3.ZERO
	origin.position += stroll_offset
	if xr_active and clock < 1.2:
		_recenter(false)
	bubble.position = origin.position - stroll_offset + bubble_anchor
	_update_floating_layout()
	bubble_mat.set_shader_parameter("clock", clock)
	outer_bubble.position = bubble.position
	outer_mat.set_shader_parameter("clock", clock)
	ripple = move_toward(ripple, 0.0, delta * 0.6)
	bubble_mat.set_shader_parameter("touch_amount", ripple)
	outer_mat.set_shader_parameter("touch_amount", ripple)
	touch_cooldown = maxf(0, touch_cooldown - delta)
	spawn_cooldown = maxf(0, spawn_cooldown - delta)
	_sync_hands()
	_hand_pinch_actions(delta)
	_update_avatar_pose(delta)
	_update_ribbons()
	_step_garden(delta)
	mirror.update_reflection(camera.global_transform, xr, origin.global_transform, focused and avatar.is_loaded() and not menu_open and not transitioning)
	for i in controllers.size():
		controller_visuals[i].visible = xr_active and side_controller[i] and not avatar.is_loaded()
		press_target[i] = 0.0
		if xr_active and side_tracked[i] and bubble.visible and not transitioning:
			var local := bubble.to_local(side_pos[i])
			var reach := local.length()
			if reach > 0.72 and reach < 1.5:
				press_target[i] = clampf((reach - 0.72) * 0.8, 0.0, 0.22)
				press_points[i] = local.normalized()
			elif side_grip[i] > 0.1:
				press_points[i] = (bubble.global_basis.inverse() * side_dir[i]).normalized()
				press_target[i] = side_grip[i] * 0.20
			if press_target[i] > 0.025 and not pressing[i]:
				_touch(bubble.to_global(press_points[i]), i, true)
			# A steady hum while the membrane is held, deepening with pressure.
			if press_target[i] > 0.025 and side_controller[i]:
				haptic_clock[i] -= delta
				if haptic_clock[i] <= 0.0:
					var strength: float = clampf(press_target[i] / 0.20, 0.2, 1.0)
					controllers[i].trigger_haptic_pulse("haptic", 0.0, 0.10 + 0.25 * strength, 0.09, 0.0)
					haptic_clock[i] = 0.10 + 0.05 * (1.0 - strength)
		else:
			haptic_clock[i] = 0.0
		pressing[i] = press_target[i] > 0.025
	if not xr_active and desktop_press and bubble.visible and not transitioning:
		press_points[1] = (bubble.global_basis.inverse() * camera.project_ray_normal(get_viewport().get_mouse_position())).normalized()
		press_target[1] = 0.20
	if stroll_offset.length() > 0.16 and not menu_open:
		press_points[0] = (bubble.global_basis.inverse() * stroll_offset.normalized()).normalized()
		press_target[0] = maxf(press_target[0], (stroll_offset.length() - 0.16) * 1.4)
	_step_membrane(delta)
	var rub_motion := 0.0
	for i in 2:
		rub_motion = maxf(rub_motion, press_points[i].distance_to(previous_rub_points[i]) * 0.25 / maxf(delta, 0.001) + absf(press_depth[i] - previous_rub_depth[i]) / maxf(delta, 0.001))
		previous_rub_points[i] = press_points[i]
		previous_rub_depth[i] = press_depth[i]
	var pressure := maxf(press_target[0], press_target[1]) / 0.20
	soundscape.update_rubbing(delta, maxf(pressure, garden.pressure), maxf(rub_motion, garden.rub_motion), balloon_mode or garden.pressure > pressure)
	_update_pointer()
	_step_spawned_bubbles(delta)

func _step_spawned_bubbles(delta: float):
	for i in range(spawned.size() - 1, -1, -1):
		var entry: Dictionary = spawned[i]
		entry.age += delta
		if entry.age >= entry.lifetime:
			entry.node.queue_free()
			spawned.remove_at(i)
			soundscape.play_pop()
	var orientation := bubble.global_basis.orthonormalized()
	BubbleMotion.step(spawned, delta, FloatingLayout.INNER_AXES, orientation.inverse() * (camera.global_position-bubble.global_position))
	for entry in spawned:
		entry.node.global_position = bubble.global_position + orientation * entry.position
		entry.material.set_shader_parameter("clock", clock)
		var pop: float = clampf((entry.age-entry.lifetime+0.28)/0.28,0,1)
		entry.node.scale = Vector3.ONE * entry.radius * (1.0+pop*0.15)
		entry.material.set_shader_parameter("opacity", 1.0-pop)

func _touch(point: Vector3, hand: int, force: bool):
	if touch_cooldown > 0.0 or not bubble.visible or menu_open or not focused or transitioning:
		return
	var local := bubble.to_local(point)
	if not force and absf(local.length() - 1.0) > 0.10:
		return
	if local.length() < 0.01:
		local = Vector3.FORWARD
	bubble_mat.set_shader_parameter("touch_point", local.normalized())
	outer_mat.set_shader_parameter("touch_point", local.normalized())
	ripple = 1.0
	touch_cooldown = 0.5
	if xr_active and side_controller[hand]:
		controllers[hand].trigger_haptic_pulse("haptic", 0.0, 0.18, 0.06, 0.0)
	soundscape.play_touch(0.75 if balloon_mode else 1.2)

func _spawn_bubble(point: Vector3, direction: Vector3):
	if spawn_cooldown > 0 or spawned.size() >= BubbleMotion.MAX_BUBBLES or not focused or transitioning or menu_open:
		return
	spawn_cooldown = 0.3
	if scene_index == MR_WORLD:
		if garden.spawn(point, direction):
			soundscape.play_bubble()
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/small_bubble.gdshader")
	mat.set_shader_parameter("opacity", 1.0)
	mat.set_shader_parameter("latex", 0.8 if balloon_mode else 0.0)
	var radius := randf_range(0.055,0.095)
	var launch := direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	var n := worlds.sphere(self, point + launch * 0.12, Vector3.ONE * radius, mat, 20, 10)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var orientation := bubble.global_basis.orthonormalized()
	var entry := {"node": n, "material": mat, "position": orientation.inverse() * (n.global_position-bubble.global_position), "velocity": orientation.inverse() * (launch * 0.48 + Vector3.UP*0.035), "radius": radius, "age": 0.0, "lifetime": randf_range(22.0,32.0)}
	BubbleMotion.contain(entry, FloatingLayout.INNER_AXES)
	n.global_position = bubble.global_position + orientation * entry.position
	spawned.append(entry)
	soundscape.play_bubble()

func _update_pointer(pressed_hand: int = -1):
	pointer_dot.visible = false
	pointer_ray.visible = false
	if not menu_open or not focused or transitioning:
		_set_hover(null)
		return
	var hit: Dictionary = {}
	var from := Vector3.ZERO
	if xr_active:
		var candidates := [pressed_hand] if pressed_hand >= 0 else [pointer_controller, 1 - pointer_controller]
		for hand in candidates:
			if not side_tracked[hand]:
				continue
			from = side_origin[hand]
			hit = _menu_ray_hit(from, side_dir[hand])
			if not hit.is_empty():
				break
	else:
		var mouse := get_viewport().get_mouse_position()
		from = camera.project_ray_origin(mouse)
		hit = _menu_ray_hit(from, camera.project_ray_normal(mouse))
	if hit.is_empty():
		_set_hover(null)
		return
	_set_hover(menu.hit_test(hit.pixel))
	if xr_active:
		pointer_dot.global_position = hit.point
		pointer_dot.visible = true
		var axis: Vector3 = hit.point - from
		var up := axis.normalized()
		var right := up.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.01:
			right = up.cross(Vector3.RIGHT).normalized()
		pointer_ray.global_transform = Transform3D(Basis(right, up, right.cross(up)).scaled_local(Vector3(0.0012, axis.length(), 0.0012)), (from + hit.point) * 0.5)
		pointer_ray.visible = true

func _menu_ray_hit(from: Vector3, direction: Vector3) -> Dictionary:
	var local_from := menu.to_local(from)
	var local_direction := menu.global_basis.inverse() * direction
	if absf(local_direction.z) < 0.0001:
		return {}
	var distance := -local_from.z / local_direction.z
	if distance <= 0.0:
		return {}
	var hit := local_from + local_direction * distance
	var uv := Vector2(hit.x / menu_size.x + 0.5, 0.5 - hit.y / menu_size.y)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return {}
	return {"point": menu.to_global(hit + Vector3(0, 0, 0.009)), "pixel": uv * menu_pixels}

func _set_hover(button: Button):
	if is_instance_valid(menu):
		menu.set_hover(button)

func _activate_hover():
	if focused and not transitioning and menu_open:
		menu.activate()

func _unhandled_input(event: InputEvent):
	if xr_active or not focused or transitioning:
		return
	if event is InputEventKey and event.keycode == KEY_P:
		desktop_press = event.pressed
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.3, 1.3)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if menu_open:
			_update_pointer()
			_activate_hover()
		else:
			_spawn_bubble(camera.global_position, camera.project_ray_normal(event.position))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_M: _toggle_menu()
			KEY_SPACE: _toggle_drift()
			KEY_1: _travel(0)
			KEY_2: _travel(1)
			KEY_3: _travel(2)
			KEY_4: _travel(3)
			KEY_5: _travel(4)
			KEY_B: _toggle_mode()
			KEY_H: _toggle_skin()
			KEY_Q: _toggle_sound()
			KEY_R: _recenter()
			KEY_T: _touch(camera.global_position + -camera.global_basis.z, 0, true)

func _step_membrane(delta: float):
	# A damped spring gives a visible overshoot and a soft return after release.
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 180.0)
		for i in 2:
			press_velocity[i] += ((press_target[i] - press_depth[i]) * 68.0 - press_velocity[i] * 8.0) * step
			press_depth[i] += press_velocity[i] * step
			# The outer skin follows the inner skin with a softer, delayed spring.
			outer_press_velocity[i] += ((press_depth[i] * 0.82 - outer_press_depth[i]) * 52.0 - outer_press_velocity[i] * 10.0) * step
			outer_press_depth[i] += outer_press_velocity[i] * step
			# Keep a gap even during fast presses; the two skins must not cross.
			outer_press_depth[i] = maxf(outer_press_depth[i], press_depth[i] - 0.045)
			# A slow, soft follower turns a steady hold into a gooey push: the
			# membrane keeps yielding while touched, then wobbles back on release.
			var goo_target := clampf(press_target[i] / 0.20, 0.0, 1.0)
			goo_velocity[i] += ((goo_target - goo[i]) * 10.0 - goo_velocity[i] * 4.5) * step
			goo[i] = clampf(goo[i] + goo_velocity[i] * step, 0.0, 1.4)
		remaining -= step
	for mat in [bubble_mat, outer_mat]:
		mat.set_shader_parameter("press_left", press_points[0])
		mat.set_shader_parameter("press_right", press_points[1])
		mat.set_shader_parameter("goo_left", goo[0])
		mat.set_shader_parameter("goo_right", goo[1])
		var depths: Array = outer_press_depth if mat == outer_mat else press_depth
		mat.set_shader_parameter("depth_left", depths[0])
		mat.set_shader_parameter("depth_right", depths[1])

func _save_preferences():
	if demo_mode or "--smoke-test" in OS.get_cmdline_user_args():
		return
	var config := ConfigFile.new()
	config.set_value("haven", "scene", scene_index)
	config.set_value("haven", "balloon", balloon_mode)
	config.set_value("haven", "membrane", membrane_visible)
	config.set_value("haven", "sound", sound_on)
	config.set_value("haven", "lang", I18n.lang)
	config.set_value("haven", "mr_membrane", mr_membrane)
	config.set_value("haven", "mr_motion", mr_motion)
	config.set_value("haven", "last_vr_world", last_vr_world)
	config.set_value("haven", "ribbons", wrist_ribbons)
	config.save("user://preferences.cfg")

func _load_preferences():
	if demo_mode or "--smoke-test" in OS.get_cmdline_user_args():
		return
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		scene_index = clampi(int(config.get_value("haven", "scene", 3)), 0, 5)
		balloon_mode = bool(config.get_value("haven", "balloon", false))
		membrane_visible = bool(config.get_value("haven", "membrane", true))
		sound_on = bool(config.get_value("haven", "sound", true))
		mr_membrane = bool(config.get_value("haven", "mr_membrane", true))
		mr_motion = bool(config.get_value("haven", "mr_motion", true))
		last_vr_world = clampi(int(config.get_value("haven", "last_vr_world", 3)), 0, 4)
		wrist_ribbons = bool(config.get_value("haven", "ribbons", true))
		var saved_lang := str(config.get_value("haven", "lang", ""))
		if saved_lang in I18n.LANG_CODES:
			I18n.set_lang(saved_lang)

func _capture_scenes():
	drift = false
	for i in 5:
		_switch_world(i)
		menu.visible = false
		menu_open = false
		_update_ui()
		camera.rotation_degrees.x = -7
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://dist/preview_%d.png" % i)
		print("FOAM_CAPTURE: world=", i, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	balloon_mode = true
	_update_ui()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/preview_balloon_membrane.png")
	# Capture a sustained press from inside, including the delayed outer skin.
	set_process(false)
	press_points[1] = (bubble.global_basis.inverse() * -camera.global_basis.z).normalized()
	press_target[1] = 0.20
	for frame in 60:
		_step_membrane(1.0 / 90.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/preview_double_membrane_press.png")
	press_target[1] = 0.0
	set_process(true)
	balloon_mode = false
	_switch_world(0)
	camera.rotation = Vector3.ZERO
	menu.visible = true
	menu_open = true
	_update_ui()
	_place_menu()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/preview_menu.png")
	menu.viewport.get_texture().get_image().save_png("res://dist/preview_menu_detail.png")
	menu.main_page.visible = false
	menu.help_page.visible = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	menu.viewport.get_texture().get_image().save_png("res://dist/preview_help.png")
	if avatar.load_avatar(AvatarLibrary.SAMPLE):
		_show_avatars(I18n.t("sample_loaded"))
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		menu.viewport.get_texture().get_image().save_png("res://dist/preview_avatar_menu.png")
		menu.visible = false
		menu_open = false
		_switch_world(3)
		camera.rotation_degrees.x = -55
		avatar.calibrate(camera.global_transform)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://dist/preview_avatar_first_person.png")
		camera.position = Vector3(0, 0.82, 0)
		camera.rotation = Vector3.ZERO
		_recenter()
		avatar.calibrate(camera.global_transform)
		mirror.set_enabled(true)
		mirror.place(camera.global_transform)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://dist/preview_seated_mirror.png")
		mirror.viewports[0].get_texture().get_image().save_png("res://dist/preview_avatar_reflection.png")
		mirror.set_enabled(false)
		camera.rotation_degrees.x = -27
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://dist/preview_floating_seated.png")
		camera.rotation = Vector3.ZERO
		_switch_world(MR_WORLD)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://dist/preview_mr_layout_simulation.png")
	print("CAPTURE_OK")
	await _finish_checks()

func _smoke_test():
	await get_tree().process_frame
	assert(not drift, "Startup must be stationary")
	for frame in 900:
		_step_stroll(1.0 / 90.0, Vector2(0, 1))
	assert(stroll_offset.length() > 0.16 and stroll_offset.length() <= 0.24)
	assert(stroll_velocity.length() <= 0.0651)
	var edge_distance := stroll_offset.length()
	for frame in 900:
		_step_stroll(1.0 / 90.0, Vector2.ZERO)
	assert(stroll_offset.length() < edge_distance and stroll_offset.length() < 0.17, "Release must softly return from the membrane")
	stroll_offset = Vector3.ZERO
	stroll_velocity = Vector3.ZERO
	press_target[0] = 0.20
	for i in 90:
		_step_membrane(1.0 / 90.0)
	assert(press_depth[0] > 0.18 and press_depth[0] < 0.23, "Membrane must respond to sustained pressure")
	assert(outer_press_depth[0] > 0.14 and outer_press_depth[0] < press_depth[0], "Outer skin follows while the double membrane compresses")
	assert(goo[0] > 0.9, "Sustained touch must build the gooey follower")
	press_target[0] = 0.0
	var overshoot := false
	for i in 270:
		_step_membrane(1.0 / 90.0)
		overshoot = overshoot or press_depth[0] < 0.0
		assert(press_depth[0] - outer_press_depth[0] <= 0.0451, "Double membrane must retain a gap")
	assert(overshoot and absf(press_depth[0]) < 0.001, "Release must wobble and settle")
	assert(absf(outer_press_depth[0]) < 0.001, "Outer skin must also settle after release")
	assert(absf(goo[0]) < 0.001, "Gooey follower must also settle after release")
	for i in 5:
		_switch_world(i)
		assert(world.get_child_count() > 0)
		assert(world.find_children("*", "GeometryInstance3D", true, false).size() < 240, "World geometry must stay within the draw submission budget")
		if i == 2:
			assert(world.get_meta("clear_radius") == 3.0)
			for entry in worlds.animated:
				var home: Vector3 = entry.home
				assert(Vector2(home.x, home.z).length() - entry.amplitude >= 3.0, "Room motion must stay outside the quiet centre")
				assert(entry.amplitude <= 0.075 and entry.speed <= 0.14)
		await get_tree().process_frame
		worlds.update(12.0)
	_toggle_drift()
	assert(drift)
	var previous := origin.position
	_process(0.5)
	assert(origin.position != previous)
	_toggle_drift()
	previous = origin.position
	_process(1.0)
	assert(origin.position == previous, "Stopping must not snap the viewpoint")
	_toggle_drift()
	_focus_lost()
	assert(not drift and not focused)
	_focus_gained()
	assert(not drift and focused)
	_toggle_mode()
	assert(balloon_mode)
	_toggle_skin()
	assert(not bubble.visible)
	_toggle_skin()
	if menu_open:
		_toggle_menu()
	_spawn_bubble(Vector3.ZERO, Vector3.FORWARD)
	assert(spawned.size() == 1)
	_process(33.0)
	assert(spawned.is_empty())
	_recenter()
	assert(bubble_anchor.distance_to(camera.position - Vector3(0, 0.25, 0)) < 0.001)
	assert(menu.scene_buttons[0].get_global_rect().size.x > 0)
	for control in menu.buttons:
		assert(control.get_global_rect().end.y <= menu_pixels.y, "Menu content must fit")
		assert(control.get_global_rect().end.x <= menu_pixels.x, "Menu content must fit horizontally")
	# Input must not escape the menu, transitions, or focus boundary.
	if not menu_open:
		_toggle_menu()
	spawn_cooldown = 0.0
	_spawn_bubble(Vector3.ZERO, Vector3.FORWARD)
	assert(spawned.is_empty(), "Menu must block bubble spawning")
	_toggle_menu()
	desktop_press = true
	pressing[0] = true
	press_target[0] = 0.2
	_focus_lost()
	assert(not desktop_press and not pressing[0] and press_target[0] == 0.0)
	assert(not soundscape.audible and not soundscape.effects_playing())
	_spawn_bubble(Vector3.ZERO, Vector3.FORWARD)
	assert(spawned.is_empty(), "Unfocused input must be ignored")
	_focus_gained()
	transitioning = true
	_spawn_bubble(Vector3.ZERO, Vector3.FORWARD)
	assert(spawned.is_empty(), "Travel must block bubble spawning")
	transitioning = false
	soundscape.play_touch(1.0)
	soundscape.select(scene_index, false, true)
	assert(not soundscape.effects_playing(), "Mute must stop active effects")
	soundscape.select(0, true, true)
	await get_tree().create_timer(0.15).timeout
	var music_position: float = soundscape.players[2].get_playback_position()
	for destination in 5:
		soundscape.select(destination, true, true)
		assert(soundscape.players[2].playing and not soundscape.players[2].stream_paused)
		assert(soundscape.players[2].get_playback_position() >= music_position - 0.02, "Changing scenery must not restart the music box")
	await get_tree().create_timer(1.4).timeout
	for ambience in [soundscape.players[0], soundscape.players[1]]:
		assert(not ambience.playing or ambience.stream_paused, "Only the common music box should be audible")
	assert(not soundscape.players[2].stream_paused)
	assert(absf(soundscape.players[2].volume_linear - Soundscape.AMBIENT_GAIN) < 0.001)
	assert(bubble.mesh == outer_bubble.mesh, "Membranes share immutable geometry")
	soundscape.select(scene_index, true, true)
	soundscape.update_rubbing(0.1, 1.0, 0.5, true)
	assert(soundscape.rubber.playing and soundscape.rubber.volume_linear > 0.0)
	assert(soundscape.wet.playing and soundscape.wet.volume_linear > 0.0)
	for i in 120:
		soundscape.update_rubbing(1.0 / 90.0, 0.0, 0.0, true)
	assert(soundscape.rubber.stream_paused and soundscape.rubber.volume_linear == 0.0)
	soundscape.update_rubbing(0.1, 1.0, 0.5, false)
	soundscape.select(scene_index, true, false)
	assert(soundscape.rubber.stream_paused and soundscape.rubber.volume_linear == 0.0)
	soundscape.select(scene_index, true, true)
	assert(bubble.visible and outer_bubble.visible, "Both membrane layers must stay visible")
	# Both pages must route hits only to visible controls.
	if not menu_open:
		_toggle_menu()
	var guide: Button
	for control in menu.buttons:
		if control.get_meta("action") == &"help" and control.get_parent() == menu.main_page:
			guide = control
	assert(guide != null)
	menu.set_hover(guide)
	_activate_hover()
	assert(menu.help_page.visible and not menu.main_page.visible)
	var card_pixel: Vector2 = menu.scene_buttons[0].get_global_rect().get_center()
	assert(menu.hit_test(card_pixel) == null, "Hidden scene cards must not intercept guide input")
	var back: Button = menu.buttons.back()
	menu.set_hover(back)
	_activate_hover()
	assert(menu.main_page.visible and not menu.help_page.visible)
	assert(menu.hit_test(card_pixel) == menu.scene_buttons[0])
	var ray := _menu_ray_hit(camera.global_position, (menu.global_position - camera.global_position).normalized())
	assert(not ray.is_empty() and ray.pixel.distance_to(menu_pixels * 0.5) < 0.01)
	assert(_menu_ray_hit(camera.global_position, (camera.global_position - menu.global_position).normalized()).is_empty())
	print("SMOKE_OK: worlds, drift, focus, membrane, expiry, audio, menu pages, ray hits, shared geometry")
	await _finish_checks()

func _finish_checks():
	soundscape.shutdown()
	mirror.shutdown()
	# Detach generated sky and viewport textures while the render server is alive.
	environment.sky = null
	menu.hide()
	menu.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Allow audio and rendering servers to drain deferred resource releases.
	await get_tree().create_timer(0.1).timeout
	var tree := get_tree()
	tree.create_timer(0.2).timeout.connect(tree.quit)
	queue_free()

func _exit_tree():
	worlds.animated.clear()
	worlds.materials.clear()
	worlds.root = null

func _make_plush_paw(parent: Node3D, hand: int):
	var fur := worlds.material(Color("ead6c7")); fur.roughness = 0.98
	var pad := worlds.material(Color("d9a0b5")); pad.roughness = 0.90
	var seam := worlds.material(Color("ad8293"))
	worlds.sphere(parent, Vector3(0, 0, 0.025), Vector3(0.062, 0.048, 0.088), fur)
	worlds.sphere(parent, Vector3(0, -0.042, 0.013), Vector3(0.033, 0.008, 0.041), pad)
	for toe in 3:
		var p := Vector3((toe - 1) * 0.038, 0, -0.047)
		worlds.sphere(parent, p, Vector3(0.024, 0.04, 0.033), fur, 16)
		worlds.sphere(parent, p + Vector3(0, -0.034, 0), Vector3(0.014, 0.007, 0.018), pad, 16)
	for stitch in 5:
		worlds.tube(parent, Vector3(-0.007, 0.047, 0.005 + stitch * 0.011), Vector3(0.007, 0.047, 0.009 + stitch * 0.011), 0.0012, seam)
	var ribbon := worlds.sphere(parent, Vector3(0, 0.008, 0.091), Vector3(0.054, 0.042, 0.013), pad, 16)
	ribbon.name = "PlushGirlRibbonLeft" if hand == 0 else "PlushGirlRibbonRight"

func _step_stroll(delta: float, stick: Vector2):
	# Slow, bounded artificial movement only. Never write the tracked head pose.
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var drive := Vector3.ZERO
	if stick.length() > 0.18:
		stick = stick.limit_length(1.0)
		drive = (right * stick.x + forward * stick.y) * 0.16
	var remaining := minf(delta, 0.1)
	while remaining > 0:
		var step := minf(remaining, 1.0 / 180.0)
		var edge := maxf(0, stroll_offset.length() - 0.16)
		var spring := stroll_offset.normalized() * edge * 2.8
		stroll_velocity += (drive - spring - stroll_velocity * 2.8) * step
		stroll_velocity = stroll_velocity.limit_length(0.065)
		stroll_offset += stroll_velocity * step
		if stroll_offset.length() > 0.24:
			stroll_offset = stroll_offset.limit_length(0.24)
			stroll_velocity -= stroll_offset.normalized() * maxf(0, stroll_velocity.dot(stroll_offset.normalized()))
		remaining -= step

func _make_avatar_system():
	avatar = AvatarRig.new()
	add_child(avatar)
	mirror = AvatarMirror.new()
	add_child(mirror)
	for i in 2:
		var grip := XRController3D.new()
		grip.tracker = "left_hand" if i == 0 else "right_hand"
		grip.pose = "grip"
		origin.add_child(grip)
		avatar_grips.append(grip)
	_make_wrist_ribbons()
	_make_chest_bow()
	avatar_picker = FileDialog.new()
	avatar_picker.access = FileDialog.ACCESS_FILESYSTEM
	avatar_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	avatar_picker.use_native_dialog = true
	avatar_picker.title = I18n.t("picker_title")
	avatar_picker.filters = PackedStringArray(["*.vrm ; VRM Avatar"])
	add_child(avatar_picker)
	avatar_picker.file_selected.connect(_load_avatar_file)
	get_tree().root.files_dropped.connect(_avatar_files_dropped)

func _make_wrist_ribbons():
	var satin := worlds.fabric(Color("f2aacb"))
	var pearl := worlds.material(Color("fff1e8"), 0.04)
	for hand in 2:
		var ribbon := Node3D.new()
		ribbon.name = "LeftWristRibbon" if hand == 0 else "RightWristRibbon"
		add_child(ribbon)
		var cuff := TorusMesh.new()
		cuff.inner_radius = 0.024
		cuff.outer_radius = 0.032
		cuff.rings = 20
		cuff.ring_segments = 8
		var band := worlds.mesh_node(ribbon, cuff, Vector3.ZERO, Vector3.ONE, satin)
		band.rotation.x = PI * 0.5
		for side in [-1.0, 1.0]:
			var points := PackedVector3Array()
			for i in 21:
				var angle := TAU * i / 20.0
				points.append(Vector3(side * (1-cos(angle)) * 0.024, 0.032 + sin(angle)*0.014, sin(angle)*0.025))
			worlds.curve(ribbon, points, 0.007, satin, 6)
			worlds.curve(ribbon, PackedVector3Array([Vector3(0,0.034,0), Vector3(side*0.014,0.030,0.03), Vector3(side*0.022,0.012,0.06)]), 0.008, satin, 6, 0.65)
		worlds.sphere(ribbon, Vector3(0,0.037,0), Vector3.ONE*0.013, pearl, 16, 8)
		worlds._batch_geometry(ribbon)
		for geometry: GeometryInstance3D in ribbon.find_children("*", "GeometryInstance3D", true, false):
			geometry.layers = 1 | (1 << 19)
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbons.append(ribbon)

func _make_chest_bow():
	var bow := Node3D.new()
	bow.name = "ChestRibbonBow"
	add_child(bow)
	var satin := worlds.fabric(Color("f2aacb"))
	var satin_edge := worlds.fabric(Color("e79fc2"))
	var pearl := worlds.material(Color("fff1e8"), 0.05)
	# Two tall loops with their inner edges meeting at the knot in the middle.
	for side in [-1.0, 1.0]:
		var loop := PackedVector3Array()
		for i in 33:
			var t := TAU * float(i) / 32.0
			loop.append(Vector3(side * 0.06 + cos(t) * 0.092, 0.02 + sin(t) * 0.115, -0.012 - sin(t) * 0.010))
		worlds.curve(bow, loop, 0.020, satin, 6)
	# Short ribbon tails that splay down over the chest from the knot.
	for side in [-1.0, 1.0]:
		var tail := PackedVector3Array()
		for i in 13:
			var t := float(i) / 12.0
			tail.append(Vector3(side * 0.028 * t, -0.02 - t * 0.16, -0.02 + sin(t * 2.4 + side) * 0.012))
		worlds.curve(bow, tail, 0.015, satin, 5, 0.8)
	worlds.rounded_box(bow, Vector3(0, -0.01, -0.012), Vector3(0.075, 0.05, 0.035), satin_edge)
	worlds.sphere(bow, Vector3(0, -0.012, -0.02), Vector3(0.017, 0.017, 0.012), pearl, 16, 8)
	worlds._batch_geometry(bow)
	for geometry: GeometryInstance3D in bow.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = 1 | (1 << 19)
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chest_ribbon = bow

func _update_ribbons():
	for hand in 2:
		var ribbon := ribbons[hand]
		ribbon.visible = wrist_ribbons and not menu_open and (avatar.is_loaded() or (xr_active and avatar_grips[hand].get_has_tracking_data()))
		if not ribbon.visible:
			continue
		if avatar.is_loaded():
			var frame: Transform3D = avatar.hand_world_frame(hand)
			var bone: int = avatar.bones["LeftHand" if hand == 0 else "RightHand"]
			frame.origin = avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(bone).origin)
			ribbon.global_transform = frame
			ribbon.scale = Vector3.ONE * avatar.size_multiplier
		else:
			ribbon.global_transform = controllers[hand].global_transform
			ribbon.global_position = avatar_grips[hand].global_position + controllers[hand].global_basis.z * 0.065
	if not is_instance_valid(chest_ribbon):
		return
	chest_ribbon.visible = wrist_ribbons and not menu_open and avatar.is_loaded()
	if not chest_ribbon.visible:
		return
	var chest_world := Vector3.ZERO
	var bone: int = avatar.bones.get("Chest", avatar.bones.get("UpperChest", avatar.bones.get("Spine", -1)))
	if bone >= 0:
		chest_world = avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(bone).origin)
	chest_world.y += 0.01
	var forward := Basis(Vector3.UP, avatar.body_yaw).z
	var back := -forward
	var x := Vector3.UP.cross(back)
	chest_ribbon.global_transform = Transform3D(Basis(x, Vector3.UP, back), chest_world + forward * 0.035)
	chest_ribbon.scale = Vector3.ONE * avatar.size_multiplier

func _update_avatar_pose(delta: float):
	if not avatar.is_loaded():
		return
	var inputs := _avatar_hand_inputs()
	avatar.update_pose(camera.global_transform, inputs.hands, inputs.tracking, delta, inputs.gestures)

func _avatar_hand_inputs() -> Dictionary:
	var hands: Array[Transform3D] = []
	var tracking: Array[bool] = []
	var gestures: Array[Vector3] = []
	for i in 2:
		# Stable semantic identity even when the hands cross: 0=left, 1=right.
		if side_handed[i]:
			# Optical hand tracking: feed the palm pose and finger folds through
			# so the avatar's arms and fingers follow the real hand.
			hands.append(side_palm_tr[i])
			tracking.append(true)
			var joints: Dictionary = hand_joints[i]
			var index_curl := HandInput.finger_curl(joints, HandInput.FINGERS[0])
			var others := HandInput.other_curl(joints)
			var thumb := HandInput.thumb_curl(joints)
			gestures.append(Vector3(maxf(index_curl, 0.05), maxf(others, 0.05), maxf(thumb, 0.10)))
			continue
		# Grip supplies the palm position; aim's +Y follows the controller's upper face.
		var hand := avatar_grips[i].global_transform
		hand.basis = controllers[i].global_basis.orthonormalized()
		hands.append(hand)
		tracking.append(xr_active and avatar_grips[i].get_has_tracking_data() and controllers[i].get_has_tracking_data())
		var grip_value: float = controllers[i].get_float("grip")
		var trigger_value: float = controllers[i].get_float("trigger")
		var thumb_touch: bool = controllers[i].is_button_pressed("primary_touch") or controllers[i].is_button_pressed("ax_touch") or controllers[i].is_button_pressed("by_touch")
		gestures.append(Vector3(maxf(trigger_value, 0.13 if controllers[i].is_button_pressed("trigger_touch") else 0.04), maxf(grip_value, 0.12), 0.60 if thumb_touch else 0.13))
	return {"hands": hands, "tracking": tracking, "gestures": gestures}

func _step_garden(delta: float):
	var positions: Array[Vector3] = []
	var tracking: Array[bool] = []
	var grips: Array[float] = []
	for hand in 2:
		positions.append(side_palm_tr[hand].origin if side_handed[hand] else avatar_grips[hand].global_position)
		tracking.append(side_tracked[hand])
		grips.append(side_grip[hand])
	garden.step(delta, camera.global_position, positions, tracking, grips, not menu_open and not transitioning and focused)

func _toggle_mirror():
	if not avatar.is_loaded():
		_show_avatars(I18n.t("need_vrm_first"))
		return
	mirror.set_enabled(not mirror.enabled)
	if mirror.enabled:
		mirror.place(camera.global_transform)
		if menu_open:
			_toggle_menu()
	_update_ui()

func _calibrate_avatar():
	if not avatar.is_loaded() or calibration_pending:
		return
	calibration_pending = true
	var model_id: int = avatar.model.get_instance_id()
	mirror.set_enabled(true)
	mirror.place(camera.global_transform)
	if menu_open:
		_toggle_menu()
	for seconds in [5,4,3,2,1]:
		mirror.caption.text = I18n.tf("cal_countdown", [seconds])
		await get_tree().create_timer(1.0).timeout
		if not focused or not avatar.is_loaded() or avatar.model.get_instance_id() != model_id or menu_open:
			mirror.caption.text = I18n.t("cal_aborted")
			calibration_pending = false
			return
	var inputs := _avatar_hand_inputs()
	if avatar.fit_to_arms(camera.global_transform, inputs.hands, inputs.tracking):
		_save_avatar()
	mirror.caption.text = avatar.last_calibration_note
	calibration_pending = false

func _show_avatars(note: String = ""):
	menu.show_avatars(AvatarLibrary.entries(), avatar.display_name, note)
	menu.update_avatar_tools(mirror.enabled, wrist_ribbons, avatar.gentle_expression)

func _choose_avatar_file():
	if xr_active and not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		menu.avatar_note.text = I18n.t("pc_transfer")
		return
	avatar_picker.popup_centered_ratio(0.8)

func _avatar_files_dropped(files: PackedStringArray):
	if files.size() == 1 and files[0].get_extension().to_lower() == "vrm" and not avatar_loading:
		if not menu_open:
			_toggle_menu()
		_load_avatar_file(files[0])

func _load_avatar_file(path: String):
	if avatar_loading:
		return
	if path.is_empty():
		avatar.unload_avatar()
		mirror.set_enabled(false)
		_save_avatar()
		_show_avatars(I18n.t("back_to_plush"))
		return
	avatar_loading = true
	_show_avatars(I18n.t("loading_avatar"))
	await get_tree().process_frame
	await get_tree().process_frame
	var imported := AvatarLibrary.import_copy(path)
	if imported.has("error"):
		_show_avatars(imported.error)
	elif avatar.load_avatar(imported.path):
		avatar.calibrate(camera.global_transform)
		_save_avatar()
		_show_avatars(I18n.t("avatar_loaded"))
	else:
		_show_avatars(avatar.last_error)
	avatar_loading = false

func _save_avatar():
	if demo_mode or "--smoke-test" in OS.get_cmdline_user_args():
		return
	var config := ConfigFile.new()
	config.set_value("avatar", "path", avatar.current_path)
	config.set_value("avatar", "size", avatar.size_multiplier)
	config.set_value("avatar", "fitted_eye_height", avatar.fitted_eye_height)
	config.set_value("avatar", "gentle_expression", avatar.gentle_expression)
	config.save("user://avatar.cfg")

func _restore_avatar():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--avatar="):
			_load_avatar_file(arg.trim_prefix("--avatar="))
			return
	var config := ConfigFile.new()
	if config.load("user://avatar.cfg") == OK:
		avatar.size_multiplier = clampf(float(config.get_value("avatar", "size", 1.0)), 0.5, 1.5)
		avatar.fitted_eye_height = clampf(float(config.get_value("avatar", "fitted_eye_height", 1.55)),0.85,2.2)
		avatar.gentle_expression = bool(config.get_value("avatar", "gentle_expression", true))
		var path := str(config.get_value("avatar", "path", ""))
		if not path.is_empty():
			_load_avatar_file(path)
	else:
		_load_avatar_file(AvatarLibrary.SAMPLE)
