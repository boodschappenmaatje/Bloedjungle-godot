#!/usr/bin/env python3
"""Render the detached Meshy rifle fitted to the 28-bone Assault rig.

Usage: blender -b --python tools/enemy_assault/capture_meshy_weapon_blender.py -- INPUT.glb OUTPUT_DIR
The input GLB is imported read-only; captures are written to OUTPUT_DIR.
"""
import bpy
import os
import sys
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SOURCE = os.path.abspath(ARGS[0]) if ARGS else os.path.join(ROOT, "assets/enemies/assault/assault_meshy_hq2_runtime.glb")
OUT = os.path.abspath(ARGS[1]) if len(ARGS) > 1 else os.path.join(ROOT, "docs/enemy_assault_hq2/captures")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
arm = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
if arm is None or len(arm.data.bones) != 28:
    raise RuntimeError("Assault GLB must contain the existing 28-bone Mixamo rig")
right = bpy.data.objects.get("Assault_RightHandGrip")
left = bpy.data.objects.get("Assault_LeftHandGrip")
if right is None or left is None:
    raise RuntimeError("Assault GLB is missing the Meshy rifle hand anchors")
for hand_name, target in [("mixamorig:RightHand", right), ("mixamorig:LeftHand", left)]:
    hand = arm.pose.bones.get(hand_name)
    if hand is None:
        raise RuntimeError("Missing expected Mixamo bone " + hand_name)
    ik = hand.constraints.new("IK")
    ik.name = "Assault review IK"
    ik.target = target
    ik.chain_count = 3
    ik.use_stretch = False

bpy.context.view_layer.update()
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = False
scene.render.resolution_x = 720
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("Assault review world")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.075, 0.09, 0.075, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32
for obj in bpy.context.scene.objects:
    if obj.type == "MESH" and "LOD0" not in obj.name:
        obj.hide_render = True

for name, location, energy, size, color in [
    ("Key", (2.8, -3.5, 4.2), 680.0, 3.0, (1.0, 0.84, 0.69)),
    ("Fill", (-3.2, -1.0, 2.4), 420.0, 3.8, (0.69, 0.79, 1.0)),
    ("Rim", (0.5, 2.6, 3.2), 850.0, 2.7, (0.78, 0.92, 0.72)),
]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0.0, -0.05, 0.9)) - light.location).to_track_quat("-Z", "Y").to_euler()

camera_data = bpy.data.cameras.new("Assault weapon review")
camera = bpy.data.objects.new("Assault weapon review", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.5

os.makedirs(OUT, exist_ok=True)
views = [
	("capture_meshy_weapon_grip_front.png", Vector((3.3, -5.6, 2.3)), Vector((0.0, -0.1, 0.94))),
	("capture_meshy_weapon_grip_side.png", Vector((4.2, -4.8, 2.15)), Vector((0.0, -0.05, 0.94))),
]
for filename, location, target in views:
    camera.location = location
    camera.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    print("ASSAULT_CAPTURE", scene.render.filepath)
