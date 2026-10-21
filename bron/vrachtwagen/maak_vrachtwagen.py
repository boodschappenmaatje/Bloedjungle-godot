"""Zware legervrachtwagen (zeswieler, 6x6) met open laadbak voor 10 soldaten, voor Bloedjungle.
Blender +Y = voorkant (wordt -Z in Godot), Z omhoog, 1 eenheid = 1 meter (het spel schaalt het model met 1,1).
Gebruik: python3 maak_vrachtwagen.py <uitmap>  ->  vrachtwagen.glb, vrachtwagen.blend, vrachtwagen_olijf.png

Hiërarchie:
  Vrachtwagen > Body > RompMesh, StuurLV > WielLV, StuurRV > WielRV, WielLM, WielRM, WielLA, WielRA,
                       Klep (laadklep, scharniert om X) > KlepMesh, Trap (klapt uit) > TrapMesh,
                       Zeil > ZeilDak, RolDak, ZeilL/ZeilR, RolL/RolR (rolt op en af), Zit0..Zit9 (plek van elke soldaat),
                       Uitlaat (bovenkant uitlaatpijp), Instap (waar soldaten achter de klep staan),
                       Koplamp L/R (spotlampen), Achterlicht L/R (puntlampen)
Animaties (clips): Open (klep zakt, trapje klapt uit), Dicht (andersom), ZeilDicht (zeil rolt af), ZeilOpen (rolt op)."""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materialen ----------
def od_image(size=512):
    """Naadloos herhalende camouflage-textuur (1 tegel = 1,6 m): olijf met donkergroene, zwarte en zandkleurige
    vlekken, modder en afgebladderde verf."""
    def noise(scale, seed):
        n = size // scale
        g = np.random.default_rng(seed).random((n, n))
        y, x = np.mgrid[0:size, 0:size] / scale
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        xa, xb, ya, yb = x0 % n, (x0 + 1) % n, y0 % n, (y0 + 1) % n
        top = g[ya, xa] * (1 - fx) + g[ya, xb] * fx
        bot = g[yb, xa] * (1 - fx) + g[yb, xb] * fx
        return top * (1 - fy) + bot * fy

    def sm(v, e0, e1):
        return np.clip((v - e0) / (e1 - e0), 0, 1)[..., None]

    olive = np.array([0.29, 0.31, 0.19])
    donker = np.array([0.15, 0.185, 0.10])
    zwart = np.array([0.065, 0.08, 0.055])
    zand = np.array([0.47, 0.42, 0.27])
    modder = np.array([0.30, 0.235, 0.15])
    metaal = np.array([0.34, 0.33, 0.30])
    a = noise(128, 1) * 0.65 + noise(64, 2) * 0.35
    b = noise(128, 3) * 0.65 + noise(32, 4) * 0.35
    img = olive * (0.9 + 0.2 * noise(8, 9)[..., None])
    img = img * (1 - sm(b, 0.60, 0.625)) + zand * sm(b, 0.60, 0.625)
    img = img * (1 - sm(a, 0.55, 0.57)) + donker * sm(a, 0.55, 0.57)
    img = img * (1 - sm(a, 0.68, 0.70)) + zwart * sm(a, 0.68, 0.70)
    m = sm(noise(32, 6) * 0.7 + noise(8, 10) * 0.3, 0.62, 0.78) * 0.5
    img = img * (1 - m) + modder * m
    c = sm(noise(4, 7) + (noise(2, 8) - 0.5) * 0.3, 0.80, 0.84) * 0.6
    img = img * (1 - c) + metaal * c
    img = np.clip(img + (noise(2, 11)[..., None] - 0.5) * 0.03, 0, 1)
    im = bpy.data.images.new("vrachtwagen_olijf", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, "vrachtwagen_olijf.png")
    im.file_format = "PNG"
    im.save()
    return im


def mat(name, color, rough=0.8, metal=0.0, image=None, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


OLIJF = mat("Olijf", (0.29, 0.31, 0.19), 0.75, 0.05, od_image())
DONKER = mat("Donker", (0.16, 0.17, 0.11), 0.8)
ZWART = mat("Zwart", (0.05, 0.05, 0.05), 0.6, 0.3)
BAND = mat("Band", (0.06, 0.06, 0.055), 0.95)
METAAL = mat("Metaal", (0.22, 0.22, 0.21), 0.4, 0.8)
CANVAS = mat("Canvas", (0.36, 0.33, 0.24), 0.95)
# lampen: emissie staat aan; het spel en de viewer zetten ze aan/uit via de emissie
KOPLAMP = mat("Koplamp", (0.9, 0.88, 0.75), 0.15, 0.0, emit=(1.0, 0.95, 0.8), strength=6.0)
ACHTERLICHT = mat("Achterlicht", (0.5, 0.05, 0.03), 0.3, 0.0, emit=(1.0, 0.06, 0.02), strength=3.0)
HUID = mat("Huid", (0.62, 0.45, 0.34), 0.7)
UNIFORM = mat("Uniform", (0.30, 0.31, 0.21), 0.95)
HELM = mat("Helm", (0.25, 0.27, 0.17), 0.6, 0.1)
KOPPEL = mat("Koppel", (0.36, 0.32, 0.20), 0.9)
LAARS = mat("Laars", (0.12, 0.09, 0.07), 0.7)
VLAM = mat("Vlam", (1.0, 0.8, 0.4), 0.5, emit=(1.0, 0.7, 0.25), strength=12.0)
WIT = mat("Wit", (0.82, 0.82, 0.76), 0.7)
HOUT = mat("Hout", (0.33, 0.21, 0.11), 0.8)
RIEM = mat("Riem", (0.19, 0.16, 0.09), 0.9)
MESSING = mat("Messing", (0.8, 0.6, 0.25), 0.3, 1.0)


def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name, parent=None, loc=(0, 0, 0)):
    e = link(bpy.data.objects.new(name, None), parent)
    e.location = loc
    return e


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(40))
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    o = mesh_obj(name, bm, material, parent, loc)
    o.rotation_euler = rot
    return o


def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    o.rotation_euler = rot
    return o


