#!/usr/bin/env python3
"""Build the mobile Meshy base wall runtime GLB from its verified source.

Usage:
  blender --background --threads 4 --python bron/base_wall_hq2/build_wall.py -- \
    source_assets/base_wall_hq2/Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb

The original file is read only. The runtime scene contains three co-located
LODs using a shared material and 2K maps. Godot selects one LOD by distance.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import bpy
import bmesh


ROOT = Path(__file__).resolve().parents[2]
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SOURCE = Path(ARGS[0]).resolve() if ARGS else ROOT / "source_assets/base_wall_hq2/Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb"
RUNTIME = ROOT / "assets/base_wall_hq2.glb"
BLEND = ROOT / "bron/base_wall_hq2/uit/base_wall_hq2.blend"
REPORT = ROOT / "bron/base_wall_hq2/uit/base_wall_hq2_build.json"
SOURCE_SHA256 = "19df1f487dc1b98f4890354340b9e4dc93aad2baa21ec900ea1fe4f46d4e9d0e"
SOURCE_BYTES = 15535848
TARGET_SIZE = (3.5, 0.4, 3.0)  # Blender axes: length X, depth Y, height Z.
CORE_SIZE = (3.5, 0.4, 1.8)
LOD_TRIANGLES = ((6000, "Wall_LOD0"), (1600, "Wall_LOD1"), (350, "Wall_LOD2"))
ATLAS_SIZE = 2048


def triangles(mesh):
    return sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)


def bbox(mesh):
    used = {index for polygon in mesh.polygons for index in polygon.vertices}
    coords = [mesh.vertices[index].co for index in used]
    return [[min(v[i] for v in coords), max(v[i] for v in coords)] for i in range(3)]


def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")


def recalculate_normals(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def make_sandbag_material():
    material = bpy.data.materials.new("BaseWallHQ2_SharedJute")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    for filename, socket, colorspace in [
        ("base_color.jpg", "Base Color", "sRGB"),
        ("roughness.jpg", "Roughness", "Non-Color"),
    ]:
        image = bpy.data.images.load(str(ROOT / "assets/textures/buildings/jute" / filename), check_existing=True)
        image.colorspace_settings.name = colorspace
        image.pack()
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        links.new(texture.outputs["Color"], principled.inputs[socket])
    normal = bpy.data.images.load(str(ROOT / "assets/textures/buildings/jute/normal_gl.jpg"), check_existing=True)
    normal.colorspace_settings.name = "Non-Color"
    normal.pack()
    normal_texture = nodes.new("ShaderNodeTexImage")
    normal_texture.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    principled.inputs["Roughness"].default_value = 0.92
    return material


def make_sandbag_course(name, segments, rings, material):
    core_top = CORE_SIZE[2]
    rows = [
        ([-1.36 + i * (2.72 / 5.0) for i in range(6)], 0.78),
        ([-1.34 + i * 0.67 for i in range(5)], 0.84),
        ([-1.36 + i * (2.72 / 5.0) for i in range(6)], 0.78),
    ]
    vertices = []
    faces = []
    face_uvs = []
    x_fractions = [-0.5 + index / (rings - 1) for index in range(rings)]
    # Square, nearly full-size end faces meet the next 3.5 m module with no
    # visible pinholes through the shared sandbag courses.
    end_factors = [0.98] + [0.92 if index in (1, rings - 2) else 1.0 for index in range(1, rings - 1)] + [0.98]
    for row, (centers, width) in enumerate(rows):
        for index, center_x in enumerate(centers):
            center_z = core_top + 0.23 + row * 0.37
            start = len(vertices)
            yaw = ((index % 3) - 1) * 0.018
            for ring_index, fraction in enumerate(x_fractions):
                x_local = width * fraction
                taper = end_factors[ring_index]
                for segment in range(segments):
                    angle = 2.0 * math.pi * segment / segments
                    local_y = 0.20 * taper * math.sin(angle)
                    local_z = 0.23 * taper * math.cos(angle)
                    x = center_x + x_local * math.cos(yaw) - local_y * math.sin(yaw)
                    y = x_local * math.sin(yaw) + local_y * math.cos(yaw)
                    vertices.append((x, y, center_z + local_z))
            for ring_index in range(rings - 1):
                u0 = ring_index / (rings - 1)
                u1 = (ring_index + 1) / (rings - 1)
                for segment in range(segments):
                    next_segment = (segment + 1) % segments
                    v0 = segment / segments
                    v1 = (segment + 1) / segments
                    a = start + ring_index * segments + segment
                    b = start + ring_index * segments + next_segment
                    c = start + (ring_index + 1) * segments + next_segment
                    d = start + (ring_index + 1) * segments + segment
                    faces.append((a, b, c, d))
                    face_uvs.append(((u0, v0), (u0, v1), (u1, v1), (u1, v0)))
            for end_ring, reverse in ((0, True), (rings - 1, False)):
                end_x = width * x_fractions[end_ring]
                center = (center_x + end_x * math.cos(yaw), end_x * math.sin(yaw), center_z)
                center_index = len(vertices)
                vertices.append(center)
                for segment in range(segments):
                    next_segment = (segment + 1) % segments
                    a = start + end_ring * segments + segment
                    b = start + end_ring * segments + next_segment
                    faces.append((center_index, b, a) if reverse else (center_index, a, b))
                    uv_center = (0.5, 0.5)
                    uv_next = (0.5 + 0.5 * math.cos(2.0 * math.pi * next_segment / segments), 0.5 + 0.5 * math.sin(2.0 * math.pi * next_segment / segments))
                    uv_current = (0.5 + 0.5 * math.cos(2.0 * math.pi * segment / segments), 0.5 + 0.5 * math.sin(2.0 * math.pi * segment / segments))
                    face_uvs.append((uv_center, uv_next, uv_current))
    mesh = bpy.data.meshes.new(name + "_SandbagMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    # GLTF exposes the first UV set as TEXCOORD_0. The Meshy source already
    # uses UVMap, so share that layer name and copy both islands into UV0 when
    # the sandbag mesh is joined; a second UV channel would leave the jute
    # surfaces sampling the unrelated Meshy atlas in Godot.
    uv = mesh.uv_layers.new(name="UVMap")
    for polygon, coords in zip(mesh.polygons, face_uvs):
        for loop_index, coordinate in zip(polygon.loop_indices, coords):
            uv.data[loop_index].uv = coordinate
    mesh.materials.append(material)
    combined = bpy.data.objects.new(name + "_SandbagCourse", mesh)
    bpy.context.scene.collection.objects.link(combined)
    recalculate_normals(combined)
    return combined


def join_meshes(target, addition):
    deselect_all()
    target.select_set(True)
    addition.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    target.data.update()


def create_lod(source, name, target_tris, collection):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    collection.objects.link(obj)
    modifier = obj.modifiers.new("Mobile LOD decimation", "DECIMATE")
    modifier.ratio = min(1.0, target_tris / max(1, triangles(obj.data)))
    deselect_all()
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.name = name + "Mesh"
    obj["wall_lod"] = name
    obj["target_triangles"] = target_tris
    obj.hide_render = False
    obj.hide_set(False)
    return obj


def main():
    started = time.time()
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    raw = SOURCE.read_bytes()
    source_hash = hashlib.sha256(raw).hexdigest()
    if len(raw) != SOURCE_BYTES or source_hash != SOURCE_SHA256 or raw[:4] != b"glTF":
        raise RuntimeError("Source size, GLB signature, or SHA-256 does not match the transfer contract")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    source_objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(source_objects) != 1 or len(source_objects[0].data.materials) != 1 or not source_objects[0].data.uv_layers:
        raise RuntimeError("Expected exactly one source mesh, one material, and a UV set")
    high = source_objects[0]
    high.name = "Wall_HQ_Source"
    material_source = high.data.materials[0]
    material_source.use_nodes = True
    initial_bounds = bbox(high.data)
    initial_size = [b[1] - b[0] for b in initial_bounds]
    if min(initial_size) <= 0:
        raise RuntimeError(f"Invalid source bounds: {initial_size}")

    # Apply exact authored dimensions around the center of the source bounds.
    # The source aspect differs from its Meshy prompt; a baked tangent normal
    # keeps its dense wood, fasteners and weathering details readable.
    centers = [(b[0] + b[1]) * 0.5 for b in initial_bounds]
    scales = [CORE_SIZE[i] / initial_size[i] for i in range(3)]
    for vertex in high.data.vertices:
        vertex.co.x = (vertex.co.x - centers[0]) * scales[0]
        vertex.co.y = (vertex.co.y - centers[1]) * scales[1]
        vertex.co.z = (vertex.co.z - initial_bounds[2][0]) * scales[2]
    high.data.update()
    recalculate_normals(high)
    high["source_sha256"] = source_hash
    high["source_dimensions_m"] = initial_size
    high["core_dimensions_m"] = CORE_SIZE
    high["runtime_dimensions_m"] = TARGET_SIZE
    high["applied_axis_scale"] = scales
    high.hide_render = True
    high.hide_set(True)

    # The source's measured 1 m height does not match its approved 3 m target.
    # Preserve its proportions as a 1.8 m Meshy core and finish the remaining
    # 1.2 m with three restrained rows of shared, low-poly jute sandbags.
    # This keeps the US stencil and concrete supports intact without stretching
    # the source silhouette vertically to three times its measured height.
    runtime_collection = bpy.data.collections.new("Base Wall HQ2 Runtime LODs")
    bpy.context.scene.collection.children.link(runtime_collection)
    jute_material = make_sandbag_material()
    lods = []
    for core_budget, name in LOD_TRIANGLES:
        obj = create_lod(high, name, core_budget, runtime_collection)
        obj.data.materials.append(jute_material)
        bag_segments, bag_rings = {
            "Wall_LOD0": (10, 7),
            "Wall_LOD1": (8, 5),
            "Wall_LOD2": (4, 3),
        }[name]
        bags = make_sandbag_course(name, bag_segments, bag_rings, jute_material)
        join_meshes(obj, bags)
        lods.append(obj)

    # The approved source already has a valid authored 2K tangent normal map.
    # Keep it as the shared normal source after decimation; an earlier geometry
    # bake on the coincident source/target surfaces produced empty UV regions.
    normal_source_image = next((
        link.from_node.image
        for link in material_source.node_tree.links
        if link.to_node.type == "NORMAL_MAP"
        and link.from_node.type == "TEX_IMAGE"
        and link.from_node.image
    ), None)
    if normal_source_image is None:
        raise RuntimeError("The Meshy PBR material does not expose its normal map")

    runtime_material = material_source.copy()
    runtime_material.name = "BaseWallHQ2_SharedPBR"
    for obj in lods:
        if len(obj.data.materials) == 0:
            obj.data.materials.append(runtime_material)
        else:
            obj.data.materials[0] = runtime_material
        if len(obj.data.materials) < 2:
            obj.data.materials.append(jute_material)
        else:
            obj.data.materials[1] = jute_material

    runtime_nodes = runtime_material.node_tree.nodes
    # Keep the Meshy color and ORM channels compact; normal data stays lossless.
    for node in runtime_nodes:
        if node.type != "TEX_IMAGE" or not node.image:
            continue
        image = node.image
        if max(image.size) > ATLAS_SIZE:
            factor = ATLAS_SIZE / max(image.size)
            image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
        if image == normal_source_image:
            image.file_format = "PNG"
            image.filepath_raw = str(ROOT / "source_assets/base_wall_hq2" / "BaseWallHQ2_MeshyNormal_2K.png")
            image.save()
            image.pack()
        else:
            image.file_format = "JPEG"
            image.filepath_raw = str(ROOT / "source_assets/base_wall_hq2" / (image.name.replace("/", "_") + ".jpg"))
            image.save()
            image.pack()
    for image in bpy.data.images:
        image.pack()

    # Exact local bounds are standardized after decimation; the geometric
    # correction is small and prevents sub-millimetre seams in module placement.
    for obj in lods:
        bounds = bbox(obj.data)
        size = [b[1] - b[0] for b in bounds]
        correction = [TARGET_SIZE[i] / size[i] for i in range(3)]
        for vertex in obj.data.vertices:
            vertex.co.x = (vertex.co.x - (bounds[0][0] + bounds[0][1]) * 0.5) * correction[0]
            vertex.co.y = (vertex.co.y - (bounds[1][0] + bounds[1][1]) * 0.5) * correction[1]
            vertex.co.z = (vertex.co.z - bounds[2][0]) * correction[2]
        recalculate_normals(obj)
        obj.data.update()
        obj.location = (0, 0, 0)
        obj.rotation_euler = (0, 0, 0)
        obj.scale = (1, 1, 1)
        obj.hide_render = False
        obj.hide_set(False)

    BLEND.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)

    deselect_all()
    for obj in lods:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = lods[0]
    bpy.ops.export_scene.gltf(filepath=str(RUNTIME), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="AUTO", export_animations=False,
                              export_cameras=False, export_lights=False)
    report = {
        "source": str(SOURCE.relative_to(ROOT)), "source_sha256": source_hash,
        "source_bytes": len(raw), "source_dimensions_blender_m": initial_size,
        "runtime_dimensions_blender_m": TARGET_SIZE, "core_dimensions_blender_m": CORE_SIZE,
        "axis_scale": scales,
        "uv_layers": len(high.data.uv_layers), "source_mesh_triangles": triangles(high.data),
        "lods": [{"name": obj.name, "triangles": triangles(obj.data), "vertices": len(obj.data.vertices), "uv_layers": len(obj.data.uv_layers), "bounds_m": bbox(obj.data)} for obj in lods],
        "source_material_count": 1, "runtime_material_count": 2,
        "texture_max_size": ATLAS_SIZE, "reused_source_tangent_normal": True,
        "runtime_bytes": RUNTIME.stat().st_size,
        "runtime_sha256": hashlib.sha256(RUNTIME.read_bytes()).hexdigest(),
        "build_seconds": round(time.time() - started, 2),
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print("BASE_WALL_HQ2_BUILD=" + json.dumps(report))


if __name__ == "__main__":
    main()
