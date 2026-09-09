extends RefCounted
## Procedural, self-contained environments. No downloaded artwork.
const CraftedMeshes = preload("res://scripts/crafted_meshes.gd")
const StaticGeometry = preload("res://scripts/static_geometry.gd")
var crafted := CraftedMeshes.new()
var opaque_vinyl: Shader
var rng := RandomNumberGenerator.new()
var animated: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var sphere_meshes: Dictionary = {}
var unit_box := BoxMesh.new()
var unit_tube: CylinderMesh
var batch_count := 0
var batched_mesh_count := 0
var root: Node3D
var palette: Array[Color] = [Color("f7b8cf"), Color("b5dedf"), Color("c9b9eb"), Color("f5d9a5"), Color("e9c6a5")]

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.38
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.scale = size
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if mesh in crafted.cache.values() and (mesh == crafted.cache.get("belly_patch") or mesh == crafted.cache.get("paw_patch") or mesh == crafted.cache.get("bunny_ear") or mesh == crafted.cache.get("bear_ear")):
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if size.y < minf(size.x, size.z) * 0.06:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, segments: int = 24, rings: int = 12) -> MeshInstance3D:
	if parent.get_meta("small_plush", false):
		segments = mini(segments, 16)
		rings = mini(rings, 8)
	# Geometry is immutable and shared; transforms and materials belong to instances.
	var key := Vector2i(segments, rings)
	if not sphere_meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = segments
		mesh.rings = rings
		sphere_meshes[key] = mesh
	return mesh_node(parent, sphere_meshes[key], pos, size, mat)

