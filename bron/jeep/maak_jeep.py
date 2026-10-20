"""Legerjeep (Willys-stijl) met .50 MG op een paal, een staande schutter en een bestuurder, voor Bloedjungle.
Blender +Y = voorkant (wordt -Z in Godot), Z omhoog, 1 eenheid = 1 meter.
Gebruik: python3 maak_jeep.py <uitmap>  ->  jeep.glb, jeep.blend, jeep_olijf.png

Hiërarchie:
  Jeep > Body > RompMesh, Bestuurder,
                StuurLV > WielLV, StuurRV > WielRV, WielLA, WielRA,
                Koplamp L/R (spotlampen), Achterlicht L/R (puntlampen),
                Geschut (draait om Z) > MG (terugslag) > Monding, Vlam, Hulzen;
                                        Schutter > Bovenlijf
Animaties (clips): Stationair, Rijden, Achteruit, Bocht, Remmen, Vuren, Rondkijken."""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materialen ----------
def od_image(size=256):
    rng = np.random.default_rng(5)
    def noise(scale):
        g = rng.random((size // scale + 2, size // scale + 2))
        y, x = np.mgrid[0:size, 0:size] / scale
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
        b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
        return a * (1 - fy) + b * fy
    base = np.array([0.29, 0.31, 0.19])  # olive drab
    n = noise(40) * 0.55 + noise(14) * 0.3 + noise(4) * 0.15
    img = base[None, None, :] * (0.84 + 0.3 * n[..., None])
    modder = np.clip((noise(24) - 0.62) * 3.0, 0, 1)[..., None]
    img = img * (1 - 0.35 * modder) + np.array([0.33, 0.27, 0.18]) * 0.35 * modder
    img = np.clip(img + (noise(2)[..., None] - 0.5) * 0.04, 0, 1)
    im = bpy.data.images.new("jeep_olijf", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, "jeep_olijf.png")
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


LOS = set()  # namen van bewegende delen die niet met de romp samengevoegd worden

root = empty("Jeep")
body = empty("Body", root)

# ---------- carrosserie ----------
# bak: open kuip met bodem en wanden, achterkant recht, zijkant met instapuitsparing
W, YA, YV = 1.26, -1.62, 0.62
box("Bodem", (W, YV - YA, 0.05), OLIJF, body, (0, (YA + YV) / 2, 0.47))
for sx in (-1, 1):
    zij = prism_x(f"Zijwand{sx}", [(YA, 0.42), (YV, 0.42), (YV, 0.98), (0.1, 0.98), (-0.05, 0.78), (-0.55, 0.78),
                                   (-0.7, 0.98), (YA, 0.98)], 0.04, OLIJF, body, (sx * W / 2, 0, 0))
    bevel(zij, 0.01)
    # achterspatbord / wielkast in de bak
    box(f"Wielkast{sx}", (0.26, 0.85, 0.3), OLIJF, body, (sx * (W / 2 - 0.13), -1.05, 0.62))
achter = box("Achterwand", (W, 0.04, 0.56), OLIJF, body, (0, YA, 0.70))
box("Schutbord", (W, 0.04, 0.5), OLIJF, body, (0, YV, 0.73))
# motorkap, iets aflopend naar voren
kap = prism_x("Motorkap", [(YV, 0.98), (1.62, 0.93), (1.62, 0.70), (YV, 0.70)], 1.02, OLIJF, body)
bevel(kap, 0.02)
box("Kapnaad", (0.02, 1.0, 0.012), DONKER, body, (0, 1.12, 0.965))
for sx in (-1, 1):
    box(f"Kapgreep{sx}", (0.04, 0.12, 0.03), METAAL, body, (sx * 0.52, 1.2, 0.86))
# grille met de negen verticale sleuven en twee koplampen
grille = box("Grille", (1.0, 0.05, 0.56), OLIJF, body, (0, 1.65, 0.67))
for i in range(9):
    box(f"Sleuf{i}", (0.045, 0.06, 0.34), ZWART, body, (-0.24 + i * 0.06, 1.655, 0.66))
for sx in (-1, 1):
    cyl(f"Lampring{sx}", 0.1, 0.1, 0.05, METAAL, "Y", 14, body, (sx * 0.36, 1.675, 0.77))
    cyl(f"Koplamp{sx}", 0.085, 0.085, 0.03, KOPLAMP, "Y", 14, body, (sx * 0.36, 1.70, 0.77))
    # verduisteringslampje (blackout) op het spatbord
    box(f"Blackout{sx}", (0.07, 0.06, 0.05), METAAL, body, (sx * 0.62, 1.55, 0.94))
# voorspatborden: plat met afgeschuinde achterkant
for sx in (-1, 1):
    sb = prism_x(f"Spatbord{sx}", [(0.45, 0.66), (0.7, 0.9), (1.78, 0.9), (1.78, 0.86), (0.72, 0.86), (0.48, 0.63)],
                 0.34, OLIJF, body, (sx * 0.67, 0, 0))
    bevel(sb, 0.01)
# bumper met sleephaken
box("Bumper", (1.55, 0.1, 0.13), OLIJF, body, (0, 1.82, 0.47))
for sx in (-1, 1):
    box(f"Chassisbalk{sx}", (0.08, 3.4, 0.12), DONKER, body, (sx * 0.42, 0.1, 0.38))
    cyl(f"Sleephaak{sx}", 0.04, 0.04, 0.08, METAAL, "X", 8, body, (sx * 0.5, 1.88, 0.42))
box("Achterbumper", (1.2, 0.08, 0.1), DONKER, body, (0, YA - 0.06, 0.44))
# voorruit plat naar voren geklapt op de motorkap
for sx in (-1, 1):
    box(f"Ruitframe{sx}", (0.04, 0.42, 0.03), DONKER, body, (sx * 0.6, 0.86, 1.0))
box("RuitframeV", (1.24, 0.04, 0.03), DONKER, body, (0, 1.06, 1.0))
box("RuitframeA", (1.24, 0.04, 0.03), DONKER, body, (0, 0.66, 1.0))
box("Ruit", (1.18, 0.38, 0.01), mat("Glas", (0.15, 0.18, 0.18), 0.05, 0.4), body, (0, 0.86, 1.0))
# achterlichten
for sx in (-1, 1):
    box(f"Achterlicht{sx}", (0.08, 0.03, 0.06), ACHTERLICHT, body, (sx * 0.52, YA - 0.025, 0.86))
# reservewiel en jerrycan achterop
cyl("Reservewiel", 0.34, 0.34, 0.17, BAND, "Y", 16, body, (0.25, YA - 0.12, 0.74))
cyl("Reservevelg", 0.2, 0.2, 0.19, OLIJF, "Y", 10, body, (0.25, YA - 0.12, 0.74))
box("Jerrycan", (0.17, 0.12, 0.4), OLIJF, body, (-0.38, YA - 0.08, 0.78))
# stoelen voor
for sx in (-1, 1):
    box(f"Zitting{sx}", (0.42, 0.42, 0.08), CANVAS, body, (sx * 0.3, 0.05, 0.62))
    box(f"Rugleuning{sx}", (0.42, 0.07, 0.42), CANVAS, body, (sx * 0.3, -0.17, 0.85), (math.radians(-10), 0, 0))
# stuur en stuurkolom (links)
cyl("Stuurkolom", 0.025, 0.025, 0.55, ZWART, "Y", 8, body, (-0.3, 0.48, 0.86), rot=(math.radians(-40), 0, 0))
stuur = bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.018, major_segments=16, minor_segments=6,
                                         location=(-0.3, 0.3, 1.02), rotation=(math.radians(55), 0, 0))
stuurwiel = bpy.context.active_object
stuurwiel.name = "Stuurwiel"
for c in stuurwiel.users_collection:
    c.objects.unlink(stuurwiel)
link(stuurwiel, body)
stuurwiel.data.materials.append(ZWART)
# munitiekisten in de bak
for i, y in enumerate((-1.35, -1.35)):
    box(f"Munitiekist{i}", (0.18, 0.3, 0.2), OLIJF, body, (-0.42 + i * 0.84, y, 0.6))
# assen
cyl("Vooras", 0.05, 0.05, 1.3, DONKER, "X", 8, body, (0, 1.12, 0.37))
cyl("Achteras", 0.05, 0.05, 1.3, DONKER, "X", 8, body, (0, -0.92, 0.37))
cyl("Differentieel", 0.12, 0.12, 0.16, DONKER, "Y", 10, body, (0.1, -0.92, 0.37))
# antenne achter
cyl("Antenne", 0.012, 0.006, 2.2, ZWART, "Z", 5, body, (-0.6, YA + 0.05, 2.0), smooth=False,
    rot=(math.radians(-8), 0, 0))
cyl("Antennevoet", 0.04, 0.04, 0.2, DONKER, "Z", 8, body, (-0.6, YA + 0.03, 0.95))

# ---------- wielen: voorwielen in een stuurknoop (yaw), wiel zelf draait om X ----------
R_WIEL = 0.37
WIELEN = {}


def wiel(naam, parent, sx):
    w = cyl(naam, R_WIEL, R_WIEL, 0.2, BAND, "X", 18, parent)
    delen = [cyl(naam + "velg", 0.2, 0.2, 0.21, OLIJF, "X", 10, w),
             cyl(naam + "naaf", 0.07, 0.06, 0.23, METAAL, "X", 8, w)]
    for k in range(5):
        a = k * math.tau / 5
        delen.append(box(naam + f"moer{k}", (0.235, 0.03, 0.03), METAAL, w, (0, math.cos(a) * 0.12, math.sin(a) * 0.12)))
    # profielnokken op de band (zichtbaar draaien)
    for k in range(16):
        a = k * math.tau / 16
        n = box(naam + f"nok{k}", (0.16, 0.06, 0.03), BAND, w, (0, math.cos(a) * R_WIEL, math.sin(a) * R_WIEL))
        n.rotation_euler = (a + math.pi / 2, 0, 0)
        delen.append(n)
    join(w, delen)
    WIELEN[naam] = w
    LOS.add(naam)
    return w


SPOOR = 0.62
stuur_l = empty("StuurLV", body, (-SPOOR, 1.12, R_WIEL))
stuur_r = empty("StuurRV", body, (SPOOR, 1.12, R_WIEL))
LOS.update({"StuurLV", "StuurRV"})
wiel("WielLV", stuur_l, -1)
wiel("WielRV", stuur_r, 1)
wla = wiel("WielLA", body, -1)
wla.location = (-SPOOR, -0.92, R_WIEL)
wra = wiel("WielRA", body, 1)
wra.location = (SPOOR, -0.92, R_WIEL)

# ---------- lampen voor het spel (KHR_lights_punctual) ----------
for sx in (-1, 1):
    sp = bpy.data.lights.new(f"Koplamp{'L' if sx < 0 else 'R'}", "SPOT")
    sp.energy = 6.0  # export in RAW-modus: dit is direct de lichtsterkte in Godot
    sp.spot_size = math.radians(55)
    sp.spot_blend = 0.5
    sp.color = (1.0, 0.95, 0.82)
    o = link(bpy.data.objects.new(sp.name, sp), body)
    o.location = (sx * 0.36, 1.75, 0.77)
    o.rotation_euler = (math.radians(80), 0, 0)  # spot kijkt langs -Z: kantel naar voren (+Y), iets omlaag
    LOS.add(o.name)
    pl = bpy.data.lights.new(f"Achterlicht{'L' if sx < 0 else 'R'}", "POINT")
    pl.energy = 0.8
    pl.color = (1.0, 0.1, 0.05)
    pl.shadow_soft_size = 0.05
    o = link(bpy.data.objects.new(pl.name + "Lamp", pl), body)
    o.location = (sx * 0.52, YA - 0.1, 0.86)
    LOS.add(o.name)

# ---------- bestuurder (zittend, links) ----------
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


bestuurder, bd, tz = soldaat("Bestuurder", body, True)
bestuurder.location = (-0.3, 0.02, 0.67)
bl, bld = bovenlijf("BestuurderBoven", bestuurder, tz, math.radians(-8),
                    [(-1, (-0.13, 0.33, 0.37)), (1, (0.13, 0.33, 0.37))])
join(bd[0], bd[1:]).name = "BestuurderBenen"
join(bld[0], bld[1:]).name = "BestuurderBovenMesh"
LOS.update({"BestuurderBenen", "BestuurderBovenMesh", "Bestuurder", "BestuurderBoven"})

# ---------- geschut: paal, draaiende houder, M2 .50 en de schutter ----------
PAAL_Y = -0.85
cyl("Paal", 0.05, 0.05, 0.85, DONKER, "Z", 10, body, (0, PAAL_Y, 0.9))
cyl("Paalvoet", 0.16, 0.18, 0.06, DONKER, "Z", 10, body, (0, PAAL_Y, 0.5))
geschut = empty("Geschut", body, (0, PAAL_Y, 1.33))
LOS.add("Geschut")
gd = [cyl("Draaikop", 0.07, 0.07, 0.12, METAAL, "Z", 10, geschut, (0, 0, 0.0)),
      box("Wieg", (0.1, 0.35, 0.1), DONKER, geschut, (0, 0.05, 0.1))]
houder = join(gd[0], gd[1:])
houder.name = "GeschutMesh"
LOS.add("GeschutMesh")

mg = empty("MG", geschut, (0, 0.0, 0.2))
LOS.add("MG")
md = [box("Kast", (0.13, 0.62, 0.17), ZWART, mg, (0, 0.05, 0)),
      cyl("Loopmantel", 0.045, 0.045, 0.42, ZWART, "Y", 10, mg, (0, 0.55, 0.02)),
      cyl("Loop", 0.024, 0.024, 0.82, ZWART, "Y", 8, mg, (0, 0.98, 0.02)),
      cyl("Mondingsdemper", 0.035, 0.03, 0.08, ZWART, "Y", 8, mg, (0, 1.4, 0.02)),
      box("Bandkist", (0.14, 0.24, 0.2), OLIJF, mg, (-0.16, 0.05, -0.04)),
      box("Patroonband", (0.1, 0.06, 0.03), MESSING, mg, (-0.08, 0.05, 0.06)),
      box("Vizier", (0.02, 0.04, 0.08), ZWART, mg, (0, 0.28, 0.12))]
for sx in (-1, 1):
    md.append(box(f"Spadegreep{sx}", (0.03, 0.1, 0.03), ZWART, mg, (sx * 0.06, -0.3, 0)))
    md.append(cyl(f"Greep{sx}", 0.02, 0.02, 0.12, KOPPEL, "Z", 6, mg, (sx * 0.1, -0.34, 0)))
mgmesh = join(md[0], md[1:])
mgmesh.name = "MGMesh"
LOS.add("MGMesh")
monding = empty("Monding", mg, (0, 1.46, 0.02))
LOS.add("Monding")
# mondingsvlam: drie gekruiste vlakken, in rust geschaald naar 0
vlam = None
vd = []
for i in range(3):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((-0.12, 0, 0), (0, 0.38, 0), (0.12, 0, 0), (0, -0.04, 0))]
    bm.faces.new(vs)
    o = mesh_obj(f"Vlam{i}", bm, VLAM, monding)
    o.rotation_euler = (0, i * math.pi / 3, 0)
    vd.append(o)
