#!/usr/bin/env python3
"""Build the mobile jungle depth pass from approved Poly Haven foliage.

Run from the repository root:
  blender --background --factory-startup --python bron/jungle_foliage_depth/make_assets.py

The source plants are real CC0 Poly Haven meshes. The editable Blender source
keeps the three 1K PBR materials; the compact GLB contains one mesh/material
slot per species/variant/LOD. Godot supplies the shared alpha-cutout shader and
MultiMesh batches at runtime.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "bron/jungle_foliage_depth"
SOURCE_ROOT = SOURCE_DIR / "polyhaven_source"
TEXTURE_ROOT = ROOT / "assets/textures/foliage/polyhaven"
SOURCE_BLEND = SOURCE_DIR / "jungle_foliage_depth.blend"
GAME_GLB = ROOT / "assets/jungle_depth_foliage.glb"
SPECIES = {
    # Runtime name, Poly Haven source, variants and target height in metres.
    "rosette": {
        "source": "anthurium_botany_01",
        "variants": [["anthurium_botany_01_a"], ["anthurium_botany_01_b"], ["anthurium_botany_01_c"]],
        "height": 0.53,
        "lod_ratios": [0.18, 0.07, 0.02],
    },
    "arch_fern": {
        "source": "fern_02",
        "variants": [["fern_02_a"], ["fern_02_b"], ["fern_02_c"]],
        "height": 0.64,
        "lod_ratios": [1.0, 0.60, 0.20],
    },
    # The old low groundcover was a hand-drawn fern card. Reuse the scanned
    # Poly Haven fern silhouettes at a lower target height and a mobile-first
    # triangle budget so all 14.5K existing instances can use real PBR leaves.
    "microcover": {
        "source": "fern_02",
        "variants": [["fern_02_a"], ["fern_02_b"], ["fern_02_c"]],
        "height": 0.34,
        "lod_ratios": [0.10, 0.05, 0.025],
        "lod_distances_m": [8.0, 22.0],
    },
    "red_bloom": {
        "source": "shrub_04",
        # Each small photographed branch is combined into one irregular low clump.
        # Angles, offsets and component choices vary between the three silhouettes.
        "variants": [
            [("shrub_04_a_LOD0", 0.0, (-0.035, 0.005)), ("shrub_04_c_LOD0", 2.2, (0.030, 0.020)), ("shrub_04_d_LOD0", 4.4, (0.010, -0.035))],
            [("shrub_04_b_LOD0", 0.7, (-0.020, -0.025)), ("shrub_04_c_LOD0", 2.9, (0.035, 0.005)), ("shrub_04_a_LOD0", 5.0, (-0.020, 0.035))],
            [("shrub_04_d_LOD0", 0.3, (-0.030, 0.025)), ("shrub_04_b_LOD0", 2.5, (0.035, -0.015)), ("shrub_04_c_LOD0", 4.8, (0.005, -0.035))],
        ],
        "height": 0.58,
        "lod_ratios": [0.095, 0.032, 0.009],
    },
}
TEXTURE_KEYS = {"rosette": "rosette", "arch_fern": "arch_fern", "microcover": "arch_fern", "red_bloom": "shrub"}


def activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def new_pbr_material(kind: str) -> bpy.types.Material:
    material = bpy.data.materials.new(f"PolyHaven_{kind}_PBR_1K")
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
    shader.inputs["Roughness"].default_value = 0.74
    shader.inputs["Specular IOR Level"].default_value = 0.28
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    def image_node(filename: str, color_space: str, location: tuple[float, float]) -> bpy.types.Node:
        image = bpy.data.images.load(str(TEXTURE_ROOT / filename), check_existing=True)
        image.colorspace_settings.name = color_space
        image.pack()
        node = nodes.new("ShaderNodeTexImage")
        node.image = image
        node.location = location
        node.label = filename
        return node

    texture_key = TEXTURE_KEYS[kind]
    color = image_node(f"{texture_key}_base_color.png", "sRGB", (-720, 260))
    links.new(color.outputs["Color"], shader.inputs["Base Color"])
    links.new(color.outputs["Alpha"], shader.inputs["Alpha"])
    normal = image_node(f"{texture_key}_normal_gl.png", "Non-Color", (-720, -20))
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    roughness = image_node(f"{texture_key}_roughness.png", "Non-Color", (-720, -300))
    links.new(roughness.outputs["Color"], shader.inputs["Roughness"])
    material.diffuse_color = (0.25, 0.34, 0.15, 1.0)
    return material


def load_source_objects(asset_id: str, required_names: set[str]) -> dict[str, bpy.types.Object]:
    blend_path = SOURCE_ROOT / asset_id / "source_blend.blend"
    with bpy.data.libraries.load(str(blend_path), link=False) as (source, destination):
        missing = required_names.difference(source.objects)
        if missing:
            raise RuntimeError(f"Missing {asset_id} objects: {sorted(missing)}")
        destination.objects = sorted(required_names)
    objects: dict[str, bpy.types.Object] = {}
    for obj in destination.objects:
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Expected source mesh in {asset_id}, got {obj}")
        bpy.context.scene.collection.objects.link(obj)
        objects[obj.name] = obj
    return objects


def object_root(obj: bpy.types.Object) -> tuple[Vector, list[Vector]]:
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(p.z for p in bounds)
    root = Vector(((min(p.x for p in bounds) + max(p.x for p in bounds)) * 0.5,
                   (min(p.y for p in bounds) + max(p.y for p in bounds)) * 0.5,
                   min_z))
    return root, bounds


def create_combined_variant(name: str, source_parts: list[tuple[bpy.types.Object, float, tuple[float, float]]],
                            target_height: float, material: bpy.types.Material) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    uv_faces: list[list[tuple[float, float]]] = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for source_obj, yaw, offset in source_parts:
        evaluated = source_obj.evaluated_get(depsgraph)
        source_mesh = evaluated.to_mesh()
        root, _ = object_root(source_obj)
        cosine, sine = math.cos(yaw), math.sin(yaw)
        vertex_offset = len(vertices)
        for vertex in source_mesh.vertices:
            world = source_obj.matrix_world @ vertex.co
            local = world - root
            x = local.x * cosine - local.y * sine + offset[0]
            y = local.x * sine + local.y * cosine + offset[1]
            vertices.append((x, y, local.z))
        uv_layer = source_mesh.uv_layers.active
        for polygon in source_mesh.polygons:
            faces.append(tuple(vertex_offset + index for index in polygon.vertices))
            if uv_layer:
                uv_faces.append([tuple(uv_layer.data[loop_index].uv) for loop_index in polygon.loop_indices])
            else:
                uv_faces.append([(0.5, 0.5)] * len(polygon.vertices))
        evaluated.to_mesh_clear()

    if not vertices or not faces:
        raise RuntimeError(f"No geometry assembled for {name}")
    min_z = min(vertex[2] for vertex in vertices)
    max_z = max(vertex[2] for vertex in vertices)
    height = max(max_z - min_z, 1e-5)
    scale = target_height / height
    vertices = [(x * scale, y * scale, (z - min_z) * scale) for x, y, z in vertices]

    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, uvs in zip(mesh.polygons, uv_faces):
        polygon.use_smooth = True
        for loop_index, uv in zip(polygon.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv
    mesh.materials.append(material)
    colors = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    radius_max = max(math.sqrt(vertex.co.x**2 + vertex.co.y**2) for vertex in mesh.vertices)
    height_max = max((vertex.co.z for vertex in mesh.vertices), default=target_height)
    for vertex in mesh.vertices:
        radial = math.sqrt(vertex.co.x**2 + vertex.co.y**2) / max(radius_max, 0.001)
        vertical = vertex.co.z / max(height_max, 0.001)
        wind = max(0.06, min(1.0, 0.10 + 0.56 * radial + 0.34 * vertical))
        colors.data[vertex.index].color = (1.0, 1.0, 1.0, wind)
    mesh.color_attributes.active_color = colors
    mesh.calc_loop_triangles()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def make_lod(source: bpy.types.Object, name: str, ratio: float, material: bpy.types.Material) -> bpy.types.Object:
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    obj.data.name = name + "_Mesh"
    bpy.context.scene.collection.objects.link(obj)
    if ratio < 0.999:
        modifier = obj.modifiers.new("Mobile_Lod_Decimate", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        activate(obj)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.data.calc_loop_triangles()
    return obj


def source_names(asset_id: str) -> set[str]:
    if asset_id == "fern_02":
        return {"fern_02_a", "fern_02_b", "fern_02_c"}
    if asset_id == "anthurium_botany_01":
        return {"anthurium_botany_01_a", "anthurium_botany_01_b", "anthurium_botany_01_c"}
    return {f"shrub_04_{letter}_LOD{lod}" for letter in "abcd" for lod in (0, 2)}


def main() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(datablocks):
            if item.users == 0:
                datablocks.remove(item)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"

    materials = {kind: new_pbr_material(kind) for kind in ("rosette", "arch_fern", "red_bloom")}
    materials["microcover"] = materials["arch_fern"]
    source_objects: dict[str, dict[str, bpy.types.Object]] = {}
    for data in SPECIES.values():
        asset_id = data["source"]
        if asset_id not in source_objects:
            source_objects[asset_id] = load_source_objects(asset_id, source_names(asset_id))

    build_manifest: dict[str, dict[str, object]] = {}
    generated: list[bpy.types.Object] = []
    for kind, spec in SPECIES.items():
        asset_id = str(spec["source"])
        objects = source_objects[asset_id]
        build_manifest[kind] = {"polyhaven_asset_id": asset_id, "variants": []}
        for variant, source_spec in enumerate(spec["variants"]):
            if kind == "red_bloom":
                parts = [(objects[name], yaw, offset) for name, yaw, offset in source_spec]
            else:
                parts = [(objects[source_spec[0]], 0.0, (0.0, 0.0))]
            base = create_combined_variant(f"HQ_{kind}_V{variant}_BASE", parts, float(spec["height"]), materials[kind])
            counts: list[int] = []
            for lod, ratio in enumerate(spec["lod_ratios"]):
                lod_source = base
                temporary_lod_source = None
                lod_ratio = float(ratio)
                if kind == "red_bloom" and lod == 2:
                    first_name = source_spec[0][0].replace("_LOD0", "_LOD2")
                    temporary_lod_source = create_combined_variant(
                        f"HQ_{kind}_V{variant}_LOD2_BASE",
                        [(objects[first_name], 0.0, (0.0, 0.0))],
                        float(spec["height"]), materials[kind],
                    )
                    lod_source = temporary_lod_source
                    # A single photographed source branch becomes the mobile
                    # long-range silhouette; this avoids the decimator's floor
                    # on three separate leafy islands.
                    lod_ratio = 0.10
                mesh_obj = make_lod(lod_source, f"HQ_{kind}_V{variant}_LOD{lod}", lod_ratio, materials[kind])
                if temporary_lod_source is not None:
                    bpy.data.objects.remove(temporary_lod_source, do_unlink=True)
                mesh_obj.data.calc_loop_triangles()
                counts.append(len(mesh_obj.data.loop_triangles))
                generated.append(mesh_obj)
            build_manifest[kind]["variants"].append({
                "source_objects": [name for name, _, _ in source_spec] if kind == "red_bloom" else [str(source_spec[0])],
                "triangles_lod0_lod1_lod2": counts,
                "dimensions_m_lod0": [round(value, 4) for value in generated[-3].dimensions],
            })
            bpy.data.objects.remove(base, do_unlink=True)

    # Delete the temporarily imported provider meshes and unused source materials.
    for objects in source_objects.values():
        for obj in objects.values():
            if obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj, do_unlink=True)
    keep_materials = {material.name for material in materials.values()}
    keep_images = {f"{key}_{suffix}.png" for key in TEXTURE_KEYS.values()
                   for suffix in ("base_color", "normal_gl", "roughness")}
    for mesh in list(bpy.data.meshes):
        if not mesh.users and not mesh.name.startswith("HQ_"):
            bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        if material.name not in keep_materials:
            bpy.data.materials.remove(material, do_unlink=True)
    for image in list(bpy.data.images):
        if image.name not in keep_images:
            bpy.data.images.remove(image, do_unlink=True)
    for image in bpy.data.images:
        if image.packed_file is None:
            image.pack()

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    GAME_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_BLEND))
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
        raise RuntimeError(f"GLB export failed: {result}")

    manifest = {
        "asset": "jungle_foliage_depth",
        "source_blend": "bron/jungle_foliage_depth/jungle_foliage_depth.blend",
        "generator": "bron/jungle_foliage_depth/make_assets.py",
        "units": "metres",
        "provider": "Poly Haven",
        "license": "CC0 1.0 Universal",
        "license_url": "https://polyhaven.com/license",
        "sources": {kind: spec["source"] for kind, spec in SPECIES.items()},
        "game_mesh_nodes": "One mesh per species, natural source variant and LOD; each species remains one cutout surface in cell-batched MultiMeshes.",
        "game_lod_distances_m": {"default": [20.0, 48.0], "microcover": [8.0, 22.0]},
        "runtime_materials": "Three 1K PBR texture sets with OpenGL normal and roughness, supplied by the shared Godot alpha-cutout foliage shader.",
        "collision": "None. Existing building clearance, actor collision, route and firing corridor remain in the owning scene code.",
        "wind": "Color alpha holds a root-to-tip vertex sway weight; one shared shader remains active.",
        "species": build_manifest,
    }
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