func fabric(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fabric.gdshader")
	m.set_shader_parameter("color", color)
	return m

func rounded_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return mesh_node(parent, crafted.rounded_box(), pos, size, mat)

func curve(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material, sides: int = 8, taper: float = 1.0) -> MeshInstance3D:
	return mesh_node(parent, crafted.curve(points, radius, sides, taper), Vector3.ZERO, Vector3.ONE, mat)

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := mesh_node(parent, unit_box, pos, size, mat)
	# Interior walls enclose the room; soft window light is authored separately.
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	if unit_tube == null:
		unit_tube = CylinderMesh.new()
		unit_tube.top_radius = 1.0
		unit_tube.bottom_radius = 1.0
		unit_tube.height = 1.0
		unit_tube.radial_segments = 6
	var n := mesh_node(parent, unit_tube, (a + b) * 0.5, Vector3.ONE, mat)
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up.cross(Vector3.RIGHT).normalized()
	n.basis = Basis(right, up, right.cross(up)).orthonormalized().scaled_local(Vector3(radius, a.distance_to(b), radius))
	return n

func soap(opacity: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/soap.gdshader")
	m.set_shader_parameter("opacity", opacity)
	materials.append(m)
	return m

func build(index: int, use_cache: bool = true) -> Node3D:
	rng.seed = 42721 + index * 761
	animated.clear()
	materials.clear()
	var cached_path := "res://assets/worlds/world_%d.scn" % index
	if use_cache and ResourceLoader.exists(cached_path):
		var packed := load(cached_path) as PackedScene
		root = packed.instantiate()
		for entry in root.get_meta("floaters", []):
			var motion: Dictionary = entry.duplicate()
			motion.node = root.get_node(entry.path)
			animated.append(motion)
		for mat in root.get_meta("animated_materials", []):
			materials.append(mat)
		print("FOAM_WORLD_READY: ", root.name, " baked=true")
		return root
	root = Node3D.new()
	root.name = ["Ocean", "Sky", "BalloonRoom", "PlushRoom", "CandyDream", "MixedReality"][index]
	match index:
		0: ocean()
		1: sky()
		2: room()
		3: plush_room()
		4: candy_dream()
	batch_count = 0
	batched_mesh_count = 0
	_batch_geometry(root)
	print("FOAM_WORLD_READY: ", root.name, " merged_meshes=", batched_mesh_count, " batches=", batch_count)
	return root

func float_node(n: Node3D, amplitude: float, speed: float, spin: float = 0.0):
	n.set_meta("animated", true)
	animated.append({"node": n, "home": n.position, "amplitude": amplitude, "speed": speed, "phase": rng.randf() * TAU, "spin": spin})

func _batch_geometry(parent: Node3D):
	var groups: Dictionary = {}
	_collect_geometry(parent, Transform3D.IDENTITY, groups)
	for group: Array in groups.values():
		if group.size() < 3:
			continue
		var first: MeshInstance3D = group[0].node
		var shared := true
		for entry: Dictionary in group:
			shared = shared and entry.node.mesh == first.mesh
		var instance: GeometryInstance3D
		if shared:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = first.mesh
			multi.instance_count = group.size()
			for i in group.size():
				multi.set_instance_transform(i, group[i].transform)
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = multi
			instance = batch
		else:
			var batch := MeshInstance3D.new()
			batch.mesh = StaticGeometry.merge(group)
			instance = batch
		instance.material_override = first.material_override
		instance.cast_shadow = first.cast_shadow
		parent.add_child(instance)
		for entry: Dictionary in group:
			entry.node.get_parent().remove_child(entry.node)
			entry.node.free()
		batch_count += 1
		batched_mesh_count += group.size()

func _collect_geometry(parent: Node3D, relative: Transform3D, groups: Dictionary):
	for child in parent.get_children():
		if not child is Node3D:
			continue
		if child.has_meta("animated"):
			_batch_geometry(child)
			continue
		var transform: Transform3D = relative * child.transform
		_collect_geometry(child, transform, groups)
		# Retain hierarchy owners and transparent objects (which need individual sorting).
		if not child is MeshInstance3D or child.get_child_count() > 0:
			continue
		var mat: Material = child.material_override
		if mat is StandardMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if mat is ShaderMaterial and not mat.get_meta("opaque", false) and mat.shader not in [preload("res://shaders/cloud.gdshader"), preload("res://shaders/fabric.gdshader"), preload("res://shaders/confection.gdshader"), preload("res://shaders/kelp.gdshader")]:
			continue
		# Outdoor batches are spatially bounded so frustum culling still works.
		var cell := Vector2i.ZERO
		if parent == root:
			var cell_size := 18.0 if root.name in ["Ocean", "Sky"] else 4.0
			cell = Vector2i(floori(transform.origin.x / cell_size), floori(transform.origin.z / cell_size))
		var key := "%d:%d:%d:%d" % [mat.get_instance_id(), cell.x, cell.y, child.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append({"node": child, "transform": transform})

func update(clock: float):
	for a in animated:
		var n: Node3D = a.node
		var phase: float = clock * a.speed + a.phase
		n.position = a.home + Vector3(sin(phase * 0.73) * a.amplitude * 0.4, sin(phase) * a.amplitude, 0)
		n.rotation.z = sin(phase * 0.67) * a.spin
	for m in materials:
		m.set_shader_parameter("clock", clock)

func scatter_bubbles(count: int, radius: float, min_y: float, max_y: float):
	var m := soap(0.85)
	for i in count:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(3.8, radius)
		var size := rng.randf_range(0.09, 0.6)
		var n := sphere(root, Vector3(cos(angle) * distance, rng.randf_range(min_y, max_y), sin(angle) * distance), Vector3.ONE * size, m)
		float_node(n, rng.randf_range(0.3, 1.1), rng.randf_range(0.1, 0.3))

func ocean():
	var sand := ShaderMaterial.new()
	sand.shader = load("res://shaders/water.gdshader")
	materials.append(sand)
	box(root, Vector3(0, -4.5, 0), Vector3(150, 0.2, 150), sand)
	var rock := material(Color("164f60"))
	rock.roughness = 0.94
	var leaf_mats: Array[ShaderMaterial] = []
	for color in [Color("287f79"), Color("339c8b"), Color("306779")]:
		var leaf := ShaderMaterial.new()
		leaf.shader = preload("res://shaders/kelp.gdshader")
		leaf.set_shader_parameter("color", color)
		leaf_mats.append(leaf)
		materials.append(leaf)
	var blade := crafted.kelp()
	for i in 32:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(7.0, 35.0)
		var p := Vector3(cos(angle) * distance, -4.3, sin(angle) * distance)
		var stone := sphere(root, p, Vector3(rng.randf_range(1, 3), rng.randf_range(0.4, 1.4), rng.randf_range(1, 2)), rock)
		stone.rotation.y = angle
		for k in 5:
			var h := rng.randf_range(1.2, 3.7)
			var leaf := mesh_node(root, blade, p + Vector3(k * 0.28 - 0.5, h * 0.5, 0), Vector3(1, h, 1), leaf_mats[i % 3])
			leaf.rotation = Vector3(0, angle + k * 1.4, sin(k) * 0.17)
	var bell_mat := material(Color("a5e0e8"), 0.35)
	var thread_mat := material(Color("6ec7d8"), 0.35)
	for i in 11:
		var jelly := Node3D.new()
		root.add_child(jelly)
		var angle := float(i) * 2.4
		jelly.position = Vector3(sin(angle) * (6 + i * 0.8), rng.randf_range(-1.7, 6), cos(angle) * (6 + i * 0.8))
		var size := rng.randf_range(0.35, 0.85)
		mesh_node(jelly, crafted.jelly_bell(), Vector3.ZERO, Vector3.ONE * size, bell_mat)
		var ring := TorusMesh.new()
		ring.inner_radius = size * 0.8
		ring.outer_radius = size
		ring.rings = 24
		ring.ring_segments = 8
		mesh_node(jelly, ring, Vector3(0, -0.07, 0), Vector3.ONE, thread_mat)
		for j in 7:
			var a := TAU * j / 7.0
			var points := PackedVector3Array()
			for k in 19:
				var t := float(k) / 18.0
				points.append(Vector3(cos(a) * size * 0.58 + sin(t * 6.0 + j) * t * 0.13, -0.08 - t * size * 2.6, sin(a) * size * 0.58 + cos(t * 5.0 + j) * t * 0.10))
			curve(jelly, points, 0.018, thread_mat, 6, 0.16)
		float_node(jelly, 0.55, 0.21, 0.06)
	# A school of small, individually oriented fish.
	var fish_mat := material(Color("79c4c9"), 0.1)
	var fish_group := Node3D.new()
	root.add_child(fish_group)
	fish_group.position = Vector3(0, 1, -12)
	for i in 32:
		var p := Vector3(rng.randf_range(-6, 6), rng.randf_range(-1, 2), rng.randf_range(-2, 2))
		sphere(fish_group, p, Vector3(0.19, 0.065, 0.05), fish_mat, 12)
		var tail := sphere(fish_group, p + Vector3(-0.19, 0, 0), Vector3(0.07, 0.11, 0.02), fish_mat, 12)
		tail.rotation.z = 0.3
	float_node(fish_group, 0.6, 0.12)
	# Broad translucent shafts remain well outside the personal bubble.
	var ray_mat := material(Color(0.32, 0.79, 0.84, 0.025))
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 7:
		var ray := box(root, Vector3(-17 + i * 5, 7, -19 - i), Vector3(0.8 + i * 0.15, 28, 0.15), ray_mat)
		ray.rotation.z = -0.25
	scatter_bubbles(52, 22, -3, 12)
	_ocean_details()

func _ocean_details():
	# Coral gardens in distinct warm colours provide scale and a calm place to look.
	var coral_mats := [material(Color("ed9eac"), 0.10), material(Color("c9a1db"), 0.10), material(Color("e8bf91"), 0.08)]
	for i in 15:
		var a := i * 2.4
		var base := Vector3(cos(a) * (6 + i % 4), -4.25, sin(a) * (6 + i % 4))
		var mat: StandardMaterial3D = coral_mats[i % 3]
		var height := rng.randf_range(0.55, 1.1)
		tube(root, base, base + Vector3.UP * height, 0.07, mat)
		for branch in 4:
			var direction := Vector3(cos(branch * 1.9 + a) * 0.4, 0.55 + branch * 0.12, sin(branch * 1.9 + a) * 0.4)
			var start := base + Vector3.UP * height * 0.4
			var end := base + direction * height
			tube(root, start, end, 0.045, mat)
			sphere(root, end, Vector3.ONE * 0.065, mat, 10)
	# Fine plankton points drift in the distance, never against the viewer's face.
	var glow := material(Color("b1eee1"), 0.45)
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.013
	dust_mesh.height = 0.026
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dust_mesh
	multi.instance_count = 160
	for i in 160:
		var a := rng.randf() * TAU
		var distance := rng.randf_range(3.0, 19.0)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cos(a) * distance, rng.randf_range(-3, 9), sin(a) * distance)))
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = multi
	dust.material_override = glow
	root.add_child(dust)
	float_node(dust, 0.3, 0.12)

