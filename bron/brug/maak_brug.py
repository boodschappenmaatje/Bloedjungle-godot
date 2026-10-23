"""Houten ophaalbrug voor Bloedjungle: maak_brug.py uit/  ->  uit/brug.blend en uit/brug.glb (1 eenheid = 1 meter).
De brug ligt langs Blender-Y (Godot -Z), 12,4 m lang met een dek van 5 m breed (tank en jeep kunnen erover).
Het zuidelijke deel (de Klep, 9,6 m) draait om een scharnier aan de zuidoever omhoog (80 graden, zoals in de web-versie),
aan twee touwen die vanaf een poortframe naar de klep lopen. Naast de brug staat een bedieningskastje met hendel en lampjes.
Bovenkant dek op z = 0,03 (de grond in het spel is z = 0). Materialen heten Hout1/Hout2/Hout3/Balk/Paal/Metaal/Touw/LampRood/LampGroen;
het spel hangt er foto-texturen aan (Kit.skin 'brug').
Animaties (NLA-sporen, 30 beeld/s): Omhoog en Omlaag. Knopen: Klep, Hendel, TouwL, TouwR, LampRood, LampGroen, KastjePunt."""
import math, sys, os, random
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
random.seed(4)

DW = 5.0            # breedte dek
TOP = 0.03          # bovenkant dek
Y0 = -6.2           # zuidrand van de klep = scharnier
Y1 = 3.4            # noordrand van de klep
YN = 6.2            # noordkant vaste oprit
YS = -7.4           # zuidkant vaste oprit
HINGE = Vector((0.0, Y0, 0.0))
UP = 1.4            # radialen omhoog (BRIDGE_UP in de web-versie)
RAIL_X = DW / 2 + 0.2
PORTAL_Y = Y0 - 0.9
PORTAL_H = 6.4
ATT_Y = 4.6         # waar de touwen aan de klep vastzitten, afstand vanaf het scharnier


