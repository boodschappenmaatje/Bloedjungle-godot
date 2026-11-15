"""Bloedjungle importstraat: Meshy-.glb -> geoptimaliseerd game-model + rapport.

Gebruik (headless, pip bpy 5.x of blender -b -P):
    python3 -I tools/importstraat/straat.py <in.glb> <uitmap> [--regels regels.json]

De bestandsnaam bepaalt het type en (optioneel) de maat:
    gebouw_kazerne_h8.glb      -> type gebouw, 8 m hoog
    plant_varen_h1.2.glb       -> type plant, 1,2 m hoog
    voertuig_pickup_l5.4.glb   -> type voertuig, 5,4 m lang
    prop_kist_b1.glb           -> type prop, 1 m breed
  maatcodes: h = hoogte (z), b = breedte (x), l = lengte/diepte (y). Zonder code geldt de standaardmaat van het type.

Stappen (zie README.md):
 1. inlezen, alle stukken samenvoegen, transformaties toepassen
 2. draaien (regels.draai_z), op maat schalen in meters (zonder vervorming), midden op x/y = 0, grond op z = 0
 3. vereenvoudigen waar je het niet ziet: platte vlakken oplossen, dan inklappen tot het driehoekbudget (randen/silhouet blijven)
 4. nieuwe nette UV's, hoog detail bakken naar kleur, normal map en ORM (2K of 4K)
 5. typeregels: gebouw = botsingsnet (-colonly) + deuren/ramen uit regels, plant = windgewicht in vertexkleur (alfa),
    voertuig = wielen/delen uit regels als losse knopen; 'delen' werkt voor elk type
 6. exporteren: <naam>.glb (game), <naam>.blend (bron), stats.json; Godot maakt bij import zelf de LOD's (generate_lods)
Daarna: rapport.py maakt de voor/na-beelden en RAPPORT.md.
"""
import bpy, bmesh, sys, os, re, json, math, time
from mathutils import Vector, Matrix

T0 = time.time()
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
SRC = os.path.abspath(ARGS[0])
OUT = os.path.abspath(ARGS[1])
REGELS = {}
if "--regels" in ARGS:
    REGELS = json.load(open(ARGS[ARGS.index("--regels") + 1]))
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ typeregels (standaarden; regels.json overschrijft)
TYPES = {
    #            standaardmaat       driehoeken  textuur  botsing
    "gebouw":   dict(maat=("h", 8.0), tris=30000, tex=2048, botsing="trimesh", botsing_tris=2000),
    "plant":    dict(maat=("h", 2.0), tris=4000,  tex=1024, botsing=None),
    "voertuig": dict(maat=("l", 5.0), tris=30000, tex=2048, botsing="convex", botsing_tris=300),
    "prop":     dict(maat=("h", 1.0), tris=3000,  tex=1024, botsing="convex", botsing_tris=200),
}


def log(*a):
    print(f"[straat {time.time() - T0:6.1f}s]", *a, flush=True)


def parse_name(path):
    base = os.path.splitext(os.path.basename(path))[0]
    typ = base.split("_")[0].lower()
    if typ not in TYPES:
        typ = "prop"
    maat = None
    m = re.search(r"_([hbl])(\d+(?:[.,]\d+)?)$", base)
    naam = base
    if m:
        maat = (m.group(1), float(m.group(2).replace(",", ".")))
        naam = base[: m.start()]
    naam = re.sub(r"[^A-Za-z0-9_]+", "_", naam).strip("_").lower()[:48]
    return naam, typ, maat


NAAM, TYPE, MAAT = parse_name(SRC)
R = dict(TYPES[TYPE])
R.update(REGELS)
NAAM = REGELS.get("naam", NAAM)
if MAAT is None:
    MAAT = tuple(REGELS["maat"]) if "maat" in REGELS else R["maat"]
log("model", NAAM, "type", TYPE, "maat", MAAT, "budget", R["tris"], "tris, textuur", R["tex"])


