"""Voorbeeldrenders van het hoofdkwartier (Cycles CPU, weinig samples). Gebruik: python render.py <blend> <uitmap>"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

blend, outdir = sys.argv[1], Path(sys.argv[2])
outdir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 32
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 900, 900
# grond (junglegrond uit de gamebibliotheek) + zon + fysische lucht
GR = Path("/nonexistent")
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
gr = bpy.context.active_object
m = bpy.data.materials.new("Grond")
m.use_nodes = True
nt = m.node_tree
bs = nt.nodes["Principled BSDF"]
if (GR / "albedo.jpg").exists():
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (9, 9, 9)
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = bpy.data.images.load(str(GR / "albedo.jpg"))
    nt.links.new(mp.outputs["Vector"], ta.inputs["Vector"])
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 1.0
    tint.inputs[2].default_value = (0.75, 0.62, 0.42, 1)
    nt.links.new(ta.outputs["Color"], tint.inputs[1])
    nt.links.new(tint.outputs[0], bs.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = bpy.data.images.load(str(GR / "normal.png"))
    tn.image.colorspace_settings.name = "Non-Color"
    nt.links.new(mp.outputs["Vector"], tn.inputs["Vector"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bs.inputs["Normal"])
else:
    bs.inputs["Base Color"].default_value = (0.055, 0.036, 0.022, 1)
bs.inputs["Roughness"].default_value = 0.95
gr.data.materials.append(m)
sun = bpy.data.lights.new("Zon", "SUN")
sun.energy = 2.4
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
sky.air_density = 1.0
w.node_tree.links.new(sky.outputs["Color"], w.node_tree.nodes["Background"].inputs["Color"])
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
sc.world = w
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
sc.view_settings.exposure = -0.6
for o in bpy.data.objects:
    if o.name.startswith("Schade"):
        o.hide_render = True
        for c in o.children_recursive:
            c.hide_render = True
cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


ONLY = sys.argv[3].split(',') if len(sys.argv) > 3 else None


def shot(name, loc, target, lens, frame=0):
    if ONLY and name.replace('.png', '') not in ONLY:
        return
    for o in bpy.data.objects:
        if o.animation_data and o.name == 'Deur':
            for tr in o.animation_data.nla_tracks:
                tr.mute = not (frame >= 24 and tr.name == 'Open')
            if frame < 24:
                o.location.x = 0.0   # zonder actieve track blijft de laatste stand hangen: terug naar rustpose (dicht)
    sc.frame_set(frame)
    cam.location = loc
    cam_d.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(outdir / name)
    bpy.ops.render.render(write_still=True)


shot("gamecamera.png", (0.0, -17.0, 20.0), (0.0, 0, 2.4), 40)        # zoals de spelcamera: schuin van boven
shot("voorkant.png", (4.5, -13.0, 4.5), (0, 0, 2.8), 38)
shot("achterkant.png", (-9.0, 11.0, 6.0), (0, 0, 2.8), 38)
shot("detail_dak.png", (3.0, -6.0, 8.5), (0, 0, 5.4), 42, frame=40)
shot("detail_schotel.png", (2.2, -3.2, 7.2), (0, 0.2, 5.9), 55, frame=30)
shot("detail_trap.png", (7.5, -3.5, 3.0), (3.0, -0.5, 1.6), 40)
shot("detail_muur.png", (-3.0, -5.0, 2.2), (-1.5, -2.5, 1.7), 40)
shot("detail_deur.png", (2.2, -6.5, 1.8), (0, -2.5, 1.5), 42)
shot("deur_open.png", (2.2, -6.5, 1.8), (0, -2.5, 1.5), 42, frame=30)
