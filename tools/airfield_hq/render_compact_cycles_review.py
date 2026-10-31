"""Render Airfield HQ 2.2/2.3 comparisons with Blender Cycles on CPU.

Run from the repository root with the bundled Blender 4.5.15 executable:
  blender -b --factory-startup --python tools/airfield_hq/render_compact_cycles_review.py

Only review PNGs are written. No project source asset is opened for writing.
The renders are Blender evidence, not Godot, GPU, or iPhone captures.
"""
from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/airfield_hq_v23/compact_layout_review/cycles"
OUT.mkdir(parents=True, exist_ok=True)

OLD_HANGAR = ROOT / "assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
NEW_HANGAR = ROOT / "assets/airfield_hq_v23/hangar/Airfield_HQ_23_Compact_LOD0.glb"
OLD_TOWER = ROOT / "assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
NEW_TOWER = ROOT / "assets/airfield_hq_v23/tower/Control_Tower_HQ_23.glb"
RUNWAY = ROOT / "assets/airfield_hq_v23/pavement/Airfield_Runway_Slab_HQ23_LOD0.glb"
TAXI = ROOT / "assets/airfield_hq_v23/pavement/Airfield_Taxiway_HQ23_Compact_LOD0.glb"
APRON = ROOT / "assets/airfield_hq_v23/pavement/Airfield_Apron_Slab_HQ23_LOD0.glb"
PSP = ROOT / "assets/airfield_hq_v23/psp/PSP_plate_library.glb"

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = 0.8
scene.render.image_settings.color_mode = "RGBA"
scene.world.use_nodes = True
scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.32, 0.36, 0.40, 1.0)
scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.5


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def import_glb(path: Path, keep_names: tuple[str, ...] = ()) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = [obj for obj in bpy.data.objects if obj not in before]
    if keep_names:
        keep = [obj for obj in added if any(obj.name.startswith(prefix) for prefix in keep_names)]
        for obj in list(added):
            if obj not in keep:
                bpy.data.objects.remove(obj, do_unlink=True)
        added = keep
    return added


def group_objects(objects: list[bpy.types.Object], name: str, location: tuple[float, float, float], scale: float = 1.0) -> bpy.types.Object:
    members = set(objects)
    roots = [obj for obj in objects if obj.parent not in members]
    lo, hi = bounds(objects)
    center = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    root = bpy.data.objects.new(name, None)
    scene.collection.objects.link(root)
    for obj in roots:
        matrix = obj.matrix_world.copy()
        matrix.translation -= center
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()
        obj.matrix_world = matrix
    root.location = location
    root.scale = (scale, scale, scale)
    return root


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == "MESH" for corner in obj.bound_box]
    if not points:
        return Vector((-1, -1, -1)), Vector((1, 1, 1))
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(tuple(max(p[i] for p in points) for i in range(3)))


def area_light(name: str, location: tuple[float, float, float], energy: float, size: float, target: Vector) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_lighting(target: Vector, span: float) -> None:
    area_light("Large soft key", (target.x - span, target.y - span, target.z + span * 1.4), 17000, span * 0.7, target)
    area_light("Neutral fill", (target.x + span, target.y - span * 0.2, target.z + span * 0.55), 9000, span * 0.8, target)
    area_light("Roof rim", (target.x, target.y + span, target.z + span), 12000, span * 0.55, target)


def camera(name: str, location: Vector, target: Vector, ortho: float | None = None, lens: float = 55) -> None:
    data = bpy.data.cameras.new(name)
    data.lens = lens
    if ortho is not None:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = obj


def label(text: str, at: tuple[float, float, float]) -> None:
    curve = bpy.data.curves.new("Review label", "FONT")
    curve.body = text
    curve.size = 1.05
    curve.extrude = 0
    obj = bpy.data.objects.new("Review label | " + text, curve)
    scene.collection.objects.link(obj)
    obj.location = at
    curve.materials.append(simple_material("Review label white", (0.92, 0.92, 0.87, 1)))


def simple_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.76
    return material


def render(path: str, camera_pos: Vector, target: Vector, ortho: float, key_span: float) -> None:
    setup_lighting(target, key_span)
    camera("Locked Cycles review camera", camera_pos, target, ortho=ortho)
    scene.render.filepath = str(OUT / path)
    bpy.ops.render.render(write_still=True)
    print("AIRFIELD_CYCLES_CPU", path, "samples=32", "device=CPU")