def tri_count(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


def bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


# ------------------------------------------------------------------ 1. inlezen
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
src_imgs = sorted({(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.size[0]})
select_only(meshes)
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
hoog = bpy.context.view_layer.objects.active
hoog.name = NAAM + "_hoog"
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
voor = dict(tris=tri_count([hoog]), verts=len(hoog.data.vertices), materialen=len(hoog.data.materials),
            texturen=[f"{n} {w}x{h}" for n, w, h in src_imgs])
log("voor:", voor)

# ------------------------------------------------------------------ 2. draaien, schalen, grond op nul
if R.get("draai_z"):
    hoog.rotation_euler.z = math.radians(R["draai_z"])
    select_only([hoog]); bpy.ops.object.transform_apply(rotation=True)
mn, mx = bbox([hoog])
size = mx - mn
as_ = {"b": 0, "l": 1, "h": 2}[MAAT[0]]
ref = R.get("maat_ref")          # optioneel: [min, max] in bronmaat langs die as (bv. alleen de muur, zonder stenen)
s = MAAT[1] / ((ref[1] - ref[0]) if ref else size[as_])
hoog.scale = (s, s, s)
select_only([hoog]); bpy.ops.object.transform_apply(scale=True)
mn, mx = bbox([hoog])
grond = R.get("grond_ref")       # optioneel: bronhoogte die op z = 0 moet (bv. de voet van de muur i.p.v. de diepste steen)
z0 = grond * s if grond is not None else mn.z
SHIFT = (-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -z0)
hoog.location = SHIFT
select_only([hoog]); bpy.ops.object.transform_apply(location=True)
mn, mx = bbox([hoog])
afm = mx - mn
log("na schalen: %.2f x %.2f x %.2f m (b x l x h), schaal %.3f" % (afm.x, afm.y, afm.z, s))

# kleine schoonmaak: dubbele punten samen (Meshy-netten hebben naden)
bm = bmesh.new(); bm.from_mesh(hoog.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=afm.length * 2e-6)
bm.to_mesh(hoog.data); bm.free()

# ------------------------------------------------------------------ 3. laag net: vereenvoudigen
laag = hoog.copy(); laag.data = hoog.data.copy(); laag.name = NAAM
bpy.context.scene.collection.objects.link(laag)
target = int(R["tris"])
n0 = tri_count([laag])
select_only([laag])
if n0 > target:
    # eerst bijna-vlakke stukken oplossen (vlakke muren hebben geen driehoeken nodig), dan inklappen tot het budget.
    # Inklappen houdt de vorm (kwadratische fout): randen en silhouet gaan het laatst.
    if R.get("vlak_hoek", 0.6) > 0:
        md = laag.modifiers.new("vlak", "DECIMATE"); md.decimate_type = "DISSOLVE"
        md.angle_limit = math.radians(R.get("vlak_hoek", 0.6)); md.delimit = {"NORMAL"}
        bpy.ops.object.modifier_apply(modifier="vlak")
        bm = bmesh.new(); bm.from_mesh(laag.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(laag.data); bm.free()
    n1 = tri_count([laag])
    if n1 > target:
        md = laag.modifiers.new("klap", "DECIMATE"); md.decimate_type = "COLLAPSE"
        md.ratio = target / n1; md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="klap")
    log("vereenvoudigd:", n0, "->", n1, "->", tri_count([laag]))
# nette normalen: gewogen op vlakgrootte, scherpe randen blijven scherp
laag.data.shade_smooth()
try:
    bpy.ops.object.shade_auto_smooth(angle=math.radians(R.get("glad_hoek", 40)))
except Exception:
    pass
md = laag.modifiers.new("gewogen", "WEIGHTED_NORMAL"); md.keep_sharp = True
bpy.ops.object.modifier_apply(modifier="gewogen")

# ------------------------------------------------------------------ 4. UV's en bakken
TEX = int(R["tex"])
while laag.data.uv_layers:
    laag.data.uv_layers.remove(laag.data.uv_layers[0])
laag.data.uv_layers.new(name="UV")
select_only([laag])
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(R.get("uv_hoek", 55)), island_margin=2.0 / TEX * 4, area_weight=1.0, scale_to_bounds=False)
try:
    bpy.ops.uv.pack_islands(margin=2.0 / TEX * 2, rotate=True, shape_method="CONCAVE")
except TypeError:
    bpy.ops.uv.pack_islands(margin=2.0 / TEX * 2)
bpy.ops.object.mode_set(mode="OBJECT")

sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = afm.length * R.get("bak_uitstulp", 0.004)
sc.render.bake.max_ray_distance = afm.length * R.get("bak_afstand", 0.02)
sc.render.bake.margin = 8

src_mats = list(hoog.data.materials)


def tex_node_for(mat, socket_name):
    """Zoek de afbeelding achter een Principled-ingang (eventueel via Separate Color / Normal Map)."""
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return None, None
    sock = bsdf.inputs[socket_name]
    if not sock.links:
        return None, sock.default_value
    n = sock.links[0].from_node
    chan = sock.links[0].from_socket.name
    if n.type in ("SEPARATE_COLOR", "SEPRGB", "SEPARATE_RGB"):
        img = n.inputs[0].links[0].from_node if n.inputs[0].links else None
        return (img, chan), None
    if n.type == "NORMAL_MAP":
        img = n.inputs["Color"].links[0].from_node if n.inputs["Color"].links else None
        return (img, "RGB"), None
    if n.type == "TEX_IMAGE":
        return (n, "RGB"), None
    return None, None


def rewire_emit(mat, what):
    """Zet de uitgang van het bronmateriaal tijdelijk op Emission met één kanaal (kleur, ruwheid, metaal, AO)."""
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    em = nt.nodes.new("ShaderNodeEmission")
    sock_name = {"kleur": "Base Color", "ruw": "Roughness", "metaal": "Metallic"}[what]
    src, val = tex_node_for(mat, sock_name)
    if src and src[0] is not None:
        img, chan = src
        if chan in ("RGB", "Color"):
            nt.links.new(img.outputs[0], em.inputs[0])
        else:
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(img.outputs[0], sep.inputs[0])
            nt.links.new(sep.outputs[chan], em.inputs[0])
    else:
        v = val if val is not None else 0.0
        em.inputs[0].default_value = tuple(v)[:3] + (1,) if hasattr(v, "__len__") else (v, v, v, 1)
    old = out.inputs[0].links[0].from_socket if out.inputs[0].links else None
    nt.links.new(em.outputs[0], out.inputs[0])
    return (out, old, em)


def restore(mat, st):
    out, old, em = st
    nt = mat.node_tree
    if old:
        nt.links.new(old, out.inputs[0])
    nt.nodes.remove(em)


bake_mat = bpy.data.materials.new(NAAM + "_mat")
if not bake_mat.node_tree:
    bake_mat.use_nodes = True
laag.data.materials.clear(); laag.data.materials.append(bake_mat)
imgs = {}


def new_img(key, noncolor):
    im = bpy.data.images.new(f"{NAAM}_{key}", TEX, TEX, alpha=False, float_buffer=False)
    im.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
    imgs[key] = im
    return im


def bake(key, kind, noncolor, pre=None):
    im = new_img(key, noncolor)
    nt = bake_mat.node_tree
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = im
    nt.nodes.active = tn
    states = []
    if pre:
        for m in src_mats:
            states.append((m, rewire_emit(m, pre)))
    select_only([hoog, laag], active=laag)
    t = time.time()
    if kind == "EMIT":
        bpy.ops.object.bake(type="EMIT")
    else:
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    for m, st in states:
        restore(m, st)
    nt.nodes.remove(tn)
    log("gebakken", key, "%.0fs" % (time.time() - t))
    return im


bake("kleur", "EMIT", False, pre="kleur")
bake("normaal", "NORMAL", True)
ruw = bake("ruw", "EMIT", True, pre="ruw")
met = bake("metaal", "EMIT", True, pre="metaal")

# ORM = (AO 1, ruwheid, metaal) in één kaart (glTF: G = ruwheid, B = metaal)
import numpy as np
px_r = np.empty(TEX * TEX * 4, dtype=np.float32); ruw.pixels.foreach_get(px_r)
px_m = np.empty(TEX * TEX * 4, dtype=np.float32); met.pixels.foreach_get(px_m)
orm = new_img("orm", True)
o = np.ones(TEX * TEX * 4, dtype=np.float32)
o[1::4] = px_r[0::4]; o[2::4] = px_m[0::4]
if R.get("metaal_max") is not None:   # Meshy zet geverfd hout/beton soms half-metallic
    o[2::4] = np.minimum(o[2::4], R["metaal_max"])
orm.pixels.foreach_set(o)
for k in ("ruw", "metaal"):
    bpy.data.images.remove(imgs.pop(k))

# eindmateriaal (glTF-standaard: kleur + ORM + normal)
nt = bake_mat.node_tree
for n in list(nt.nodes):
    if n.type not in ("OUTPUT_MATERIAL", "BSDF_PRINCIPLED"):
        nt.nodes.remove(n)
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
tk = nt.nodes.new("ShaderNodeTexImage"); tk.image = imgs["kleur"]; nt.links.new(tk.outputs[0], bsdf.inputs["Base Color"])
to = nt.nodes.new("ShaderNodeTexImage"); to.image = imgs["orm"]
so = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(to.outputs[0], so.inputs[0])
nt.links.new(so.outputs["Green"], bsdf.inputs["Roughness"]); nt.links.new(so.outputs["Blue"], bsdf.inputs["Metallic"])
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = imgs["normaal"]
nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs[0], nm.inputs["Color"]); nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])

