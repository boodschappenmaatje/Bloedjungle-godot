"""Reproducible Blender source for B-depth broadleaf, fern, and bloom assets.

Run from the repository root after build_pbr_atlas.py:
  blender --background --factory-startup --python bron/jungle_foliage_depth/make_assets.py
The scene is authored Z-up in metres. GLB export converts it to glTF/Godot Y-up.
"""
from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "bron/jungle_foliage_depth"
ATLAS_DIR = ROOT / "assets/textures/foliage/depth_pass"
SOURCE_BLEND = SOURCE_DIR / "jungle_foliage_depth.blend"
GAME_GLB = ROOT / "assets/jungle_depth_foliage.glb"
SPECIES = ("rosette", "arch_fern", "red_bloom")


class Builder:
    def __init__(self) -> None:
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.uvs: list[tuple[tuple[float, float], ...]] = []
        self.weights: list[float] = []

    def vertex(self, p: tuple[float, float, float], weight: float) -> int:
        self.vertices.append(p)
        self.weights.append(max(0.0, min(1.0, weight)))
        return len(self.vertices) - 1

    def face(self, ids: tuple[int, ...], uv: tuple[tuple[float, float], ...]) -> None:
        self.faces.append(ids)
        self.uvs.append(uv)


def uv_leaf(t: float, width: float, *, region: str = "leaf") -> tuple[float, float]:
    # Each quadrant of the shared 1024² atlas carries an authored 512px source.
    regions = {
        "leaf": (0.02, 0.48, 0.52, 0.98),
        "flower": (0.52, 0.98, 0.52, 0.98),
        # Fern and palm sources are 512×256 in the approved pack and are
        # centered vertically in their 512px atlas cells.
        "fern": (0.02, 0.48, 0.125, 0.375),
        "palm": (0.52, 0.98, 0.125, 0.375),
    }
    u0, u1, v0, v1 = regions[region]
    return (u0 + (u1 - u0) * t, v0 + (v1 - v0) * width)


def leaf(builder: Builder, origin: Vector, yaw: float, length: float, width: float,
         rise: float, droop: float, segments: int, across: int,
         region: str = "leaf", phase: float = 0.0) -> None:
    direction = Vector((__import__("math").cos(yaw), __import__("math").sin(yaw), 0.0))
    side = Vector((-direction.y, direction.x, 0.0))
    rows: list[list[int]] = []
    # Pointed edges and a raised midrib give the leaf a shallow PBR-catching fold.
    profile = [-1.0, -0.45, 0.0, 0.45, 1.0] if across >= 4 else [-1.0, 1.0]
    for i in range(segments + 1):
        t = i / max(segments, 1)
        taper = max(0.015, __import__("math").sin(__import__("math").pi * (t ** 0.76)))
        center = origin + direction * (length * t)
        center.z += rise * __import__("math").sin(__import__("math").pi * min(t, 1.0) * 0.72) - droop * t * t
        row = []
        for q in profile:
            ridge = (1.0 - abs(q)) * width * 0.12
            p = center + side * (q * width * taper)
            p.z += ridge - abs(q) * width * (0.05 + 0.04 * __import__("math").sin(t * __import__("math").pi))
            p.z += phase * (t - 0.35) * 0.035
            row.append(builder.vertex(tuple(p), 0.03 + 0.97 * t * t))
        rows.append(row)
    for i in range(segments):
        t0, t1 = i / max(segments, 1), (i + 1) / max(segments, 1)
        for j in range(len(profile) - 1):
            v0, v1 = j / (len(profile) - 1), (j + 1) / (len(profile) - 1)
            a, b, c, d = rows[i][j], rows[i][j + 1], rows[i + 1][j], rows[i + 1][j + 1]
            builder.face((a, c, b), (uv_leaf(t0, v0, region=region), uv_leaf(t1, v0, region=region), uv_leaf(t0, v1, region=region)))
            builder.face((b, c, d), (uv_leaf(t0, v1, region=region), uv_leaf(t1, v0, region=region), uv_leaf(t1, v1, region=region)))


def rod(builder: Builder, start: Vector, end: Vector, radius: float, sides: int = 5, steps: int = 3) -> None:
    import math
    axis = end - start
    if axis.length < 1e-6:
        return
    axis.normalize()
    tangent = axis.cross(Vector((0, 1, 0)))
    if tangent.length < 1e-4:
        tangent = axis.cross(Vector((1, 0, 0)))
    tangent.normalize()
    bitangent = axis.cross(tangent).normalized()
    rings = []
    for i in range(steps + 1):
        t = i / steps
        center = start.lerp(end, t)
        rr = radius * (1.0 - 0.45 * t)
        ring = []
        for s in range(sides):
            a = 2.0 * math.pi * s / sides
            p = center + tangent * (math.cos(a) * rr) + bitangent * (math.sin(a) * rr)
            ring.append(builder.vertex(tuple(p), 0.2 + 0.65 * t))
        rings.append(ring)
    for i in range(steps):
        for s in range(sides):
            a, b = rings[i][s], rings[i][(s + 1) % sides]
            c, d = rings[i + 1][s], rings[i + 1][(s + 1) % sides]
            # Narrow UV strips use the leaf's central vein and remain within the same atlas.
            u0 = 0.02 + 0.46 * s / sides
            u1 = 0.02 + 0.46 * (s + 1) / sides
            v0, v1 = 0.45 + 0.12 * i / steps, 0.45 + 0.12 * (i + 1) / steps
            builder.face((a, b, c), ((u0, v0), (u1, v0), (u0, v1)))
            builder.face((b, d, c), ((u1, v0), (u1, v1), (u0, v1)))