func sky():
	var cloud_mats: Array[ShaderMaterial] = []
	for colors in [[Color("ffe0ce"), Color("827b9c")], [Color("ffe6df"), Color("9381a4")], [Color("f2d4e3"), Color("7d7d9d")]]:
		var cloud_mat := ShaderMaterial.new()
		cloud_mat.shader = load("res://shaders/cloud.gdshader")
		cloud_mat.set_shader_parameter("upper_color", colors[0])
		cloud_mat.set_shader_parameter("lower_color", colors[1])
		cloud_mats.append(cloud_mat)
	# Soft sculptural clouds, with clear air around the viewer.
	for i in 34:
		var cluster := Node3D.new()
		root.add_child(cluster)
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(10, 65)
		cluster.position = Vector3(cos(angle) * distance, rng.randf_range(-11, -3), sin(angle) * distance)
		var size := rng.randf_range(1.5, 4.5)
		var cloud_mesh: Mesh = load("res://assets/models/cloud_%d.obj" % (i % 3))
		mesh_node(cluster, cloud_mesh, Vector3.ZERO, Vector3.ONE * size, cloud_mats[i % 3])
		float_node(cluster, 0.15, 0.08)
	var sun_mat := material(Color("ffe6bc"), 0.7)
	sphere(root, Vector3(-29, 10, -65), Vector3.ONE * 5.5, sun_mat, 48)
	for i in 9:
		var p := Vector3(rng.randf_range(-28, 28), rng.randf_range(0, 16), rng.randf_range(-40, -14))
		balloon(root, p, rng.randf_range(0.8, 1.4), palette[i % 5], true)
	scatter_bubbles(28, 22, -2, 12)
	# Distant layers give the cloud sea a horizon instead of isolated floating blobs.
	for i in 12:
		var angle := TAU * i / 12.0
		sphere(root, Vector3(cos(angle) * 78, -13, sin(angle) * 78), Vector3(24, 3.0, 15), cloud_mats[i % 3])

func balloon(parent: Node3D, pos: Vector3, size: float, color: Color, basket: bool = false) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var mat := material(color)
	mat.metallic = 0.10
	mat.roughness = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.5
	mesh_node(n, crafted.balloon(), Vector3.ZERO, Vector3.ONE * size, mat)
	var knot := CylinderMesh.new()
	knot.top_radius = 0.035
	knot.bottom_radius = 0.09
	knot.height = 0.12
	knot.radial_segments = 16
	mesh_node(n, knot, Vector3(0, -size * 1.34, 0), Vector3.ONE * size, mat)
	var string_mat := material(Color("d7c8c1"))
	if basket:
		rounded_box(n, Vector3(0, -size * 2.0, 0), Vector3(size * 0.65, size * 0.42, size * 0.6), material(Color("a98779")))
		for x in [-1, 1]:
			tube(n, Vector3(x * size * 0.32, -size * 0.8, 0), Vector3(x * size * 0.28, -size * 1.8, 0), 0.015, string_mat)
	else:
		var points := PackedVector3Array()
		for i in 25:
			var t := float(i) / 24.0
			points.append(Vector3(sin(t * 8.0) * t * 0.11, -size * (1.38 + t * 2.0), sin(t * 4.0) * 0.06))
		curve(n, points, 0.005, string_mat, 6)
	float_node(n, size * 0.22, rng.randf_range(0.15, 0.32), 0.06)
	return n

