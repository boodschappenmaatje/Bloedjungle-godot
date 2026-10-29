#!/usr/bin/env python3
"""Build the player-only Jungle Commando GLB and editable Blender source.

Input is the shipped VQ2 GLB so the source remains compatible with Blender 4.5.
The shared soldier asset is read only and never overwritten.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path)
    p.add_argument("--blend", required=True, type=Path)
    p.add_argument("--glb", required=True, type=Path)
    p.add_argument("--textures", required=True, type=Path)
    p.add_argument("--report", required=True, type=Path)
    return p.parse_args(raw)


def srgb_to_linear(rgb):
    a = np.asarray(rgb, dtype=np.float32) / 255.0
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def tiger_stripe(path: Path, size=2048):
    """Make an original tileable tiger-stripe color map; existing normal/ORM maps stay intact."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / size
    v = yy / size
    warp = u + 0.020 * np.sin(2 * np.pi * (v * 2.2 + 0.18 * np.sin(u * 9.0)))
    warp += 0.009 * np.sin(2 * np.pi * (v * 6.0 - u * 2.1))
    phase = np.mod(warp * 13.0 + 0.025 * np.sin(2 * np.pi * v * 3.0), 1.0)
    ragged = 0.035 * np.sin(2 * np.pi * (v * 18 + u * 1.7)) + 0.018 * np.sin(2 * np.pi * (v * 47 - u * 2.0))
    stripe = (phase < 0.15 + ragged) | ((phase > 0.54) & (phase < 0.61 + ragged * 0.4))
    dark = (phase > 0.15 + ragged) & (phase < 0.22 + ragged)

    broad = (np.sin(2 * np.pi * (u * 3.0 + v * 1.2)) + np.sin(2 * np.pi * (v * 2.1 - u * 1.1))) * 0.5
    palette = np.empty((size, size, 3), dtype=np.float32)
    palette[:] = np.array([101, 111, 71], dtype=np.float32)  # olive textile ground
    palette[broad > 0.47] = [129, 117, 83]                    # subdued khaki variation
    palette[broad < -0.49] = [76, 91, 57]                    # moss variation
    palette[stripe] = [48, 58, 43]                           # broken dark green bands
    palette[dark] = [37, 37, 31]                             # narrow charcoal accents
    rng = np.random.default_rng(138)
    grain = rng.normal(0.0, 2.0, (size, size, 1)).astype(np.float32)
    palette = np.clip(palette + grain, 0, 255)
    rgba = np.concatenate((srgb_to_linear(palette), np.ones((size, size, 1), dtype=np.float32)), axis=2)
    image = bpy.data.images.new("Tiger Stripe · 2K · original", width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def save_image(name, path, pixels, size, colorspace="sRGB"):
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(pixels.astype(np.float32, copy=False).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def micro_maps(directory, label, rgb, fabric=True, roughness_override=None):
    """Small tileable PBR maps for the new nylon or parkerized hardware."""
    size = 512
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    if fabric:
        h = 0.5 + 0.045 * np.sin(2 * np.pi * x / 6.0) + 0.045 * np.sin(2 * np.pi * y / 6.0)
        rough = 0.76 + 0.02 * np.sin(2 * np.pi * x / 6.0) * np.sin(2 * np.pi * y / 6.0)
        rng = np.random.default_rng(22)
        grain = rng.normal(0, 2.2, (size, size, 1)).astype(np.float32)
    else:
        h = 0.5 + 0.018 * np.sin(2 * np.pi * x / 46.0) + 0.012 * np.sin(2 * np.pi * y / 9.0)
        rough = 0.34 + 0.025 * np.sin(2 * np.pi * y / 9.0)
        rng = np.random.default_rng(23)
        grain = rng.normal(0, 1.2, (size, size, 1)).astype(np.float32)
    if roughness_override is not None:
        rough = np.clip(roughness_override + 0.015 * np.sin(2 * np.pi * y / 12.0), 0.0, 1.0)
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nx, ny, nz = -dx * 1.2, -dy * 1.2, np.ones_like(h)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / norm * 0.5 + 0.5, ny / norm * 0.5 + 0.5, nz / norm * 0.5 + 0.5), axis=2)
    base = np.asarray(rgb, dtype=np.float32)[None, None, :] + grain
    color = np.clip(base * (0.94 + 0.12 * h[:, :, None]), 0, 255)
    color = np.concatenate((srgb_to_linear(color), np.ones((size, size, 1), dtype=np.float32)), axis=2)
    rough_rgba = np.stack((rough, rough, rough, np.ones_like(rough)), axis=2)
    normal_rgba = np.concatenate((normal.astype(np.float32), np.ones((size, size, 1), dtype=np.float32)), axis=2)
    albedo = save_image(label + " albedo", directory / (label.lower().replace(" ", "_") + "_albedo_512.png"), color, size)
    roughness = save_image(label + " roughness", directory / (label.lower().replace(" ", "_") + "_roughness_512.png"), rough_rgba, size, "Non-Color")
    normal_map = save_image(label + " tangent normal", directory / (label.lower().replace(" ", "_") + "_normal_512.png"), normal_rgba, size, "Non-Color")
    return albedo, roughness, normal_map