vlam = join(vd[0], vd[1:])
vlam.name = "Vlam"
vlam.scale = (0.001, 0.001, 0.001)
LOS.add("Vlam")
HULZEN = []
for i in range(3):
    h = cyl(f"Huls{i}", 0.012, 0.012, 0.1, MESSING, "X", 6, mg, (0.08, 0.02, 0))
    h.scale = (0.001, 0.001, 0.001)
    HULZEN.append(h)
    LOS.add(h.name)

# schutter: staat achter het geschut en draait mee; handen op de spadegrepen
schutter, sd, tz = soldaat("Schutter", geschut, False)
schutter.location = (0, -0.62, 0.47 - 1.33)
LOS.add("Schutter")
greep_z = 1.33 + 0.2 - (0.47)  # hoogte van de grepen boven de voeten
sbl, sbd = bovenlijf("Bovenlijf", schutter, tz, math.radians(14),
                     [(-1, (-0.1, 0.28, greep_z)), (1, (0.1, 0.28, greep_z))])
LOS.add("Bovenlijf")
benen = join(sd[0], sd[1:])
benen.name = "SchutterBenen"
LOS.add("SchutterBenen")
boven = join(sbd[0], sbd[1:])
boven.name = "BovenlijfMesh"
LOS.add("BovenlijfMesh")

