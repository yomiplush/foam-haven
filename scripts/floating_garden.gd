extends Node3D
## Room-anchored, bounded floating toys. Pausing never moves the tracked viewpoint.
signal touched(hand: int, strength: float)
const MAX_BALLOONS := 18
const COLORS := [Color("f6a9c8"), Color("dfbcec"), Color("f7dbdf"), Color("f5c4d8"), Color("c2dce9"), Color("fff1df")]
var toys: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var shapes: RefCounted
var ribbon_material: StandardMaterial3D
var clock := 0.0
var floating := true
var room_anchor := Vector3.ZERO
var floor_height := 0.0
var active := false
var pressure := 0.0
var rub_motion := 0.0
var haptic_delay := [0.0, 0.0]
var previous_hands := [Vector3.ZERO, Vector3.ZERO]
var previously_tracked := [false, false]
var hand_armed := [false, false]

func configure(factory: RefCounted):
	shapes = factory
	ribbon_material = StandardMaterial3D.new()
	ribbon_material.albedo_color = Color("fbe8dc")
	ribbon_material.roughness = 0.40

func populate(head: Transform3D, mixed: bool, seed_value: int = 0):
	clear()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	room_anchor = head.origin
	floor_height = 0.0 if mixed else head.origin.y - 1.45
	var forward := -head.basis.z
	forward.y = 0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var yaw := Basis.looking_at(forward)
	var count := 12 if mixed else 8
	for i in count:
		# Stratified random sampling avoids clumps, with an open view straight ahead.
		var angle := (float(i) + rng.randf_range(0.15, 0.85)) / count * TAU + 0.20
		var distance := rng.randf_range(0.90, 1.75) if mixed else rng.randf_range(1.35, 2.3)
		var size := rng.randf_range(0.13, 0.22)
		var point := head.origin + yaw * Vector3(sin(angle) * distance, rng.randf_range(-0.35, 0.65), -cos(angle) * distance)
		point.y = maxf(point.y, floor_height + size * 2.7 + 0.24)
		_add(point, size, i % 4 == 0, COLORS[i % COLORS.size()])
	active = true
	show()

func clear():
	for entry in toys:
		remove_child(entry.node)
		entry.node.queue_free()
	toys.clear()
	active = false
	clear_interaction()
	hide()

