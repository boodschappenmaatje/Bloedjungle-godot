"""Voorbeeldrenders van een voorraadmodel (Cycles CPU, weinig samples), camera's in Godot-coordinaten.

    python render.py <blend> <uitmap> <set> [namen]      set = stapel | truck | depot ; namen = komma-gescheiden subset
    optioneel: VR_FRAME=<n> voor een animatiestand, VR_CLIP=<naam> om alleen die NLA-track te laten spelen
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

blend, outdir, which = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
only = sys.argv[4].split(",") if len(sys.argv) > 4 else None
outdir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("VR_SAMPLES", "24"))
sc.cycles.use_denoising = True
RES = int(os.environ.get("VR_RES", "760"))
sc.render.resolution_x, sc.render.resolution_y = RES, int(RES * 0.78)


def P(x, y, z):
    return Vector((x, -z, y))


bpy.ops.mesh.primitive_plane_add(size=90, location=(0, 0, -0.001))
gr = bpy.context.active_object
m = bpy.data.materials.new("Grond")
m.use_nodes = True
bs = m.node_tree.nodes["Principled BSDF"]
bs.inputs["Base Color"].default_value = (0.16, 0.115, 0.07, 1)
bs.inputs["Roughness"].default_value = 0.95
gr.data.materials.append(m)
sun = bpy.data.lights.new("Zon", "SUN")
sun.energy = 2.6
sun.angle = math.radians(1.2)
so = bpy.data.objects.new("Zon", sun)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(48), math.radians(8), math.radians(38))
w = bpy.data.worlds.new("W")
w.use_nodes = True
sky = w.node_tree.nodes.new("ShaderNodeTexSky")
sky.sky_type = "MULTIPLE_SCATTERING"
sky.sun_elevation = math.radians(42)
sky.sun_rotation = math.radians(-52)
w.node_tree.links.new(sky.outputs["Color"], w.node_tree.nodes["Background"].inputs["Color"])
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.24
sc.world = w
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
sc.view_settings.exposure = -0.5
cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam

SHOTS = {
    "stapel": [
        ("alle", (0, 7.5, 15.5), (0, 0.8, 0), 40, 0),
        ("vol", (-6.0 + 3.8, 3.6, 7.5), (-6, 1.0, 0), 38, 0),
        ("half", (0 + 3.8, 3.4, 7.5), (0, 0.9, 0), 38, 0),
        ("leeg", (6 + 3.8, 3.0, 7.0), (6, 0.5, 0), 38, 0),
        ("detail", (-6 + 1.6, 1.6, 3.6), (-6 + 1.2, 0.8, 1.0), 45, 0),
    ],
    "truck": [
        ("gamecamera", (0.0, 17.0, -15.0), (0, 1.2, 0), 40, 0),
        ("voor", (6.5, 3.0, 8.5), (0, 1.4, 0), 40, 0),
        ("achter", (-6.0, 3.2, -8.5), (0, 1.6, 0), 40, 0),
        ("zij", (9.5, 2.4, 0.5), (0, 1.5, 0), 40, 0),
        ("kraan", (4.4, 4.2, -2.0), (0, 3.0, 0.8), 45, 0),
    ],
    "depot": [
        ("gamecamera", (0.0, 22.0, 16.0), (0, 1.5, 0), 40, 0),
        ("voor", (7.0, 3.2, 12.0), (0, 1.8, 0), 38, 0),
        ("achter", (-9.0, 4.0, -11.0), (0, 1.8, 0), 38, 0),
        ("kraan", (4.0, 3.5, 7.0), (0, 2.8, 1.5), 45, 0),
        ("poort", (3.2, 1.6, 5.5), (0, 1.6, 1.0), 45, 0),
    ],
}


def shot(name, loc, target, lens, frame):
    if only and name not in only:
        return
    fr = int(os.environ.get("VR_FRAME", frame))
    clip = os.environ.get("VR_CLIP")
    for o in bpy.data.objects:
        if o.animation_data:
            for tr in o.animation_data.nla_tracks:
                tr.mute = bool(clip) and tr.name != clip
    sc.frame_set(fr)
    cam.location = P(*loc)
    cam_d.lens = lens
    d = P(*target) - P(*loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(outdir / f"{name}.png")
    bpy.ops.render.render(write_still=True)


for s in SHOTS[which]:
    shot(*s)
