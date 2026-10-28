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


def make_commando_body(image):
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
    glove = bpy.data.materials.get("Commando Webbing · Dark Olive")
    hair = bpy.data.materials.get("Commando Hair · Short Dark Brown")
    if glove is None or hair is None:
        raise RuntimeError("Commando glove or hair PBR material is missing")
    clone.data.materials.append(glove)
    glove_index = len(clone.data.materials) - 1
    clone.data.materials.append(hair)
    hair_index = len(clone.data.materials) - 1
    group_indices = {
        group.index for group in clone.vertex_groups
        if group.name.startswith(("DEF-hand", "DEF-thumb", "DEF-f_", "DEF-index", "DEF-middle", "DEF-ring", "DEF-pinky"))
    }
    head_group = next((group.index for group in clone.vertex_groups if group.name == "DEF-head"), None)
    glove_polygons = hair_polygons = 0
    for polygon in clone.data.polygons:
        hand_weight = sum(
            next((item.weight for item in clone.data.vertices[vertex_index].groups if item.group in group_indices), 0.0)
            for vertex_index in polygon.vertices
        ) / len(polygon.vertices)
        if polygon.material_index in {0, 1} and hand_weight > 0.32:
            polygon.material_index = glove_index
            glove_polygons += 1
            continue
        if head_group is not None and polygon.material_index == 0:
            weights = [next((item.weight for item in clone.data.vertices[index].groups if item.group == head_group), 0.0) for index in polygon.vertices]
            center_z = sum(clone.data.vertices[index].co.z for index in polygon.vertices) / len(polygon.vertices)
            if center_z > 1.555 and sum(weights) / len(weights) > 0.35:
                polygon.material_index = hair_index
                hair_polygons += 1
    clone["glove_polygons"] = glove_polygons
    clone["short_hair_polygons"] = hair_polygons
    if glove_polygons == 0 or hair_polygons == 0:
        raise RuntimeError(f"Expected glove and cropped-hair faces, got gloves={glove_polygons}, hair={hair_polygons}")
    original.users_collection[0].objects.link(clone)
    clone.matrix_world = original.matrix_world.copy()
    return clone


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


def new_cylinder(name, location, radius, depth, material, vertices=12, horizontal=False):
    rotation = (math.pi / 2, 0, 0) if horizontal else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Machined edge", "BEVEL")
    bevel.width = min(radius * 0.2, depth * 0.15)
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
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


def build_equipment(rig, texture_dir):
    olive_maps = micro_maps(texture_dir, "olive_nylon", (76, 88, 55), fabric=True)
    trim_maps = micro_maps(texture_dir, "dark_olive_webbing", (49, 60, 39), fabric=True)
    steel_maps = micro_maps(texture_dir, "parkerized_steel", (54, 59, 50), fabric=False)
    hair_maps = micro_maps(texture_dir, "short_cropped_hair", (52, 40, 31), fabric=False, roughness_override=0.82)
    olive = pbr_material("Commando Nylon · Olive Drab", olive_maps)
    trim = pbr_material("Commando Webbing · Dark Olive", trim_maps)
    hardware = pbr_material("Commando Hardware · Parkerized Steel", steel_maps, 0.72)
    pbr_material("Commando Hair · Short Dark Brown", hair_maps)
    boots = bpy.data.materials["Uitrusting"].copy()
    boots.name = "Commando Combat Boots"
    boot_bsdf = next(node for node in boots.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    boot_bsdf.inputs["Base Color"].default_value = (0.3, 0.27, 0.21, 1.0)
    bpy.data.objects["Laarzen"].data.materials.clear()
    bpy.data.objects["Laarzen"].data.materials.append(boots)
    mags = []
    for x in (-0.155, 0.0, 0.155):
        mags.append(new_box("mag pouch body", (x, -0.333, 1.245), (0.105, 0.083, 0.155), olive, 0.012))
        mags.append(new_box("mag pouch cover flap", (x, -0.382, 1.305), (0.096, 0.018, 0.046), trim, 0.006))
        mags.append(new_box("mag pouch clasp", (x, -0.395, 1.285), (0.026, 0.012, 0.018), hardware, 0.003))
        # Visible reinforced vertical stitch channels on the front face.
        for dx in (-0.036, 0.036):
            mags.append(new_box("mag pouch seam", (x + dx, -0.391, 1.235), (0.003, 0.003, 0.064), trim, 0.001))

    radio = [
        new_box("radio shell", (-0.235, -0.295, 1.345), (0.078, 0.074, 0.14), trim, 0.010),
        new_box("radio speaker grille", (-0.235, -0.336, 1.353), (0.052, 0.007, 0.043), hardware, 0.003),
        new_box("radio display", (-0.235, -0.337, 1.314), (0.032, 0.007, 0.019), olive, 0.002),
        new_cylinder("radio antenna", (-0.244, -0.298, 1.451), 0.006, 0.10, hardware, 10),
        new_cylinder("radio channel dial", (-0.199, -0.338, 1.414), 0.011, 0.01, hardware, 12, horizontal=True),
    ]
    marker = pbr_material("IFAK subdued marker", olive_maps)
    ifak = [
        new_box("IFAK pouch shell", (0.247, -0.252, 1.095), (0.11, 0.082, 0.125), olive, 0.012),
        new_box("IFAK cover", (0.247, -0.298, 1.111), (0.096, 0.015, 0.082), trim, 0.006),
        new_box("IFAK pull tab", (0.247, -0.311, 1.08), (0.03, 0.01, 0.014), hardware, 0.003),
        new_box("IFAK cross marker", (0.247, -0.31, 1.111), (0.008, 0.003, 0.034), marker, 0.001),
        new_box("IFAK cross marker horizontal", (0.247, -0.311, 1.111), (0.03, 0.003, 0.008), marker, 0.001),
    ]
    return [merge_and_bind(mags, "Mag_Pouches", rig), merge_and_bind(radio, "Radio_Field", rig), merge_and_bind(ifak, "IFAK_Pouch", rig)]


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
    added = build_equipment(rig, args.textures)
    commando_body = make_commando_body(tiger)

    # This is a dedicated player scene: preserve all selectable player tops, while avoiding
    # duplicate enemy/ally geometry and textures in the game PCK. Shared role models stay intact.
    player_meshes = {
        "Lijf_Uniform", "Lijf_JungleCommando", "Lijf_Bloot", "Lijf_Mouwloos",
        "Hoofdband", "Koppel", "Laarzen", "Vest", "Mag_Pouches", "Radio_Field", "IFAK_Pouch",
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
        "glove_polygons": commando_body.get("glove_polygons", 0),
        "short_hair_polygons": commando_body.get("short_hair_polygons", 0),
        "animation_contract": ["stil", "lopen", "rennen", "achteruit", "schieten", "geraakt", "dood1", "dood2", "steken", "herladen", "klimmen", "zitten", "rollen", "sprinten", "explosie_dood", "brand_rennen", "brand_val"],
        "note": "Ten embedded source actions retained; Godot soldier_model.gd merges the other seven from their existing GLBs.",
    })
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run(arguments())
