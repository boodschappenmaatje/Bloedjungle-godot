"""Importstraat-rapport: voor/na-beelden uit dezelfde hoeken + cijfers.

    python3 -I tools/importstraat/rapport.py <bron.glb> <uitmap>

Leest <uitmap>/stats.json en <uitmap>/<naam>.glb (gemaakt door straat.py). Zet het Meshy-origineel op precies dezelfde
maat/plek, rendert beide met dezelfde camera's en hetzelfde licht (Cycles CPU), en schrijft:
  <uitmap>/rapport/<hoek>.jpg      (links voor, rechts na)
  <uitmap>/rapport/overzicht.jpg   (alle hoeken)
  <uitmap>/RAPPORT.md              (driehoeken, texturen, geheugen, geschatte fps, beeldverschil per hoek)
"""
import bpy, sys, os, json, math
from mathutils import Vector
import numpy as np

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
SRC, OUT = os.path.abspath(ARGS[0]), os.path.abspath(ARGS[1])
ST = json.load(open(os.path.join(OUT, "stats.json")))
NAAM = ST["naam"]
RDIR = os.path.join(OUT, "rapport"); os.makedirs(RDIR, exist_ok=True)
W, H = int(os.environ.get("RW", 800)), int(os.environ.get("RH", 520))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def load(path, coll_name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    coll = bpy.data.collections.new(coll_name); sc.collection.children.link(coll)
    for o in new:
        for c in o.users_collection:
            c.objects.unlink(o)
        coll.objects.link(o)
        if "colonly" in o.name:
            o.hide_render = True
    return coll, new


voor, vo = load(SRC, "voor")
roots = [o for o in vo if o.parent is None]
for o in roots:   # zelfde draai, schaal en verschuiving als straat.py
    o.matrix_world = (
        __import__("mathutils").Matrix.Translation(Vector(ST["verschuiving"]))
        @ __import__("mathutils").Matrix.Scale(ST["schaal"], 4)
        @ __import__("mathutils").Matrix.Rotation(math.radians(ST.get("draai_z", 0)), 4, "Z")
        @ o.matrix_world)
na, no = load(os.path.join(OUT, NAAM + ".glb"), "na")

sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = int(os.environ.get("S", 16))
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.64, 0.78, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN")); sun.data.energy = 3.5; sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(48), 0, math.radians(-38)); sc.collection.objects.link(sun)
gm = bpy.data.meshes.new("grond"); gm.from_pydata([(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)], [], [(0, 1, 2, 3)])
g = bpy.data.objects.new("grond", gm); sc.collection.objects.link(g)
mat = bpy.data.materials.new("grond")
if not mat.node_tree:
    mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.16, 0.19, 0.11, 1)
gm.materials.append(mat)

meshes = [o for o in no if o.type == "MESH" and not o.hide_render]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2; r = (mx - mn).length / 2
g.scale = (r * 6, r * 6, 1); g.location.z = -0.02

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
# hoeken: richting vanaf het midden, afstand x straal, brandpunt. 'spelcamera' = schuin van boven zoals in Bloedjungle (~55 graden).
VIEWS = [("voor", (0, -1, 0.18), 2.3, 35), ("achter", (0, 1, 0.18), 2.3, 35), ("schuin", (0.75, -1, 0.6), 2.3, 35),
         ("spelcamera", (0, -0.7, 1.0), 2.6, 35), ("boven", (0, -0.001, 1), 2.3, 35), ("dichtbij", (-0.5, -1, 0.35), 0.9, 35)]


