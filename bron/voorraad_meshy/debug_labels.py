"""Debugbeelden: de gelabelde voxel-schil in kleuren (zijkant, bovenkant, kraan en klauw close-up). Gebruik: python3 debug_labels.py <cache> <uit-map>"""
import sys
import numpy as np
import bpy
from mathutils import Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen as D
CACHE, OUT = Path(sys.argv[-2]), Path(sys.argv[-1]); OUT.mkdir(exist_ok=True, parents=True)
g = np.load(CACHE / "voxel.npz"); vv, vt = g["co"], g["tri"]
lab = D.indelen((vv[vt[:, 0]] + vv[vt[:, 1]] + vv[vt[:, 2]]) / 3.0 / D.SCHAAL)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 6; sc.cycles.use_denoising = False
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.9, 0.92, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
PAL = {0: (0.55, 0.55, 0.5), 1: (0.9, 0.1, 0.1), 2: (0.1, 0.7, 0.2), 3: (0.1, 0.3, 0.95), 4: (0.95, 0.8, 0.1), 5: (0.9, 0.2, 0.9), 6: (0.1, 0.9, 0.9),
       7: (0.95, 0.5, 0.1), 8: (0.4, 0.2, 0.7), 9: (0.75, 0.55, 0.3)}
def kleur(l):
    if l >= 100:
        k = (l - 100)
        return [(0.05, 0.05, 0.05), (0.25, 0.25, 0.25)][k % 2]
    return PAL[l]
for l in np.unique(lab):
    sel = lab == l
    f = vt[sel]
    uniek, inv = np.unique(f.ravel(), return_inverse=True)
    m = bpy.data.meshes.new("l%d" % l)
    m.vertices.add(len(uniek)); m.vertices.foreach_set("co", vv[uniek].ravel())
    n = len(f)
    m.loops.add(n * 3); m.loops.foreach_set("vertex_index", inv.astype(np.int32))
    m.polygons.add(n); m.polygons.foreach_set("loop_start", np.arange(0, n * 3, 3, dtype=np.int32)); m.polygons.foreach_set("loop_total", np.full(n, 3, np.int32))
    m.update(calc_edges=True)
    o = bpy.data.objects.new("l%d" % l, m); sc.collection.objects.link(o)
    mat = bpy.data.materials.new("m%d" % l); mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (*kleur(int(l)), 1); em.inputs["Strength"].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], out.inputs[0])
    m.materials.append(mat)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam; cam.data.type = "ORTHO"
S = D.SCHAAL
def shot(name, dirv, up, centre_src, scale_src, w_, h_):
    c = Vector(centre_src) * S
    cam.data.ortho_scale = scale_src * S
    sc.render.resolution_x, sc.render.resolution_y = w_, h_
    d = Vector(dirv)
    cam.location = c + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", up).to_euler()
    sc.render.filepath = str(OUT / ("lab_%s.png" % name))
    bpy.ops.render.render(write_still=True)
# vv is in SA frame (bronassen, geschaald): X length, Y width, Z up (Z not yet shifted)
ONLY = [int(a) for a in sys.argv[1:-2] if a.lstrip("-").isdigit()]
if ONLY:
    for o in bpy.data.objects:
        if o.type == "MESH" and int(o.name[1:]) not in ONLY:
            o.hide_render = True
    shot("claw_top", (0, 0, 1), "Y", (0.82, 0, 0.2), 0.4, 800, 800)
    shot("claw_bot", (0, 0, -1), "Y", (0.82, 0, 0.2), 0.4, 800, 800)
    shot("claw_front", (-1, 0, 0), "Z", (0.82, 0, 0.2), 0.4, 800, 800)
    shot("claw_rear2", (1, 0, 0), "Z", (0.82, 0, 0.2), 0.4, 800, 800)
    sys.exit(0)
shot("side", (0, -1, 0), "Z", (0.0, 0, 0.0), 2.2, 1760, 800)
shot("top", (0, 0, 1), "Y", (0.0, 0, 0.0), 2.2, 1760, 800)
shot("claw", (0, -1, 0), "Z", (0.80, 0, 0.28), 0.5, 1000, 800)
shot("col", (0, -1, 0), "Z", (0.12, 0, 0.15), 0.7, 1000, 800)
shot("rear", (1, 0, 0), "Z", (0.0, 0, 0.0), 1.2, 800, 800)