texdir = os.path.join(OUT, "textures"); os.makedirs(texdir, exist_ok=True)
for k, im in imgs.items():
    im.filepath_raw = os.path.join(texdir, f"{NAAM}_{k}.jpg"); im.file_format = "JPEG"
    sc.render.image_settings.quality = 92
    im.save()
try:   # Godot leest jpg's met een ICC-profiel niet (Blender zet er een in bij sRGB): zonder profiel opnieuw opslaan
    from PIL import Image as _PIL
    for f in os.listdir(texdir):
        fp = os.path.join(texdir, f)
        _PIL.open(fp).convert("RGB").save(fp, quality=92)
except ImportError:
    log("LET OP: Pillow ontbreekt; controleer of Godot de jpg's laadt (ICC-profiel)")

# ------------------------------------------------------------------ 5. typeregels
extra = {}


def split_box(obj, naam, mn_, mx_):
    """Haal alle vlakken met hun midden in het blok [mn, mx] uit obj en maak er een eigen knoop van (pivot = midden)."""
    bm_ = bmesh.new(); bm_.from_mesh(obj.data)
    mnv, mxv = Vector(mn_), Vector(mx_)
    sel = [f for f in bm_.faces if all(mnv[i] <= f.calc_center_median()[i] <= mxv[i] for i in range(3))]
    if not sel:
        bm_.free(); return None
    keep = set(sel)
    bm2 = bm_.copy()
    bmesh.ops.delete(bm_, geom=sel, context="FACES")
    bm_.to_mesh(obj.data); bm_.free()
    bmesh.ops.delete(bm2, geom=[f for i, f in enumerate(bm2.faces) if i not in {g.index for g in keep}], context="FACES")
    me = bpy.data.meshes.new(naam); bm2.to_mesh(me); bm2.free()
    ob = bpy.data.objects.new(naam, me); bpy.context.scene.collection.objects.link(ob)
    c = sum((v.co for v in me.vertices), Vector()) / max(1, len(me.vertices))
    me.transform(Matrix.Translation(-c)); ob.location = c
    ob.parent = obj
    ob.matrix_parent_inverse = obj.matrix_world.inverted()
    return ob


