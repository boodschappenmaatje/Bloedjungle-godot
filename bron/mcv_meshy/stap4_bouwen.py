"""MCV stap 4: de drie gebakken delen (wagen, module, poot) samenbouwen tot één bouwwagen met draaipunten en de clip Uitklappen; schrijft .blend en .glb.
Knopen (contract met scripts/mcv.gd): Mcv > [Romp, Schild, Stuur_A1L/R, Stuur_A2L/R > Wiel_*, Wiel_A3L/R, Wiel_A4L/R,
 Module > [Kern, Dak_L, Dak_R, Mast, Schotel], Poot_ML, Poot_MR, Poot_AL, Poot_AR > [PootBoven, PootOnder]].
Spelassen: x = breedte, voorkant = +Y in Blender (-Z in Godot), 1 eenheid = 1 m, grond op z = 0, oorsprong midden onder de wagen.
Clip Uitklappen (6,0 s, 30 beelden/s): schild omhoog, poten zakken, dakpanelen schuiven uit, mast rijst, schotel klapt open. Eindpose = uitgeklapt.
Gebruik: python3 stap4_bouwen.py <cache-map> <uit-map> [textuurgrootte]"""
import sys, math, json
import numpy as np
import bpy
from mathutils import Vector, Matrix
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen_wagen as DW
import delen_module as DM
import delen_poot as DP

CACHE, UIT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
GAME_TEX = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
UIT.mkdir(parents=True, exist_ok=True)
FPS = 30
NF = 180
bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "wagen_gebakken.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.fps = FPS
for n in ("wagen_HQ",):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])
voor = set(bpy.data.objects)
for naam in ("module", "poot"):
    with bpy.data.libraries.load(str(CACHE / (naam + "_gebakken.blend")), link=False) as (van, naar):
        naar.objects = [o for o in van.objects if not o.endswith("_HQ")]
    for o in naar.objects:
        if o is not None:
            scene.collection.objects.link(o)
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.name = o.name


def leeg(naam, loc=(0, 0, 0), rot=(0, 0, 0)):
    e = bpy.data.objects.new(naam, None)
    e.empty_display_type = "PLAIN_AXES"; e.empty_display_size = 0.3
    scene.collection.objects.link(e)
    e.location = Vector(loc); e.rotation_euler = rot
    return e


def hang(ob, ouder):
    view.update()
    m = ob.matrix_world.copy()
    ob.parent = ouder
    ob.matrix_parent_inverse = ouder.matrix_world.inverted()
    ob.matrix_world = m


def kind(ob, ouder):
    """hangt ob onder ouder met zijn huidige LOKALE plaats (de ouder levert de verplaatsing)"""
    ob.parent = ouder
    ob.matrix_parent_inverse = Matrix.Identity(4)


def zet_origin(ob, punt):
    d = Vector(punt) - ob.location
    ob.data.transform(Matrix.Translation(-d))
    ob.location = Vector(punt)


root = leeg("Mcv")
# ---------- wagen ----------
romp = bpy.data.objects["Romp"]; schild = bpy.data.objects["Schild"]
hang(romp, root)
zet_origin(schild, (0.0, -DW.SCHILD_DRAAI[0], DW.SCHILD_DRAAI[1] - DW.GROND))
hang(schild, root)
for i, (as_naam, xc, stuurt) in enumerate(DW.ASSEN):
    for kant in ("R", "L"):
        w = bpy.data.objects["Wiel_%s%s" % (as_naam, kant)]
        nx, ny, nz = w["naaf"]
        zet_origin(w, (nx, ny, nz))
        if stuurt:
            st = leeg("Stuur_%s%s" % (as_naam, kant), (nx, ny, nz))
            hang(st, root); hang(w, st)
        else:
            hang(w, root)
# ---------- module op de laadbak ----------
BAK_Z = 1.41                        # bovenkant van de laadbakvloer boven de grond
BAK_Y = -DW.SCHILD_DRAAI[0] * 0 - 1.68   # midden van de laadbak (bronassen x = +1,68)
module = leeg("Module", (0.0, BAK_Y, BAK_Z))
hang(module, root)
dak = {}
for n in ("Kern", "Dak_L", "Dak_R", "Mast", "Schotel"):
    o = bpy.data.objects[n]
    o.location = (0, 0, 0); o.rotation_euler = (0, 0, 0)     # gebouwd in spelassen met de onderkant van de container op z = 0
    if n in ("Mast", "Schotel"):
        pts = np.array([v.co[:] for v in o.data.vertices])
        zet_origin(o, (float(pts[:, 0].mean()), float(pts[:, 1].mean()), float(pts[:, 2].min())))
    kind(o, module)
# ---------- poten ----------
OPS = DP.AS
poten = {}
POOT_X, POOT_Z = 1.70, -0.11            # oorsprong van de poot (voetplaat) t.o.v. de wagen: kop tegen de zijkant van de laadbak
for naam, yy, zijde in (("Poot_MR", -0.5, 1), ("Poot_ML", -0.5, -1), ("Poot_AR", -3.45, 1), ("Poot_AL", -3.45, -1)):
    e = leeg(naam, (zijde * POOT_X, yy, POOT_Z), (0, 0, 0 if zijde > 0 else math.pi))
    hang(e, root)
    for basis in ("PootBoven", "PootOnder"):
        o = bpy.data.objects[basis].copy()
        o.data = bpy.data.objects[basis].data
        o.name = "%s_%s" % (basis, naam[-2:])
        scene.collection.objects.link(o)
        o.location = (0, 0, 0)
        kind(o, e)
        poten.setdefault(naam, {})[basis] = o
