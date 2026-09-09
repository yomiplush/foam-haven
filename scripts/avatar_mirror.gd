extends Node3D
## Two eye reflections of the full avatar; no recursive world or membrane rendering.
const SIZE := Vector2(1.50, 1.90)
const AVATAR_LAYER := 1 << 19
var viewports: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var surface: MeshInstance3D
var material: ShaderMaterial
var caption: Label3D
var enabled := false
var stereo := false

func _ready():
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/mirror.gdshader")
	for eye in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(600, 760)
		viewport.msaa_3d = Viewport.MSAA_2X
		viewport.world_3d = get_viewport().world_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.positional_shadow_atlas_size = 0
		add_child(viewport)
		viewports.append(viewport)
		var camera := Camera3D.new()
		camera.cull_mask = AVATAR_LAYER
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("47334f")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("f2e7df")
		environment.ambient_light_energy = 0.65
		camera.environment = environment
		viewport.add_child(camera)
		cameras.append(camera)
		material.set_shader_parameter("left_eye" if eye == 0 else "right_eye", viewport.get_texture())
	var quad := QuadMesh.new()
	quad.size = SIZE
	surface = MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("efcbd9")
	trim.roughness = 0.5
	for side in [-1, 1]:
		_frame_piece(Vector3(side*(SIZE.x+0.035)*0.5,0,0.02), Vector3(0.035,SIZE.y+0.07,0.055), trim)
		_frame_piece(Vector3(0,side*(SIZE.y+0.035)*0.5,0.02), Vector3(SIZE.x+0.07,0.035,0.055), trim)
	caption = Label3D.new()
	caption.font = I18n.font()
	caption.text = I18n.t("mirror_caption")
	caption.font_size = 26
	caption.pixel_size = 0.0012
	caption.position = Vector3(0, SIZE.y*0.5+0.065,0.03)
	add_child(caption)
	I18n.language_changed.connect(func(_code): _refresh_language())
	hide()

func _refresh_language():
	if is_instance_valid(caption):
		caption.font = I18n.font()
		if caption.text in I18n.variants("mirror_caption") or caption.text.is_empty():
			caption.text = I18n.t("mirror_caption")

func _frame_piece(at: Vector3, dimensions: Vector3, mat: Material):
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func place(head: Transform3D):
	var forward := -head.basis.z
	forward.y = 0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	global_basis = Basis(forward.cross(Vector3.UP), Vector3.UP, -forward)
	global_position = head.origin + forward * 1.8
	global_position.y = head.origin.y - 0.30

func set_enabled(value: bool):
	enabled = value
	visible = value
	if not value:
		for viewport in viewports:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func update_reflection(head: Transform3D, xr: XRInterface, origin: Transform3D, active: bool):
	if not enabled:
		return
	stereo = xr != null and xr.is_initialized() and xr.get_view_count() == 2
	material.set_shader_parameter("stereo", stereo)
	var facing := (global_position - head.origin).normalized().dot(-head.basis.z)
	var local_head := to_local(head.origin)
	var render := active and local_head.z > 0.08 and facing > 0.05
	for eye in 2:
		var viewport := viewports[eye]
		if not render or (eye == 1 and not stereo):
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		var eye_pose: Transform3D = xr.get_transform_for_view(eye, origin) if stereo else head
		_update_camera(cameras[eye], eye_pose.origin)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _update_camera(camera: Camera3D, eye_position: Vector3):
	var eye := to_local(eye_position)
	var distance := maxf(eye.z, 0.08)
	camera.global_transform = global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(eye.x, eye.y, -eye.z))
	var near_plane := 0.05
	camera.set_frustum(SIZE.y * near_plane / distance, Vector2(eye.x,-eye.y) * near_plane / distance, near_plane, distance + 5.0)

func shutdown():
	set_enabled(false)
	material.set_shader_parameter("left_eye", null)
	material.set_shader_parameter("right_eye", null)
