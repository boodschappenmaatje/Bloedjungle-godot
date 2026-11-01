"""CPU Workbench comparisons for the current and compact Airfield HQ layouts.

Run from the repository root with Blender 4.5.15. This is a geometry review
render, not a Godot/mobile render or a performance measurement.
"""
import bpy
import math
import os
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "docs/airfield_hq_v23/compact_layout_review")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
phase = args[args.index("--phase") + 1] if "--phase" in args else "after"
if phase not in ("before", "after"):
    raise ValueError("--phase must be before or after")

old = phase == "before"
hangar_center = Vector((-24.125, 0.3, 0.0)) if old else Vector((0.0, -2.5, 0.0))
out_dir = os.path.join(OUT, phase)
os.makedirs(out_dir, exist_ok=True)

KEEP = {"01_Hangar_HQ_22", "02_Hangar_Sliding_Doors", "07_Hangar_Service_Props_22"}
for obj in list(bpy.data.objects):
    if not any(collection.name in KEEP for collection in obj.users_collection):
        bpy.data.objects.remove(obj, do_unlink=True)

if old:
    # Match the current HQ2.3 placement offsets around the approved 2.2 core.
    shift = Vector((-24.125, 0.3, 0.0))
    for collection_name in KEEP:
        for obj in bpy.data.collections[collection_name].objects:
            if obj.parent is None:
                obj.location += shift
else:
    # New review source has already been transformed around its authored origin.
    shift = Vector((0.0, -2.5, 0.0))
    for collection_name in KEEP:
        for obj in bpy.data.collections[collection_name].objects:
            if obj.parent is None:
                obj.location += shift

def mat(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    return material

concrete = mat("Airfield concrete review", (0.43, 0.44, 0.42))
paint = mat("Zone outline review", (0.72, 0.62, 0.34))
ground = mat("Neutral review ground", (0.16, 0.20, 0.16))
reference = mat("Scale reference staging", (0.10, 0.17, 0.10))

def box(name, location, dimensions, material, rotation=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    obj.rotation_euler.z = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material:
        obj.data.materials.append(material)
    return obj

def ground_box(name, cx, cy, width, length, material=concrete):
    return box(name, (cx, cy, 0.0), (width, length, 0.22), material)

def build_paving():
    if old:
        start_x, center_y = -56.5, 31.5
        apron_x, apron_y = 28.0, 20.0
        taxi = [(28.0, 20.0), (28.0, 22.5)]
        center = (16.0, 22.5)
        for i in range(1, 9):
            a = math.radians(-90.0 * i / 8.0)
            taxi.append((center[0] + math.cos(a) * 12.0, center[1] + math.sin(a) * 12.0))
        runway_y = center_y
    else:
        start_x, center_y = -37.5, 17.5
        apron_x, apron_y = 0.0, -19.5
        taxi = [(9.0, -19.5), (16.0, -19.5)]
        center = (16.0, -7.5)
        for i in range(1, 9):
            a = math.radians(90.0 - 90.0 * i / 8.0)
            taxi.append((center[0] + math.cos(a) * 12.0, center[1] + math.sin(a) * 12.0))
        taxi.append((28.0, 8.5))
        runway_y = center_y

    for i in range(5):
        box(f"Runway slab {i+1}", (start_x + 7.5 + i * 15.0, runway_y, -0.02), (15.0, 18.0, 0.22), concrete)
    ground_box("Apron", apron_x, apron_y, 18.0, 14.0)
    # Short oriented paving sections follow only the taxi centerline.
    for i, (a, b) in enumerate(zip(taxi, taxi[1:])):
        start, end = Vector(a), Vector(b)
        delta = end - start
        length = delta.length
        center_point = (start + end) * 0.5
        ground_box(f"Taxi paving {i:02d}", center_point.x, center_point.y, length + 0.3, 18.0)
        bpy.context.object.rotation_euler.z = math.atan2(delta.y, delta.x)

def box_outline(name, center, dimensions, material, height=0.07):
    cx, cy = center
    w, d = dimensions
    t = 0.15
    box(name+" N", (cx, cy+d/2, 0.1), (w,t,height), material)
    box(name+" S", (cx, cy-d/2, 0.1), (w,t,height), material)
    box(name+" E", (cx+w/2, cy, 0.1), (t,d,height), material)
    box(name+" W", (cx-w/2, cy, 0.1), (t,d,height), material)

build_paving()
box("Review ground", (28.0, 0.0, -0.33), (235.0, 150.0, 0.4), ground)

# Tower, town-base boundary and scale references are real game assets or the
# measured game boundary, placed in a separate reference strip for comparison.
if old:
    tower_center = (47.875, 20.3)
else:
    tower_center = (-17.0, -19.5)
reference_x = 55.0

def import_asset(path, root_name, position, scale=1.0):
    previous = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, path))
    added = [obj for obj in bpy.data.objects if obj not in previous]
    top = [obj for obj in added if obj.parent not in added]
    root = bpy.data.objects.new(root_name, None)
    bpy.context.scene.collection.objects.link(root)
    for obj in top:
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()
    root.location = position
    root.scale = (scale, scale, scale)
    return root