def hangar_pair(interior: bool = False) -> None:
    clear_scene()
    old_objects = import_glb(OLD_HANGAR, ("Hangar HQ 22", "Hangar sliding door", "Hangar Service Props", "USAAF"))
    old_root = group_objects(old_objects, "HQ22 approved source", (-13.0, 0.0, 0.0), 0.5)
    new_objects = import_glb(NEW_HANGAR)
    new_root = group_objects(new_objects, "HQ23 compact derivative", (13.0, 0.0, 0.0), 1.0)
    if interior:
        for obj in new_objects:
            if obj.animation_data and obj.animation_data.action:
                scene.frame_set(90)
        for obj in old_objects:
            if obj.animation_data and obj.animation_data.action:
                scene.frame_set(90)
        target = Vector((0.0, 0.0, 3.0))
        label("HQ 2.2 · approved source", (-23.5, -11.0, 0.1))
        label("HQ 2.3 · compact", (2.0, -11.0, 0.1))
        render("hangar_interior_2.2_vs_2.3_cycles.png", Vector((0.0, -25.0, 8.0)), target, 54.0, 30.0)
    else:
        target = Vector((0.0, 0.0, 4.0))
        label("HQ 2.2 · approved source", (-23.5, -10.0, 0.1))
        label("HQ 2.3 · compact", (2.0, -10.0, 0.1))
        render("hangar_exterior_2.2_vs_2.3_cycles.png", Vector((0.0, -42.0, 18.0)), target, 52.0, 32.0)


def tower_pair() -> None:
    clear_scene()
    old_objects = import_glb(OLD_TOWER, ("Control Tower 22", "Tower access door", "Tower wind sock"))
    old_root = group_objects(old_objects, "HQ22 tower source", (-12.0, 0.0, 0.0), 0.54)
    new_objects = import_glb(NEW_TOWER)
    new_root = group_objects(new_objects, "HQ23 compact tower", (12.0, 0.0, 0.0), 0.54)
    label("HQ 2.2 · tower source", (-22.0, -7.0, 0.1))
    label("HQ 2.3 · tower", (1.0, -7.0, 0.1))
    target = Vector((0.0, 0.0, 6.0))
    render("tower_2.2_vs_2.3_cycles.png", Vector((0.0, -36.0, 25.0)), target, 54.0, 34.0)


def paving_review() -> None:
    clear_scene()
    runway_objects = import_glb(RUNWAY)
    runway = next(obj for obj in runway_objects if obj.name.startswith("Airfield Runway Slab"))
    # The GLB prototype carries an authored source-scene offset; runtime uses
    # its mesh data with explicit transforms, so match that production path here.
    runway.location = (0.0, 0.0, 0.0)
    runway.rotation_euler.z = math.pi * 0.5
    for i in range(5):
        tile = runway if i == 0 else runway.copy()
        if i > 0:
            tile.data = runway.data
            scene.collection.objects.link(tile)
        tile.name = f"Compact 15 m concrete slab {i + 1}"
        tile.location = (-30.0 + 15.0 * i, -17.5, 0.11)

    taxi_objects = import_glb(TAXI)
    taxi = next(obj for obj in taxi_objects if obj.name.startswith("Airfield Taxiway"))
    taxi.location = (0.0, 0.0, 0.0)
    taxi.location.z = 0.11
    apron_objects = import_glb(APRON)
    apron = next(obj for obj in apron_objects if obj.name.startswith("Airfield Apron"))
    apron.location = (0.0, 19.5, 0.11)
    psp_objects = import_glb(PSP, ("PSP_Plate_LOD0_87",))
    psp = next((obj for obj in psp_objects if obj.type == "MESH" and "LOD0" in obj.name), None)
    if psp:
        psp.location = (0.0, 13.9, 0.34)
        psp.scale = (0.42, 0.42, 0.42)
    label("HQ 2.3 compact paving · 75 m / 5 × 15 m", (-28.0, -30.0, 0.15))
    target = Vector((0.0, 1.0, 0.0))
    render("compact_paving_cycles.png", Vector((0.0, -48.0, 52.0)), target, 104.0, 58.0)


hangar_pair(False)
hangar_pair(True)
tower_pair()
paving_review()