def sphere(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1), half=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
    if half:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc, True)


def prism_x(name, profile_yz, width, material, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    left = [bm.verts.new((-width / 2, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((width / 2, y, z)) for y, z in profile_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    for i in range(len(profile_yz)):
        j = (i + 1) % len(profile_yz)
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc)


def bevel(o, w=0.015, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"


def join(target, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def soldaat(naam, parent, zittend):
    """Eenvoudige soldaat; oorsprong tussen de voeten (staand) of op het zitvlak (zittend)."""
    s = empty(naam, parent)
    delen = []
    if zittend:
        for sx in (-1, 1):
            delen.append(cyl(f"{naam}Dij{sx}", 0.075, 0.07, 0.42, UNIFORM, "Y", 8, s, (sx * 0.1, 0.2, 0.06)))
            delen.append(cyl(f"{naam}Scheen{sx}", 0.065, 0.055, 0.42, UNIFORM, "Z", 8, s, (sx * 0.1, 0.42, -0.15)))
            delen.append(box(f"{naam}Laars{sx}", (0.1, 0.24, 0.09), LAARS, s, (sx * 0.1, 0.47, -0.36)))
        torso_z = 0.05
    else:
        for sx in (-1, 1):
            delen.append(cyl(f"{naam}Been{sx}", 0.075, 0.06, 0.8, UNIFORM, "Z", 8, s, (sx * 0.11, 0.02, 0.45),
                             rot=(math.radians(-6), 0, sx * 0.05)))
            delen.append(box(f"{naam}Laars{sx}", (0.11, 0.26, 0.12), LAARS, s, (sx * 0.12, 0.05, 0.06)))
        torso_z = 0.85
    return s, delen, torso_z


def bovenlijf(naam, parent, z, buig, handen):
    """Romp, hoofd, helm en armen naar de handposities (in parent-ruimte)."""
    b = empty(naam, parent, (0, 0, z))
    b.rotation_euler = (buig, 0, 0)
    d = []
    d.append(box(f"{naam}Heup", (0.32, 0.2, 0.16), UNIFORM, b, (0, 0, 0.08)))
    d.append(prism_x(f"{naam}Torso", [(-0.11, 0.12), (0.1, 0.12), (0.12, 0.55), (-0.12, 0.58)], 0.38, UNIFORM, b))
    d.append(box(f"{naam}Koppel", (0.4, 0.24, 0.06), KOPPEL, b, (0, 0, 0.16)))
    d.append(box(f"{naam}Vest", (0.36, 0.06, 0.26), KOPPEL, b, (0, 0.11, 0.38)))
    d.append(cyl(f"{naam}Nek", 0.05, 0.05, 0.1, HUID, "Z", 8, b, (0, 0, 0.62)))
    d.append(sphere(f"{naam}Hoofd", 0.11, HUID, b, (0, 0.01, 0.74), (0.9, 1.0, 1.05)))
    d.append(sphere(f"{naam}Helm", 0.15, HELM, b, (0, 0.0, 0.76), (1.0, 1.08, 0.85), half=True))
    d.append(cyl(f"{naam}Helmrand", 0.155, 0.155, 0.02, HELM, "Z", 14, b, (0, 0.0, 0.76)))
    for i, (sx, hand) in enumerate(handen):
        sch = Vector((sx * 0.21, 0.0, 0.52))
        h = Vector(hand)
        # hand van parent-ruimte naar bovenlijf-ruimte (alleen kanteling om X en hoogte)
        h = Matrix.Rotation(-buig, 3, "X") @ (h - Vector((0, 0, z)))
        elle = (sch + h) / 2 + Vector((sx * 0.08, -0.04, -0.08))
        for a, bpt, rr, tag in ((sch, elle, 0.055, "Boven"), (elle, h, 0.048, "Onder")):
            v = bpt - a
            arm = cyl(f"{naam}Arm{tag}{sx}", rr, rr * 0.9, v.length, UNIFORM, "Z", 8, b, (a + bpt) / 2)
            arm.rotation_euler = v.to_track_quat("Z", "Y").to_euler()
            d.append(arm)
        d.append(sphere(f"{naam}Hand{sx}", 0.045, HUID, b, h))
    return b, d


def torus(name, major, minor, material, parent, loc, rot=(0, 0, 0), segs=14):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segs, minor_segments=5,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    for c in o.users_collection:
        c.objects.unlink(o)
    link(o, parent)
    o.data.materials.append(material)
    return o


def ster(name, r, material, parent, loc, rot=(0, 0, 0)):
    """Vlakke vijfpuntige ster in het XY-vlak, zichtkant naar +Z."""
    bm = bmesh.new()
    vs = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.40
        vs.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, 0)))
    bm.faces.new(vs)
    o = mesh_obj(name, bm, material, parent, loc)
    o.rotation_euler = rot
    return o



LOS = set()  # namen van bewegende delen die niet met de romp samengevoegd worden
CAMO = mat("Camo", (0.29, 0.31, 0.19), 0.8, 0.0, bpy.data.images["vrachtwagen_olijf"])
PLAAT = mat("Laadvloer", (0.20, 0.21, 0.15), 0.85, 0.2)
GLAS = mat("Glas", (0.10, 0.13, 0.14), 0.05, 0.5)
ZAND = mat("Zandzak", (0.45, 0.39, 0.25), 1.0)

root = empty("Vrachtwagen")
body = empty("Body", root)

# ---------- maten ----------
R_WIEL = 0.52
Y_VOOR, Y_MID, Y_ACHTER = 2.45, -1.15, -2.45   # assen
SPOOR_V = 0.98                                 # voorwielen (enkel)
SPOOR_A = 0.95                                 # achterwielen (dubbel, midden van het paar)
BAK_Y0, BAK_Y1 = -3.75, 0.45                   # laadbak achter- en voorkant
BAK_X = 1.22                                   # halve breedte laadbak
VLOER = 1.30                                   # bovenkant laadvloer
WAND = 0.55                                    # hoogte van de zijwanden

# ---------- chassis ----------
for sx in (-1, 1):
    box(f"Langsbalk{sx}", (0.14, 7.0, 0.24), DONKER, body, (sx * 0.5, -0.2, 0.86))
for y in (3.0, 1.4, -0.2, -1.8, -3.2):
    box(f"Dwarsbalk{y}", (1.0, 0.1, 0.16), DONKER, body, (0, y, 0.86))
for y in (Y_VOOR, Y_MID, Y_ACHTER):
    cyl(f"As{y}", 0.07, 0.07, 1.7, DONKER, "X", 8, body, (0, y, R_WIEL))
    cyl(f"Diff{y}", 0.2, 0.2, 0.28, DONKER, "Y", 10, body, (0.0, y, R_WIEL))
cyl("Cardan", 0.05, 0.05, 4.6, METAAL, "Y", 8, body, (0, 0.2, 0.6), rot=(0.05, 0, 0))
# bladveren boven de achterassen (zichtbaar tussen de wielen)
for sx in (-1, 1):
    for y in (Y_MID, Y_ACHTER):
        for k in range(3):
            box(f"Veer{sx}{y}{k}", (0.1, 1.0 - k * 0.22, 0.03), METAAL, body, (sx * 0.5, y, 0.70 + k * 0.035))

# ---------- neus: bumper, lier, grille, motorkap, spatborden ----------
box("Bumper", (2.45, 0.22, 0.3), CAMO, body, (0, 3.6, 0.78))
for sx in (-1, 1):
    box(f"Bumperstreep{sx}", (0.42, 0.005, 0.12), WIT, body, (sx * 0.85, 3.713, 0.80))
    cyl(f"Sleepoog{sx}", 0.07, 0.07, 0.05, METAAL, "Y", 10, body, (sx * 0.62, 3.73, 0.72))
    torus(f"Sleepring{sx}", 0.07, 0.022, METAAL, body, (sx * 0.62, 3.76, 0.63), (0, math.pi / 2, 0), 10)
# lier op de bumper
cyl("Lier", 0.16, 0.16, 0.8, DONKER, "X", 12, body, (0, 3.55, 1.08))
cyl("Lierkabel", 0.165, 0.165, 0.6, mat("Kabel", (0.25, 0.24, 0.22), 0.5, 0.7), "X", 12, body, (0, 3.55, 1.08))
for sx in (-1, 1):
    box(f"Lierplaat{sx}", (0.05, 0.3, 0.4), DONKER, body, (sx * 0.43, 3.55, 1.05))
# grille + koeler
box("Grillekast", (1.3, 0.12, 0.85), CAMO, body, (0, 3.36, 1.28))
for i in range(11):
    box(f"Grillestaaf{i}", (0.035, 0.05, 0.7), ZWART, body, (-0.5 + i * 0.1, 3.43, 1.28))
box("Grillerand", (1.36, 0.06, 0.07), DONKER, body, (0, 3.44, 1.72))
# beschermrooster (bull bar) voor de grille
for sx in (-1, 1):
    cyl(f"Bullstaaf{sx}", 0.035, 0.035, 0.85, METAAL, "Z", 8, body, (sx * 0.55, 3.62, 1.35))
cyl("Bulldwars", 0.035, 0.035, 1.12, METAAL, "X", 8, body, (0, 3.62, 1.75))
# motorkap, iets aflopend naar voren
kap = prism_x("Motorkap", [(1.95, 1.86), (3.36, 1.76), (3.36, 1.40), (1.95, 1.40)], 1.32, CAMO, body)
bevel(kap, 0.03)
box("Kapnaad", (0.02, 1.4, 0.012), DONKER, body, (0, 2.65, 1.82), (math.atan2(-0.1, 1.41), 0, 0))
for sx in (-1, 1):
    # luchtsleuven opzij in de motorkap
    for k in range(4):
        box(f"Kapsleuf{sx}{k}", (0.01, 0.07, 0.25), ZWART, body, (sx * 0.665, 2.4 + k * 0.14, 1.6))
    # brede vlakke spatborden
    sb = prism_x(f"Spatbord{sx}", [(1.75, 1.0), (1.95, 1.3), (3.35, 1.3), (3.35, 1.25), (1.98, 1.25), (1.8, 0.98)],
                 0.55, CAMO, body, (sx * 0.93, 0, 0))
    bevel(sb, 0.01)
    box(f"Spatlap{sx}", (0.5, 0.02, 0.45), BAND, body, (sx * 0.93, 1.8, 0.82))
    # koplamp in een kooi op het spatbord
    cyl(f"Lamphuis{sx}", 0.13, 0.13, 0.16, DONKER, "Y", 14, body, (sx * 0.9, 3.25, 1.45))
    cyl(f"Koplamp{sx}", 0.11, 0.11, 0.03, KOPLAMP, "Y", 14, body, (sx * 0.9, 3.34, 1.45))
    torus(f"Lampkooi{sx}", 0.14, 0.012, METAAL, body, (sx * 0.9, 3.37, 1.45), (math.pi / 2, 0, 0), 12)
    box(f"Lampkooih{sx}", (0.28, 0.012, 0.012), METAAL, body, (sx * 0.9, 3.37, 1.45))
    box(f"Lampkooiv{sx}", (0.012, 0.012, 0.28), METAAL, body, (sx * 0.9, 3.37, 1.45))
    box(f"Blackout{sx}", (0.09, 0.07, 0.06), METAAL, body, (sx * 1.08, 3.25, 1.34))
# zandzakken op de spatborden (bescherming tegen mijnen, maakt hem zwaar en stoer)
for sx in (-1, 1):
    for k, (y, rz) in enumerate(((2.25, 0.1), (2.75, -0.08), (3.15, 0.05))):
        z = sphere(f"Zandzak{sx}{k}", 0.2, ZAND, body, (sx * 0.94, y, 1.38), (1.15, 0.85, 0.42))
        z.rotation_euler = (0, 0, rz)
# witte ster op de motorkap
ster("Kapster", 0.28, WIT, body, (0, 2.7, 1.815 + 0.004), (math.atan2(-0.1, 1.41), 0, 0))

# ---------- cabine ----------
CAB_Y0, CAB_Y1 = 0.62, 1.95
box("Cabinevloer", (2.25, CAB_Y1 - CAB_Y0, 0.08), DONKER, body, (0, (CAB_Y0 + CAB_Y1) / 2, 1.1))
for sx in (-1, 1):
    deur = prism_x(f"Deur{sx}", [(CAB_Y0, 1.06), (CAB_Y1, 1.06), (CAB_Y1, 1.95), (CAB_Y0, 1.95)], 0.06, CAMO, body,
                   (sx * 1.1, 0, 0))
    bevel(deur, 0.01)
    box(f"Deurraam{sx}", (0.065, 0.75, 0.48), GLAS, body, (sx * 1.1, 1.32, 2.2))
    box(f"Deurstijl{sx}", (0.07, 0.08, 0.6), CAMO, body, (sx * 1.1, CAB_Y0 + 0.04, 2.22))
    box(f"Deurgreep{sx}", (0.03, 0.14, 0.03), METAAL, body, (sx * 1.14, 0.85, 1.75))
    ster(f"Deurster{sx}", 0.2, WIT, body, (sx * 1.133, 1.28, 1.5), (0, sx * math.pi / 2, 0))
    # opstapjes onder de deur
    box(f"Opstap{sx}", (0.3, 0.45, 0.04), METAAL, body, (sx * 1.0, 1.25, 0.72))
    # spiegels aan armen
    cyl(f"Spiegelarm{sx}", 0.015, 0.015, 0.4, METAAL, "X", 6, body, (sx * 1.3, 1.85, 2.15))
    box(f"Spiegel{sx}", (0.04, 0.2, 0.32), ZWART, body, (sx * 1.5, 1.85, 2.15))
# achterwand met klein raampje
box("Cabineachter", (2.25, 0.06, 1.55), CAMO, body, (0, CAB_Y0, 1.85))
box("Achterraam", (0.8, 0.065, 0.3), GLAS, body, (0, CAB_Y0, 2.25))
# schuine voorruit in twee delen
VR = math.radians(10)
for sx in (-1, 1):
    box(f"Voorruit{sx}", (1.0, 0.03, 0.62), GLAS, body, (sx * 0.53, CAB_Y1 + 0.02, 2.24), (-VR, 0, 0))
box("Ruitstijl", (0.07, 0.07, 0.66), CAMO, body, (0, CAB_Y1 + 0.02, 2.24), (-VR, 0, 0))
for sx in (-1, 1):
    box(f"Astijl{sx}", (0.08, 0.08, 0.68), CAMO, body, (sx * 1.09, CAB_Y1 + 0.02, 2.24), (-VR, 0, 0))
box("Ruitonder", (2.25, 0.1, 0.12), CAMO, body, (0, CAB_Y1 + 0.03, 1.92))
# ruitenwissers
for sx in (-1, 1):
    box(f"Wisser{sx}", (0.45, 0.02, 0.02), ZWART, body, (sx * 0.55, CAB_Y1 + 0.06, 1.99), (0, 0, sx * 0.25))
# dak met luik en ringaffuit (vanaf de spelcamera goed te zien)
dak = box("Dak", (2.3, CAB_Y1 - CAB_Y0 + 0.12, 0.08), CAMO, body, (0, (CAB_Y0 + CAB_Y1) / 2 + 0.02, 2.58))
bevel(dak, 0.03)
for k in range(3):
    box(f"Dakrib{k}", (2.1, 0.05, 0.02), DONKER, body, (0, 0.85 + k * 0.4, 2.63))
torus("Ring", 0.5, 0.045, DONKER, body, (0.35, 1.3, 2.78), segs=20)
for a in range(4):
    ang = a * math.pi / 2 + math.pi / 4
    cyl(f"Ringpoot{a}", 0.025, 0.025, 0.18, DONKER, "Z", 6, body,
        (0.35 + math.cos(ang) * 0.5, 1.3 + math.sin(ang) * 0.5, 2.7))
# M2 op de ring (vast, wijst vooruit)
cyl("RingMGloop", 0.03, 0.03, 1.0, ZWART, "Y", 8, body, (0.35, 2.0, 2.98))
cyl("RingMGmantel", 0.05, 0.05, 0.4, ZWART, "Y", 8, body, (0.35, 1.7, 2.98))
box("RingMGkast", (0.14, 0.6, 0.18), ZWART, body, (0.35, 1.25, 2.96))
box("RingMGband", (0.16, 0.24, 0.2), CAMO, body, (0.2, 1.25, 2.92))
box("RingMGwieg", (0.12, 0.3, 0.12), DONKER, body, (0.35, 1.3, 2.83))
# uitlaatpijp rechts achter de cabine, met hitteschild
cyl("Uitlaatpijp", 0.07, 0.07, 2.1, ZWART, "Z", 10, body, (1.0, 0.52, 1.95))
cyl("Uitlaatschild", 0.1, 0.1, 0.9, METAAL, "Z", 10, body, (1.0, 0.52, 1.9))
cyl("Uitlaatbocht", 0.07, 0.07, 0.2, ZWART, "Y", 10, body, (1.0, 0.45, 3.02), rot=(math.radians(-30), 0, 0))
uitlaat = empty("Uitlaat", body, (1.0, 0.4, 3.08))
LOS.add("Uitlaat")
# antennes op de cabinehoeken
for sx in (-1, 1):
    cyl(f"Antennevoet{sx}", 0.04, 0.04, 0.12, DONKER, "Z", 8, body, (sx * 1.05, 0.7, 2.68))
    cyl(f"Antenne{sx}", 0.012, 0.005, 2.6, ZWART, "Z", 5, body, (sx * 1.05, 0.55, 3.9), smooth=False,
        rot=(math.radians(-8), 0, 0))
# brandstoftank links en gereedschapskist rechts onder de cabine
cyl("Tank", 0.28, 0.28, 1.1, CAMO, "Y", 14, body, (-1.0, 1.0, 0.75))
for y in (0.6, 1.4):
    cyl(f"Tankband{y}", 0.29, 0.29, 0.04, RIEM, "Y", 14, body, (-1.0, y, 0.75))
cyl("Tankdop", 0.06, 0.06, 0.06, METAAL, "Z", 8, body, (-1.0, 1.2, 1.05))
box("Gereedschapskist", (0.4, 0.9, 0.42), CAMO, body, (1.0, 1.05, 0.78))
box("Kistslot", (0.04, 0.12, 0.08), METAAL, body, (1.21, 1.05, 0.9))

# ---------- bestuurder (zittend, links) ----------
bestuurder, bd, tz = soldaat("Bestuurder", body, True)
bestuurder.location = (-0.5, 1.15, 1.55)
bl, bld = bovenlijf("BestuurderBoven", bestuurder, tz, math.radians(-6),
                    [(-1, (-0.15, 0.42, 0.5)), (1, (0.15, 0.42, 0.5))])
box("Bestuurderstoel", (0.5, 0.5, 0.1), CANVAS, body, (-0.5, 1.15, 1.5))
box("Bestuurderrug", (0.5, 0.08, 0.6), CANVAS, body, (-0.5, 0.82, 1.82))
box("Bijrijderstoel", (0.9, 0.5, 0.1), CANVAS, body, (0.45, 1.15, 1.5))
cyl("Stuurkolom", 0.03, 0.03, 0.6, ZWART, "Y", 8, body, (-0.5, 1.68, 1.95), rot=(math.radians(-50), 0, 0))
torus("Stuurwiel", 0.22, 0.02, ZWART, body, (-0.5, 1.52, 2.1), (math.radians(40), 0, 0), 16)
box("Dashboard", (2.1, 0.2, 0.15), DONKER, body, (0, 1.85, 1.95))

# ---------- reservewiel tussen cabine en laadbak ----------
cyl("Reservewiel", R_WIEL, R_WIEL, 0.3, BAND, "Y", 18, body, (-0.45, 0.53, 1.85))
cyl("Reservevelg", 0.3, 0.3, 0.32, CAMO, "Y", 10, body, (-0.45, 0.53, 1.85))

# ---------- laadbak ----------
box("Laadvloer", (BAK_X * 2, BAK_Y1 - BAK_Y0, 0.08), PLAAT, body, (0, (BAK_Y0 + BAK_Y1) / 2, VLOER - 0.04))
for k in range(9):
    x = -1.0 + k * 0.25
    box(f"Vloerlat{k}", (0.05, BAK_Y1 - BAK_Y0 - 0.1, 0.012), DONKER, body, (x, (BAK_Y0 + BAK_Y1) / 2, VLOER + 0.005))
box("Laadbakbalk", (BAK_X * 2, BAK_Y1 - BAK_Y0, 0.14), DONKER, body, (0, (BAK_Y0 + BAK_Y1) / 2, VLOER - 0.15))
for sx in (-1, 1):
    wand = box(f"Zijwand{sx}", (0.06, BAK_Y1 - BAK_Y0, WAND), CAMO, body, (sx * BAK_X, (BAK_Y0 + BAK_Y1) / 2, VLOER + WAND / 2))
    bevel(wand, 0.01)
    # verticale rongen buiten op de wand
    for k in range(6):
        y = BAK_Y0 + 0.2 + k * (BAK_Y1 - BAK_Y0 - 0.4) / 5
        box(f"Rong{sx}{k}", (0.05, 0.08, WAND + 0.06), DONKER, body, (sx * (BAK_X + 0.04), y, VLOER + WAND / 2))
    box(f"Wandrand{sx}", (0.1, BAK_Y1 - BAK_Y0, 0.05), DONKER, body, (sx * BAK_X, (BAK_Y0 + BAK_Y1) / 2, VLOER + WAND))
    # spatborden boven de achterwielen
    sbr = box(f"Spatbordachter{sx}", (0.55, 2.4, 0.05), CAMO, body, (sx * SPOOR_A, (Y_MID + Y_ACHTER) / 2, 1.12))
    bevel(sbr, 0.01)
    box(f"Spatlapachter{sx}", (0.55, 0.02, 0.4), BAND, body, (sx * SPOOR_A, Y_ACHTER - 1.2, 0.85))
    # jerrycans in een rek langs de bak
    for k, y in enumerate((-0.35, -0.6)):
        box(f"Can{sx}{k}", (0.13, 0.22, 0.4), CAMO, body, (sx * (BAK_X + 0.12), y, 0.95))
        cyl(f"Candop{sx}{k}", 0.025, 0.025, 0.04, METAAL, "Z", 6, body, (sx * (BAK_X + 0.12), y + 0.06, 1.17))
    box(f"Canriem{sx}", (0.15, 0.6, 0.04), RIEM, body, (sx * (BAK_X + 0.12), -0.48, 1.05))
box("Voorwand", (BAK_X * 2, 0.06, WAND + 0.3), CAMO, body, (0, BAK_Y1, VLOER + (WAND + 0.3) / 2))
# banken langs beide wanden, met rugleuning van latten
for sx in (-1, 1):
    bx = sx * 0.98
    box(f"Bankzitting{sx}", (0.36, 3.75, 0.06), HOUT, body, (bx, -1.6, VLOER + 0.47))
    for k in range(6):
        y = BAK_Y0 + 0.35 + k * 0.7
        box(f"Bankpoot{sx}{k}", (0.04, 0.04, 0.45), METAAL, body, (sx * 0.85, y, VLOER + 0.225))
    for z in (0.65, 0.85):
        box(f"Banklat{sx}{z}", (0.03, 3.75, 0.09), HOUT, body, (sx * (BAK_X - 0.05), -1.6, VLOER + z))
# munitiekisten en een rugzak voorin de bak, tussen de banken
box("Laadkist", (0.6, 0.4, 0.3), CAMO, body, (0, 0.15, VLOER + 0.15))
box("Laadkistdeksel", (0.58, 0.38, 0.015), DONKER, body, (0, 0.15, VLOER + 0.31))
box("Laadkiststempel", (0.25, 0.08, 0.005), WIT, body, (0, 0.1, VLOER + 0.32))

# spanten (hoepels) over de laadbak en het opgerolde zeil
SPANT_Z = VLOER + WAND        # voet van de spanten
SPANT_H = 1.25                # hoogte van de rechte poten
SPANT_YS = [BAK_Y1 - 0.12, -0.6, -1.65, -2.7, BAK_Y0 + 0.1]
for i, y in enumerate(SPANT_YS):
    for sx in (-1, 1):
        cyl(f"Spantpoot{i}{sx}", 0.03, 0.03, SPANT_H, DONKER, "Z", 6, body, (sx * (BAK_X - 0.02), y, SPANT_Z + SPANT_H / 2))
    # gebogen bovenkant: halve torus
    bpy.ops.mesh.primitive_torus_add(major_radius=BAK_X - 0.02, minor_radius=0.03, major_segments=16, minor_segments=5,
                                     location=(0, y, SPANT_Z + SPANT_H), rotation=(math.pi / 2, 0, 0))
    sp = bpy.context.active_object
    sp.name = f"Spantboog{i}"
    for c in sp.users_collection:
        c.objects.unlink(sp)
    link(sp, body)
    sp.data.materials.append(DONKER)
    sp.scale = (1, 0.35, 1)  # platter boog
    bm = bmesh.new()
    bm.from_mesh(sp.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.01], context="VERTS")
    bm.to_mesh(sp.data)
    bm.free()
# langsliggers over de spanten
for x in (-0.6, 0.0, 0.6):
    zt = SPANT_Z + SPANT_H + math.sqrt(max(0.0, (BAK_X - 0.02) ** 2 - x * x)) * 0.35
    cyl(f"Ligger{x}", 0.02, 0.02, BAK_Y1 - BAK_Y0, DONKER, "Y", 6, body, (x, (BAK_Y0 + BAK_Y1) / 2, zt))
# zeil: dak en zijkanten rollen op en af (clips ZeilDicht en ZeilOpen). In rust is het zeil opgerold: het dak
# als rol tegen de voorkant, de zijkanten als rollen bovenaan. Dicht hangen de zijkanten tot op de wand.
DAK_Z = SPANT_Z + SPANT_H
ZR = BAK_X + 0.04            # straal van het zeil over de spanten (horizontaal)
ZEIL_L = BAK_Y1 - BAK_Y0 + 0.04
ZIJ_H = SPANT_H + WAND * 0.35  # hoogte van een zijflap (hangt over de bovenrand van de wand)
zeil = empty("Zeil", body)
LOS.add("Zeil")
# dak: boog over de spanten; draaipunt aan de voorkant, schaal Y 0..1 rolt hem uit naar achteren
dak = empty("ZeilDak", zeil, (0, BAK_Y1 + 0.02, 0))
LOS.add("ZeilDak")
bm = bmesh.new()
voor, achter = [], []
for k in range(13):
    an = math.pi * k / 12
    x, z = math.cos(an) * ZR, DAK_Z + math.sin(an) * ZR * 0.35 + 0.03
    voor.append(bm.verts.new((x, 0, z)))
    achter.append(bm.verts.new((x, -ZEIL_L, z)))
for i in range(12):
    bm.faces.new([voor[i], voor[i + 1], achter[i + 1], achter[i]])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    if f.normal.z < 0:
        f.normal_flip()
dakmesh = mesh_obj("ZeilDakMesh", bm, CANVAS, dak)
LOS.add("ZeilDakMesh")
# rol aan de achterrand van het dak: een dikke boog van zeil met drie riemen
rol = empty("RolDak", zeil, (0, BAK_Y1 - 0.1, 0))
LOS.add("RolDak")
bpy.ops.mesh.primitive_torus_add(major_radius=ZR + 0.05, minor_radius=0.15, major_segments=16, minor_segments=8,
                                 location=(0, 0, DAK_Z + 0.03), rotation=(math.pi / 2, 0, 0))
rd = bpy.context.active_object
for c in rd.users_collection:
    c.objects.unlink(rd)
link(rd, rol)
rd.data.materials.append(CANVAS)
rd.scale = (1, 0.35, 1)
bm = bmesh.new()
bm.from_mesh(rd.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.05], context="VERTS")
bm.to_mesh(rd.data)
bm.free()
for p_ in rd.data.polygons:
    p_.use_smooth = True