func room():
	# A grounded room with a clear centre and an uninterrupted view of the window.
	# Toys belong to a few perimeter groups, never scattered through the head space.
	root.set_meta("clear_radius", 3.0)
	var wall := material(Color("bbaab4"))
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/room_floor.gdshader")
	var shadow_regions := PackedVector4Array()
	if root.name == "PlushRoom":
		floor_mat.set_shader_parameter("room_extent", Vector2(6, 6.5))
		for p in [Vector4(-2.4,-2.7,0.9,0.7), Vector4(2.5,-2.9,0.85,0.7), Vector4(-3.55,-5.7,1.8,0.7), Vector4(3.55,-5.7,1.8,0.7), Vector4(4.5,0.5,1.1,0.7), Vector4(0,-4.5,2.8,0.4)]:
			shadow_regions.append(p)
	else:
		for p in [Vector4(-4.5,-4.6,0.7,0.6), Vector4(4.1,-4.9,0.7,0.6), Vector4(-5.8,4.2,1.6,1.0), Vector4(5.5,4.8,0.8,0.8)]:
			shadow_regions.append(p)
	floor_mat.set_shader_parameter("shadow_count", shadow_regions.size())
	shadow_regions.resize(12)
	floor_mat.set_shader_parameter("contact_shadows", shadow_regions)
	var trim := material(Color("ead9c7"))
	box(root, Vector3(0, -0.15, 0), Vector3(16, 0.3, 18), floor_mat)
	box(root, Vector3(-8, 3.3, 0), Vector3(0.25, 6.6, 18), wall)
	box(root, Vector3(8, 3.3, 0), Vector3(0.25, 6.6, 18), wall)
	box(root, Vector3(0, 3.3, 9), Vector3(16, 6.6, 0.25), wall)
	box(root, Vector3(0, 6.6, 0), Vector3(16, 0.2, 18), trim)
	for side in [-1, 1]:
		box(root, Vector3(side * 6.25, 3.3, -9), Vector3(3.5, 6.6, 0.25), wall)
		box(root, Vector3(side * 7.8, 0.18, 0), Vector3(0.13, 0.36, 18), trim)
	box(root, Vector3(0, 6.25, -9), Vector3(9, 0.7, 0.25), wall)
	box(root, Vector3(0, 0.45, -9), Vector3(9, 0.9, 0.25), wall)
	var window_mat := ShaderMaterial.new()
	window_mat.shader = preload("res://shaders/window.gdshader")
	box(root, Vector3(0, 3.4, -9.15), Vector3(9, 5, 0.1), window_mat)
	for x in [-4.5, 0, 4.5]:
		box(root, Vector3(x, 3.4, -8.84), Vector3(0.09, 5.1, 0.20), trim)
	for y in [0.9, 3.4, 5.9]:
		box(root, Vector3(0, y, -8.84), Vector3(9.1, 0.09, 0.20), trim)
	box(root, Vector3(0, 0.84, -8.65), Vector3(9.4, 0.14, 0.65), trim)
	var rug := sphere(root, Vector3(0, 0.035, 0), Vector3(2.7, 0.03, 3.3), material(Color("a8b7b3")), 48)
	rug.name = "QuietCenterRug"
	# Four deliberately spaced groups against the side and back walls.
	var anchors := [Vector3(-6.6, 2.6, -5.8), Vector3(6.4, 2.7, -5.6), Vector3(-5.0, 2.8, 6.8), Vector3(4.8, 2.6, 6.7)]
	for group in anchors.size():
		for i in 3:
			var offset := Vector3((i - 1) * 0.62, [0.0, 0.65, 0.22][i], (i % 2) * 0.3)
			balloon(root, anchors[group] + offset, [0.40, 0.47, 0.36][i], palette[(group + i) % palette.size()])
	_inflatable_collection()
	_room_fabrics()
	for entry in animated:
		entry.amplitude = minf(entry.amplitude, 0.075)
		entry.speed = minf(entry.speed, 0.14)
		entry.spin = minf(entry.spin, 0.035)