def broadleaf(lod: int) -> Builder:
    import math
    b = Builder()
    count, seg, across = ((9, 9, 4), (7, 4, 2), (5, 1, 1))[lod]
    for i in range(count):
        yaw = math.tau * i / count + (i % 3 - 1) * 0.09
        length = (0.46 + 0.14 * ((i * 7) % 5) / 4.0) * (1.0 if lod == 0 else 0.98)
        width = 0.105 + 0.025 * (i % 4) / 3.0
        start = Vector((math.cos(yaw) * 0.06, math.sin(yaw) * 0.06, 0.025 + 0.012 * (i % 3)))
        leaf(b, start, yaw, length, width, 0.18 + 0.08 * (i % 4) / 3.0, 0.03 + 0.035 * (i % 2), seg, across, phase=(i % 3 - 1))
    return b


def fern(lod: int) -> Builder:
    import math
    b = Builder()
    fronds, segments, across = ((9, 8, 4), (7, 4, 3), (5, 2, 2))[lod]
    for i in range(fronds):
        yaw = math.tau * i / fronds + 0.12 * math.sin(i * 2.1)
        length = (0.78 + 0.18 * ((i * 5) % 7) / 6.0) if lod == 0 else (0.8 + 0.12 * (i % 3) / 2.0)
        start = Vector((math.cos(yaw) * 0.035, math.sin(yaw) * 0.035, 0.035))
        direction = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        side = Vector((-direction.y, direction.x, 0.0))
        height = (0.38 + 0.11 * (i % 4) / 3.0) if lod == 0 else (0.34 + 0.07 * (i % 3) / 2.0)
        droop = 0.11 + 0.035 * (i % 3)
        rows: list[list[int]] = []
        profile = [-1.0 + 2.0 * column / across for column in range(across + 1)]
        for row in range(segments + 1):
            t = row / segments
            center = start + direction * (length * t)
            center.z += height * math.sin(math.pi * t * 0.76) - droop * t * t
            # Slightly bowed geometry plus the fern normal map keeps the long frond
            # dimensional without turning it into a flat billboard.
            spread = (0.12 + 0.09 * math.sin(math.pi * min(1.0, t * 1.15))) * (1.0 - 0.35 * t)
            line: list[int] = []
            for q in profile:
                p = center + side * (q * spread)
                p.z += (1.0 - abs(q)) * 0.018 - abs(q) * 0.018
                line.append(b.vertex(tuple(p), 0.03 + 0.97 * t * t))
            rows.append(line)
        for row in range(segments):
            t0, t1 = row / segments, (row + 1) / segments
            for col in range(len(profile) - 1):
                v0 = col / (len(profile) - 1)
                v1 = (col + 1) / (len(profile) - 1)
                a, c = rows[row][col], rows[row + 1][col]
                bb, d = rows[row][col + 1], rows[row + 1][col + 1]
                b.face((a, c, bb), (uv_leaf(t0, v0, region="fern"), uv_leaf(t1, v0, region="fern"), uv_leaf(t0, v1, region="fern")))
                b.face((bb, c, d), (uv_leaf(t0, v1, region="fern"), uv_leaf(t1, v0, region="fern"), uv_leaf(t1, v1, region="fern")))
        # Raised central rachis is real geometry; the surrounding leaflets use the
        # project's finely cut, 512px fern texture on the curved frond surface.
        middle = start + direction * (length * 0.52)
        middle.z += height * math.sin(math.pi * 0.52 * 0.76) - droop * 0.52 * 0.52
        tip = start + direction * length
        tip.z += height * math.sin(math.pi * 0.76) - droop
        rod(b, start, middle, 0.010 if lod == 0 else 0.008, sides=4, steps=2)
        rod(b, middle, tip, 0.008 if lod == 0 else 0.006, sides=4, steps=2)
    return b