rdl = [rd]
for x in (-0.75, 0.0, 0.75):
    zz = DAK_Z + 0.03 + math.sqrt(max(0.0, (ZR + 0.05) ** 2 - x * x)) * 0.35
    rdl.append(box(f"Rolriem{x}", (0.06, 0.34, 0.34), RIEM, rol, (x, 0, zz), (math.atan2(-x * 0.35, (ZR + 0.05)) if False else 0, 0, 0)))
rolmesh = join(rd, rdl[1:])
rolmesh.name = "RolDakMesh"
LOS.add("RolDakMesh")
# zijflappen: draaipunt bovenaan, schaal Z 0..1 laat ze zakken; de rol zit aan de onderrand
for sx, kant in ((-1, "L"), (1, "R")):
    zij = empty("Zeil" + kant, zeil, (sx * (BAK_X + 0.04), (BAK_Y0 + BAK_Y1) / 2, DAK_Z + 0.03))
    LOS.add(zij.name)
    m = box("Zeil" + kant + "Mesh", (0.02, ZEIL_L, ZIJ_H), CANVAS, zij, (0, 0, -ZIJ_H / 2))
    LOS.add(m.name)
    r = empty("Rol" + kant, zeil, (sx * (BAK_X + 0.1), (BAK_Y0 + BAK_Y1) / 2, DAK_Z - 0.06))
    LOS.add(r.name)
    rl = [cyl("Rol" + kant + "Mesh", 0.12, 0.12, ZEIL_L - 0.1, CANVAS, "Y", 10, r)]
    for y in (-1.3, 0.0, 1.3):
        rl.append(cyl(f"Rol{kant}riem{y}", 0.128, 0.128, 0.06, RIEM, "Y", 10, r, (0, y, 0)))
    rm = join(rl[0], rl[1:])
    rm.name = "Rol" + kant + "Mesh"
    LOS.add(rm.name)
