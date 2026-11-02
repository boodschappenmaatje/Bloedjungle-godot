"""Stap 2: poort uitsnijden, schuifdeuren en vloer maken, UV-atlas, textuur bakken van de Meshy-bron (Cycles CPU).
Gebruik: python3 stap2_bakken.py <cache-map> [atlas] [samples]
Leest hq.blend, laag.blend en maten.json; schrijft gebakken.blend (texturen ingepakt) in de cache."""
import sys, json, time
import numpy as np
import bpy, bmesh
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
CACHE = Path(args[0]).resolve()
ATLAS = int(args[1]) if len(args) > 1 else 2048
SAMPLES = int(args[2]) if len(args) > 2 else 4
M = json.loads((CACHE / "maten.json").read_text())
t0 = time.time()

bpy.ops.wm.open_mainfile(filepath=str(CACHE / "laag.blend"))
with bpy.data.libraries.load(str(CACHE / "hq.blend")) as (src, dst):
    dst.objects = ["Garage_HQ"]
scene = bpy.context.scene
view = bpy.context.view_layer
hoog = dst.objects[0]
scene.collection.objects.link(hoog)
romp = bpy.data.objects["Romp"]
scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = SAMPLES

PX0, PX1 = M["poort_x"]
PZ0, PZ1 = M["poort_z"]
PY_VOOR = M["poort_y"][0]          # voorkant van de deurplaat (voorkant gebouw = -Y)
DIK = 0.10


def alleen(*objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = active or objs[0]


# 1. poortopening uitsnijden (de vaste deurplaat van de voorgevel); de onderste 10 cm blijft staan als drempel,
#    bovenin gaat 6 cm extra weg zodat er geen tanden van de oude plaat onder de rail hangen
bm = bmesh.new(); bm.from_mesh(romp.data)


def in_poort(p):
    return PX0 < p.x < PX1 and PZ0 + 0.10 < p.z < PZ1 and PY_VOOR - 0.30 < p.y < PY_VOOR + 0.70


# Eerst netjes doorsnijden langs de vier randen van de opening (links, rechts, onder, boven), zodat er geen grote
# driehoeken meer zijn die half in en half buiten de opening liggen; dan alleen de vlakken wegdoen die echt in de opening liggen.
# (Eerst werd elk vlak met een hoekpunt in de opening weggegooid: bij de grote driehoeken van de voorgevel gaf dat een gat naast de poort.)
for co_, no_ in (((PX0, 0, 0), (1, 0, 0)), ((PX1, 0, 0), (1, 0, 0)), ((0, 0, PZ0 + 0.10), (0, 0, 1)), ((0, 0, PZ1), (0, 0, 1))):
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-5, plane_co=co_, plane_no=no_)
bm.faces.ensure_lookup_table()
weg = [f for f in bm.faces if in_poort(f.calc_center_median())]
wy = [v.co.y for f in weg for v in f.verts]
Y0, Y1 = min(wy), max(wy)
bmesh.ops.delete(bm, geom=weg, context="FACES")
# De voorgevel is een holle schil: de snede liet de binnenkant van de muur open, zodat je naast de poort door de muur
# heen keek (gat). Vier vlakken in de opening sluiten de snede (links, rechts, boven, drempel); ze kijken naar de opening.
ZB, ZT = PZ0 + 0.10, PZ1


def vlak(punten):
    bm.faces.new([bm.verts.new(p) for p in punten])


vlak([(PX0, Y0, ZB), (PX0, Y1, ZB), (PX0, Y1, ZT), (PX0, Y0, ZT)])   # linker wang, kijkt naar +X
vlak([(PX1, Y0, ZB), (PX1, Y0, ZT), (PX1, Y1, ZT), (PX1, Y1, ZB)])   # rechter wang, kijkt naar -X
vlak([(PX0, Y0, ZT), (PX0, Y1, ZT), (PX1, Y1, ZT), (PX1, Y0, ZT)])   # bovenkant, kijkt naar -Z (omlaag)
vlak([(PX0, Y0, ZB), (PX1, Y0, ZB), (PX1, Y1, ZB), (PX0, Y1, ZB)])   # drempel, kijkt naar +Z (omhoog)
bm.normal_update()
bm.to_mesh(romp.data); bm.free()
print("poort uitgesneden: %d vlakken weg" % len(weg), flush=True)


def blok(naam, x0, x1, y0, y1, z0, z1, binnen=False):
    me = bpy.data.meshes.new(naam)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    if binnen:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(naam, me); scene.collection.objects.link(ob)
    return ob


