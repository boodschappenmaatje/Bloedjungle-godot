"""Jeep stap 4: de gebakken delen (romp, MG, vier wielen) samenbouwen met draaipunten, bemanning en clips; schrijft .blend en .glb.
Knopen (contract met scripts/vijand_jeep.gd): VijandJeep > Body > [RompMesh, StuurLV > WielLV, StuurRV > WielRV, WielLA, WielRA,
 Bestuurder > [BestuurderBenen, BestuurderBovenMesh], Geschut > [MG > Monding, Schutter > [SchutterBenen, Bovenlijf > BovenlijfMesh]]].
Spelassen: x = breedte (rechts = +x), voorkant = +Y in Blender (-Z in Godot), 1 eenheid = 1 m, grond op z = 0, oorsprong midden tussen de assen.
Clips (24 beelden/s, lussen): Rijden (wielen draaien, 1,0 s), Sturen (voorwielen links-rechts, 2,0 s), Vuren (MG-terugslag, 4 beelden = 0,17 s).
Het spel (scripts/vijand_jeep.gd) bestuurt wielen, sturen en MG zelf; de clips zijn voor de viewer en voor Vuren in het spel.
Gebruik: python3 stap4_bouwen.py <cache-map> <uit-map> <jeep.glb van de speler (bron van de figuren)> [textuurgrootte]"""
import sys, math
import numpy as np
import bpy
from mathutils import Vector, Matrix
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen_jeep as D

CACHE, UIT, FIGUREN = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve()
GAME_TEX = int(sys.argv[4]) if len(sys.argv) > 4 else 2048
UIT.mkdir(parents=True, exist_ok=True)
FPS = 24
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "jeep_gebakken.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.fps = FPS
for n in ("jeep_HQ",):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.name = o.name

# bemanning: de bestuurder en de schutter van de eigen jeep (lage figuren, ~1.000 driehoeken per stuk), in vijandkleuren
FIG = ["BestuurderBenen", "BestuurderBovenMesh", "SchutterBenen", "BovenlijfMesh"]
# verschuiving t.o.v. waar ze in de eigen jeep zitten (spelassen): bestuurder rechts op de voorbank, schutter achter het MG
DRIVER = Vector((0.75, -0.61, 0.28))
GUNNER = Vector((0.0, -0.03, 0.35))
UNIFORM = (0.549, 0.482, 0.322)   # 8c7b52, het kaki van de vijandelijke soldaten (Data.ETYPES)
HELM = (0.357, 0.376, 0.220)      # 5b6038, het olijfgeel van de vijandbasis (VijandBasis.KLEUR_BLOK)


def srgb(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


voor = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(FIGUREN))
gevonden = {}
for o in list(bpy.data.objects):
    if o in voor:
        continue
    if o.type == "MESH" and o.name in FIG:
        gevonden[o.name] = o
for o in list(bpy.data.objects):
    if o not in voor and o not in gevonden.values():
        bpy.data.objects.remove(o)
for n, o in gevonden.items():
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
    o.data = o.data.copy()
    mats = []
    for m in o.data.materials:
        k = m.copy()
        k.name = "Vijand_" + m.name.split(".")[0]
        pr = k.node_tree.nodes.get("Principled BSDF")
        if pr is not None:
            basis = k.name.split(".")[0]
            if basis.endswith("Uniform"):
                pr.inputs["Base Color"].default_value = (*srgb(UNIFORM), 1.0)
            elif basis.endswith("Helm"):
                pr.inputs["Base Color"].default_value = (*srgb(HELM), 1.0)
        mats.append(k)
    o.data.materials.clear()
    for k in mats:
        o.data.materials.append(k)
    off = DRIVER if n.startswith("Bestuurder") else GUNNER
    o.data.transform(Matrix.Translation(off))
    scene.collection.objects.link(o) if o.name not in scene.collection.objects else None


def leeg(naam, loc=(0, 0, 0)):
    e = bpy.data.objects.new(naam, None)
    e.empty_display_type = "PLAIN_AXES"; e.empty_display_size = 0.3
    scene.collection.objects.link(e)
    e.location = Vector(loc)
    return e


def hang(ob, ouder):
    view.update()
    m = ob.matrix_world.copy()
    ob.parent = ouder
    ob.matrix_parent_inverse = ouder.matrix_world.inverted()
    ob.matrix_world = m


def zet_origin(ob, punt):
    d = Vector(punt) - ob.location
    ob.data.transform(Matrix.Translation(-d))
    ob.location = Vector(punt)