ZEIL_DELEN = dict(dak=dak, rol=rol, L=bpy.data.objects["ZeilL"], R=bpy.data.objects["ZeilR"],
                  rolL=bpy.data.objects["RolL"], rolR=bpy.data.objects["RolR"])
DAK_REST = 0.02  # opgerold: het dak is bijna nul lang
dak.scale = (1, DAK_REST, 1)
for k in ("L", "R"):
    ZEIL_DELEN[k].scale = (1, 1, 0.02)

# achterkant: achterlichten en bumper laag onder de klep (die hangt open tot 0,75 m), trekhaak opzij
for sx in (-1, 1):
    box(f"Achterlicht{sx}", (0.14, 0.04, 0.1), ACHTERLICHT, body, (sx * 1.0, BAK_Y0 - 0.02, 0.62))
    box(f"Lichtbak{sx}", (0.2, 0.1, 0.16), DONKER, body, (sx * 1.0, BAK_Y0 + 0.04, 0.62))
box("Achterbumper", (1.7, 0.12, 0.12), DONKER, body, (0, BAK_Y0 + 0.08, 0.6))
cyl("Trekhaak", 0.05, 0.05, 0.2, METAAL, "Y", 8, body, (0.6, BAK_Y0 - 0.05, 0.5))
box("Achternummer", (0.4, 0.005, 0.1), WIT, body, (-0.45, BAK_Y0 + 0.018, 0.6))