# 2. twee schuifdeuren op de plek van de oude deurplaat (gebakken van de bron, dus ze zien er hetzelfde uit)
mid = (PX0 + PX1) / 2
deurL = blok("DeurL", PX0, mid - 0.01, PY_VOOR, PY_VOOR + DIK, PZ0 - 0.02, PZ1)
deurR = blok("DeurR", mid + 0.01, PX1, PY_VOOR, PY_VOOR + DIK, PZ0 - 0.02, PZ1)
# planken in de deuren voor een beter silhouet in de normal map zijn niet nodig: de bake neemt ze mee

# 3. werkplaats binnen: vloer en een donkere binnenbak, alleen zichtbaar door de open poort
binnen = blok("Binnen", PX0 - 0.9, PX1 + 0.6, PY_VOOR + 0.35, PY_VOOR + 7.0, 0.02, PZ1 + 0.15, binnen=True)
mat_b = bpy.data.materials.new("Garage_binnen"); mat_b.use_nodes = True
pr = mat_b.node_tree.nodes["Principled BSDF"]
pr.inputs["Base Color"].default_value = (0.016, 0.015, 0.013, 1); pr.inputs["Roughness"].default_value = 0.9
binnen.data.materials.append(mat_b)

# 4. UV-atlas voor romp + deuren
for o in (romp, deurL, deurR):
    if not o.data.uv_layers:
        o.data.uv_layers.new(name="UVMap")
k = []
for o in (romp, deurL, deurR):
    c = o.copy(); c.data = o.data.copy(); scene.collection.objects.link(c); k.append(c)
alleen(*k); bpy.ops.object.join(); atl = view.objects.active; atl.name = "Atlas_tmp"
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002, area_weight=1.0)
bpy.ops.uv.pack_islands(margin=0.002)
bpy.ops.object.mode_set(mode="OBJECT")
print("uv %.0f s" % (time.time() - t0), flush=True)

mat = bpy.data.materials.new("Garage"); mat.use_nodes = True
atl.data.materials.clear(); atl.data.materials.append(mat)
nt = mat.node_tree
mat_hoog = hoog.data.materials[0]
bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def beeld(naam, kleur):
    im = bpy.data.images.new(naam, ATLAS, ATLAS, alpha=False)
    im.colorspace_settings.name = "sRGB" if kleur else "Non-Color"
    return im


def bak(im, soort, **kw):
    node = nt.nodes.new("ShaderNodeTexImage"); node.image = im; nt.nodes.active = node
    alleen(hoog, atl, active=atl)
    bpy.ops.object.bake(type=soort, use_selected_to_active=True, cage_extrusion=0.10, max_ray_distance=0.35, margin=8, **kw)
    nt.nodes.remove(node)


alb = beeld("garage_albedo", True); bak(alb, "DIFFUSE", pass_filter={"COLOR"})
print("albedo %.0f s" % (time.time() - t0), flush=True)
nrm = beeld("garage_normal", False); bak(nrm, "NORMAL", normal_space="TANGENT")
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
# Meshy zet geverfd hout en golfplaat half-metallic: alleen donker, kleurloos staal blijft metaal
staal = (a.max(1) - a.min(1) < 0.06) & (a.max(1) < 0.22)
met = np.where(staal, np.clip(met, 0.3, 0.7), 0.0)
ruw = np.clip(ruw, 0.55, 0.95)
orm = np.ones((ATLAS * ATLAS, 4), np.float32); orm[:, 1] = ruw; orm[:, 2] = met
o_im = beeld("garage_orm", False); o_im.pixels.foreach_set(orm.ravel())
print("orm %.0f s" % (time.time() - t0), flush=True)

# UV's terug naar de losse objecten
uvs = np.empty(len(atl.data.loops) * 2, np.float32); atl.data.uv_layers[0].data.foreach_get("uv", uvs); uvs = uvs.reshape(-1, 2)
pos = 0
for o in (romp, deurL, deurR):
    n = len(o.data.loops); o.data.uv_layers[0].data.foreach_set("uv", uvs[pos:pos + n].ravel()); pos += n
    o.data.materials.clear(); o.data.materials.append(mat)
bpy.data.objects.remove(atl)

# achterkant van de deuren: de stralen vinden daar alleen het donkere binnenwerk, dus dezelfde planken als de voorkant (gespiegeld)
for o in (deurL, deurR):
    bm = bmesh.new(); bm.from_mesh(o.data); uvl = bm.loops.layers.uv.active
    voor = next(f for f in bm.faces if f.normal.y < -0.9)
    achter = next(f for f in bm.faces if f.normal.y > 0.9)
    for l in achter.loops:
        m = min(voor.loops, key=lambda v: (v.vert.co.x - l.vert.co.x) ** 2 + (v.vert.co.z - l.vert.co.z) ** 2)
        l[uvl].uv = m[uvl].uv.copy()
    bm.to_mesh(o.data); bm.free()

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
