"""Hulpmiddel: render een .blend (of .glb) met Cycles CPU vanuit vaste standpunten, ter controle (de sandbox heeft geen EGL voor Workbench).
Gebruik: python3 kijk.py <bestand.blend|.glb> <uit-map> [kleur-per-deel] [standpunten,komma-gescheiden] [pose-script]
Standpunten: iso, iso2, side, top, front, back, kraan, klauw."""
import sys, math
import bpy
from mathutils import Vector
from pathlib import Path

args = sys.argv[1:]
bron, uit = Path(args[0]).resolve(), Path(args[1]).resolve()
kleur = len(args) > 2 and args[2] == "kleur"
gekozen = args[3].split(",") if len(args) > 3 else ["iso", "iso2", "side", "top"]
uit.mkdir(parents=True, exist_ok=True)
if bron.suffix == ".blend":
    bpy.ops.wm.open_mainfile(filepath=str(bron))
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(bron))
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 20; sc.cycles.use_denoising = False
meshes = [o for o in sc.objects if o.type == "MESH" and not o.hide_render]
pal = [(0.9, 0.2, 0.2), (0.2, 0.8, 0.3), (0.2, 0.4, 0.95), (0.95, 0.85, 0.2), (0.9, 0.3, 0.9), (0.2, 0.85, 0.85), (0.95, 0.55, 0.15), (0.6, 0.4, 0.9)]
if kleur:
    for i, o in enumerate(meshes):
        m = bpy.data.materials.new("k%d" % i); m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*pal[i % len(pal)], 1)
        o.data.materials.clear(); o.data.materials.append(m)
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.66, 0.72, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.1
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun); sun.rotation_euler = (0.8, 0.2, 0.6); sun.data.energy = 3.5
sc.render.resolution_x = 960; sc.render.resolution_y = 600
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
vs = {"iso": ((1, -1, 0.7), (0, 0, 1.5), 15.0), "iso2": ((-1, 1, 0.7), (0, 0, 1.5), 15.0), "side": ((1, 0, 0.12), (0, 0, 1.8), 15.0),
      "top": ((0.001, 0.001, 1), (0, 0, 1.5), 14.0), "front": ((0, -1, 0.2), (0, 0, 1.8), 14.0), "back": ((0, 1, 0.2), (0, 0, 1.8), 14.0),
      "kraan": ((1, -0.8, 0.5), (0, 0.4, 3.0), 7.0), "klauw": ((1, -1, 0.45), (0, 3.1, 3.1), 3.2)}
poses = []
if len(args) > 4:
    clip, frames = args[4].split(":")
    for o in sc.objects:
        if o.animation_data:
            for tr in o.animation_data.nla_tracks:
                tr.mute = tr.name != clip
    poses = [(clip, int(f)) for f in frames.split(",")]
for clip, fr in (poses or [(None, 0)]):
    if clip:
        sc.frame_set(fr)
    for nm in gekozen:
        v, tgt, d = vs[nm]
        v = Vector(v).normalized(); tgt = Vector(tgt)
        cam.location = tgt + v * d
        cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(uit / ("%s%s.png" % (nm, ("_%s_%d" % (clip, fr)) if clip else "")))
        bpy.ops.render.render(write_still=True)
print("klaar")