# ---------- laadklep met trapje ----------
klep = empty("Klep", body, (0, BAK_Y0, VLOER))
LOS.add("Klep")
kd = [box("KlepPlaat", (BAK_X * 2 - 0.04, 0.06, WAND), CAMO, klep, (0, 0.03, WAND / 2))]
for x in (-0.9, -0.3, 0.3, 0.9):
    kd.append(box(f"KlepRib{x}", (0.06, 0.04, WAND), DONKER, klep, (x, 0.07, WAND / 2)))
kd.append(box("KlepRand", (BAK_X * 2 - 0.04, 0.08, 0.05), DONKER, klep, (0, 0.03, WAND)))
for sx in (-1, 1):
    kd.append(cyl(f"Scharnier{sx}", 0.04, 0.04, 0.16, METAAL, "X", 8, klep, (sx * 0.8, 0.03, 0)))
    kd.append(box(f"Klepketting{sx}", (0.02, 0.02, 0.3), METAAL, klep, (sx * 1.15, 0.06, WAND - 0.15)))
kd.append(box("KlepNummer", (0.5, 0.005, 0.12), WIT, klep, (0, -0.001, WAND * 0.55)))
klepmesh = join(kd[0], kd[1:])
klepmesh.name = "KlepMesh"
LOS.add("KlepMesh")
# trapje: scharniert aan de bovenrand van de klep; dicht ligt het dubbelgevouwen tegen de binnenkant.
# Open hangt de klep naar beneden en het trapje eronder tot vlak boven de grond.
TRAP_L = 0.7
trap = empty("Trap", klep, (0, 0.2, WAND))
LOS.add("Trap")
td = []
for sx in (-1, 1):
    td.append(box(f"Trapboom{sx}", (0.05, 0.04, TRAP_L), METAAL, trap, (sx * 0.28, 0, TRAP_L / 2)))