# ---------- UV's, modifiers, samenvoegen ----------
for o in list(scene.objects):
    if o.type == "MESH":
        bpy.context.view_layer.objects.active = o
        for s in scene.objects:
            s.select_set(s == o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=1.5)
        bpy.ops.object.mode_set(mode="OBJECT")
for o in scene.objects:
    o.select_set(o.type == "MESH")
romp = bpy.data.objects["Bodem"]
bpy.context.view_layer.objects.active = romp
bpy.ops.object.convert(target="MESH")
delen = [o for o in body.children if o.type == "MESH" and o.name not in LOS]
join(romp, [d for d in delen if d != romp])
romp.name = romp.data.name = "RompMesh"
bpy.ops.object.select_all(action="DESELECT")
romp.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.images["jeep_olijf"].pack()

# ---------- animaties ----------
FPS = 30
scene.render.fps = FPS
LUS = 2.0


def ease(t):
    return t * t * (3 - 2 * t)


ANIM = [body, stuur_l, stuur_r, geschut, mg, vlam, sbl, bl] + list(WIELEN.values()) + HULZEN


def clip(naam, duur, pose, snelheid=lambda t: 0.0, stuurhoek=lambda t: 0.0, geschut_yaw=lambda t: 0.0,
         schot=None, schudden=lambda t: 0.0):
    """pose(t) -> (z, pitch, roll); snelheid(t) m/s; schot(t) -> tijd sinds laatste schot (of None)."""
    frames = int(round(duur * FPS))
    for o in ANIM:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    basis = {o: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in ANIM}
    # afstand vooraf, zodat de wielhoek aan het eind een geheel aantal moerstappen is (naadloze lus)
    eind = sum(snelheid(f / FPS) / FPS for f in range(1, frames + 1))
    raw = eind / R_WIEL
    stap = math.tau / 5
    corr = (round(raw / stap) * stap / raw) if abs(raw) > 1e-6 and round(raw / stap) else 1.0
    afstand = 0.0
    for f in range(frames + 1):
        t = f / FPS
        if f:
            afstand += snelheid(t) / FPS
        z, pitch, roll = pose(t)
        sch = schudden(t)
        body.location = (0, 0, z)
        body.rotation_euler = (pitch, roll, 0)
        for w in WIELEN.values():
            w.rotation_euler = (-afstand / R_WIEL * corr, 0, 0)
        for st_ in (stuur_l, stuur_r):
            st_.rotation_euler = (0, 0, stuurhoek(t))
        geschut.rotation_euler = (0, 0, geschut_yaw(t))
        # schieten: terugslag van de MG, vlam en hulzen; schutter schokt mee
        dt_s = schot(t) if schot else None
        rek = 0.0
        if dt_s is not None:
            rek = -0.035 * math.exp(-dt_s * 40)
            v = 1.0 if dt_s < 0.04 else 0.001
            vlam.scale = (v * (0.8 + 0.4 * math.sin(f * 2.3)), v, v * (0.8 + 0.4 * math.cos(f * 1.7)))
            vlam.rotation_euler = (0, f * 0.9, 0)
        else:
            vlam.scale = (0.001, 0.001, 0.001)
        mg.location = basis[mg][0] + Vector((0, rek, 0))
        sbl.location = basis[sbl][0] + Vector((0, rek * 0.6, sch * 0.004))
        sbl.rotation_euler = (basis[sbl][1].x + rek * 0.4, sch * 0.01, 0)
        bl.rotation_euler = (basis[bl][1].x + math.sin(t * math.tau) * 0.01 * abs(snelheid(t)) / 6, 0, 0)
        for i, h in enumerate(HULZEN):
            if schot:
                # elke huls volgt een eigen schot: zijwaarts uit de kast, met een boog naar beneden
                periode = 0.125 * 3
                th = (t - i * 0.125) % periode
                if th < 0.3:
                    h.location = (0.08 + th * 1.6, 0.02 - th * 0.3, 0.05 + th * 1.2 - 9.8 * th * th / 2 * 1.4)
                    h.rotation_euler = (th * 30, th * 20, 0)
                    h.scale = (1, 1, 1)
                else:
                    h.scale = (0.001, 0.001, 0.001)
            else:
                h.scale = (0.001, 0.001, 0.001)
        for o in ANIM:
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in ANIM:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
        o.location, o.rotation_euler, o.scale = basis[o]


