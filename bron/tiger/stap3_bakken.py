"""Stap 3: textuur van de bron naar de lage delen bakken (Cycles CPU).
- Atlas voor romp, toren, kanon en wielen: albedo, tangent-normal en ruwheid/metallic (glTF-ORM)
- Rupsband: aparte lange strook (u = afstand langs de band), zodat het spel hem kan laten lopen
Leest laag.blend uit de cache, schrijft gebakken.blend (met ingepakte texturen).
Gebruik: python3 stap3_bakken.py <cache-map> [atlasgrootte] [rupsbreedte]"""
import sys, time
import numpy as np
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-3:]
CACHE = Path(args[0]).resolve()
ATLAS = int(args[1]) if len(args) > 1 else 2048
RUPS_B = int(args[2]) if len(args) > 2 else 4096
RUPS_H = RUPS_B // 8
t0 = time.time()
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "laag.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4

hoog = bpy.data.objects["Tiger_HQ"]
hoog.hide_render = False; hoog.hide_viewport = False
mat_hoog = hoog.data.materials[0]
bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
atlas_namen = ["Romp", "Toren", "Kanon"] + [o.name for o in bpy.data.objects if o.name.startswith("Wiel")]
rups_namen = ["RupsL", "RupsR"]


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


mat_a = maak_materiaal("Tiger")
alb, nrm, orm = bak_groep(atlas_namen, mat_a, ATLAS, ATLAS, "Tiger", ray=0.30, cage=0.14)
verbind(mat_a, alb, nrm, orm)
for n in atlas_namen:
    o = bpy.data.objects[n]; o.data.materials.clear(); o.data.materials.append(mat_a)
print("atlas klaar %.0f s" % (time.time() - t0), flush=True)

# rupsband: alleen de linker bakken, rechts gebruikt dezelfde textuur
mat_r = maak_materiaal("Tiger_rups")
ralb, rnrm, rorm = bak_groep(["RupsL"], mat_r, RUPS_B, RUPS_H, "Tiger_rups", ray=0.20, cage=0.10, rups=True)
verbind(mat_r, ralb, rnrm, rorm)
for n in rups_namen:
    o = bpy.data.objects[n]; o.data.materials.clear(); o.data.materials.append(mat_r)
print("rups klaar %.0f s" % (time.time() - t0), flush=True)
for n in ("Tiger_HQ", "Tiger_vox", "Romp_V", "Toren_V"):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_render = True
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "gebakken.blend"))
print("STAP3 klaar %.0f s" % (time.time() - t0))