for k in range(4):
    td.append(box(f"Trede{k}", (0.56, 0.07, 0.035), METAAL, trap, (0, 0, 0.1 + k * 0.2)))
trapmesh = join(td[0], td[1:])
trapmesh.name = "TrapMesh"
LOS.add("TrapMesh")
KLEP_OPEN = math.pi           # klep hangt recht naar beneden
TRAP_DICHT = math.pi          # trapje dubbelgevouwen tegen de klep
trap.rotation_euler = (TRAP_DICHT, 0, 0)

# plekken voor de soldaten: oorsprong van het mannetje (0,44 m onder de vloer, zodat hij op de bank zit)
for i in range(10):
    sx = -1 if i < 5 else 1
    y = 0.0 - (i % 5) * 0.75
    z = empty(f"Zit{i}", body, (sx * 1.0, y, VLOER - 0.44))
    LOS.add(z.name)
# waar een soldaat achter de wagen staat om in te klimmen (vlak voor het trapje)
LOS.add(empty("Instap", body, (0, BAK_Y0 - 0.75, 0)).name)

# ---------- wielen: voorwielen in een stuurknoop (yaw), wiel zelf draait om X ----------
WIELEN = {}


def band(naam, parent, breedte, x=0.0):
    w = cyl(naam, R_WIEL, R_WIEL, breedte, BAND, "X", 20, parent, (x, 0, 0))
    delen = []
    # grove noppen (terreinbanden), zichtbaar draaien
    for k in range(18):
        a = k * math.tau / 18
        n = box(naam + f"nop{k}", (breedte * 0.9, 0.1, 0.05), BAND, parent, (x, math.cos(a) * R_WIEL, math.sin(a) * R_WIEL))
        n.rotation_euler = (a + math.pi / 2, 0, (0.25 if k % 2 else -0.25))
        delen.append(n)
    return join(w, delen)