func vinyl(color: Color, opacity: float = 1.0, panels: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/vinyl.gdshader")
	if opacity >= 0.99:
		m.shader = preload("res://shaders/vinyl_opaque.gdshader")
		m.set_meta("opaque", true)
	m.set_shader_parameter("color_a", color)
	m.set_shader_parameter("color_b", Color("fff0df"))
	m.set_shader_parameter("transparency", opacity)
	m.set_shader_parameter("panels", panels)
	return m

func swim_ring(pos: Vector3, size: float, color: Color, upright: bool = false) -> Node3D:
	var toy := Node3D.new()
	root.add_child(toy)
	toy.position = pos
	var ring := TorusMesh.new()
	ring.inner_radius = size * 0.51
	ring.outer_radius = size
	ring.rings = 48
	ring.ring_segments = 16
	var ring_mesh := mesh_node(toy, ring, Vector3.ZERO, Vector3.ONE, vinyl(color, 0.78, 1.0))
	if upright:
		ring_mesh.rotation.x = PI * 0.5
	else:
		ring_mesh.rotation.z = 0.2
	# Raised heat-welded seam and little inflation valve.
	var seam := TorusMesh.new()
	seam.inner_radius = size * 0.986
	seam.outer_radius = size * 1.005
	seam.rings = 48
	seam.ring_segments = 6
	mesh_node(ring_mesh, seam, Vector3.ZERO, Vector3.ONE, vinyl(color.lightened(0.35), 0.85))
	sphere(ring_mesh, Vector3(size * 0.81, size * 0.19, 0), Vector3(0.045, 0.045, 0.045), vinyl(color.lightened(0.45)), 12)
	float_node(toy, 0.15, 0.25, 0.08)
	return toy

func inflatable_duck(pos: Vector3, size: float, color: Color) -> Node3D:
	var duck := Node3D.new()
	root.add_child(duck)
	duck.position = pos
	duck.scale = Vector3.ONE * size
	var skin := vinyl(color)
	var wing_skin := vinyl(color.lightened(0.15))
	mesh_node(duck, load("res://assets/models/duck_body.obj"), Vector3.ZERO, Vector3.ONE, skin)
	sphere(duck, Vector3(0, 0.68, -0.86), Vector3(0.25, 0.095, 0.24), vinyl(Color("ffac66")), 24)
	for side in [-1, 1]:
		var wing := sphere(duck, Vector3(side * 0.53, 0.05, 0.04), Vector3(0.15, 0.24, 0.47), wing_skin, 24)
		wing.rotation.z = side * -0.15
		sphere(duck, Vector3(side * 0.22, 0.83, -0.77), Vector3.ONE * 0.035, material(Color("392e4e")), 12)
		sphere(duck, Vector3(side * 0.22 - 0.007, 0.843, -0.8), Vector3.ONE * 0.01, material(Color.WHITE, 0.2), 8)
	float_node(duck, 0.14, 0.28, 0.07)
	return duck

func inflatable_dolphin(pos: Vector3, size: float) -> Node3D:
	var toy := Node3D.new()
	root.add_child(toy)
	toy.position = pos
	toy.scale = Vector3.ONE * size
	toy.set_meta("small_plush", size < 0.65)
	var skin := vinyl(Color("8bd7e9"))
	var belly := vinyl(Color("e9f7ee"))
	mesh_node(toy, load("res://assets/models/dolphin_body.obj"), Vector3.ZERO, Vector3.ONE, skin)
	sphere(toy, Vector3(0, -0.18, -0.15), Vector3(0.35, 0.24, 0.76), belly, 24)
	for side in [-1, 1]:
		sphere(toy, Vector3(side * 0.275, 0.13, -0.92), Vector3.ONE * 0.035, material(Color("283854")), 12)
	toy.rotation = Vector3(-0.12, -0.8, 0.06)
	float_node(toy, 0.23, 0.21, 0.08)
	return toy

func _inflatable_collection():
	# One gentle focal point on each side, with no objects in the forward corridor.
	swim_ring(Vector3(-4.5, 1.0, -4.6), 0.78, Color("d9a6b5"), true)
	var duck := inflatable_duck(Vector3(4.1, 0.54, -4.9), 0.72, Color("e9ce96"))
	duck.rotation.y = -0.65
	var dolphin := inflatable_dolphin(Vector3(-5.8, 1.55, 2.8), 0.70)
	dolphin.rotation.y = 0.65
	swim_ring(Vector3(5.5, 0.3, 4.8), 0.66, Color("a5c9bf"))
	var beach_mat := vinyl(Color.WHITE, 1.0, 2.0)
	for position in [Vector3(-5.6, 0.40, -4.2), Vector3(5.5, 0.33, 5.9)]:
		var ball := sphere(root, position, Vector3.ONE * 0.32, beach_mat, 32)
		ball.rotation = Vector3(0.3, 0.7, 0.2)

func _room_fabrics():
	var curtain := ShaderMaterial.new()
	curtain.shader = preload("res://shaders/curtain.gdshader")
	var fabric := PlaneMesh.new()
	fabric.orientation = PlaneMesh.FACE_Z
	fabric.size = Vector2(1.45, 5.0)
	fabric.subdivide_width = 48
	for side in [-1, 1]:
		mesh_node(root, fabric, Vector3(side * 5.2, 3.3, -8.68), Vector3.ONE, curtain)
	var cushion_mat := fabric(Color("c3b0bc"))
	var seat := sphere(root, Vector3(-5.8, 0.28, 4.2), Vector3(1.3, 0.28, 0.85), cushion_mat, 32)
	seat.name = "PerimeterSeat"
	sphere(root, Vector3(-6.1, 0.67, 4.7), Vector3(1.05, 0.5, 0.26), cushion_mat, 32)
	for i in 2:
		var cushion := sphere(root, Vector3(-5.4 + i * 0.5, 0.60, 4.1), Vector3(0.32, 0.13, 0.29), fabric(palette[i + 1]), 24)
		cushion.rotation.y = i * 0.6
	var stem := material(Color("aa9486"))
	var shade := material(Color("ead8b9"), 0.22)
	for side in [-1, 1]:
		var base := Vector3(side * 6.8, 0, -7.2)
		sphere(root, base + Vector3(0, 0.06, 0), Vector3(0.32, 0.06, 0.32), stem, 24)
		tube(root, base, base + Vector3(0, 1.2, 0), 0.025, stem)
		sphere(root, base + Vector3(0, 1.25, 0), Vector3(0.42, 0.27, 0.42), shade, 24)

func plush(parent: Node3D, pos: Vector3, size: float, fur: Material, cream: Material, eyes: Material, ribbon: Material, bunny: bool = false):
	var toy := Node3D.new()
	toy.position = pos
	toy.scale = Vector3.ONE * size
	toy.rotation.y = atan2(-pos.x, -pos.z)
	parent.add_child(toy)
	sphere(toy, Vector3(0, 0.63, 0), Vector3(0.48, 0.60, 0.34), fur, 48 if size > 1.0 else 24, 24 if size > 1.0 else 12)
	sphere(toy, Vector3(0, 1.34, 0), Vector3(0.48, 0.43, 0.36), fur, 48 if size > 1.0 else 24, 24 if size > 1.0 else 12)
	mesh_node(toy, crafted.patch("belly_patch", Vector3(0.48,0.60,0.34), Vector2(0.68,0.65)), Vector3(0,0.63,0), Vector3.ONE, cream)
	for side in [-1, 1]:
		var ear := Vector3(side * 0.32, 1.70 if not bunny else 1.96, 0)
		var ear_size := Vector3(0.21, 0.22 if not bunny else 0.48, 0.12)
		sphere(toy, ear, ear_size, fur)
		mesh_node(toy, crafted.patch("bunny_ear" if bunny else "bear_ear", ear_size, Vector2(0.62,0.74)), ear, Vector3.ONE, ribbon)
		sphere(toy, Vector3(side * 0.46, 0.66, 0.07), Vector3(0.19, 0.37, 0.20), fur)
		sphere(toy, Vector3(side * 0.28, 0.20, 0.26), Vector3(0.25, 0.22, 0.32), fur)
		mesh_node(toy, crafted.patch("paw_patch", Vector3(0.25,0.22,0.32), Vector2(0.58,0.60)), Vector3(side*0.28,0.20,0.26), Vector3.ONE, cream)
		sphere(toy, Vector3(side * 0.17, 1.40, 0.335), Vector3(0.040, 0.045, 0.025), eyes, 16)
		sphere(toy, Vector3(side * 0.18, 1.414, 0.356), Vector3.ONE * 0.009, cream, 12)
		sphere(toy, Vector3(side * 0.27, 1.27, 0.31), Vector3(0.085, 0.035, 0.015), ribbon, 16)
		sphere(toy, Vector3(side * 0.13, 1.00, 0.35), Vector3(0.14, 0.085, 0.04), ribbon)
	sphere(toy, Vector3(0, 1.22, 0.34), Vector3(0.22, 0.13, 0.09), cream)
	sphere(toy, Vector3(0, 1.27, 0.425), Vector3(0.065, 0.045, 0.025), eyes, 16)
	tube(toy, Vector3(0, 1.24, 0.43), Vector3(0, 1.18, 0.43), 0.009, eyes)
	if size > 0.6:
		for side in [-1, 1]:
			var smile := PackedVector3Array()
			for j in 10:
				var t := float(j) / 9.0
				smile.append(Vector3(side * t * 0.10, 1.18 - sin(t * PI) * 0.025, 0.426 - t * 0.012))
			curve(toy, smile, 0.005, eyes, 6)
		for j in 22:
			var a := TAU * j / 22.0
			var p := Vector3(cos(a) * 0.30, 0.65 + sin(a) * 0.35, 0.355)
			tube(toy, p, p + Vector3(cos(a), sin(a), 0) * 0.020, 0.0028, ribbon)
	for i in 7:
		tube(toy, Vector3(-0.024, 0.45 + i * 0.055, 0.383), Vector3(0.024, 0.47 + i * 0.055, 0.383), 0.004, ribbon)

func candy_dream():
	root.set_meta("clear_radius", 1.6)
	var cream := material(Color("fff0df"))
	var pink := material(Color("efa9cb"))
	var berry := ShaderMaterial.new()
	berry.shader = preload("res://shaders/confection.gdshader")
	berry.set_shader_parameter("color", Color("d96594"))
	berry.set_shader_parameter("seeds", 1.0)
	var biscuit := material(Color("e9c48d"))
	var lilac := material(Color("c7b2e7"))
	var mint := material(Color("b6ddd3"))
	var green := material(Color("9fc8a3"))
	var colors: Array[Material] = [pink, lilac, mint, biscuit]
	sphere(root, Vector3(0, -0.4, 0), Vector3(18, 0.42, 18), pink, 64)
	sphere(root, Vector3(0, -0.05, 0), Vector3(3.0, 0.06, 3.2), cream, 48)
	for tier in 3:
		var radius := 3.0 - tier * 0.68
		var y := 0.58 + tier * 1.02
		var cake := CylinderMesh.new()
		cake.top_radius = radius
		cake.bottom_radius = radius
		cake.height = 1.02
		cake.radial_segments = 64
		mesh_node(root, cake, Vector3(0, y, -8), Vector3.ONE, cream if tier % 2 == 0 else pink)
		for i in 30:
			var a := i * TAU / 30
			var p := Vector3(cos(a) * radius, y + 0.48, -8 + sin(a) * radius)
			mesh_node(root, crafted.cream(), p, Vector3.ONE, cream)
			if i % 3 == 0:
				var fruit := p + Vector3(0, 0.23, 0)
				mesh_node(root, crafted.berry(), fruit + Vector3(0, 0.13, 0), Vector3.ONE, berry)
				sphere(root, fruit + Vector3(0, 0.20, 0), Vector3(0.17, 0.035, 0.09), green, 12)
	for side in [-1, 1]:
		sphere(root, Vector3(side * 0.19, 3.85, -8), Vector3(0.27, 0.30, 0.18), pink)
		for i in 4:
			var p := Vector3(side * (3.5 + i * 1.45), 0.35, -2.8 - i * 0.85)
			for stack in range(1 + i % 3):
				var q := p + Vector3(0, stack * 0.57, 0)
				sphere(root, q, Vector3(0.67, 0.13, 0.57), cream)
				mesh_node(root, crafted.macaron(), q + Vector3(0, 0.09, 0), Vector3(1, 1, 0.86), colors[i])
				var bottom := mesh_node(root, crafted.macaron(), q - Vector3(0, 0.09, 0), Vector3(1, 1, 0.86), colors[i])
				bottom.rotation.x = PI
			var lp := p + Vector3(side * 0.5, 2.3 + i * 0.2, -1.5)
			tube(root, Vector3(lp.x, 0, lp.z), lp, 0.045, cream)
			sphere(root, lp, Vector3(0.55, 0.55, 0.13), colors[(i + 1) % 4])
			var spiral := PackedVector3Array()
			for point in 97:
				var a := float(point) / 96.0 * TAU * 2.4
				var rad := float(point) / 96.0 * 0.45
				spiral.append(lp + Vector3(cos(a) * rad, sin(a) * rad, 0.13))
			curve(root, spiral, 0.028, cream, 6)

	sphere(root, Vector3(0, 3.65, -8), Vector3(0.29, 0.28, 0.18), pink)
	for i in 36:
		var a := i * TAU / 36
		var p := Vector3(cos(a) * 15, 0.2 + sin(i * 1.9) * 0.3, sin(a) * 15)
		sphere(root, p, Vector3(2.6, 0.7, 2.0), cream)
		if i % 3 == 0:
			sphere(root, p + Vector3(0, 0.9, 0), Vector3(0.55, 0.8, 0.55), colors[i % 4])
	var glow := material(Color("ffe5a8"), 0.5)
	for i in 24:
		var a := rng.randf() * TAU
		var radius := rng.randf_range(4.0, 15.0)
		var star := Node3D.new()
		star.position = Vector3(cos(a) * radius, rng.randf_range(3.7, 7.0), sin(a) * radius)
		root.add_child(star)
		for axis in [Vector3(0.13, 0.035, 0.035), Vector3(0.035, 0.19, 0.035)]:
			sphere(star, Vector3.ZERO, axis, glow, 12)
		float_node(star, 0.08, 0.17, 0.04)
	for i in 12:
		sphere(root, Vector3(-1.0 + (i % 3), 0.04, -2.6 - (i / 3) * 0.64), Vector3(0.32, 0.04, 0.23), colors[i % 4], 16)
	plush(root, Vector3(-3, 0, 1), 0.8, lilac, cream, berry, pink, true)
	plush(root, Vector3(3, 0, 1), 0.8, mint, cream, berry, pink)

func plush_room():
	root.set_meta("clear_radius", 1.6)
	var wall := material(Color("d5bbc7"))
	var wood := material(Color("d6ac86"))
	var cream := fabric(Color("fff0d8"))
	var trim := material(Color("fff0d8"))
	var eyes := material(Color("493c42"))
	var pink := fabric(Color("d58ca8"))
	var furs: Array[Material] = []
	for color in [Color("bb8e70"), Color("e8d4b2"), Color("b4bbc9"), Color("d6a8bb"), Color("b7c9b4")]:
		var fur := fabric(color)
		furs.append(fur)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/room_floor.gdshader")
	var shadow_regions := PackedVector4Array()
	if root.name == "PlushRoom":
		floor_mat.set_shader_parameter("room_extent", Vector2(6, 6.5))
		for p in [Vector4(-2.4,-2.7,0.9,0.7), Vector4(2.5,-2.9,0.85,0.7), Vector4(-3.55,-5.7,1.8,0.7), Vector4(3.55,-5.7,1.8,0.7), Vector4(4.5,0.5,1.1,0.7), Vector4(0,-4.5,2.8,0.4)]:
			shadow_regions.append(p)
	else:
		for p in [Vector4(-4.5,-4.6,0.7,0.6), Vector4(4.1,-4.9,0.7,0.6), Vector4(-5.8,4.2,1.6,1.0), Vector4(5.5,4.8,0.8,0.8)]:
			shadow_regions.append(p)
	floor_mat.set_shader_parameter("shadow_count", shadow_regions.size())
	shadow_regions.resize(12)
	floor_mat.set_shader_parameter("contact_shadows", shadow_regions)
	box(root, Vector3(0, -0.10, 0), Vector3(12, 0.2, 13), floor_mat)
	for side in [-1, 1]:
		box(root, Vector3(side * 6, 2.4, 0), Vector3(0.18, 4.8, 13), wall)
		box(root, Vector3(0, 2.4, side * 6.5), Vector3(12, 4.8, 0.18), wall)
		box(root, Vector3(side * 5.88, 0.32, 0), Vector3(0.10, 0.64, 13), trim)
	box(root, Vector3(0, 4.8, 0), Vector3(12, 0.15, 13), trim)
	for x in range(-5, 6):
		box(root, Vector3(x, 2.5, -6.39), Vector3(0.025, 4.3, 0.015), trim)
	var rug := material(Color("ceb5c6")); rug.roughness = 1.0
	sphere(root, Vector3(0, 0.025, 0), Vector3(2.9, 0.024, 3.2), rug, 48)
	sphere(root, Vector3(0, 0.045, 0), Vector3(2.62, 0.018, 2.92), furs[1], 48)
	# A pair of big companions at seated eye height, facing the visitor.
	plush(root, Vector3(-2.4, 0, -2.7), 1.25, furs[0], cream, eyes, pink)
	plush(root, Vector3(2.5, 0, -2.9), 1.12, furs[1], cream, eyes, pink, true)
	for side in [-1, 1]:
		var x: float = side * 3.55
		for y in [0.12, 1.1, 2.12, 3.14]:
			rounded_box(root, Vector3(x, y, -5.7), Vector3(3.4, 0.12, 1.0), wood)
		for dx in [-1.64, 0, 1.64]:
			rounded_box(root, Vector3(x + dx, 1.62, -5.7), Vector3(0.12, 3.2, 1.0), trim)
		for row in 3:
			for col in 4:
				plush(root, Vector3(x + (col - 1.5) * 0.77, 0.2 + row * 1.01, -5.55), 0.39, furs[(col + row) % 5], cream, eyes, pink, col % 2 == 1)
	# Toy chest, piled soft animals, colored blocks, and a little wooden train.
	rounded_box(root, Vector3(4.5, 0.36, 0.5), Vector3(1.7, 0.72, 1.1), wood)
	rounded_box(root, Vector3(4.5, 0.75, 0.5), Vector3(1.85, 0.12, 1.2), trim)
	for i in 5:
		plush(root, Vector3(4.2 + (i % 2) * 0.65, 0.80, -0.0 + (i / 2) * 0.46), 0.40, furs[i], cream, eyes, pink, i % 2 == 0)
	for i in 24:
		var p := Vector3(-3.7 + rng.randf_range(-0.65, 0.65), 0.16, rng.randf_range(-0.4, 2.2))
		var block := rounded_box(root, p, Vector3.ONE * 0.3, furs[i % 5])
		block.rotation.y = rng.randf() * 1.2
	for i in 5:
		var p := Vector3(-1.6 + i * 0.65, 0.22, -4.5)
		rounded_box(root, p, Vector3(0.51, 0.28, 0.38), furs[i])
		if i == 0:
			rounded_box(root, p + Vector3(-0.12, 0.24, 0), Vector3(0.23, 0.28, 0.35), wood)
		for side in [-1, 1]:
			for dx in [-0.16, 0.16]:
				sphere(root, p + Vector3(dx, -0.09, side * 0.22), Vector3(0.10, 0.10, 0.035), eyes, 16)
	for i in 7:
		plush(root, Vector3(-4.6 + i * 1.5, 0, 4.8), 0.64, furs[i % 5], cream, eyes, pink, i % 3 == 0)
	var glow := material(Color("ffe1a6"), 0.7)
	for i in 19:
		var p := Vector3(-5.6 + i * 0.62, 3.8 - sin(i * PI / 18) * 0.42, -6.15)
		sphere(root, p, Vector3.ONE * 0.055, glow, 12)
		if i > 0:
			var prev := Vector3(-5.6 + (i - 1) * 0.62, 3.8 - sin((i - 1) * PI / 18) * 0.42, -6.15)
			tube(root, prev, p, 0.008, wood)
	var window_mat := ShaderMaterial.new(); window_mat.shader = preload("res://shaders/window.gdshader")
	box(root, Vector3(0, 2.8, -6.30), Vector3(2.7, 2.8, 0.10), trim)
	box(root, Vector3(0, 2.8, -6.22), Vector3(2.45, 2.55, 0.08), window_mat)
	box(root, Vector3(0, 2.8, -6.15), Vector3(0.07, 2.55, 0.08), trim)
	box(root, Vector3(0, 2.8, -6.15), Vector3(2.45, 0.07, 0.08), trim)
