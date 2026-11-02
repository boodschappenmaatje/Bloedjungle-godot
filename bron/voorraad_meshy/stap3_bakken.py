"""Stap 3: textuur van de Meshy-bron (3,73 miljoen driehoeken) naar de lage delen van de vrachtwagen bakken (Cycles CPU): één atlas met albedo,
tangent-normal en ruwheid/metallic (glTF-ORM) voor alle delen. Leest cache/laag.blend (stap 2), schrijft cache/gebakken.blend (ingepakte texturen).
Gebruik: python3 stap3_bakken.py <bron.glb> <cache-map> [atlasgrootte]"""
import sys, time
import numpy as np
import bpy
from pathlib import Path

import math
from mathutils import Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen as D

args = sys.argv[1:]
BRON, CACHE = Path(args[0]).resolve(), Path(args[1]).resolve()
ATLAS = int(args[2]) if len(args) > 2 else 2048
t0 = time.time()
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "laag.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4

# de bron opnieuw inlezen en op ware grootte in spelassen zetten (zelfde omzetting als delen.naar_spel)
voor = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(BRON))
hoog = next(o for o in bpy.data.objects if o not in voor and o.type == "MESH")
for o in list(bpy.data.objects):
    if o not in voor and o is not hoog:
        bpy.data.objects.remove(o)
hoog.parent = None
hoog.matrix_world = Matrix.Identity(4)
K = D.SCHAAL
hoog.data.transform(Matrix(((0, -K, 0, 0), (K, 0, 0, 0), (0, 0, K, -D.GROND * K), (0, 0, 0, 1))))
hoog.name = "Truck_HQ"
hoog.hide_render = False; hoog.hide_viewport = False
print("bron: %d driehoeken, %.0f s" % (len(hoog.data.polygons), time.time() - t0), flush=True)
mat_hoog = hoog.data.materials[0]
bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
atlas_namen = [o.name for o in bpy.data.objects if o.type == "MESH" and o is not hoog]


def alleen(*objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = active or objs[0]


def nieuw_beeld(naam, b, h, kleur):
    im = bpy.data.images.new(naam, b, h, alpha=False, float_buffer=False)
    im.colorspace_settings.name = "sRGB" if kleur else "Non-Color"
    return im


def maak_materiaal(naam):
    m = bpy.data.materials.new(naam); m.use_nodes = True
    m.use_backface_culling = False
    return m


def bak_groep(doel_namen, mat, b, h, naam, ray, cage, rups=False):
    """bakt alle doelen samen (tijdelijk aan elkaar gelegd); geeft (albedo, normal, orm) en de UV's terug"""
    originelen = [bpy.data.objects[n] for n in doel_namen]
    kopieen = []
    for o in originelen:
        k = o.copy(); k.data = o.data.copy(); scene.collection.objects.link(k); kopieen.append(k)
        k.data.materials.clear(); k.data.materials.append(mat)
    alleen(*kopieen)
    bpy.ops.object.join()
    laag = view.objects.active
    nt = mat.node_tree
    pr = nt.nodes["Principled BSDF"]

    def bak(im, soort, **kw):
        node = nt.nodes.new("ShaderNodeTexImage"); node.image = im
        nt.nodes.active = node
        alleen(hoog, laag, active=laag)
        bpy.ops.object.bake(type=soort, use_selected_to_active=True, cage_extrusion=cage, max_ray_distance=ray,
                            margin=12, **kw)
        return node

    alb = nieuw_beeld(naam + "_albedo", b, h, True)
    n_alb = bak(alb, "DIFFUSE", pass_filter={"COLOR"})
    print("  albedo %s %.0f s" % (naam, time.time() - t0), flush=True)
    nrm = nieuw_beeld(naam + "_normal", b, h, False)
    n_nrm = bak(nrm, "NORMAL", normal_space="TANGENT")
    print("  normal %s %.0f s" % (naam, time.time() - t0), flush=True)

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
        im = nieuw_beeld("tmp_" + sok, b, h, False)
        nd = bak(im, "EMIT")
        mat_hoog.node_tree.links.new(oud, uit.inputs["Surface"])
        mat_hoog.node_tree.nodes.remove(em); nt.nodes.remove(nd)
        arr = np.array(im.pixels[:], np.float32).reshape(-1, 4)[:, 0]
        bpy.data.images.remove(im)
        return arr
    ruw = kanaal("Roughness"); met = kanaal("Metallic")
    print("  ruwheid/metallic %s %.0f s" % (naam, time.time() - t0), flush=True)
    a = np.array(alb.pixels[:], np.float32).reshape(-1, 4)[:, :3]
    # geverfde delen mat-dielectrisch, alleen donker grijs staal (rups, loop, beslag) is metaal
    staal = (a.max(1) - a.min(1) < 0.07) & (a.max(1) < 0.25)
    met = np.where(staal, np.clip(met, 0.45, 0.8), 0.0)
    ruw = np.where(staal, np.clip(ruw, 0.4, 0.75), np.clip(ruw, 0.6, 0.95))
    orm = np.ones((b * h, 4), np.float32); orm[:, 1] = ruw; orm[:, 2] = met
    o_im = nieuw_beeld(naam + "_orm", b, h, False)
    o_im.pixels.foreach_set(orm.ravel())
    # UV's van de samengevoegde kopie terug naar de originelen
    uvs = np.empty(len(laag.data.loops) * 2, np.float32); laag.data.uv_layers[0].data.foreach_get("uv", uvs)
    uvs = uvs.reshape(-1, 2)
    pos = 0
    for o, k_ in zip(originelen, kopieen):
        nl = len(o.data.loops)
        layer = o.data.uv_layers[0] if len(o.data.uv_layers) else o.data.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", uvs[pos:pos + nl].ravel()); pos += nl
    bpy.data.objects.remove(laag)
    for n_ in (n_alb, n_nrm):
        nt.nodes.remove(n_)
    return alb, nrm, o_im


def verbind(mat, alb, nrm, orm):
    nt = mat.node_tree; pr = nt.nodes["Principled BSDF"]; lk = nt.links
    na = nt.nodes.new("ShaderNodeTexImage"); na.image = alb
    lk.new(na.outputs["Color"], pr.inputs["Base Color"])
    no = nt.nodes.new("ShaderNodeTexImage"); no.image = orm
    sep = nt.nodes.new("ShaderNodeSeparateColor"); lk.new(no.outputs["Color"], sep.inputs["Color"])
    lk.new(sep.outputs["Green"], pr.inputs["Roughness"]); lk.new(sep.outputs["Blue"], pr.inputs["Metallic"])
    nn = nt.nodes.new("ShaderNodeTexImage"); nn.image = nrm
    nm = nt.nodes.new("ShaderNodeNormalMap"); lk.new(nn.outputs["Color"], nm.inputs["Color"]); lk.new(nm.outputs["Normal"], pr.inputs["Normal"])
    for im in (alb, nrm, orm):
        im.pack()


mat_a = maak_materiaal("VR_Meshy_truck")
alb, nrm, orm = bak_groep(atlas_namen, mat_a, ATLAS, ATLAS, "Truck", ray=0.12, cage=0.06)
verbind(mat_a, alb, nrm, orm)
for n in atlas_namen:
    o = bpy.data.objects[n]; o.data.materials.clear(); o.data.materials.append(mat_a)
print("atlas klaar %.0f s" % (time.time() - t0), flush=True)
hoog.hide_render = True
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "gebakken.blend"))
print("STAP3 klaar %.0f s" % (time.time() - t0))