def wiel(naam, parent, sx, dubbel):
    if dubbel:
        a = band(naam, parent, 0.27, -0.15)
        b = band(naam + "b", parent, 0.27, 0.15)
        w = join(a, [b])
        velg_x = sx * 0.15
    else:
        w = band(naam, parent, 0.34)
        velg_x = 0.0
    delen = [cyl(naam + "velg", 0.3, 0.3, 0.02, CAMO, "X", 12, parent, (velg_x + sx * (0.14 if not dubbel else 0.14), 0, 0)),
             cyl(naam + "naaf", 0.11, 0.09, 0.08, METAAL, "X", 8, parent, (velg_x + sx * 0.17, 0, 0))]
    for k in range(8):
        a = k * math.tau / 8
        delen.append(cyl(naam + f"moer{k}", 0.022, 0.022, 0.05, METAAL, "X", 6, parent,
                         (velg_x + sx * 0.16, math.cos(a) * 0.19, math.sin(a) * 0.19)))
    w = join(w, delen)
    w.name = naam
    WIELEN[naam] = w
    LOS.add(naam)
    return w


stuur_l = empty("StuurLV", body, (-SPOOR_V, Y_VOOR, R_WIEL))
stuur_r = empty("StuurRV", body, (SPOOR_V, Y_VOOR, R_WIEL))
LOS.update({"StuurLV", "StuurRV"})
for naam, st in (("WielLV", stuur_l), ("WielRV", stuur_r)):
    hub = empty(naam + "_tmp", None)
    w = wiel(naam, None, -1 if naam == "WielLV" else 1, False)
    bpy.data.objects.remove(hub)
    w.parent = st
    w.location = (0, 0, 0)