def pbr_material(name, maps, metallic=0.0):
    albedo, roughness, normal = maps
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (0.12, 0.16, 0.095, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = albedo
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    rough_tex = nodes.new("ShaderNodeTexImage")
    rough_tex.image = roughness
    mat.node_tree.links.new(rough_tex.outputs["Color"], bsdf.inputs["Roughness"])
    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_tex.image = normal
    normal_node = nodes.new("ShaderNodeNormalMap")
    mat.node_tree.links.new(normal_tex.outputs["Color"], normal_node.inputs["Color"])
    mat.node_tree.links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def add_light_stubble(body, texture_dir):
    """Subtly add short facial stubble in UV space, confined to the lower face."""
    skin_slot = next((i for i, m in enumerate(body.data.materials) if m and m.name == "Uniform_Huid"), None)
    if skin_slot is None:
        raise RuntimeError("Uniform_Huid material required for the player face")
    skin = body.data.materials[skin_slot].copy()
    skin.name = "JungleCommando_Skin_Stubble"
    body.data.materials[skin_slot] = skin
    tex_node = next((n for n in skin.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name == "lijf_uniform_albedo"), None)
    if tex_node is None:
        raise RuntimeError("Could not locate the original skin albedo map")
    source = tex_node.image
    image = source.copy()
    image.name = "Commando skin · light stubble · 1K"
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((height, width, 4))
    uv_layer = body.data.uv_layers.active
    if uv_layer is None:
        raise RuntimeError("Player body is missing UVs for facial detail")
    skin_faces = [p for p in body.data.polygons if p.material_index == skin_slot and 1.49 <= p.center.z <= 1.615 and p.normal.y < -0.22]
    rng = np.random.default_rng(138)
    follicle_count = 0
    for poly in skin_faces:
        loop_ids = list(range(poly.loop_start, poly.loop_start + poly.loop_total))
        verts = list(poly.vertices)
        uvs = [uv_layer.data[i].uv[:] for i in loop_ids]
        for k in range(1, len(verts) - 1):
            ids = (0, k, k + 1)
            uv = np.asarray([uvs[i] for i in ids], dtype=np.float32)
            xyz = np.asarray([body.data.vertices[verts[i]].co[:] for i in ids], dtype=np.float32)
            tri_px = uv * np.array([width - 1, height - 1], dtype=np.float32)
            lo = np.maximum(np.floor(tri_px.min(axis=0)).astype(int), 0)
            hi = np.minimum(np.ceil(tri_px.max(axis=0)).astype(int), [width - 1, height - 1])
            if np.any(hi <= lo):
                continue
            gx, gy = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
            p2 = np.stack([gx, gy], axis=-1).astype(np.float32)
            a, b, c = tri_px
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(float(den)) < 1e-6:
                continue
            w0 = ((b[1] - c[1]) * (p2[..., 0] - c[0]) + (c[0] - b[0]) * (p2[..., 1] - c[1])) / den
            w1 = ((c[1] - a[1]) * (p2[..., 0] - c[0]) + (a[0] - c[0]) * (p2[..., 1] - c[1])) / den
            w2 = 1.0 - w0 - w1
            inside = (w0 >= -0.001) & (w1 >= -0.001) & (w2 >= -0.001)
            pos = w0[..., None] * xyz[0] + w1[..., None] * xyz[1] + w2[..., None] * xyz[2]
            # Mustache, chin and jaw only; cheeks and the clean upper face stay clear.
            z, x, y = pos[..., 2], pos[..., 0], pos[..., 1]
            band = ((z > 1.505) & (z < 1.565) & (np.abs(x) < 0.074)) | ((z > 1.565) & (z < 1.586) & (np.abs(x) < 0.043))
            front = y < -0.025
            density = np.clip((1.0 - (np.abs(x) / 0.082) ** 2) * 0.12, 0.0, 0.12)
            dots = rng.random(gx.shape) < density
            mask = inside & band & front & dots
            if not np.any(mask):
                continue
            patch = pixels[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
            # Slight warm charcoal variation, not a painted beard block.
            strength = rng.uniform(0.77, 0.91, int(mask.sum())).astype(np.float32)
            patch[mask, 0] *= strength * 0.96
            patch[mask, 1] *= strength * 0.88
            patch[mask, 2] *= strength * 0.82
            follicle_count += int(mask.sum())
    image.pixels.foreach_set(pixels.ravel())
    output = texture_dir / "commando_skin_stubble_1024.png"
    image.filepath_raw = str(output)
    image.file_format = "PNG"
    image.save()
    image.pack()
    tex_node.image = image
    return image, follicle_count


def skinned_surface(source, name, face_indices, rig, outer_material, inner_material, edge_material,
                    offset=0.0025, thickness=0.008, fold=None, inner_surface=True):
    """Create a separately skinned, closed garment layer from selected VQ2 faces.

    The outside follows the source garment, while the inside and hem are real geometry.
    Vertex weights, UVs and the 53-bone armature contract are copied from the source mesh.
    """
    face_indices = sorted(set(face_indices))
    if not face_indices:
        raise RuntimeError(f"No source faces selected for {name}")
    source_mesh = source.data
    uv_layer = source_mesh.uv_layers.active
    if uv_layer is None:
        raise RuntimeError(f"Source mesh {source.name} has no UV map")
    selected = [source_mesh.polygons[i] for i in face_indices]
    used_vertices = sorted({v for poly in selected for v in poly.vertices})
    index = {v: i for i, v in enumerate(used_vertices)}
    original_normals = {i: source_mesh.vertices[i].normal.normalized() for i in used_vertices}
    vertices = []
    for i in used_vertices:
        v = source_mesh.vertices[i]
        normal = original_normals[i]
        amount = fold(v.co, normal) if fold else 0.0
        vertices.append(v.co + normal * (offset + amount))
    for i in used_vertices:
        v = source_mesh.vertices[i]
        normal = original_normals[i]
        amount = fold(v.co, normal) * 0.45 if fold else 0.0
        vertices.append(v.co + normal * (offset - thickness + amount))

    faces = []
    face_materials = []
    face_uvs = []
    edge_counts = {}
    edge_uv = {}
    for poly in selected:
        ids = list(poly.vertices)
        outer = [index[v] for v in ids]
        inner = [index[v] + len(used_vertices) for v in reversed(ids)]
        uv_values = [uv_layer.data[li].uv.copy() for li in range(poly.loop_start, poly.loop_start + poly.loop_total)]
        faces.append(outer); face_materials.append(0); face_uvs.append(uv_values)
        if inner_surface:
            faces.append(inner); face_materials.append(1); face_uvs.append(list(reversed(uv_values)))
        for j, va in enumerate(ids):
            vb = ids[(j + 1) % len(ids)]
            key = tuple(sorted((va, vb)))
            edge_counts[key] = edge_counts.get(key, 0) + 1
            edge_uv.setdefault(key, (uv_values[j], uv_values[(j + 1) % len(ids)]))
    for (va, vb), count in edge_counts.items():
        if count != 1:
            continue
        a, b = index[va], index[vb]
        faces.append([a, b, b + len(used_vertices), a + len(used_vertices)])
        face_materials.append(2)
        uv_a, uv_b = edge_uv[(va, vb)]
        face_uvs.append([uv_a, uv_b, uv_b, uv_a])

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(outer_material)
    mesh.materials.append(inner_material)
    mesh.materials.append(edge_material)
    mesh.update()
    for i, poly in enumerate(mesh.polygons):
        poly.material_index = face_materials[i]
        poly.use_smooth = face_materials[i] != 2
    layer = mesh.uv_layers.new(name=uv_layer.name or "UVMap")
    for poly, uvs in zip(mesh.polygons, face_uvs):
        if len(uvs) != poly.loop_total:
            raise RuntimeError(f"UV loop mismatch while creating {name}")
        for li, uv in zip(range(poly.loop_start, poly.loop_start + poly.loop_total), uvs):
            layer.data[li].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    source.users_collection[0].objects.link(obj)
    obj.parent = rig
    obj.matrix_world = source.matrix_world.copy()
    groups = {group.index: obj.vertex_groups.new(name=group.name) for group in source.vertex_groups}
    memberships = [source_mesh.vertices[i].groups for i in used_vertices]
    for j, weights in enumerate(memberships):
        for item in weights:
            group = groups.get(item.group)
            if group is not None and item.weight > 0.0001:
                group.add([j, j + len(used_vertices)], item.weight, "REPLACE")
    arm = obj.modifiers.new("VQ2 garment skin", "ARMATURE")
    arm.object = rig
    obj["garment_layer"] = True
    obj["shell_thickness_m"] = thickness
    obj["source_face_count"] = len(selected)
    return obj


def face_weight(obj, poly, group_indices):
    total = 0.0
    for vi in poly.vertices:
        total += sum(item.weight for item in obj.data.vertices[vi].groups if item.group in group_indices)
    return total / len(poly.vertices)


def make_commando_body(image, texture_dir):
    original = bpy.data.objects.get("Lijf_Uniform")
    if original is None:
        raise RuntimeError("Lijf_Uniform body missing from the VQ2 GLB")
    mat = bpy.data.materials.get("Uniform_Kleding")
    if mat is None or not mat.use_nodes:
        raise RuntimeError("Uniform_Kleding PBR material missing from the VQ2 GLB")
    mat = mat.copy()
    mat.name = "JungleCommando_Camo"
    tree = mat.node_tree
    bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        raise RuntimeError("Uniform_Kleding has no Principled BSDF")
    color_input = bsdf.inputs.get("Base Color")
    old_link = next((l for l in list(color_input.links)), None)
    if old_link is None or old_link.from_node.type != "TEX_IMAGE":
        raise RuntimeError("Could not locate the original UV albedo map")
    old = old_link.from_node
    tree.links.remove(old_link)
    old.image = image
    tree.links.new(old.outputs["Color"], color_input)
    mat.diffuse_color = (0.31, 0.38, 0.23, 1.0)
    clone = original.copy()
    clone.data = original.data.copy()
    clone.name = "Lijf_JungleCommando"
    clone.data.name = "Lijf_JungleCommandoMesh"
    for index, slot_mat in enumerate(clone.data.materials):
        if slot_mat and slot_mat.name == "Uniform_Kleding":
            clone.data.materials[index] = mat
    if not any(slot_mat and slot_mat.name == "JungleCommando_Camo" for slot_mat in clone.data.materials):
        raise RuntimeError("Tiger Stripe material did not bind to the duplicate body")
    # Keep skin and uniform as one skinned under-layer; the new outfit is built as
    # separate weighted garment shells below instead of recoloring this surface alone.
    for poly in clone.data.polygons:
        center = poly.center
        if center.z > 1.49 and poly.material_index == 0:
            poly.use_smooth = True
    original.users_collection[0].objects.link(clone)
    clone.matrix_world = original.matrix_world.copy()
    garment_idx = next((i for i, material in enumerate(original.data.materials) if material and material.name == "Uniform_Kleding"), None)
    if garment_idx is None:
        raise RuntimeError("Uniform_Kleding slot missing from source body")
    top_faces, trouser_faces = [], []
    for poly in original.data.polygons:
        if poly.material_index != garment_idx:
            continue
        if poly.center.z <= 0.95:
            trouser_faces.append(poly.index)
        if poly.center.z >= 0.88:
            top_faces.append(poly.index)
    camo = bpy.data.materials["JungleCommando_Camo"]
    nylon = bpy.data.materials["Commando Nylon · Olive Drab"]
    binding = bpy.data.materials["Commando Webbing · Dark Olive"]

    def fabric_folds(part):
        def amount(co, normal):
            x, y, z = co
            if part == "trousers":
                centers = (0.34, 0.54, 0.79)
                envelope = sum(math.exp(-((z - c) / 0.043) ** 2) for c in centers)
                phase = math.atan2(y + 0.005, abs(x) + 0.012) * 3.3 + z * 14.0
                return 0.0060 * envelope * math.cos(phase)
            arm_envelope = math.exp(-((abs(x) - 0.45) / 0.055) ** 2) * math.exp(-((z - 1.43) / 0.11) ** 2)
            chest_envelope = math.exp(-((z - 1.12) / 0.08) ** 2) * math.exp(-((abs(x) - 0.12) / 0.09) ** 2)
            arm_phase = math.atan2(y - 0.035, z - 1.43) * 3.0 + abs(x) * 18.0
            chest_phase = math.sin(x * 42.0 + y * 35.0)
            return 0.0060 * arm_envelope * math.cos(arm_phase) + 0.0030 * chest_envelope * chest_phase
        return amount

    pants = skinned_surface(original, "Uniform_Trousers_Shell", trouser_faces, bpy.data.objects["Rig"], camo, nylon, binding, fold=fabric_folds("trousers"))
    jacket = skinned_surface(original, "Uniform_Jacket_Shell", top_faces, bpy.data.objects["Rig"], camo, nylon, binding, fold=fabric_folds("jacket"))

    # Separate cropped-hair shell: keep the front hairline above the brows and
    # taper the sides/back lower for a close military cut.
    head_index = next((g.index for g in original.vertex_groups if g.name == "DEF-head"), None)
    hair_faces = []
    if head_index is not None:
        for poly in original.data.polygons:
            weights = [sum(w.weight for w in original.data.vertices[vi].groups if w.group == head_index) for vi in poly.vertices]
            if sum(weights) / len(weights) < 0.35:
                continue
            front_hairline = poly.center.y < -0.055
            # The imported front scalp faces have centers down to z≈1.56m.
            # Include them so the forehead does not leave a skin-colored cap;
            # the side/back threshold stays lower for a close military crop.
            threshold = 1.590 if front_hairline else 1.535
            if poly.center.z > threshold:
                hair_faces.append(poly.index)
    if not hair_faces:
        raise RuntimeError("Could not identify scalp faces for the short-hair shell")
    hair = bpy.data.materials["Commando Hair · Short Dark Brown"]
    # The source skin mesh also contains the bald scalp surface. Reassign the
    # upper scalp polygons on the player-only copy to hair; the separate shell
    # by itself would leave that pale scalp showing through around its edges.
    scalp_slot = next((i for i, material in enumerate(clone.data.materials) if material and material.name == hair.name), None)
    if scalp_slot is None:
        clone.data.materials.append(hair)
        scalp_slot = len(clone.data.materials) - 1
    for poly in clone.data.polygons:
        if poly.index in hair_faces:
            poly.material_index = scalp_slot
        elif poly.material_index == 0 and 1.44 <= poly.center.z <= 1.60:
            # Softer skin normals around the face/ears reduce coarse faceting
            # without changing the original facial silhouette or UVs.
            poly.use_smooth = True
    hair_shell = skinned_surface(original, "Hair_Cropped", hair_faces, bpy.data.objects["Rig"], hair, hair, hair, offset=0.004, thickness=0.004)
    skin_image, stubble_pixels = add_light_stubble(clone, texture_dir)
    clone["facial_stubble_pixels"] = stubble_pixels
    return clone, [pants, jacket, hair_shell]


def new_box(name, location, dimensions, material, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Stitched rounded edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.harden_normals = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def new_cylinder(name, location, radius, depth, material, vertices=12, horizontal=False, bevel=True):
    rotation = (math.pi / 2, 0, 0) if horizontal else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Machined edge", "BEVEL")
        mod.width = min(radius * 0.2, depth * 0.15)
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def new_soft_volume(name, location, dimensions, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def new_rod_between(name, start, end, radius, material, vertices=8):
    a, b = Vector(start), Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=(a + b) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def merge_and_bind(objects, name, rig, bone_name="DEF-spine002"):
    if not objects:
        raise RuntimeError(f"No geometry to build {name}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    active = objects[0]
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = name
    active.data.name = name + "Mesh"
    group = active.vertex_groups.new(name=bone_name)
    group.add(list(range(len(active.data.vertices))), 1.0, "REPLACE")
    mod = active.modifiers.new("VQ2 rig attachment", "ARMATURE")
    mod.object = rig
    active.parent = rig
    active.matrix_parent_inverse = rig.matrix_world.inverted()
    active["Bloedjungle detail"] = "Player-only Tiger Stripe equipment; weighted to the existing VQ2 DEF rig"
    return active


def build_equipment(rig, texture_dir, source_body):
    olive_maps = micro_maps(texture_dir, "olive_nylon", (76, 88, 55), fabric=True)
    trim_maps = micro_maps(texture_dir, "dark_olive_webbing", (49, 60, 39), fabric=True)
    steel_maps = micro_maps(texture_dir, "parkerized_steel", (54, 59, 50), fabric=False)
    hair_maps = micro_maps(texture_dir, "short_cropped_hair", (28, 19, 16), fabric=False, roughness_override=0.92)
    boot_maps = micro_maps(texture_dir, "combat_boot_leather", (43, 39, 31), fabric=False, roughness_override=0.86)
    rubber_maps = micro_maps(texture_dir, "combat_boot_rubber", (26, 29, 26), fabric=False, roughness_override=0.94)
    olive = pbr_material("Commando Nylon · Olive Drab", olive_maps)
    trim = pbr_material("Commando Webbing · Dark Olive", trim_maps)
    hardware = pbr_material("Commando Hardware · Parkerized Steel", steel_maps, 0.72)
    boot_leather = pbr_material("Commando Combat Boot · Matte Leather", boot_maps, 0.03)
    boot_rubber = pbr_material("Commando Boot · Rubber Sole", rubber_maps, 0.0)
    hair_material = pbr_material("Commando Hair · Short Dark Brown", hair_maps)
    hair_bsdf = next(n for n in hair_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    # The head's imported UV atlas does not match the generated micro-map. Use
    # a stable dark-brown dielectric color while retaining the authored roughness
    # and normal maps, instead of allowing a pale generated-coordinate result.
    for link in list(hair_material.node_tree.links):
        if link.to_node == hair_bsdf and link.to_socket.name == "Base Color":
            hair_material.node_tree.links.remove(link)
    hair_bsdf.inputs["Base Color"].default_value = (0.012, 0.007, 0.005, 1.0)
    boot_mesh = bpy.data.objects["Laarzen"].data
    boot_mesh.materials.clear()
    boot_mesh.materials.append(boot_leather)
    boot_mesh.materials.append(boot_rubber)
    sole_faces = 0
    for poly in boot_mesh.polygons:
        # Follow the original boot topology and skin weights; only its ground-
        # facing lower surface becomes rubber. No rigid shoe props are added.
        if poly.normal.z < -0.35 and poly.center.z < 0.08:
            poly.material_index = 1
            sole_faces += 1
        else:
            poly.material_index = 0
    if sole_faces < 20:
        raise RuntimeError(f"Expected boot sole faces, found only {sole_faces}")
    bpy.data.objects["Laarzen"]["rubber_sole_face_count"] = sole_faces

    # Snug, separately skinned carrier panels are extracted from the actual torso
    # surface; the old wide, protruding vest remains only for the legacy cosmetic.
    garment_idx = next((i for i, m in enumerate(source_body.data.materials) if m and m.name == "Uniform_Kleding"), None)
    if garment_idx is None:
        raise RuntimeError("Cannot build plate carrier without Uniform_Kleding geometry")
    def carrier_face(poly, front):
        if poly.material_index != garment_idx or not (1.165 <= poly.center.z <= 1.385) or abs(poly.center.x) > 0.142:
            return False
        if (poly.normal.y < -0.34) != front or abs(poly.normal.y) <= 0.34:
            return False
        # Reject large torso/shoulder triangles that previously made the rear
        # carrier flare into a pointed poncho-like silhouette.
        return all(1.14 <= source_body.data.vertices[i].co.z <= 1.405 and abs(source_body.data.vertices[i].co.x) <= 0.16
                   for i in poly.vertices)

    carrier_front = [p.index for p in source_body.data.polygons if carrier_face(p, True)]
    carrier_back = [p.index for p in source_body.data.polygons if carrier_face(p, False)]
    vest = skinned_surface(source_body, "Vest_JungleCommando", carrier_front, rig, olive, trim, trim,
                           offset=0.007, thickness=0.005)
    vest_back = skinned_surface(source_body, "Vest_JungleCommando_Back", carrier_back, rig, olive, trim, trim,
                                offset=0.006, thickness=0.005)
    vest["design"] = "Compact fitted front carrier panel; separate from the close-fitting rear panel"
    vest_back["design"] = "Close-fitting rear panel without backpack or projecting frame"
    plate_parts = []
    # Rounded plate faces, narrow straps and low profile MOLLE webbing stay close
    # to the ribcage; the Tiger Stripe shirt remains visible at the shoulders.
    plate_parts.append(new_box("carrier chest plate", (0.0, -0.164, 1.315), (0.265, 0.016, 0.190), trim, 0.032))
    plate_parts.append(new_box("carrier rear panel", (0.0, 0.116, 1.315), (0.215, 0.010, 0.165), trim, 0.026))
    for side in (-1, 1):
        plate_parts.append(new_box("carrier shoulder strap", (side * 0.095, -0.066, 1.438), (0.032, 0.014, 0.105), olive, 0.010))
        plate_parts.append(new_box("carrier side strap", (side * 0.158, 0.004, 1.285), (0.014, 0.086, 0.070), trim, 0.006))
    plate_parts.append(new_box("carrier ID loop", (0.0, -0.177, 1.405), (0.064, 0.006, 0.010), olive, 0.004))
    plate_parts.append(new_box("carrier seam front left", (-0.122, -0.177, 1.315), (0.003, 0.003, 0.13), olive, 0.001))
    plate_parts.append(new_box("carrier seam front right", (0.122, -0.177, 1.315), (0.003, 0.003, 0.13), olive, 0.001))
    for z in (1.275, 1.305, 1.335, 1.365):
        plate_parts.append(new_box("carrier MOLLE webbing row", (0.0, -0.179, z), (0.226, 0.006, 0.006), olive, 0.002))
    plate_parts = [o for o in plate_parts if o is not None]
    carrier_details = merge_and_bind(plate_parts, "Vest_JungleCommando_Details", rig)
    carrier_details["garment_layer"] = True

    mags = []
    for x in (-0.145, 0.0, 0.145):
        mags.append(new_box("mag pouch body", (x, -0.211, 1.245), (0.094, 0.052, 0.130), olive, 0.020))
        mags.append(new_box("mag pouch cover flap", (x, -0.242, 1.296), (0.086, 0.012, 0.039), trim, 0.012))
        mags.append(new_box("mag pouch clasp", (x, -0.249, 1.281), (0.022, 0.006, 0.014), hardware, 0.004))
        # Visible reinforced vertical stitch channels on the front face.
        for dx in (-0.036, 0.036):
            mags.append(new_box("mag pouch seam", (x + dx, -0.245, 1.235), (0.002, 0.002, 0.055), olive, 0.0007))

    radio = [
        new_box("radio shell", (-0.166, -0.196, 1.345), (0.058, 0.050, 0.112), trim, 0.016),
        new_box("radio speaker grille", (-0.166, -0.223, 1.350), (0.040, 0.005, 0.034), hardware, 0.004),
        new_box("radio display", (-0.166, -0.224, 1.315), (0.024, 0.005, 0.015), olive, 0.003),
        new_cylinder("radio antenna", (-0.174, -0.188, 1.415), 0.004, 0.070, hardware, 10),
        new_cylinder("radio channel dial", (-0.140, -0.225, 1.405), 0.008, 0.008, hardware, 12, horizontal=True),
    ]
    marker = pbr_material("IFAK subdued marker", olive_maps)
    ifak = [
        new_box("IFAK pouch shell", (0.215, -0.185, 1.095), (0.10, 0.065, 0.12), olive, 0.016),
        new_box("IFAK cover", (0.215, -0.221, 1.111), (0.088, 0.012, 0.078), trim, 0.009),
        new_box("IFAK pull tab", (0.215, -0.230, 1.08), (0.026, 0.007, 0.013), hardware, 0.004),
        new_box("IFAK cross marker", (0.215, -0.229, 1.111), (0.006, 0.002, 0.032), marker, 0.001),
        new_box("IFAK cross marker horizontal", (0.215, -0.230, 1.111), (0.028, 0.002, 0.006), marker, 0.001),
    ]
    for side in (-1, 1):
        pocket_x = side * 0.108
        # Low-profile cargo pockets, separate from the uniform shell and weighted to the thigh.
        mags.extend([
            new_box("cargo thigh pocket", (pocket_x, -0.142, 0.805), (0.095, 0.034, 0.105), olive, 0.012),
            new_box("cargo pocket flap", (pocket_x, -0.164, 0.854), (0.089, 0.009, 0.031), trim, 0.006),
            new_box("cargo pocket tab", (pocket_x, -0.170, 0.839), (0.018, 0.005, 0.012), hardware, 0.003),
            new_box("cargo pocket topstitch", (pocket_x, -0.170, 0.787), (0.076, 0.002, 0.002), trim, 0.0007),
        ])

    # Full-cover glove shells follow the hand and individual finger weights.
    hand_groups = {g.index for g in source_body.vertex_groups if g.name.startswith(("DEF-hand", "DEF-thumb", "DEF-f_"))}
    glove_faces = [p.index for p in source_body.data.polygons if face_weight(source_body, p, hand_groups) > 0.28]
    gloves = skinned_surface(source_body, "Gloves_Closed", glove_faces, rig, trim, trim, hardware, offset=0.002, thickness=0.003, inner_surface=False)

    # Reinforced knee/elbow panels are shaped from uniform topology, not decals.
    knee_faces, elbow_faces = [], []
    for p in source_body.data.polygons:
        if p.material_index != garment_idx:
            continue
        if (0.485 <= p.center.z <= 0.620 and abs(p.center.x) <= 0.132 and p.normal.y < -0.28
                and all(0.455 <= source_body.data.vertices[i].co.z <= 0.65 and abs(source_body.data.vertices[i].co.x) <= 0.15 for i in p.vertices)):
            knee_faces.append(p.index)
        elbow_side = 1.0 if p.center.x >= 0 else -1.0
        elbow_center = Vector((elbow_side * 0.4663, 0.0701, 1.4408))
        near_elbow = (p.center - elbow_center).length < 0.090
        elbow_surface = p.normal.x * elbow_side > 0.12 or p.normal.y < -0.28
        in_elbow_patch = all((source_body.data.vertices[i].co - elbow_center).length < 0.115 for i in p.vertices)
        if near_elbow and elbow_surface and in_elbow_patch:
            elbow_faces.append(p.index)
    reinforcements = []
    if knee_faces:
        reinforcements.append(skinned_surface(source_body, "Knee_Reinforcements", knee_faces, rig, olive, olive, trim, offset=0.006, thickness=0.005))
    if elbow_faces:
        reinforcements.append(skinned_surface(source_body, "Elbow_Reinforcements", elbow_faces, rig, olive, olive, trim, offset=0.005, thickness=0.004))

    return [vest, vest_back, carrier_details, merge_and_bind(mags, "Mag_Pouches", rig),
            merge_and_bind(radio, "Radio_Field", rig), merge_and_bind(ifak, "IFAK_Pouch", rig),
            gloves, *reinforcements]


def mesh_report(scene):
    meshes = [o for o in scene.objects if o.type == "MESH"]
    return {
        "mesh_objects": [o.name for o in meshes],
        "triangles": sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons) for o in meshes),
        "materials": sorted({m.name for o in meshes for m in o.data.materials if m}),
        "uv_mapped_meshes": [o.name for o in meshes if len(o.data.uv_layers) > 0],
        "rig_bones": len(bpy.data.objects["Rig"].data.bones),
        "actions": sorted(a.name for a in bpy.data.actions),
        "bounds_m": [[round(float(min((o.matrix_world @ Vector(c))[axis] for o in meshes for c in o.bound_box)), 4) for axis in range(3)], [round(float(max((o.matrix_world @ Vector(c))[axis] for o in meshes for c in o.bound_box)), 4) for axis in range(3)]],
    }


def run(args):
    for path in (args.source,):
        if not path.is_file():
            raise FileNotFoundError(path)
    for path in (args.blend, args.glb, args.report):
        if path.exists():
            raise FileExistsError(f"Refusing to overwrite {path}")
    args.textures.mkdir(parents=True, exist_ok=True)
    for path in (args.blend, args.glb, args.report):
        path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    result = bpy.ops.import_scene.gltf(filepath=str(args.source))
    if "FINISHED" not in result:
        raise RuntimeError(f"VQ2 GLB import failed: {result}")

    rig = bpy.data.objects.get("Rig")
    if rig is None or rig.type != "ARMATURE" or len(rig.data.bones) != 53:
        raise RuntimeError("Expected the existing 53-bone DEF rig")
    if not all(name in bpy.data.actions for name in ("stil", "lopen", "rennen", "achteruit", "schieten", "geraakt", "dood1", "dood2", "steken", "herladen")):
        raise RuntimeError("One or more original VQ2 clips are missing")
    for junk in ("Cube", "Icosphere"):
        obj = bpy.data.objects.get(junk)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)

    tiger = tiger_stripe(args.textures / "tiger_stripe_albedo_2048.png")
    source_body = bpy.data.objects.get("Lijf_Uniform")
    if source_body is None:
        raise RuntimeError("Lijf_Uniform is required for the player-only shell build")
    added = build_equipment(rig, args.textures, source_body)
    commando_body, garment_shells = make_commando_body(tiger, args.textures)
    added.extend(garment_shells)

    # This is a dedicated player scene: preserve all selectable player tops, while avoiding
    # duplicate enemy/ally geometry and textures in the game PCK. Shared role models stay intact.
    player_meshes = {
        "Lijf_Uniform", "Lijf_JungleCommando", "Lijf_Bloot", "Lijf_Mouwloos",
        "Hoofdband", "Koppel", "Laarzen", "Vest", "Mag_Pouches", "Radio_Field", "IFAK_Pouch",
        "Uniform_Trousers_Shell", "Uniform_Jacket_Shell", "Hair_Cropped", "Vest_JungleCommando",
        "Vest_JungleCommando_Back", "Vest_JungleCommando_Details", "Gloves_Closed", "Knee_Reinforcements", "Elbow_Reinforcements",
    }
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name not in player_meshes:
            bpy.data.objects.remove(obj, do_unlink=True)

    # High quality editable source retains all source bodies/actions and the new player-only detail objects.
    bpy.ops.file.pack_all()
    bpy.data.orphans_purge(do_recursive=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(args.blend))

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in bpy.context.scene.objects:
        if obj.type in {"ARMATURE", "MESH"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    export = bpy.ops.export_scene.gltf(
        filepath=str(args.glb), export_format="GLB", export_yup=True,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_materials="EXPORT", export_image_format="AUTO", export_cameras=False,
        export_lights=False, export_apply=False,
    )
    if "FINISHED" not in export:
        raise RuntimeError(f"GLB export failed: {export}")
    report = mesh_report(bpy.context.scene)
    report.update({
        "status": "PASS", "source_read_only": str(args.source),
        "blend": str(args.blend), "glb": str(args.glb),
        "texture": str(args.textures / "tiger_stripe_albedo_2048.png"),
        "added_equipment": [o.name for o in added],
        "commando_body_variant": commando_body.name,
        "separate_garments": [o.name for o in garment_shells],
        "light_stubble_uv_pixels": int(commando_body.get("facial_stubble_pixels", 0)),
        "added_equipment": [o.name for o in added],
        "closed_glove_meshes": [o.name for o in added if o.name == "Gloves_Closed"],
        "reinforcement_meshes": [o.name for o in added if "Reinforcements" in o.name],
        "animation_contract": ["stil", "lopen", "rennen", "achteruit", "schieten", "geraakt", "dood1", "dood2", "steken", "herladen", "klimmen", "zitten", "rollen", "sprinten", "explosie_dood", "brand_rennen", "brand_val"],
        "note": "Ten embedded source actions retained; Godot soldier_model.gd merges the other seven from their existing GLBs.",
    })
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run(arguments())
