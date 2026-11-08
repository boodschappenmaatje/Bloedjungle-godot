#!/usr/bin/env python3
"""Build one mobile fern-clump field trial from the approved Poly Haven source.

Run from the project root with Blender 4.3+:
  blender --background --factory-startup --python bron/jungle_foliage_depth/make_fern_trial.py

This writes a separate review-only .blend and one-material GLB. It never
rebuilds or edits the shared jungle foliage asset or the live scatter.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_BLEND = ROOT / "bron/jungle_foliage_depth/polyhaven_source/fern_02/source_blend.blend"
SOURCE_TEXTURES = ROOT / "bron/jungle_foliage_depth/polyhaven_source/fern_02/textures"
GAME_GLB = ROOT / "assets/jungle_fern_trial.glb"
SOURCE_OUT = ROOT / "bron/jungle_foliage_depth/fern_trial.blend"
MANIFEST_OUT = ROOT / "bron/jungle_foliage_depth/fern_trial_manifest.json"
LOD_RATIOS = [1.0, 0.54, 0.18]
TARGET_HEIGHT_M = 0.68
PARTS = [
    ("fern_02_a", 0.15, (-0.045, -0.015), 1.0),
    ("fern_02_c", 2.35, (0.060, 0.035), 0.72),
]


def load_sources() -> dict[str, bpy.types.Object]:
    names = {part[0] for part in PARTS}
    with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (src, dst):
        missing = names.difference(src.objects)
        if missing:
            raise RuntimeError(f"Missing approved fern source object(s): {sorted(missing)}")
        dst.objects = sorted(names)
    sources: dict[str, bpy.types.Object] = {}
    source_collection = bpy.data.collections.new("Approved CC0 source ferns · Fern 02")
    bpy.context.scene.collection.children.link(source_collection)
    for obj in dst.objects:
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Expected a source mesh, got {obj}")
        source_collection.objects.link(obj)
        sources[obj.name] = obj
    return sources


def pbr_material() -> bpy.types.Material:
    material = bpy.data.materials.new("Fern 02 · shared high quality PBR")
    material.use_nodes = True
    material.use_backface_culling = False
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "DITHERED"
    if hasattr(material, "alpha_threshold"):
        material.alpha_threshold = 0.42
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 0.70
    shader.inputs["Specular IOR Level"].default_value = 0.24
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    def image(filename: str, color_space: str, location: tuple[int, int]) -> bpy.types.Node:
        texture = bpy.data.images.load(str(SOURCE_TEXTURES / filename), check_existing=True)
        texture.colorspace_settings.name = color_space
        texture.pack()
        node = nodes.new("ShaderNodeTexImage")
        node.image = texture
        node.location = location
        node.label = filename
        return node

    color = image("fern_02_diff_2k.jpg", "sRGB", (-760, 320))
    alpha = image("fern_02_alpha_2k.png", "Non-Color", (-760, 80))
    normal = image("fern_02_nor_gl_2k.exr", "Non-Color", (-760, -180))
    roughness = image("fern_02_rough_2k.exr", "Non-Color", (-760, -440))
    links.new(color.outputs["Color"], shader.inputs["Base Color"])
    links.new(alpha.outputs["Color"], shader.inputs["Alpha"])
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    links.new(roughness.outputs["Color"], shader.inputs["Roughness"])
    material.diffuse_color = (0.18, 0.31, 0.12, 1.0)
    return material


def source_root(obj: bpy.types.Object) -> tuple[Vector, list[Vector]]:
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    root = Vector(((min(p.x for p in bounds) + max(p.x for p in bounds)) * 0.5,
                   (min(p.y for p in bounds) + max(p.y for p in bounds)) * 0.5,
                   min(p.z for p in bounds)))
    return root, bounds


def build_cluster(sources: dict[str, bpy.types.Object], material: bpy.types.Material) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    face_uvs: list[list[tuple[float, float]]] = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for source_name, yaw, offset, scale in PARTS:
        source = sources[source_name]
        evaluated = source.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        root, _ = source_root(source)
        cosine, sine = math.cos(yaw), math.sin(yaw)
        vertex_offset = len(vertices)
        for vertex in mesh.vertices:
            local = (source.matrix_world @ vertex.co - root) * scale
            vertices.append((local.x * cosine - local.y * sine + offset[0],
                             local.x * sine + local.y * cosine + offset[1],
                             local.z))
        uv_layer = mesh.uv_layers.active
        for polygon in mesh.polygons:
            faces.append(tuple(vertex_offset + index for index in polygon.vertices))
            face_uvs.append([tuple(uv_layer.data[i].uv) for i in polygon.loop_indices]
                            if uv_layer else [(0.5, 0.5)] * len(polygon.vertices))
        evaluated.to_mesh_clear()

    if not vertices or not faces:
        raise RuntimeError("Fern trial cluster has no source geometry")
    min_z, max_z = min(v[2] for v in vertices), max(v[2] for v in vertices)
    height = max(max_z - min_z, 1e-5)
    scale = TARGET_HEIGHT_M / height
    vertices = [(x * scale, y * scale, (z - min_z) * scale) for x, y, z in vertices]

    mesh = bpy.data.meshes.new("FernTrial_Cluster_LOD0_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, uvs in zip(mesh.polygons, face_uvs):
        polygon.use_smooth = True
        for loop_index, uv in zip(polygon.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv
    mesh.materials.append(material)
    weights = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    radius_max = max(math.hypot(v.co.x, v.co.y) for v in mesh.vertices)
    for vertex in mesh.vertices:
        radial = math.hypot(vertex.co.x, vertex.co.y) / max(radius_max, 0.001)
        vertical = vertex.co.z / TARGET_HEIGHT_M
        sway_weight = max(0.06, min(1.0, 0.10 + 0.56 * radial + 0.34 * vertical))
        weights.data[vertex.index].color = (1.0, 1.0, 1.0, sway_weight)
    mesh.color_attributes.active_color = weights
    mesh.calc_loop_triangles()
    obj = bpy.data.objects.new("HQ_fern_trial_LOD0", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def create_lod(source: bpy.types.Object, lod: int, ratio: float) -> bpy.types.Object:
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = f"HQ_fern_trial_LOD{lod}"
    obj.data.name = f"FernTrial_Cluster_LOD{lod}_Mesh"
    bpy.context.scene.collection.objects.link(obj)
    if ratio < 0.999:
        modifier = obj.modifiers.new(f"FernTrial_Mobile_LOD{lod}", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.calc_loop_triangles()
    return obj


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    sources = load_sources()
    material = pbr_material()
    cluster = build_cluster(sources, material)
    generated = [cluster]
    triangle_counts = [len(cluster.data.loop_triangles)]
    for lod, ratio in enumerate(LOD_RATIOS[1:], start=1):
        obj = create_lod(cluster, lod, ratio)
        generated.append(obj)
        triangle_counts.append(len(obj.data.loop_triangles))

    # Keep both source ferns editable in the source file, outside the runtime GLB.
    for source in sources.values():
        source.hide_render = True
        source.hide_viewport = True
        source.name = "Source_" + source.name
    for image_node in material.node_tree.nodes:
        if image_node.type == "TEX_IMAGE" and image_node.image and image_node.image.packed_file is None:
            image_node.image.pack()

    SOURCE_OUT.parent.mkdir(parents=True, exist_ok=True)
    GAME_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_OUT))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in generated:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = generated[0]
    result = bpy.ops.export_scene.gltf(
        filepath=str(GAME_GLB), export_format="GLB", export_yup=True,
        export_tangents=True, export_normals=True, export_texcoords=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=True,
        export_apply=True, export_materials="NONE", use_selection=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Fern trial GLB export failed: {result}")

    mesh_dims = [round(value, 4) for value in cluster.dimensions]
    manifest = {
        "asset": "jungle_fern_trial",
        "purpose": "Review-only bospad field trial; not added to the live foliage scatter.",
        "source_blend": "bron/jungle_foliage_depth/fern_trial.blend",
        "generator": "bron/jungle_foliage_depth/make_fern_trial.py",
        "provider": "Poly Haven",
        "license": "CC0 1.0 Universal",
        "license_url": "https://polyhaven.com/license",
        "polyhaven_asset_id": "fern_02",
        "source_objects": [part[0] for part in PARTS],
        "pbr": {
            "runtime_material": "Shared Godot depth_arch_fern alpha-cutout material; no blended transparency.",
            "runtime_maps": ["assets/textures/foliage/polyhaven/arch_fern_base_color.png", "assets/textures/foliage/polyhaven/arch_fern_normal_gl.png", "assets/textures/foliage/polyhaven/arch_fern_roughness.png"],
            "runtime_map_size": "1024x1024 each; reused, no new texture payload",
            "normal": "OpenGL tangent normal",
        },
        "geometry": {
            "components": 2,
            "dimensions_m_lod0": mesh_dims,
            "triangles_lod0_lod1_lod2": triangle_counts,
            "lod_distances_m": [20.0, 48.0],
            "surfaces_per_lod": 1,
            "collisions": 0,
            "material_blend_transparency": False,
        },
        "placement": "The trial capture temporarily hides one existing arch_fern variant-0 MultiMesh batch in one bounded 24 m bospad cell; live placement and counts are unchanged.",
        "apple_quicklook": "Not generated in this Linux Blender 4.3.2 environment; the trial deliverable is the Godot comparison capture.",
    }
    MANIFEST_OUT.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