func _add(point: Vector3, radius: float, heart: bool, color: Color):
	var node := Node3D.new()
	node.name = "FloatingHeart" if heart else "FloatingBalloon"
	add_child(node)
	node.global_position = point
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/dream_balloon.gdshader")
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("pearl", rng.randf_range(0.15, 0.7))
	var mesh: Mesh = load("res://assets/models/dream_heart.obj") if heart else shapes.crafted.balloon()
	var body: MeshInstance3D = shapes.mesh_node(node, mesh, Vector3.ZERO, Vector3.ONE * radius, mat)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.extra_cull_margin = radius * 0.3
	# A tied bow and short curled ribbon: no floor-length strings to intersect a room.
	var knot_y := -radius * (1.05 if heart else 1.32)
	shapes.sphere(node, Vector3(0, knot_y, 0), Vector3(0.027, 0.019, 0.018), ribbon_material, 12, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		var loop_points := PackedVector3Array()
		for j in 17:
			var t := float(j) / 16.0 * TAU
			loop_points.append(Vector3(side * (1.0 - cos(t)) * 0.025, knot_y + sin(t) * 0.022, sin(t * 2.0) * 0.01))
		shapes.curve(node, loop_points, 0.006, ribbon_material, 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail := PackedVector3Array()
	for j in 18:
		var t := float(j) / 17.0
		tail.append(Vector3(sin(t * 8.0) * t * 0.027, knot_y - t * radius * 1.18, cos(t * 7.0) * t * 0.025))
	shapes.curve(node, tail, 0.0028, ribbon_material, 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Merge the opaque bow pieces once. Each toy needs only body + ribbon draws.
	shapes._batch_geometry(node)
	var rotation := Vector3(rng.randf_range(-0.13, 0.13), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.25, 0.25))
	node.rotation = rotation
	toys.append({"node": node, "home": point, "radius": radius, "velocity": Vector3.ZERO, "phase": rng.randf() * TAU, "rotation": rotation, "squeeze": 0.0, "spring": 0.0, "target": 0.0, "material": mat, "holder": -1, "offset": Vector3.ZERO, "age": 0.0})

func spawn(point: Vector3, direction: Vector3) -> bool:
	if not active or toys.size() >= MAX_BALLOONS:
		return false
	var radius := rng.randf_range(0.13, 0.19)
	var at := point + direction.normalized() * (radius + 0.18)
	at.y = maxf(at.y, floor_height + radius * 2.7 + 0.24)
	_add(at, radius, rng.randf() < 0.25, COLORS[rng.randi_range(0, COLORS.size()-1)])
	toys.back().velocity = direction.normalized() * 0.20 + Vector3.UP * 0.08
	return true

func clear_interaction():
	pressure = 0.0
	rub_motion = 0.0
	hand_armed.fill(false)
	previously_tracked.fill(false)
	for entry in toys:
		entry.holder = -1
		entry.target = 0.0

func step(delta: float, head: Vector3, hands: Array[Vector3], tracked: Array[bool], grips: Array[float], interactive: bool):
	if not active:
		return
	var dt := minf(delta, 0.05)
	if floating:
		clock += dt
	pressure = 0.0
	rub_motion = 0.0
	var hand_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for hand in 2:
		haptic_delay[hand] = maxf(0, haptic_delay[hand] - dt)
		if tracked[hand] and previously_tracked[hand]:
			hand_velocity[hand] = ((hands[hand] - previous_hands[hand]) / maxf(dt, 0.001)).limit_length(1.2)
		if not interactive or not tracked[hand]:
			hand_armed[hand] = false
		elif grips[hand] < 0.25:
			hand_armed[hand] = true
		previous_hands[hand] = hands[hand]
		previously_tracked[hand] = tracked[hand] and interactive
	for entry in toys:
		entry.age += dt
		entry.target = 0.0
		var node: Node3D = entry.node
		var holder: int = entry.holder
		if holder >= 0 and (not interactive or not tracked[holder] or grips[holder] < 0.35):
			entry.holder = -1
			entry.home = node.global_position
			entry.velocity = hand_velocity[holder] * 0.55 if interactive and tracked[holder] else Vector3.ZERO
			# One release per grab; closing the menu while squeezing cannot re-grab.
			hand_armed[holder] = false
		if entry.holder < 0 and interactive:
			for hand in 2:
				if not tracked[hand]:
					continue
				var offset: Vector3 = node.global_position - hands[hand]
				var contact_radius: float = entry.radius + 0.055
				if offset.length() < contact_radius:
					var depth := clampf((contact_radius - offset.length()) / maxf(entry.radius, 0.01), 0.0, 1.0)
					entry.target = maxf(entry.target, depth * 0.32)
					var normal := offset.normalized() if offset.length_squared() > 0.00001 else Vector3.FORWARD
					entry.velocity += normal * dt * 0.6 + hand_velocity[hand] * dt * 1.5
					entry.material.set_shader_parameter("contact_axis", node.global_basis.inverse() * normal)
					_notify_touch(hand, maxf(depth, 0.20))
					rub_motion = maxf(rub_motion, hand_velocity[hand].length())
					if hand_armed[hand] and grips[hand] > 0.65 and not _hand_holds(hand):
						entry.holder = hand
						entry.offset = node.global_position - hands[hand]
						break
		if entry.holder >= 0:
			var hand: int = entry.holder
			node.global_position = hands[hand] + entry.offset
			entry.target = 0.15 + grips[hand] * 0.18
			_notify_touch(hand, grips[hand] * 0.8)
			rub_motion = maxf(rub_motion, hand_velocity[hand].length())
		else:
			var phase: float = clock * 0.22 + entry.phase
			var target: Vector3 = entry.home + Vector3(sin(phase * 0.73) * 0.07, sin(phase) * 0.085, cos(phase * 0.81) * 0.055)
			entry.velocity += (target - node.global_position) * dt * 0.65
			entry.velocity *= exp(-dt * 1.3)
			entry.velocity = entry.velocity.limit_length(0.38)
			node.global_position += entry.velocity * dt
			_keep_clear(entry, head)
		pressure = maxf(pressure, entry.target / 0.33)
		# Substep the rubber spring after hitches; never integrate a long pause.
		var remaining := dt
		while remaining > 0.00001:
			var step_size := minf(remaining, 1.0 / 180.0)
			entry.spring += ((entry.target-entry.squeeze) * 65.0 - entry.spring * 7.0) * step_size
			entry.squeeze = clampf(entry.squeeze + entry.spring * step_size, -0.10, 0.42)
			remaining -= step_size
		entry.material.set_shader_parameter("squeeze", entry.squeeze)
		node.rotation = entry.rotation + Vector3(sin(clock * 0.17 + entry.phase) * 0.045, sin(clock * 0.11 + entry.phase) * 0.09, sin(clock * 0.20 + entry.phase) * 0.07)
	# Soft pair separation prevents intersecting clusters. Held toys keep hand ownership.
	for i in toys.size():
		for j in range(i + 1, toys.size()):
			var a: Dictionary = toys[i]
			var b: Dictionary = toys[j]
			var separation: float = (a.radius + b.radius) * 1.08
			var offset: Vector3 = a.node.global_position - b.node.global_position
			if offset.length_squared() >= separation * separation:
				continue
			var normal := offset.normalized() if offset.length_squared() > 0.00001 else Vector3.RIGHT
			var correction := normal * (separation - offset.length())
			if a.holder < 0:
				a.node.global_position += correction * (0.5 if b.holder < 0 else 1.0)
			if b.holder < 0:
				b.node.global_position -= correction * (0.5 if a.holder < 0 else 1.0)
	for entry in toys:
		if entry.holder < 0:
			_keep_clear(entry, head)

func _hand_holds(hand: int) -> bool:
	for entry in toys:
		if entry.holder == hand:
			return true
	return false

func _keep_clear(entry: Dictionary, head: Vector3):
	var node: Node3D = entry.node
	var offset := node.global_position - head
	var clearance: float = entry.radius * 1.2 + 0.25
	if offset.length_squared() < clearance * clearance:
		var normal := offset.normalized() if offset.length_squared() > 0.00001 else Vector3.FORWARD
		node.global_position = head + normal * clearance
		entry.velocity += normal * 0.015
	node.global_position.y = maxf(node.global_position.y, floor_height + entry.radius * 2.7 + 0.10)

func _notify_touch(hand: int, strength: float):
	if haptic_delay[hand] <= 0.0:
		touched.emit(hand, clampf(strength, 0.0, 1.0))
		haptic_delay[hand] = 0.12
