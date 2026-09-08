extends RefCounted
## Shared, deterministic silhouette meshes. Detail belongs in the outline first.
var cache: Dictionary = {}

func lathe(key: String, profile: PackedVector2Array, segments: int = 48, lobes: float = 0.0, twist: float = 0.0) -> ArrayMesh:
	if cache.has(key):
		return cache[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in profile.size():
		var v := float(j) / (profile.size() - 1)
		var tangent := profile[mini(j + 1, profile.size() - 1)] - profile[maxi(0, j - 1)]
		for i in range(segments + 1):
			var u := float(i) / segments
			var a := u * TAU
			var modulation := 1.0 + lobes * cos(a * 8.0 + twist * v)
			vertices.append(Vector3(cos(a) * profile[j].x * modulation, profile[j].y, sin(a) * profile[j].x * modulation))
			normals.append(Vector3(cos(a) * tangent.y, -tangent.x, sin(a) * tangent.y).normalized())
			uvs.append(Vector2(u, v))
			if j < profile.size() - 1 and i < segments:
				var k := j * (segments + 1) + i
				indices.append_array(PackedInt32Array([k, k + 1, k + segments + 1, k + 1, k + segments + 2, k + segments + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Profile normals retain a continuous highlight across the UV seam.
	cache[key] = mesh
	return mesh

func balloon() -> ArrayMesh:
	var p := PackedVector2Array([Vector2(0, -1.30), Vector2(0.055, -1.30), Vector2(0.08, -1.22)])
	for i in range(1, 33):
		var t := float(i) / 33.0
		var a := t * PI
		p.append(Vector2(sin(a) * (0.73 + 0.27 * sin(t * PI * 0.5)), -1.20 + (1.0 - cos(a)) * 1.23))
	p.append(Vector2(0, 1.26))
	return lathe("balloon", p, 48)

func jelly_bell() -> ArrayMesh:
	var p := PackedVector2Array([Vector2(0, -0.05), Vector2(0.60, -0.08), Vector2(0.98, -0.10)])
	for i in range(17):
		var a := float(i) / 16.0 * PI * 0.5
		p.append(Vector2(cos(a), sin(a) * 0.65))
	return lathe("jelly", p, 48, 0.025)

func cream() -> ArrayMesh:
	return lathe("piped_cream", PackedVector2Array([Vector2(0,-0.13), Vector2(0.19,-0.12), Vector2(0.23,-0.04), Vector2(0.21,0.05), Vector2(0.16,0.15), Vector2(0.10,0.23), Vector2(0.035,0.30), Vector2(0,0.33)]), 32, 0.16, -4.0)

func berry() -> ArrayMesh:
	return lathe("strawberry", PackedVector2Array([Vector2(0,-0.20), Vector2(0.06,-0.16), Vector2(0.13,-0.07), Vector2(0.18,0.05), Vector2(0.17,0.15), Vector2(0.10,0.20), Vector2(0,0.20)]), 32)

func macaron() -> ArrayMesh:
	return lathe("macaron", PackedVector2Array([Vector2(0,-0.10), Vector2(0.50,-0.10), Vector2(0.65,-0.08), Vector2(0.70,-0.025), Vector2(0.70,0.015), Vector2(0.66,0.09), Vector2(0.55,0.16), Vector2(0.32,0.205), Vector2(0,0.22)]), 48)

func curve(points: PackedVector3Array, radius: float, sides: int = 8, taper: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var tangent := (points[mini(i+1, points.size()-1)] - points[maxi(i-1, 0)]).normalized()
		var axis := Vector3.UP if absf(tangent.y) < 0.95 else Vector3.RIGHT
		var right := tangent.cross(axis).normalized()
		var up := right.cross(tangent).normalized()
		var v := float(i) / (points.size()-1)
		for j in range(sides + 1):
			var a := float(j) / sides * TAU
			var normal := right * cos(a) + up * sin(a)
			st.set_normal(normal)
			st.set_uv(Vector2(float(j) / sides, v))
			st.add_vertex(points[i] + normal * radius * lerpf(1.0, taper, v))
			if i < points.size()-1 and j < sides:
				var k := i * (sides+1) + j
				for index in [k, k+1, k+sides+1, k+1, k+sides+2, k+sides+1]:
					st.add_index(index)
	return st.commit()

func patch(key: String, ellipsoid: Vector3, coverage: Vector2) -> ArrayMesh:
	if cache.has(key):
		return cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 9:
		var r := float(ring) / 8.0
		for i in 49:
			var a := float(i) / 48.0 * TAU
			var x := cos(a) * r * coverage.x
			var y := sin(a) * r * coverage.y
			var n := Vector3(x, y, sqrt(maxf(0.001, 1.0-x*x-y*y)))
			st.set_normal((n / ellipsoid).normalized())
			st.set_uv(Vector2(x, y) * 0.5 + Vector2.ONE * 0.5)
			st.add_vertex(n * ellipsoid * 1.012)
			if ring < 8 and i < 48:
				var k := ring * 49 + i
				for index in [k, k+1, k+49, k+1, k+50, k+49]:
					st.add_index(index)
	cache[key] = st.commit()
	return cache[key]

func kelp() -> ArrayMesh:
	if cache.has("kelp"):
		return cache.kelp
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 25:
		var t := float(row) / 24.0
		var width := pow(sin(t * PI), 0.65) * 0.22 + 0.004
		for col in 3:
			var side := float(col - 1)
			st.set_uv(Vector2(float(col) / 2, t))
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(sin(t*4.0)*t*0.13 + side*width, t-0.5, side*side*sin(t*9.0)*0.045))
			if row < 24 and col < 2:
				var k := row*3+col
				for index in [k,k+3,k+1,k+1,k+3,k+4]:
					st.add_index(index)
	cache.kelp = st.commit()
	return cache.kelp

func rounded_box() -> ArrayMesh:
	if cache.has("rounded_box"):
		return cache.rounded_box
	var source := BoxMesh.new()
	source.subdivide_width = 7
	source.subdivide_height = 7
	source.subdivide_depth = 7
	var arrays := source.get_mesh_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in positions.size():
		var inner := positions[i].clamp(Vector3.ONE * -0.40, Vector3.ONE * 0.40)
		var normal := (positions[i] - inner).normalized()
		positions[i] = inner + normal * 0.10
		normals[i] = normal
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cache.rounded_box = mesh
	return mesh