def mat(name, color, rough=0.9, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = 2.5
    return m


M = {
    "Hout1": mat("Hout1", (0.55, 0.40, 0.25)),
    "Hout2": mat("Hout2", (0.46, 0.33, 0.20)),
    "Hout3": mat("Hout3", (0.62, 0.46, 0.30)),
    "Balk": mat("Balk", (0.30, 0.21, 0.13)),
    "Paal": mat("Paal", (0.24, 0.17, 0.10)),
    "Metaal": mat("Metaal", (0.36, 0.38, 0.40), 0.5, 0.6),
    "Touw": mat("Touw", (0.58, 0.5, 0.34)),
    "LampRood": mat("LampRood", (0.8, 0.1, 0.08), 0.4, 0.0, (1.0, 0.1, 0.06)),
    "LampGroen": mat("LampGroen", (0.2, 0.75, 0.2), 0.4, 0.0, (0.2, 1.0, 0.25)),
}
PARTS = ("vast", "klep", "hendel", "lamprood", "lampgroen")
B = {p: {k: bmesh.new() for k in M} for p in PARTS}


def box(k, loc, size, rot=(0, 0, 0), part="vast", off=(0, 0, 0)):
    b = B[part][k]
    r = bmesh.ops.create_cube(b, size=1)
    v = r["verts"]
    bmesh.ops.scale(b, vec=size, verts=v)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(b, verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(b, verts=v, vec=(loc[0] - off[0], loc[1] - off[1], loc[2] - off[2]))


def cyl(k, loc, radius, depth, seg=8, rot=(0, 0, 0), part="vast", off=(0, 0, 0)):
    b = B[part][k]
    r = bmesh.ops.create_cone(b, cap_ends=True, segments=seg, radius1=radius, radius2=radius * 0.92, depth=depth)
    v = r["verts"]
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(b, verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(b, verts=v, vec=(loc[0] - off[0], loc[1] - off[1], loc[2] - off[2]))


def kbox(k, loc, size, rot=(0, 0, 0)):
    """Doos in de klep (coordinaten zoals in de wereld, het scharnier zit op HINGE)."""
    box(k, loc, size, rot, "klep", HINGE)


def planken(part, y_a, y_b, off):
    n = max(1, int(round((y_b - y_a) / 0.4)))
    st = (y_b - y_a) / n
    for i in range(n):
        y = y_a + st * (i + 0.5)
        k = random.choice(["Hout1", "Hout2", "Hout3"])
        w = DW - random.uniform(0.0, 0.05)
        box(k, (random.uniform(-0.01, 0.01), y, TOP - 0.05 + random.uniform(-0.006, 0.006)), (w, st - 0.04, 0.1),
            (0, 0, random.uniform(-0.012, 0.012)), part, off)


def leuning(part, y_a, y_b, off, posten):
    for sx in (-1, 1):
        x = sx * RAIL_X
        for k in range(posten):
            y = y_a + 0.2 + k * (y_b - y_a - 0.4) / (posten - 1)
            box("Paal", (x, y, 0.62), (0.2, 0.2, 1.24), part=part, off=off)
            box("Hout3", (x, y, 1.26), (0.26, 0.26, 0.05), part=part, off=off)
        box("Hout2", (x, (y_a + y_b) / 2, 1.12), (0.18, y_b - y_a, 0.14), part=part, off=off)
        box("Hout1", (x, (y_a + y_b) / 2, 0.62), (0.12, y_b - y_a, 0.1), part=part, off=off)
        for k in range(posten - 1):
            y = y_a + 0.2 + (k + 0.5) * (y_b - y_a - 0.4) / (posten - 1)
            box("Balk", (x, y, 0.36), (0.08, 0.08, 0.72), (0.6 * (1 if k % 2 else -1), 0, 0), part, off)


# ---------------------------------------------------------------- de klep (beweegt)
Z = (0, 0, 0)
planken("klep", Y0, Y1, tuple(HINGE))
for x in (-1.8, 0.0, 1.8):
    kbox("Balk", (x, (Y0 + Y1) / 2, -0.2), (0.3, Y1 - Y0, 0.3))
for i in range(6):
    y = Y0 + 0.2 + i * (Y1 - Y0 - 0.4) / 5
    kbox("Balk", (0, y, -0.45), (DW + 0.5, 0.3, 0.28))
leuning("klep", Y0, Y1, tuple(HINGE), 7)
kbox("Balk", (0, Y0 - 0.05, -0.12), (DW + 0.6, 0.45, 0.45))     # scharnierbalk
kbox("Balk", (0, Y1 + 0.1, -0.12), (DW + 0.6, 0.4, 0.4))        # kop aan de noordkant
for sx in (-1, 1):                                               # metalen scharnierogen
    cyl("Metaal", (sx * 1.2, Y0 - 0.05, -0.12), 0.22, 0.9, 10, (0, math.pi / 2, 0), "klep", tuple(HINGE))
for sx in (-1, 1):                                               # ogen waar de touwen aan vastzitten
    kbox("Metaal", (sx * RAIL_X, Y0 + ATT_Y, 0.2), (0.3, 0.3, 0.14))

# ---------------------------------------------------------------- vaste delen
planken("vast", Y1, YN, (0, 0, 0))
planken("vast", YS, Y0, (0, 0, 0))
leuning("vast", Y1, YN, (0, 0, 0), 5)
leuning("vast", YS, Y0, (0, 0, 0), 4)
for y in (Y1 + 0.2, (Y1 + YN) / 2, YN - 0.2):
    box("Balk", (0, y, -0.45), (DW + 0.5, 0.3, 0.28))
for x in (-1.8, 0.0, 1.8):
    box("Balk", (x, (Y1 + YN) / 2, -0.2), (0.3, YN - Y1, 0.3))
    box("Balk", (x, (YS + Y0) / 2, -0.2), (0.3, Y0 - YS, 0.3))
for y in (YS + 0.2, Y0 - 0.2):
    box("Balk", (0, y, -0.45), (DW + 0.5, 0.3, 0.28))
for y in (Y1 + 0.5, YN - 0.6):
    for x in (-2.1, 2.1):
        cyl("Paal", (x, y, -0.65), 0.19, 1.7)
        box("Balk", (x, y, 0.1), (0.5, 0.5, 0.1))
    d = math.hypot(4.2, 0.9)
    ang = math.atan2(0.9, 4.2)
    box("Balk", (0, y, -0.9), (d, 0.12, 0.12), (0, -ang, 0))
    box("Balk", (0, y, -0.9), (d, 0.12, 0.12), (0, ang, 0))
for sy, yy in ((-1, YS), (1, YN)):
    box("Balk", (0, yy + sy * 0.2, -0.12), (DW + 0.6, 0.4, 0.4))
    for j in range(3):
        y = yy + sy * (0.55 + j * 0.4)
        box("Hout2", (0, y, TOP - 0.05 - 0.012 * (j + 1)), (DW - 0.1, 0.36, 0.1), (math.radians(-3 * sy), 0, 0))
# scharnierlagers op de zuidoever
for sx in (-1, 1):
    box("Balk", (sx * 1.2, Y0 - 0.45, -0.3), (0.5, 0.5, 0.6))
    cyl("Metaal", (sx * 1.2, Y0 - 0.05, -0.12), 0.1, 1.1, 8, (0, math.pi / 2, 0))
# poortframe voor de touwen
for sx in (-1, 1):
    x = sx * (RAIL_X + 0.55)
    cyl("Paal", (x, PORTAL_Y, PORTAL_H / 2 - 0.2), 0.24, PORTAL_H + 0.4)
    box("Balk", (x, PORTAL_Y - 0.9, 1.5), (0.14, 2.1, 0.14), (0.9, 0, 0))   # schoor naar achteren
    box("Balk", (x, PORTAL_Y + 0.0, 0.3), (0.7, 0.7, 0.18))
box("Balk", (0, PORTAL_Y, PORTAL_H), (2 * (RAIL_X + 0.55) + 0.6, 0.3, 0.3))
cyl("Metaal", (0, PORTAL_Y, PORTAL_H + 0.3), 0.1, 2 * (RAIL_X + 0.55), 10, (0, math.pi / 2, 0))   # katrolas
for sx in (-1, 1):
    cyl("Metaal", (sx * RAIL_X, PORTAL_Y, PORTAL_H + 0.3), 0.26, 0.12, 12, (0, math.pi / 2, 0))     # katrollen

# ---------------------------------------------------------------- bedieningskastje op een paal bij de zuidoprit
KX, KY, KZ = RAIL_X + 1.7, Y0 - 2.4, 1.15
cyl("Paal", (KX, KY, 0.55), 0.17, 1.4, 8)
box("Balk", (KX, KY, 0.0), (0.7, 0.7, 0.16))
box("Balk", (KX, KY, KZ), (0.62, 0.5, 0.55))
box("Metaal", (KX, KY, KZ + 0.3), (0.68, 0.56, 0.06))                   # deksel
box("Metaal", (KX - 0.32, KY, KZ), (0.03, 0.4, 0.42))                   # deurtje op de kant van de weg
for dy in (-0.16, 0.16):
    for dz in (-0.14, 0.14):
        cyl("Metaal", (KX - 0.345, KY + dy, KZ + dz), 0.025, 0.03, 6, (0, math.pi / 2, 0))
box("Metaal", (KX - 0.2, KY, KZ + 0.34), (0.16, 0.34, 0.03))             # hendelsleuf
cyl("Metaal", (KX - 0.2, KY, KZ + 0.36), 0.05, 0.1, 8, (math.pi / 2, 0, 0))   # draaipunt
# hendel: steel + rode knop; draait om het draaipunt
HX, HY, HZ = KX - 0.2, KY, KZ + 0.36
box("Metaal", (HX, HY, HZ + 0.22), (0.04, 0.04, 0.44), part="hendel", off=(HX, HY, HZ))
cyl("LampRood", (HX, HY, HZ + 0.47), 0.065, 0.1, 8, part="hendel", off=(HX, HY, HZ))
# lampjes op het deurtje
LX = KX - 0.36
cyl("LampRood", (LX, KY - 0.1, KZ + 0.19), 0.055, 0.04, 8, (0, math.pi / 2, 0), "lamprood", (LX, KY - 0.1, KZ + 0.19))
cyl("LampGroen", (LX, KY + 0.1, KZ + 0.19), 0.055, 0.04, 8, (0, math.pi / 2, 0), "lampgroen", (LX, KY + 0.1, KZ + 0.19))
cyl("Metaal", (LX, KY - 0.1, KZ + 0.19), 0.075, 0.02, 8, (0, math.pi / 2, 0))
cyl("Metaal", (LX, KY + 0.1, KZ + 0.19), 0.075, 0.02, 8, (0, math.pi / 2, 0))

# ---------------------------------------------------------------- objecten
root = bpy.data.objects.new("Brug", None)
scene.collection.objects.link(root)
klep = bpy.data.objects.new("Klep", None)
klep.location = HINGE
scene.collection.objects.link(klep)
klep.parent = root
hendel = bpy.data.objects.new("Hendel", None)
hendel.location = (HX, HY, HZ)
scene.collection.objects.link(hendel)
hendel.parent = root
lamp_r = bpy.data.objects.new("LampRood", None)
lamp_r.location = (LX, KY - 0.1, KZ + 0.19)
lamp_g = bpy.data.objects.new("LampGroen", None)
lamp_g.location = (LX, KY + 0.1, KZ + 0.19)
punt = bpy.data.objects.new("KastjePunt", None)
punt.location = (KX, KY, 0.0)
for o in (lamp_r, lamp_g, punt):
    scene.collection.objects.link(o)
    o.parent = root
dragers = {"vast": root, "klep": klep, "hendel": hendel, "lamprood": lamp_r, "lampgroen": lamp_g}
for part, d in B.items():
    for k, bm in d.items():
        if not bm.verts:
            bm.free()
            continue
        me = bpy.data.meshes.new(f"Brug_{part}_{k}")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(M[k])
        ob = bpy.data.objects.new(f"Brug_{part}_{k}", me)
        scene.collection.objects.link(ob)
        ob.parent = dragers[part]

# touwen: dunne stokken van het poortframe naar de klep, elk beeld opnieuw uitgelijnd
touw = {}
for name, sx in (("TouwL", -1), ("TouwR", 1)):
    bm = bmesh.new()
    r = bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(0.07, 1.0, 0.07), verts=r["verts"])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M["Touw"])
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.parent = root
    ob.rotation_mode = "XYZ"
    touw[name] = (ob, sx * RAIL_X)


def zet_touwen(th):
    for name, (ob, x) in touw.items():
        top = Vector((x, PORTAL_Y, PORTAL_H + 0.3))
        att = HINGE + Vector((x, ATT_Y * math.cos(th) - 0.2 * math.sin(th), ATT_Y * math.sin(th) + 0.2 * math.cos(th)))
        att.x = x
        d = att - top
        ob.location = (top + att) / 2
        ob.rotation_euler = (math.atan2(d.z, d.y), 0, 0)
        ob.scale = (1, d.length, 1)


# ---------------------------------------------------------------- animaties
FPS = 30
scene.render.fps = FPS


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def hoek_omhoog(t, duur):
    """0 -> UP: eerst langzaam, dan vlot, een klein nawiebelen aan het eind."""
    u = t / duur
    h = UP * ease(u)
    if u > 0.9:
        h += 0.025 * math.sin((u - 0.9) * 10 * math.pi) * (1 - u) * 10
    return h


def hoek_omlaag(t, duur):
    """UP -> 0: zakt aan de touwen, valt het laatste stuk en stuitert even op de oprit."""
    u = t / duur
    if u < 0.8:
        h = UP * (1 - ease(u / 0.8) * 0.93)
    else:
        v = (u - 0.8) / 0.2
        base = UP * 0.07
        h = max(0.0, base * (1 - v) - 0.0)
        h += 0.05 * math.sin(v * 2.5 * math.pi) * (1 - v) if v < 0.9 else 0.0
    return max(0.0, h)


def hendel_hoek(t, naar, duur):
    """De hendel gaat in 0,5 s van de ene stand naar de andere, voor de brug beweegt."""
    a0, a1 = (-0.65, 0.65) if naar == "omhoog" else (0.65, -0.65)
    return a0 + (a1 - a0) * ease(t / 0.5)


def clip(naam, duur, hoek, naar):
    frames = int(round(duur * FPS))
    objs = [klep, hendel, touw["TouwL"][0], touw["TouwR"][0]]
    for o in objs:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    basis = {o: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in objs}
    for f in range(0, frames + 1):
        t = f / FPS
        th = hoek(max(0.0, t - 0.6), duur - 0.6) if t > 0.6 else (UP if naar == "omlaag" else 0.0)
        klep.rotation_euler = (th, 0, 0)
        klep.keyframe_insert("rotation_euler", frame=f)
        hendel.rotation_euler = (0, hendel_hoek(min(t, 0.5), naar, duur), 0)
        hendel.keyframe_insert("rotation_euler", frame=f)
        zet_touwen(th)
        for nm in ("TouwL", "TouwR"):
            o = touw[nm][0]
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in objs:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
        o.location, o.rotation_euler, o.scale = basis[o]
        o.rotation_mode = "XYZ"


zet_touwen(0.0)
hendel.rotation_euler = (0, -0.65, 0)           # hendel staat naar voren zolang de brug omlaag ligt
clip("Omhoog", 4.2, hoek_omhoog, "omhoog")
hendel.rotation_euler = (0, 0.65, 0)
clip("Omlaag", 3.6, hoek_omlaag, "omlaag")
hendel.rotation_euler = (0, -0.65, 0)           # rustpose: brug omlaag, hendel naar voren
klep.rotation_euler = (0, 0, 0)
zet_touwen(0.0)

scene.frame_start, scene.frame_end = 0, 126
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "brug.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "brug.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)