delen = []
for d in R.get("delen", []):
    ob = split_box(laag, d["naam"], d["min"], d["max"])
    if ob:
        delen.append(ob.name)
if delen:
    extra["delen"] = delen

if TYPE == "plant":
    # windgewicht in de alfa van de vertexkleur (shaders/foliage.gdshader): 0 aan de voet, 1 in de top
    me = laag.data
    ca = me.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
    for poly in me.polygons:
        for li in poly.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            w = max(0.0, min(1.0, z / max(afm.z, 0.01))) ** 1.5
            ca.data[li].color = (1, 1, 1, w)
    extra["wind"] = "vertexkleur-alfa (foliage.gdshader)"

if R.get("botsing"):
    col = laag.copy(); col.data = laag.data.copy(); col.parent = None
    for c in list(col.children):
        c.parent = None
    bpy.context.scene.collection.objects.link(col)
    col.matrix_world = laag.matrix_world
    select_only([col])
    nb = tri_count([col])
    if R["botsing"] == "convex":   # één convex blok om het model heen
        bm_ = bmesh.new(); bm_.from_mesh(col.data)
        res = bmesh.ops.convex_hull(bm_, input=bm_.verts)
        bmesh.ops.delete(bm_, geom=list(set(res["geom_interior"]) | set(res["geom_unused"])), context="VERTS")
        bm_.to_mesh(col.data); bm_.free()
        nb = tri_count([col])
    if nb > R["botsing_tris"]:
        md = col.modifiers.new("klap", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = R["botsing_tris"] / nb
        bpy.ops.object.modifier_apply(modifier="klap")
    col.data.materials.clear()
    # Godot-importsuffix: -colonly = vaste botsing (trimesh, ook binnen begaanbaar), -convcolonly = convex blok
    col.name = NAAM + ("-colonly" if R["botsing"] == "trimesh" else "-convcolonly")
    extra["botsing"] = f"{R['botsing']} {tri_count([col])} tris"
if R.get("deuren"):
    extra["deuren"] = [d["naam"] for d in R["deuren"]]
    for d in R["deuren"]:   # deuren/ramen als losse knopen zodat Godot ze kan openen of laten breken
        split_box(laag, d["naam"], d["min"], d["max"])

# ------------------------------------------------------------------ 6. exporteren
bpy.data.objects.remove(hoog)
for m in src_mats:
    if m.users == 0:
        bpy.data.materials.remove(m)
for im in list(bpy.data.images):
    if im.users == 0:
        bpy.data.images.remove(im)
glb = os.path.join(OUT, NAAM + ".glb")
select_only([o for o in sc.objects])
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_apply=True,
                          export_image_format="JPEG", export_jpeg_quality=92, export_animations=False,
                          export_yup=True, export_tangents=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAAM + ".blend"), compress=True)
game = [o for o in sc.objects if o.type == "MESH" and "colonly" not in o.name]
na = dict(tris=tri_count(game), verts=sum(len(o.data.vertices) for o in game), materialen=1,
          texturen=[f"{NAAM}_{k}.jpg {TEX}x{TEX}" for k in imgs], glb_mb=round(os.path.getsize(glb) / 1e6, 2))
stats = dict(naam=NAAM, type=TYPE, bron=os.path.basename(SRC), maat=list(MAAT), schaal=s, verschuiving=list(SHIFT), draai_z=R.get("draai_z", 0),
             afmeting_m=[round(afm.x, 2), round(afm.y, 2), round(afm.z, 2)], voor=voor, na=na, extra=extra,
             regels={k: v for k, v in R.items() if k not in ("delen", "deuren")}, tijd_s=round(time.time() - T0))
json.dump(stats, open(os.path.join(OUT, "stats.json"), "w"), indent=1)
log("klaar:", json.dumps(na))