def flowering(lod: int) -> Builder:
    import math
    b = Builder()
    if lod == 0:
        leaves, spikes, seg, across = 7, 4, 6, 3
    elif lod == 1:
        leaves, spikes, seg, across = 5, 3, 3, 2
    else:
        leaves, spikes, seg, across = 3, 2, 1, 1
    for i in range(leaves):
        yaw = math.tau * i / leaves + 0.14 * math.sin(i * 1.7)
        length = 0.32 + 0.08 * (i % 4) / 3.0
        start = Vector((math.cos(yaw) * 0.045, math.sin(yaw) * 0.045, 0.025))
        leaf(b, start, yaw, length, 0.075 + 0.012 * (i % 2), 0.15 + 0.09 * (i % 3) / 2.0, 0.025, seg, across, region="palm" if i % 2 == 0 else "leaf", phase=(i % 3 - 1) * 0.25)
    for i in range(spikes):
        angle = math.tau * i / max(spikes, 1) + 0.2
        base = Vector((math.cos(angle) * 0.06, math.sin(angle) * 0.06, 0.05))
        top = base + Vector((math.cos(angle) * 0.09, math.sin(angle) * 0.09, 0.66 - 0.07 * i))
        rod(b, base, top, 0.009, sides=5, steps=4)
        buds = 6 if lod == 0 else (4 if lod == 1 else 2)
        for j in range(buds):
            t = 0.52 + 0.42 * j / max(buds - 1, 1)
            center = base.lerp(top, t)
            petal_length = (0.115 if lod == 0 else (0.105 if lod == 1 else 0.09)) * (1.0 - 0.18 * t)
            for petal in range(3 if lod < 2 else 2):
                petal_yaw = angle + math.tau * petal / (3 if lod < 2 else 2) + 0.18 * (j % 2)
                leaf(b, center, petal_yaw, petal_length, petal_length * 0.46, 0.025, 0.006, seg, across, region="flower", phase=0.18 * (j % 2))
    return b


BUILDERS = {"rosette": broadleaf, "arch_fern": fern, "red_bloom": flowering}


def make_material() -> bpy.types.Material:
    material = bpy.data.materials.new("B_Depth_Jungle_Leaf_PBR_1K")
    material.use_nodes = True
    material.use_backface_culling = False
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.32
    bsdf.inputs["Alpha"].default_value = 1.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    color = nodes.new("ShaderNodeTexImage")
    color.image = bpy.data.images.load(str(ATLAS_DIR / "jungle_leaf_flower_base_color.png"), check_existing=True)
    color.image.colorspace_settings.name = "sRGB"
    links.new(uv.outputs["UV"], color.inputs["Vector"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    alpha = color.outputs["Alpha"]
    links.new(alpha, bsdf.inputs["Alpha"])
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = bpy.data.images.load(str(ATLAS_DIR / "jungle_leaf_flower_normal_gl.png"), check_existing=True)
    normal.image.colorspace_settings.name = "Non-Color"
    links.new(uv.outputs["UV"], normal.inputs["Vector"])
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.78
    links.new(normal.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    rough = nodes.new("ShaderNodeTexImage")
    rough.image = bpy.data.images.load(str(ATLAS_DIR / "jungle_leaf_flower_roughness.png"), check_existing=True)
    rough.image.colorspace_settings.name = "Non-Color"
    links.new(uv.outputs["UV"], rough.inputs["Vector"])
    links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    material.diffuse_color = (0.33, 0.49, 0.20, 1.0)
    return material


def create_mesh(name: str, builder: Builder, material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly, uvs in zip(mesh.polygons, builder.uvs):
        for loop_index, uv in zip(poly.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv
        poly.use_smooth = True
    colors = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i, weight in enumerate(builder.weights):
        colors.data[i].color = (1.0, 1.0, 1.0, weight)
    mesh.color_attributes.active_color = colors
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def main() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        # Keep generated data clean if the script is rerun in an existing process.
        for item in list(datablocks):
            if item.users == 0:
                datablocks.remove(item)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    material = make_material()
    stats: dict[str, dict[str, int]] = {}
    for species in SPECIES:
        stats[species] = {}
        for lod in range(3):
            name = f"HQ_{species}_LOD{lod}"
            obj = create_mesh(name, BUILDERS[species](lod), material)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.normals_make_consistent(inside=False)
            bpy.ops.object.mode_set(mode="OBJECT")
            obj.data.calc_loop_triangles()
            stats[species][str(lod)] = len(obj.data.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_BLEND))
    bpy.ops.object.select_all(action="SELECT")
    result = bpy.ops.export_scene.gltf(
        filepath=str(GAME_GLB), export_format="GLB", export_yup=True,
        export_tangents=True, export_normals=True, export_texcoords=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=True, export_apply=True, export_materials="EXPORT",
        export_image_format="AUTO", export_keep_originals=False,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"GLB export failed: {result}")
    triangles = {name: values for name, values in stats.items()}
    manifest = {
        "asset": "jungle_foliage_depth",
        "source_blend": "bron/jungle_foliage_depth/jungle_foliage_depth.blend",
        "generator": "bron/jungle_foliage_depth/make_assets.py",
        "units": "metres",
        "lod_nodes": "One GLB node per species/LOD; game code merges each species into a MultiMesh mesh with native ArrayMesh LOD index sets.",
        "materials": 1,
        "texture_set": "assets/textures/foliage/depth_pass/",
        "game_triangle_counts": triangles,
        "wind": "Vertex alpha is authored root-to-tip wind weight; Godot foliage shader drives sway.",
        "collisions": "None; render-only foliage.",
    }
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