for basis in ("PootBoven", "PootOnder"):
    bpy.data.objects.remove(bpy.data.objects[basis])

# ---------- clip Uitklappen ----------
UITSLAG = 0.55           # m: poot ingeschoven langs de as in rust (voet hangt boven de grond)
SCHILD_HOEK = math.radians(32.0)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)


def kf(o, pad, waarde_per_beeld, idx=None):
    o.animation_data_create()
    if o.animation_data.action is None:
        o.animation_data.action = bpy.data.actions.new("Uitklappen_" + o.name)
    for fr, w in waarde_per_beeld:
        setattr(o, pad, w)
        o.keyframe_insert(pad, frame=fr)


def glad(t):      # smoothstep
    return t * t * (3 - 2 * t)


def verloop(reeks):
    """reeks: [(beeld, waarde)] -> waarde per beeld 0..NF (glad tussen de punten)"""
    out = []
    for fr in range(NF + 1):
        for (f0, w0), (f1, w1) in zip(reeks[:-1], reeks[1:]):
            if f0 <= fr <= f1:
                t = 0.0 if f1 == f0 else (fr - f0) / (f1 - f0)
                out.append((fr, w0 + (w1 - w0) * glad(t))); break
    return out


def schuif(o, as_vec, reeks):
    o.animation_data_create(); o.animation_data.action = bpy.data.actions.new("Uitklappen_" + o.name)
    for fr, d in verloop(reeks):
        o.location = Vector(as_vec) * d
        o.keyframe_insert("location", frame=fr)


def draai(o, euler_per_waarde, reeks):
    o.animation_data_create(); o.animation_data.action = bpy.data.actions.new("Uitklappen_" + o.name)
    for fr, w in verloop(reeks):
        o.rotation_euler = euler_per_waarde(w)
        o.keyframe_insert("rotation_euler", frame=fr)


S = lambda s: int(round(s * FPS))
# poten (0,5 - 2,0 s): de onderste buis schuift langs de as naar buiten (van UITSLAG ingeschoven naar 0)
for naam, d in poten.items():
    o = d["PootOnder"]
    as_loc = Vector((OPS[0], 0.0, OPS[1]))        # de as voet -> kop in de poot-assen
    # voet omhoog (ingeschoven) = naar de kop toe: +as; uitgeschoven = 0
    o.animation_data_create(); o.animation_data.action = bpy.data.actions.new("Uitklappen_" + o.name)
    for fr, w in verloop([(0, 1.0), (S(0.4), 1.0), (S(2.0), 0.0), (NF, 0.0)]):
        o.location = as_loc * (UITSLAG * w)
        o.keyframe_insert("location", frame=fr)
# schild (0 - 1,2 s): 32 graden omhoog
draai(schild, lambda w: (SCHILD_HOEK * w, 0, 0), [(0, 0.0), (S(0.2), 0.0), (S(1.4), 1.0), (NF, 1.0)])
# dakpanelen (1,8 - 4,2 s): schuiven opzij uit (links = +x kant in bron, hier per paneel naar buiten)
dak_l, dak_r = bpy.data.objects["Dak_L"], bpy.data.objects["Dak_R"]
UIT_DAK = 0.80
# Dak_L (bron y >= 0 -> spel x >= 0), Dak_R (spel x < 0)
schuif(dak_l, (1, 0, 0), [(0, 0.0), (S(1.8), 0.0), (S(4.2), UIT_DAK), (NF, UIT_DAK)])
schuif(dak_r, (-1, 0, 0), [(0, 0.0), (S(1.8), 0.0), (S(4.2), UIT_DAK), (NF, UIT_DAK)])
# mast (3,6 - 5,6 s): rijst 0,9 m
schuif(bpy.data.objects["Mast"], (0, 0, 1), [(0, 0.0), (S(3.6), 0.0), (S(5.6), 0.9), (NF, 0.9)])
# schotel (3,0 - 5,0 s): kantelt 35 graden omhoog om de dwarsas
draai(bpy.data.objects["Schotel"], lambda w: (math.radians(-35.0) * w, 0, 0), [(0, 0.0), (S(3.0), 0.0), (S(5.0), 1.0), (NF, 1.0)])
objs = [o for o in bpy.data.objects if o.animation_data and o.animation_data.action]
for o in objs:
    act = o.animation_data.action
    o.animation_data.action = None
    tr = o.animation_data.nla_tracks.new(); tr.name = "Uitklappen"
    tr.strips.new(act.name, 0, act)
# rustpose = begin
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


externaliseer(UIT / "textures_mcv")
tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.parent is not None)
print("driehoeken (met 4 poten):", sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "mcv_meshy.blend"), compress=True)
for o in bpy.data.objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(UIT / "mcv_meshy.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("STAP4 klaar; GLB in", UIT)