root = leeg("VijandJeep")
body = leeg("Body")
hang(body, root)
romp = bpy.data.objects["Romp"]
romp.name = "RompMesh"; romp.data.name = "RompMesh"
hang(romp, body)
# wielen (R = rechts = +x); de voorwielen hangen aan een stuurknoop op de naaf
NAMEN = {"VR": ("StuurRV", "WielRV"), "VL": ("StuurLV", "WielLV"), "AR": (None, "WielRA"), "AL": (None, "WielLA")}
wielen, sturen = [], []
for sleutel, (stuur_naam, wiel_naam) in NAMEN.items():
    w = bpy.data.objects["Wiel_" + sleutel]
    nx, ny, nz = w["naaf"]
    zet_origin(w, (nx, ny, nz))
    w.name = wiel_naam; w.data.name = wiel_naam
    if stuur_naam:
        st = leeg(stuur_naam, (nx, ny, nz))
        hang(st, body); hang(w, st)
        sturen.append(st)
    else:
        hang(w, body)
    wielen.append(w)
# MG op zijn steunpaal: Geschut draait om de paal, MG (loop, huis, band) schuift bij het vuren, Monding is het uiteinde van de loop
dx, dy, dz = D.punt_naar_spel(D.MG_DRAAI)
geschut = leeg("Geschut", (0.0, dy, dz))
hang(geschut, body)
mg = bpy.data.objects["MG"]
zet_origin(mg, (0.0, dy, dz))
hang(mg, geschut)
mx, my, mz = D.punt_naar_spel(D.MONDING)
monding = leeg("Monding", (0.0, my, mz))
hang(monding, mg)
# bemanning
bestuurder = leeg("Bestuurder", (DRIVER.x - 0.3, 0.0, 0.0))
hang(bestuurder, body)
for n in ("BestuurderBenen", "BestuurderBovenMesh"):
    hang(gevonden[n], bestuurder)
schutter = leeg("Schutter", (0.0, dy, dz))
hang(schutter, geschut)
hang(gevonden["SchutterBenen"], schutter)
bovenlijf = leeg("Bovenlijf", (0.0, dy, dz))
hang(bovenlijf, schutter)
hang(gevonden["BovenlijfMesh"], bovenlijf)
view.update()

# ---------- clips ----------
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
tracks = []


def actie(o, naam):
    o.animation_data_create()
    o.animation_data.action = bpy.data.actions.new("%s_%s" % (naam, o.name))
    tracks.append((o, naam))


def sleutel(o, pad, idx, reeks):
    for fr, w in reeks:
        v = list(getattr(o, pad))
        v[idx] = w
        setattr(o, pad, v)
        o.keyframe_insert(pad, index=idx, frame=fr)


for w in wielen:
    actie(w, "Rijden")
    sleutel(w, "rotation_euler", 0, [(0, 0.0), (12, -math.pi), (24, -2 * math.pi)])
for st in sturen:
    actie(st, "Sturen")
    sleutel(st, "rotation_euler", 2, [(0, 0.0), (12, 0.5), (24, 0.0), (36, -0.5), (48, 0.0)])
actie(mg, "Vuren")
mg0 = Vector(mg.location)
for fr, d in [(0, 0.0), (1, 0.05), (3, 0.0), (4, 0.0)]:
    mg.location = mg0 + Vector((0.0, -d, 0.0))
    mg.keyframe_insert("location", frame=fr)
mg.location = mg0
for o, naam in tracks:
    act = o.animation_data.action
    o.animation_data.action = None
    tr = o.animation_data.nla_tracks.new(); tr.name = naam
    tr.strips.new(act.name, 0, act)
view.update()


# ---------- exporteren ----------
def externaliseer(map_):
    map_ = Path(map_); map_.mkdir(parents=True, exist_ok=True)
    for im in list(bpy.data.images):
        if im.users == 0 or im.type != "IMAGE" or im.size[0] < 8:
            bpy.data.images.remove(im); continue
        if max(im.size) > GAME_TEX:
            im.scale(GAME_TEX, GAME_TEX)
        pad = map_ / (im.name + ".jpg")
        im.filepath_raw = str(pad); im.file_format = "JPEG"; im.save()
        if im.packed_file:
            im.unpack(method="REMOVE")
        im.filepath = str(pad); im.source = "FILE"; im.reload()


externaliseer(UIT / "textures_jeep")
print("driehoeken:", sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
for o in bpy.data.objects:
    if o.type == "MESH":
        print("  %-22s %6d" % (o.name, len(o.data.polygons)))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "vijand_jeep.blend"), compress=True)
for o in bpy.data.objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(UIT / "vijand_jeep.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("STAP4 klaar; GLB in", UIT)