def shoot(name, d, dist, lens, coll_show):
    for coll in (voor, na):
        coll.hide_render = coll is not coll_show
    d = Vector(d).normalized()
    tgt = c + (Vector((-(mx.x - mn.x) * 0.18, 0, (mx.z - mn.z) * 0.1)) if name == "dichtbij" else Vector())
    cam.location = tgt + d * r * dist
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    cam.data.clip_end = r * 20
    p = os.path.join(RDIR, f"_{name}_{coll_show.name}.png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    return p


from PIL import Image, ImageDraw, ImageFont
try:
    FONT = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
except Exception:
    FONT = ImageFont.load_default()
verschil = {}
tiles = []
for name, d, dist, lens in VIEWS:
    a = Image.open(shoot(name, d, dist, lens, voor)).convert("RGB")
    b = Image.open(shoot(name, d, dist, lens, na)).convert("RGB")
    A = np.asarray(a, dtype=np.float32) / 255; B = np.asarray(b, dtype=np.float32) / 255
    mse = float(np.mean((A - B) ** 2))
    verschil[name] = dict(psnr=round(10 * math.log10(1 / max(mse, 1e-10)), 1), gem_afwijking_pct=round(float(np.mean(np.abs(A - B))) * 100, 2))
    sheet = Image.new("RGB", (W * 2 + 6, H), (20, 20, 20))
    sheet.paste(a, (0, 0)); sheet.paste(b, (W + 6, 0))
    dr = ImageDraw.Draw(sheet)
    for x, t in ((10, f"VOOR (Meshy) {ST['voor']['tris']:,} tris".replace(",", ".")), (W + 16, f"NA (game) {ST['na']['tris']:,} tris".replace(",", "."))):
        dr.rectangle((x - 4, 6, x + 12 * len(t) + 8, 36), fill=(0, 0, 0))
        dr.text((x, 8), t, fill=(255, 255, 255), font=FONT)
    dr.text((10, H - 32), name, fill=(255, 230, 120), font=FONT)
    sheet.save(os.path.join(RDIR, f"{name}.jpg"), quality=85)
    tiles.append(sheet)
    for p in (f"_{name}_voor.png", f"_{name}_na.png"):
        os.remove(os.path.join(RDIR, p))
ov = Image.new("RGB", (tiles[0].width, tiles[0].height * len(tiles)))
for i, t in enumerate(tiles):
    ov.paste(t, (0, i * t.height))
ov = ov.resize((ov.width // 2, ov.height // 2))
ov.save(os.path.join(RDIR, "overzicht.jpg"), quality=85)

# ------------------------------------------------------------------ geheugen en fps (vuistregels)
def tex_mb(w_, h_, astc=True):
    # ASTC 4x4 = 1 byte per pixel (iPhone), ongecomprimeerd RGBA8 = 4; mipmaps +33 %
    return w_ * h_ * (1 if astc else 4) * 1.33 / 1e6


def mesh_mb(verts, tris):
    # Godot 4 met compressie: ~24 bytes per punt (positie, normaal/tangent, uv) + 4 bytes per index
    return (verts * 24 + tris * 3 * 4) / 1e6


def texsizes(lst):
    out = []
    for t in lst:
        wh = t.split()[-1].split("x")
        out.append((int(wh[0]), int(wh[1])))
    return out


v, n = ST["voor"], ST["na"]
tv = sum(tex_mb(*s) for s in texsizes(v["texturen"]))
tn = sum(tex_mb(*s) for s in texsizes(n["texturen"]))
mv, mn_ = mesh_mb(v["verts"], v["tris"]), mesh_mb(n["verts"], n["tris"])
# Frame-schatting: iPhone (A15-A17) tekent grofweg 1 miljoen zichtbare driehoeken in ~2 ms met deze shaders,
# plus ~0,02 ms per tekenopdracht. Dennis' native meting: ~110 fps (27 okt) => ~9 ms; eis 60 fps = 16,7 ms.
BASIS_MS = 1000 / 110


def fps(tris, calls):
    ms = BASIS_MS + tris / 1e6 * 2.0 + calls * 0.02
    return round(1000 / ms), round(ms, 1)


fv, msv = fps(v["tris"], v["materialen"])
fn, msn = fps(n["tris"], n["materialen"] + len(ST["extra"].get("delen", [])))
ok = fn >= 60
psnrs = [x["psnr"] for x in verschil.values()]
oordeel = "GOED" if min(psnrs) >= 28 else ("LET OP" if min(psnrs) >= 24 else "ZICHTBAAR VERSCHIL")

L = []
L.append(f"# Importstraat-rapport: {NAAM}\n")
L.append(f"Bron: `{ST['bron']}` · type **{ST['type']}** · maat {ST['afmeting_m'][0]} x {ST['afmeting_m'][1]} x {ST['afmeting_m'][2]} m (b x l x h), grond op 0 · straat {ST['tijd_s']} s\n")
L.append("| | Voor (Meshy) | Na (game) |\n|---|---:|---:|")
L.append(f"| Driehoeken | {v['tris']:,} | {n['tris']:,} |".replace(",", "."))
L.append(f"| Punten | {v['verts']:,} | {n['verts']:,} |".replace(",", "."))
L.append(f"| Materialen | {v['materialen']} | {n['materialen']} |")
L.append(f"| Texturen | {', '.join(v['texturen'])} | {', '.join(n['texturen'])} |")
L.append(f"| Geheugen texturen (ASTC, iPhone) | {tv:.0f} MB | {tn:.0f} MB |")
L.append(f"| Geheugen net | {mv:.0f} MB | {mn_:.1f} MB |")
L.append(f"| Geschatte fps (alleen dit model in beeld) | {fv} ({msv} ms) | {fn} ({msn} ms) |")
L.append(f"| LOD's | geen | Godot maakt ze bij import (generate_lods) |\n")
L.append(f"**Eis 60 fps:** {'haalbaar volgens de schatting' if ok else 'NIET haalbaar volgens de schatting'} · iPhone: **NIET GETEST** (schatting = vuistregel vanaf de native meting van ~110 fps).\n")
L.append(f"**Beeldverschil voor/na:** {oordeel} (PSNR per hoek, hoger = gelijker; boven 28 dB is op spelafstand nauwelijks te zien)\n")
L.append("| Hoek | PSNR | gem. afwijking |\n|---|---:|---:|")
for k, x in verschil.items():
    L.append(f"| {k} | {x['psnr']} dB | {x['gem_afwijking_pct']} % |")
if ST["extra"]:
    L.append("\n**Typeregels:** " + "; ".join(f"{k}: {v_ if isinstance(v_, str) else ', '.join(v_)}" for k, v_ in ST["extra"].items()))
L.append("\nBeelden: `rapport/overzicht.jpg` en per hoek `rapport/<hoek>.jpg` (links voor, rechts na, zelfde camera en licht).")
open(os.path.join(OUT, "RAPPORT.md"), "w").write("\n".join(L) + "\n")
json.dump(dict(verschil=verschil, geheugen_mb=dict(voor=round(tv + mv), na=round(tn + mn_, 1)), fps_schatting=dict(voor=fv, na=fn), oordeel=oordeel),
          open(os.path.join(OUT, "rapport.json"), "w"), indent=1)
print("\n".join(L))
