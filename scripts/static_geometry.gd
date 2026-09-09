extends RefCounted
## Bake nonuniform transforms with inverse-transpose normals. SurfaceTool's
## append_from transforms normals as directions, which distorts soft highlights.

static func merge(entries: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var cache: Dictionary = {}
	for entry: Dictionary in entries:
		var mesh: Mesh = entry.node.mesh
		var id := mesh.get_instance_id()
		if not cache.has(id):
			cache[id] = mesh.surface_get_arrays(0)
		var source: Array = cache[id]
		var transform: Transform3D = entry.transform
		var base := vertices.size()
		var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		vertices.append_array(transform * source_vertices)
		var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var normal_matrix := transform.basis.inverse().transposed()
		for normal in source_normals:
			normals.append((normal_matrix * normal).normalized())
		if source[Mesh.ARRAY_TEX_UV] != null:
			uvs.append_array(source[Mesh.ARRAY_TEX_UV])
		else:
			uvs.resize(vertices.size())
		if source[Mesh.ARRAY_INDEX] != null:
			for index in source[Mesh.ARRAY_INDEX]:
				indices.append(base + index)
		else:
			for index in source_vertices.size():
				indices.append(base + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