for naam, sx, y in (("WielLM", -1, Y_MID), ("WielRM", 1, Y_MID), ("WielLA", -1, Y_ACHTER), ("WielRA", 1, Y_ACHTER)):
    w = wiel(naam, None, sx, True)
    w.parent = body
    w.location = (sx * SPOOR_A, y, R_WIEL)

# ---------- lampen voor het spel (KHR_lights_punctual) ----------
for sx in (-1, 1):
    sp = bpy.data.lights.new(f"Koplamp{'L' if sx < 0 else 'R'}", "SPOT")
    sp.energy = 7.0  # export in RAW-modus: dit is direct de lichtsterkte in Godot
    sp.spot_size = math.radians(55)
    sp.spot_blend = 0.5
    sp.color = (1.0, 0.95, 0.82)
    o = link(bpy.data.objects.new(sp.name, sp), body)
    o.location = (sx * 0.9, 3.4, 1.45)
    o.rotation_euler = (math.radians(80), 0, 0)
    LOS.add(o.name)
    pl = bpy.data.lights.new(f"Achterlicht{'L' if sx < 0 else 'R'}", "POINT")
    pl.energy = 0.8
    pl.color = (1.0, 0.1, 0.05)
    pl.shadow_soft_size = 0.05
    o = link(bpy.data.objects.new(pl.name + "Lamp", pl), body)
    o.location = (sx * 1.0, BAK_Y0 - 0.15, 0.62)
    LOS.add(o.name)

# ---------- UV's, samenvoegen ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH":
        me = o.data
        mw = o.matrix_world
        uvl = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
        for poly in me.polygons:
            n = mw.to_3x3() @ poly.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for li in poly.loop_indices:
                c = mw @ me.vertices[me.loops[li].vertex_index].co
                u, v = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
                uvl.data[li].uv = (u / 1.6, v / 1.6)
for o in scene.objects:
    o.select_set(o.type == "MESH")
romp = bpy.data.objects["Langsbalk-1"]
bpy.context.view_layer.objects.active = romp
bpy.ops.object.convert(target="MESH")


def alle_kinderen(o):
    for c in o.children:
        yield c
        if c.name not in LOS:
            yield from alle_kinderen(c)


delen = [o for o in alle_kinderen(body) if o.type == "MESH" and o.name not in LOS]
join(romp, [d for d in delen if d != romp])
romp.name = romp.data.name = "RompMesh"
bpy.ops.object.select_all(action="DESELECT")
romp.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.images["vrachtwagen_olijf"].pack()

# ---------- animaties: Open en Dicht ----------
FPS = 30
scene.render.fps = FPS


def ease(t):
    return t * t * (3 - 2 * t)


def stuiter(t):
    """Klep valt naar beneden en veert twee keer na tegen de kettingen."""
    if t < 0.7:
        return ease(t / 0.7)
    u = (t - 0.7) / 0.3
    return 1.0 + 0.06 * math.sin(u * math.pi * 2) * (1 - u)


def clip(naam, duur, zet):
    """zet(t) zet de delen voor moment t (0..1); daarna wordt alles van elk deel gekeyd."""
    frames = int(round(duur * FPS))
    delen = [klep, trap] + list(ZEIL_DELEN.values())
    for o in delen:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    basis = {o: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in delen}
    for f in range(frames + 1):
        for o in delen:
            o.location, o.rotation_euler, o.scale = basis[o]
        zet(f / frames)
        for o in delen:
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in delen:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
        o.location, o.rotation_euler, o.scale = basis[o]


def klep_open(t):
    """Klep valt in 0,55 s naar beneden en veert na tegen de kettingen; daarna klapt het trapje uit."""
    k = stuiter(min(1.0, t / 0.75))
    klep.rotation_euler = (KLEP_OPEN * k, 0, 0)
    trap.rotation_euler = (TRAP_DICHT * (1 - ease(min(1.0, max(0.0, (t - 0.55) / 0.45)))), 0, 0)


def klep_dicht(t):
    trap.rotation_euler = (TRAP_DICHT * ease(min(1.0, t / 0.4)), 0, 0)
    klep.rotation_euler = (KLEP_OPEN * (1 - ease(min(1.0, max(0.0, (t - 0.35) / 0.65)))), 0, 0)


def zeil(d):
    """d = 0 opgerold, 1 dicht. Eerst zakken de zijflappen, dan rolt het dak naar achteren uit."""
    zij = ease(min(1.0, d / 0.55))
    dk = ease(min(1.0, max(0.0, (d - 0.35) / 0.65)))
    for k, sx in (("L", -1), ("R", 1)):
        ZEIL_DELEN[k].scale = (1, 1, max(0.02, zij))
        r = ZEIL_DELEN["rol" + k]
        r.location.z = DAK_Z - 0.06 - zij * (ZIJ_H - 0.05)
        r.rotation_euler = (0, -sx * zij * 9.0, 0)  # rol draait mee terwijl hij afrolt
    ZEIL_DELEN["dak"].scale = (1, max(DAK_REST, dk), 1)
    ZEIL_DELEN["rol"].location.y = BAK_Y1 - 0.1 - dk * (ZEIL_L - 0.12)


clip("Open", 1.2, klep_open)
clip("Dicht", 1.0, klep_dicht)
clip("ZeilDicht", 1.8, lambda t: zeil(t))
clip("ZeilOpen", 1.8, lambda t: zeil(1 - t))

scene.frame_start, scene.frame_end = 0, 54
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "vrachtwagen.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "vrachtwagen.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)
