"""Rebuild the Blender source and animated mobile GLB from the Meshy master.
Run from repository root with Blender 4.3+: blender -b --python assets/apache_showcase/build_showcase.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "apache_showcase_meshy.glb"
BLEND = ROOT / "Apache_Showcase_Source.blend"
MOBILE = ROOT / "Apache_Showcase_Mobile.glb"
FPS = 30

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and len(obj.data.polygons) > 100)
mesh.name = "Apache_Showcase_Body"
mesh.data.name = "Apache_Showcase_Body_Mesh"
for obj in list(bpy.context.scene.objects):
    if obj != mesh:
        bpy.data.objects.remove(obj, do_unlink=True)

root = bpy.data.objects.new("Apache_Showcase", None)
bpy.context.scene.collection.objects.link(root)
mesh.parent = root

# The imported Apache is about 1.9 units long. Add independent, rigged rotor assemblies.
# Local +Y is the model's up axis; the tail lies at the positive-X end.
rotor_mat = bpy.data.materials.new("Rotor_Olive_Dark")
rotor_mat.diffuse_color = (0.10, 0.13, 0.09, 1.0)
rotor_mat.use_nodes = True
bsdf = rotor_mat.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.10, 0.13, 0.09, 1.0)
bsdf.inputs["Metallic"].default_value = 0.42
bsdf.inputs["Roughness"].default_value = 0.48


def box_mesh(name, dims, loc, parent, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = parent
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Soft_Rotor_Edges", "BEVEL")
    bevel.width = 0.006
    bevel.segments = 2
    obj.modifiers.new("Rotor_Normals", "WEIGHTED_NORMAL")
    return obj

main = bpy.data.objects.new("Rotor_Main_Pivot", None)
bpy.context.scene.collection.objects.link(main)
main.location = (0.0, 0.48, 0.0)
main.parent = root
box_mesh("Rotor_Main_Hub", (0.10, 0.08, 0.10), (0, 0, 0), main, rotor_mat)
for i in range(4):
    blade = box_mesh(f"Rotor_Main_Blade_{i+1}", (0.72, 0.018, 0.055), (0.38, 0, 0), main, rotor_mat)
    blade.rotation_euler[1] = i * math.pi / 2

tail = bpy.data.objects.new("Rotor_Tail_Pivot", None)
bpy.context.scene.collection.objects.link(tail)
tail.location = (0.82, 0.30, 0.0)
tail.parent = root
box_mesh("Rotor_Tail_Hub", (0.07, 0.07, 0.07), (0, 0, 0), tail, rotor_mat)
for i in range(2):
    blade = box_mesh(f"Rotor_Tail_Blade_{i+1}", (0.016, 0.18, 0.035), (0, 0.10, 0), tail, rotor_mat)
    blade.rotation_euler[0] = i * math.pi / 2

scene = bpy.context.scene
scene.render.fps = FPS

# Build distinct actions on the body and both rotor pivots. Tracks share clip names in GLB.
def linearize(action):
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
    for curve in getattr(action, "fcurves", []):
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"


def clip(name, duration, body_pose, spin=1.0, loop=False):
    frames = int(duration * FPS)
    objects = (root, main, tail)
    actions = {}
    for obj in objects:
        action = bpy.data.actions.new(f"{name}_{obj.name}")
        obj.animation_data_create()
        obj.animation_data.action = action
        actions[obj] = action
    for frame in range(frames + 1):
        t = frame / FPS
        x, y, z, pitch, roll, yaw = body_pose(t, duration)
        root.location = (x, y, z)
        root.rotation_euler = (pitch, roll, yaw)
        root.keyframe_insert("location", frame=frame)
        root.keyframe_insert("rotation_euler", frame=frame)
        main.rotation_euler.y = 2 * math.pi * 4.0 * spin * t
        tail.rotation_euler.x = 2 * math.pi * 12.0 * spin * t
        main.keyframe_insert("rotation_euler", frame=frame)
        tail.keyframe_insert("rotation_euler", frame=frame)
    for obj, action in actions.items():
        linearize(action)
        track = obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.name = name + ("-loop" if loop else "")
        obj.animation_data.action = None
    scene.frame_end = max(scene.frame_end, frames)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

clip("Grond", 4, lambda t, d: (0, 0.004 * math.sin(2*math.pi*t*8), 0, 0.0015*math.sin(2*math.pi*t*8), 0, 0), 0.25, True)
clip("Opstijgen", 4, lambda t, d: (0, 0.45*smooth((t-0.6)/3.0), 0, math.radians(2)*math.sin(math.pi*smooth((t-0.6)/3.0)), 0, 0), 0.25 + 0.75, False)
clip("Zweven", 4, lambda t, d: (0.025*math.sin(2*math.pi*t/4), 0.45+0.035*math.sin(2*math.pi*t/2), 0.012*math.sin(2*math.pi*t/4), math.radians(0.6)*math.sin(2*math.pi*t/4), math.radians(0.8)*math.sin(2*math.pi*t/2), math.radians(1.0)*math.sin(2*math.pi*t/4)), 1.0, True)
clip("Vliegen", 4, lambda t, d: (0.05*math.sin(2*math.pi*t/4), 0.45+0.015*math.sin(2*math.pi*t/2), 0, math.radians(-3), math.radians(2)*math.sin(2*math.pi*t/4), 0), 1.0, True)
clip("Bocht", 4, lambda t, d: (0, 0.45, 0, math.radians(-1), math.radians(12)*math.sin(2*math.pi*t/4), math.radians(20)*math.sin(2*math.pi*t/4)), 1.0, True)

# Keep the high detail editable; export an additional decimated game copy with clips.
source_mesh = mesh
mobile = mesh.copy()
mobile.data = mesh.data.copy()
mobile.name = "Apache_Showcase_Mobile_Body"
bpy.context.collection.objects.link(mobile)
mobile.parent = root
mod = mobile.modifiers.new("Mobile_Triangle_Budget", "DECIMATE")
mod.ratio = min(1.0, 50000 / max(1, len(mobile.data.polygons)))
bpy.context.view_layer.objects.active = mobile
bpy.ops.object.modifier_apply(modifier=mod.name)

bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.context.scene.objects:
    if obj != source_mesh:
        obj.select_set(obj.type in {"EMPTY", "MESH"})
bpy.context.view_layer.objects.active = root
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(filepath=str(MOBILE), export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_apply=True)
print(f"source polygons={len(source_mesh.data.polygons)} mobile polygons={len(mobile.data.polygons)} clips=Grond,Opstijgen,Zweven,Vliegen,Bocht")
