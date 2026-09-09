"""Create an original inflated heart in an isolated Blender collection.

Run through the minipc Blender MCP, or with Blender --background --python.
Only this script's temporary mesh is removed; existing scenes stay intact.
The exported coordinates are Godot's Y-up convention. No external assets.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path


def build(out_dir):
    count, rings = 96, 20
    vertices, faces = [], []
    for hemisphere in (1, -1):
        start = len(vertices)
        vertices.append((0, hemisphere * 0.48, 0.03))
        for row in range(1, rings + 1):
            angle = row / rings * math.pi / 2
            radial = math.sin(angle)
            for i in range(count):
                t = i / count * math.tau
                x = math.sin(t) ** 3
                z = (13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) / 16 + 0.12
                depth = 0.48 * math.cos(angle) * (0.86 + 0.14 * math.sin(t)**2)
                vertices.append((x * radial, hemisphere * depth, 0.03 + (z - 0.03) * radial))
        for i in range(count):
            faces.append((start, start + 1 + i, start + 1 + (i + 1) % count))
        for row in range(rings - 1):
            for i in range(count):
                a = start + 1 + row * count + i
                b = start + 1 + row * count + (i + 1) % count
                faces.append((a, a + count, b + count, b))
    mesh = bpy.data.meshes.new("FoamHaven_Heart_Temporary")
    mesh.from_pydata(vertices, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.update()
    mesh.calc_loop_triangles()
    # Explicit normals and continuous UVs, with smooth front/back seam.
    lines = ["# Original Foam Haven inflated heart; generated with Blender MCP"]
    for v in mesh.vertices:
        lines.append("v %.7f %.7f %.7f" % (v.co.x, v.co.z, -v.co.y))
    for v in mesh.vertices:
        lines.append("vn %.7f %.7f %.7f" % (v.normal.x, v.normal.z, -v.normal.y))
    for v in mesh.vertices:
        lines.append("vt %.7f %.7f" % (v.co.x * 0.5 + 0.5, v.co.z * 0.5 + 0.5))
    for tri in mesh.loop_triangles:
        lines.append("f " + " ".join(f"{i+1}/{i+1}/{i+1}" for i in tri.vertices))
    path = Path(out_dir) / "dream_heart.obj"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")
    print(json.dumps({"asset": str(path), "vertices": len(mesh.vertices), "triangles": len(mesh.loop_triangles), "license": "project MIT", "blender": bpy.app.version_string}))
    bpy.data.meshes.remove(mesh)


if __name__ == "__main__":
    build("/workspace/foam-haven-dream")