import_asset("assets/airfield_hq_v23/tower/Control_Tower_HQ_23.glb", "Control tower scale reference", (tower_center[0], tower_center[1], 0.0), 0.54 if not old else 1.0)

# Base boundary dimensions from the authored BaseProps perimeter.
base_center = (reference_x + 25.0, 0.0)
box_outline("Player base 56.65 by 56.95 m", base_center, (56.65, 56.95), paint, 0.1)
box("Reference staging pad", (reference_x + 25.0, 0.0, -0.1), (48.0, 34.0, 0.18), reference)
far_player = import_asset("assets/soldaat_vq2.glb", "Player scale 1.2", (reference_x + 10.0, 0.0, 0.0), 1.2)
far_garage = import_asset("assets/garage.glb", "Garage 6.4 m", (reference_x + 20.0, 0.0, 0.0))
far_barracks = import_asset("assets/kazerne.glb", "Barracks", (reference_x + 30.0, 0.0, 0.0))
close_player = import_asset("assets/soldaat_vq2.glb", "Doorway player scale 1.2", (hangar_center.x + 13.0, hangar_center.y - 21.0, 0.0), 1.2)
close_garage = import_asset("assets/garage.glb", "Doorway garage scale", (hangar_center.x + 23.0, hangar_center.y - 21.0, 0.0))
close_barracks = import_asset("assets/kazerne.glb", "Doorway barracks scale", (hangar_center.x + 33.0, hangar_center.y - 21.0, 0.0))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 1100
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.display.shading.light = "STUDIO"
scene.display.shading.studio_light = "paint.sl"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.background_type = "WORLD"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "WORLD"
scene.display.shading.curvature_ridge_factor = 1.3
scene.display.shading.curvature_valley_factor = 1.0
scene.world.color = (0.09, 0.11, 0.10)

camera_data = bpy.data.cameras.new("Locked review camera")
camera = bpy.data.objects.new("Locked review camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera

def aim_camera(location, target):
    camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()

airport_center = (0.0, 0.0) if not old else (0.0, 10.0)
views = {
    "top_down": ("ORTHO", (airport_center[0], airport_center[1], 160.0), (airport_center[0], airport_center[1], 0.0), 220.0),
    "player_height": ("PERSP", (hangar_center.x + 10.0, hangar_center.y - 42.0, 1.65), (hangar_center.x + 10.0, hangar_center.y - 5.0, 2.5), 24.0),
    "build_camera": ("ORTHO", (airport_center[0], airport_center[1] - 145.0, 165.0), (airport_center[0], airport_center[1], 0.0), 220.0),
}
for name, (kind, location, target, value) in views.items():
    scene.frame_set(90 if name == "player_height" else 1)
    for obj in (far_player, far_garage, far_barracks):
        obj.hide_render = (name == "player_height")
    for obj in (close_player, close_garage, close_barracks):
        obj.hide_render = (name != "player_height")
    camera_data.type = kind
    if kind == "ORTHO":
        camera_data.ortho_scale = value
    else:
        camera_data.lens = value
    aim_camera(location, target)
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    print(f"AIRFIELD_CPU_REVIEW_CAPTURE phase={phase} view={name} output={scene.render.filepath}")
