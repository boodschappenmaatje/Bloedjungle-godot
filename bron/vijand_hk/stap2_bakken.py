"""Stap 2: UV-atlas maken en de texturen van het Meshy-bronmodel op de lage romp bakken (Cycles CPU).
Gebruik: python3 stap2_bakken.py <cache-map> [atlas] [samples]
Leest hq.blend en laag.blend; schrijft gebakken.blend (texturen ingepakt) in de cache. Zelfde aanpak als bron/garage_meshy."""
import sys, time
import numpy as np
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
CACHE = Path(args[0]).resolve()
ATLAS = int(args[1]) if len(args) > 1 else 2048
SAMPLES = int(args[2]) if len(args) > 2 else 8
t0 = time.time()

bpy.ops.wm.open_mainfile(filepath=str(CACHE / "laag.blend"))
with bpy.data.libraries.load(str(CACHE / "hq.blend")) as (src, dst):
    dst.objects = ["HK_HQ"]
scene = bpy.context.scene
view = bpy.context.view_layer
hoog = dst.objects[0]
scene.collection.objects.link(hoog)
romp = bpy.data.objects["Romp"]
scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = SAMPLES


def alleen(*objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = active or objs[0]


# UV-atlas
if not romp.data.uv_layers:
    romp.data.uv_layers.new(name="UVMap")
alleen(romp)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002, area_weight=1.0)
bpy.ops.uv.pack_islands(margin=0.002)
bpy.ops.object.mode_set(mode="OBJECT")
print("uv %.0f s" % (time.time() - t0), flush=True)

mat = bpy.data.materials.new("VijandHK"); mat.use_nodes = True
romp.data.materials.clear(); romp.data.materials.append(mat)
nt = mat.node_tree
mat_hoog = hoog.data.materials[0]
bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def beeld(naam, kleur):
    im = bpy.data.images.new(naam, ATLAS, ATLAS, alpha=False)
    im.colorspace_settings.name = "sRGB" if kleur else "Non-Color"
    return im


def bak(im, soort, **kw):
    node = nt.nodes.new("ShaderNodeTexImage"); node.image = im; nt.nodes.active = node
    alleen(hoog, romp, active=romp)
    bpy.ops.object.bake(type=soort, use_selected_to_active=True, cage_extrusion=0.10, max_ray_distance=0.35, margin=8, **kw)
    nt.nodes.remove(node)


alb = beeld("vijand_hk_albedo", True); bak(alb, "DIFFUSE", pass_filter={"COLOR"})
print("albedo %.0f s" % (time.time() - t0), flush=True)
nrm = beeld("vijand_hk_normal", False); bak(nrm, "NORMAL", normal_space="TANGENT")
print("normal %.0f s" % (time.time() - t0), flush=True)


def kanaal(sok):
    src = bsdf.inputs[sok]
    van = src.links[0].from_socket if src.links else None
    em = mat_hoog.node_tree.nodes.new("ShaderNodeEmission")
    uit = next(n for n in mat_hoog.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    oud = uit.inputs["Surface"].links[0].from_socket
    if van:
        mat_hoog.node_tree.links.new(van, em.inputs["Color"])
    else:
        v = src.default_value; em.inputs["Color"].default_value = (v, v, v, 1)
    mat_hoog.node_tree.links.new(em.outputs[0], uit.inputs["Surface"])
    im = beeld("tmp_" + sok, False); bak(im, "EMIT")
    mat_hoog.node_tree.links.new(oud, uit.inputs["Surface"]); mat_hoog.node_tree.nodes.remove(em)
    arr = np.array(im.pixels[:], np.float32).reshape(-1, 4)[:, 0]; bpy.data.images.remove(im)
    return arr


ruw = kanaal("Roughness"); met = kanaal("Metallic")
a = np.array(alb.pixels[:], np.float32).reshape(-1, 4)[:, :3]
# Meshy zet geverfd staal half-metallic: alleen donker, kleurloos staal blijft metaal (zo blijft het in het spel niet te spiegelend)
staal = (a.max(1) - a.min(1) < 0.06) & (a.max(1) < 0.22)
met = np.where(staal, np.clip(met, 0.3, 0.7), 0.0)
ruw = np.clip(ruw, 0.55, 0.95)
orm = np.ones((ATLAS * ATLAS, 4), np.float32); orm[:, 1] = ruw; orm[:, 2] = met
o_im = beeld("vijand_hk_orm", False); o_im.pixels.foreach_set(orm.ravel())
print("orm %.0f s" % (time.time() - t0), flush=True)

lk = nt.links; pr = nt.nodes["Principled BSDF"]
na = nt.nodes.new("ShaderNodeTexImage"); na.image = alb; lk.new(na.outputs["Color"], pr.inputs["Base Color"])
no = nt.nodes.new("ShaderNodeTexImage"); no.image = o_im
sep = nt.nodes.new("ShaderNodeSeparateColor"); lk.new(no.outputs["Color"], sep.inputs["Color"])
lk.new(sep.outputs["Green"], pr.inputs["Roughness"]); lk.new(sep.outputs["Blue"], pr.inputs["Metallic"])
nn = nt.nodes.new("ShaderNodeTexImage"); nn.image = nrm
nm = nt.nodes.new("ShaderNodeNormalMap"); lk.new(nn.outputs["Color"], nm.inputs["Color"]); lk.new(nm.outputs["Normal"], pr.inputs["Normal"])
for im in (alb, nrm, o_im):
    im.pack()
bpy.data.objects.remove(hoog)
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "gebakken.blend"))
print("klaar %.0f s" % (time.time() - t0), flush=True)