def tril(t, s=1.0):
    return 0.003 * s * math.sin(t * math.tau * 15), 0.002 * s * math.sin(t * math.tau * 10 + 1.1)


V_RIJ = 8.0
V_ACH = 3.0
clip("Stationair-loop", LUS, lambda t: (tril(t)[0], tril(t)[1], 0.001 * math.sin(t * math.tau * 5)))
clip("Rijden-loop", LUS,
     lambda t: (0.02 * math.sin(t * math.tau * 2) + 0.01 * math.sin(t * math.tau * 3 + 0.7) + tril(t, 0.5)[0],
                math.radians(-0.6) + math.radians(1.0) * math.sin(t * math.tau * 1 + 0.4),
                math.radians(0.8) * math.sin(t * math.tau * 1.5 + 1.0)),
     lambda t: V_RIJ)
clip("Achteruit-loop", LUS,
     lambda t: (0.012 * math.sin(t * math.tau * 2) + tril(t, 0.5)[0],
                math.radians(0.5) + math.radians(0.5) * math.sin(t * math.tau), 0),
     lambda t: -V_ACH)
clip("Bocht-loop", LUS,
     lambda t: (0.015 * math.sin(t * math.tau * 2) + tril(t, 0.5)[0], math.radians(-0.4),
                math.radians(3.5) + math.radians(0.6) * math.sin(t * math.tau)),
     lambda t: 6.0, lambda t: math.radians(26))


def remmen(t):
    k = math.exp(-t * 3.5)
    duik = math.radians(-3.2) * (ease(min(1, t / 0.25)) if t < 0.25 else k * math.cos((t - 0.25) * 7))
    return (-0.025 * min(1, t / 0.25) * (1 if t < 0.25 else k), duik, 0)


clip("Remmen", 1.5, remmen, lambda t: max(0.0, V_RIJ * (1 - t / 0.6)))
clip("Vuren-loop", LUS, lambda t: (tril(t)[0], tril(t)[1], 0), schot=lambda t: t % 0.125,
     schudden=lambda t: math.sin(t * math.tau * 8) * 0.6)
clip("Rondkijken-loop", 4.0, lambda t: (tril(t)[0], tril(t)[1], 0),
     geschut_yaw=lambda t: math.radians(70) * math.sin(t * math.tau / 4))

scene.frame_start, scene.frame_end = 0, 60
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "jeep.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "jeep.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)
