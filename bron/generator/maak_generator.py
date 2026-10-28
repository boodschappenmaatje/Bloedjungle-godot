"""Dieselgenerator voor Bloedjungle (VQ2): geluiddempende olijfgroene kap op stalen slede, koelventilator, bedieningskast, uitlaat.
Z = omhoog (Godot Y), 1 eenheid = 1 meter. Twee wortelknopen in één glb:
  Generator  oorsprong = midden van de betonplaat op de grond, 3,0 x 1,8 m, kap 2,2 x 1,0 x 1,05 m (top 1,45 m, uitlaat tot 2,05 m).
             Voorkant (deuren, bedieningskast) = +Y in Blender (= -Z in Godot); de ventilator zit aan de +X-kant. Kindknoop Ventilator draait; clip "Draaien" (lus).
  Wrak       zelfde oorsprong: ingezakte, zwartgeblakerde kap, losgeraakte deur en uitlaat, scheve ventilatorkooi. Staat in de glb 4 m naast de generator.
Materialen: VQ2-families (olive, steel, concrete) + gedeelde vlakke materialen (rubber, glas, geel, gebrand). Gebruik: python3 maak_generator.py uit/"""
import math, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vq2_common import pbr, finish_mesh, corrugated, bolt

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(ARGS[0] if ARGS else str(Path(__file__).parent / "uit"))
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30


def flat(name, color, rough=0.6, metal=0.0, emit=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 1.0
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


MAT = {"olive": pbr("olive"), "steel": pbr("steel"), "concrete": pbr("concrete"),
       "rubber": flat("Rubber", (0.04, 0.04, 0.04), 0.85), "glas": flat("Meterglas", (0.06, 0.08, 0.08), 0.1, alpha=0.35),
       "geel": flat("Waarschuwing", (0.78, 0.6, 0.08), 0.55), "rood": flat("Rood", (0.55, 0.06, 0.04), 0.5),
       "kool": flat("Gebrand", (0.045, 0.04, 0.037), 0.8, 0.2),
       "olijf_zwart": pbr("olive", (0.22, 0.2, 0.18), "_gebrand"), "beton_zwart": pbr("concrete", (0.3, 0.29, 0.28), "_gebrand"),
       "staal_zwart": pbr("steel", (0.28, 0.26, 0.25), "_gebrand")}
FAM = {"olive": "olive", "steel": "steel", "concrete": "concrete", "olijf_zwart": "olive", "beton_zwart": "concrete", "staal_zwart": "steel"}
FLATK = ("rubber", "glas", "geel", "rood", "kool")


class Part:
    def __init__(self, name, parent):
        self.name, self.parent, self.bm = name, parent, {}

    def b(self, k):
        if k not in self.bm:
            self.bm[k] = bmesh.new()
        return self.bm[k]

    def box(self, k, c, size, rot=0.0, rotx=0.0, roty=0.0):
        bm = self.b(k)
        r = bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=size, verts=r["verts"])
        for ang, ax in ((rotx, "X"), (roty, "Y"), (rot, "Z")):
            if ang:
                bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, ax))
        bmesh.ops.translate(bm, verts=r["verts"], vec=c)

    def beam(self, k, p0, p1, w=0.1, w2=None):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        bm = self.b(k)
        r = bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(w, w2 or w, d.length), verts=r["verts"])
        bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix())
        bmesh.ops.translate(bm, verts=r["verts"], vec=(p0 + p1) / 2)

    def cyl(self, k, c, r, h, seg=16, axis="Z", r2=None):
        bm = self.b(k)
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        if axis == "X":
            bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
        elif axis == "Y":
            bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
        bmesh.ops.translate(bm, verts=res["verts"], vec=c)

    def finish(self, bevel=0.006):
        for k, bm in self.bm.items():
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            me = bpy.data.meshes.new(self.name + "_" + k)
            bm.to_mesh(me); bm.free()
            me.materials.append(MAT[k])
            o = bpy.data.objects.new(self.name + "_" + k, me)
            scene.collection.objects.link(o)
            o.parent = self.parent
            finish_mesh(o, FAM.get(k, "steel"), 0 if k in FLATK and k in ("glas",) else bevel)


def empty(name, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


L, W = 2.2, 1.0         # kap
ZK0, ZK1 = 0.34, 1.42   # onderkant/bovenkant kap

# ================= Generator =================
root = empty("Generator")
g = Part("Generator", root)
# betonplaat met afgeschuinde rand en ankerbouten
g.box("concrete", (0, 0, 0.06), (3.0, 1.8, 0.12))
g.box("concrete", (0, 0, 0.125), (2.9, 1.7, 0.03))
for sx in (-1, 1):
    for sy in (-1, 1):
        bolt(g.b("steel"), (sx * 1.38, sy * 0.78, 0.15), (0, 0, 1), 0.03)
# stalen slede: twee I-liggers met kopplaten en dwarsliggers, rubber trillingsdempers
for sy in (-1, 1):
    g.box("steel", (0, sy * 0.46, 0.2), (2.5, 0.14, 0.06))      # onderflens
    g.box("steel", (0, sy * 0.46, 0.27), (2.5, 0.04, 0.12))     # lijf
    g.box("steel", (0, sy * 0.46, 0.34), (2.5, 0.14, 0.04))     # bovenflens
for dx in (-1.1, -0.4, 0.4, 1.1):
    g.box("steel", (dx, 0, 0.27), (0.1, 0.92, 0.1))
for dx in (-1.0, 0.0, 1.0):
    for sy in (-1, 1):
        g.cyl("rubber", (dx, sy * 0.46, 0.155), 0.045, 0.06, 10)
# hijsoog op de kopplaat
g.cyl("steel", (-1.27, 0.0, 0.3), 0.07, 0.03, 12, axis="X")
# kap: onderrand, wanden met panelen, dak met nok en ribben
g.box("olive", (0, 0, ZK0 + 0.05), (L + 0.04, W + 0.04, 0.1))
g.box("olive", (0, 0, (ZK0 + ZK1) / 2 - 0.02), (L, W - 0.04, ZK1 - ZK0 - 0.1))
for sy in (-1, 1):
    # deurpanelen met lamellen en greep aan beide lange zijden
    for sx in (-1, 1):
        xc = sx * 0.55
        g.box("olive", (xc, sy * (W / 2 + 0.012), 0.82), (1.0, 0.024, 0.76))
        for i in range(7):
            g.box("steel", (xc, sy * (W / 2 + 0.034), 0.6 + i * 0.065), (0.7, 0.022, 0.012))   # ventilatielamellen
        g.box("steel", (xc - sx * 0.44, sy * (W / 2 + 0.04), 0.95), (0.03, 0.03, 0.16))
        for dz in (0.55, 1.12):
            g.box("steel", (xc + sx * 0.48, sy * (W / 2 + 0.02), dz), (0.03, 0.04, 0.12))
        for bx in (-0.42, 0.42):
            for bz in (0.5, 1.15):
                bolt(g.b("steel"), (xc + bx, sy * (W / 2 + 0.026), bz), (0, sy, 0), 0.02)
# dak
g.box("olive", (0, 0, ZK1 + 0.03), (L + 0.1, W + 0.1, 0.06))
g.box("olive", (0, 0, ZK1 + 0.075), (L - 0.3, W - 0.3, 0.04))
for dx in (-0.8, -0.3, 0.3, 0.8):
    g.box("steel", (dx, 0, ZK1 + 0.11), (0.06, W - 0.2, 0.03))
# brandstofvuldop met ketting en een kleine tankmeterhuls
g.cyl("steel", (-0.65, 0.3, ZK1 + 0.1), 0.1, 0.05, 14)
g.cyl("rood", (-0.65, 0.3, ZK1 + 0.14), 0.065, 0.04, 14)
g.beam("steel", (-0.65, 0.3, ZK1 + 0.1), (-0.5, 0.22, ZK1 + 0.1), 0.012)
# uitlaat: dikke demper op het dak met buis omhoog en regenkap
g.cyl("steel", (0.55, -0.15, ZK1 + 0.25), 0.15, 0.4, 16, axis="X")
g.cyl("steel", (0.55, -0.15, ZK1 + 0.25), 0.155, 0.05, 16, axis="X")
g.cyl("steel", (0.78, -0.15, ZK1 + 0.55), 0.045, 0.6, 12)
g.cyl("steel", (0.78, -0.15, ZK1 + 0.9), 0.07, 0.04, 12)
g.cyl("steel", (0.78, -0.15, ZK1 + 0.94), 0.09, 0.02, 12, r2=0.0)
g.box("steel", (0.55, -0.15, ZK1 + 0.1), (0.08, 0.26, 0.1))                         # steun
# bedieningskast aan de -X-kant, op de voorkant: grijze kast met meters, noodstop, stopcontacten
g.box("steel", (-1.43, 0.12, 0.72), (0.4, 0.62, 0.95))
g.box("olive", (-1.43, 0.12, 1.22), (0.44, 0.66, 0.06))                              # kastdakje
g.box("steel", (-1.24, 0.12, 0.8), (0.03, 0.5, 0.6))                                 # paneel
for i, dy in enumerate((-0.08, 0.1, 0.28)):
    g.cyl("glas", (-1.255, dy, 1.0), 0.06, 0.02, 16, axis="X")                       # meters
    g.cyl("rubber", (-1.248, dy, 1.0), 0.07, 0.012, 16, axis="X")
g.cyl("rood", (-1.255, 0.3, 0.76), 0.045, 0.04, 14, axis="X")                      # noodstop
g.cyl("geel", (-1.25, 0.3, 0.76), 0.065, 0.012, 14, axis="X")
for i in range(3):
    g.cyl("rubber", (-1.252, -0.06 + i * 0.14, 0.64), 0.04, 0.03, 12, axis="X")      # contactdozen
    g.box("steel", (-1.268, -0.06 + i * 0.14, 0.64), (0.012, 0.05, 0.015))
for i in range(4):
    g.cyl("steel", (-1.255, -0.1 + i * 0.1, 0.9), 0.016, 0.03, 8, axis="X")          # schakelaars
# aansluitkabel: dikke rubber kabel van de kast over de plaat naar een verdeeldoos
g.box("steel", (-1.1, 0.78, 0.2), (0.34, 0.24, 0.22))
g.box("geel", (-1.1, 0.78, 0.33), (0.36, 0.26, 0.02))
pts = [(-1.43, 0.34, 0.3), (-1.43, 0.55, 0.14), (-1.3, 0.72, 0.14), (-1.1, 0.78, 0.2)]
for a, b2 in zip(pts, pts[1:]):
    g.beam("rubber", a, b2, 0.05)
g.beam("rubber", (-1.1, 0.78, 0.2), (-0.7, 1.2, 0.1), 0.05)
g.beam("rubber", (-0.7, 1.2, 0.1), (0.3, 1.5, 0.07), 0.05)
# luchtinlaat op de +X-kant: stalen kooi achter de ventilator
FX = 1.27
g.box("steel", (FX, 0, 0.78), (0.1, W - 0.06, 1.0))
g.cyl("steel", (FX + 0.06, 0, 0.8), 0.46, 0.02, 24, axis="X")
for r in (0.12, 0.24, 0.36, 0.45):
    g.cyl("steel", (FX + 0.075, 0, 0.8), r, 0.014, 24, axis="X")
for i in range(8):
    t = i * math.pi / 8
    g.beam("steel", (FX + 0.075, math.cos(t) * 0.46, 0.8 + math.sin(t) * 0.46), (FX + 0.075, -math.cos(t) * 0.46, 0.8 - math.sin(t) * 0.46), 0.016)
g.finish(0.006)
# ventilator in de kooi (draait om X): naaf en zes bladen onder een hoek
fan = empty("Ventilator", root, (FX + 0.03, 0, 0.8))
fp = Part("Ventilator", fan)
fp.cyl("steel", (0.0, 0, 0), 0.07, 0.07, 16, axis="X")
for i in range(6):
    t = i * math.tau / 6
    c = Vector((0, math.cos(t) * 0.24, math.sin(t) * 0.24))
    fp.box("rubber", (c.x, c.y, c.z), (0.01, 0.17, 0.2), rotx=t + 0.35, roty=0.0)
fp.cyl("steel", (0.0, 0, 0), 0.04, 0.09, 12, axis="X")
fp.finish(0.002)
fan.rotation_mode = "XYZ"
act = bpy.data.actions.new("Draaien")
act.use_fake_user = True
fan.animation_data_create()
fan.animation_data.action = act
for fr, ang in ((0, 0.0), (24, math.tau)):
    fan.rotation_euler = (ang, 0, 0)
    fan.keyframe_insert("rotation_euler", frame=fr)
for lay in act.layers:
    for st in lay.strips:
        for cb in st.channelbags:
            for fc in cb.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
scene.frame_start, scene.frame_end = 0, 24
fan.rotation_euler = (0, 0, 0)

# ================= Wrak =================
wr = empty("Wrak", None, (0, 4.0, 0))
w = Part("Wrak", wr)
w.box("beton_zwart", (0, 0, 0.06), (3.0, 1.8, 0.12))
w.box("kool", (0.1, 0.05, 0.13), (2.6, 1.4, 0.01), rot=0.1)                           # brandvlek op de plaat
for sy in (-1, 1):
    w.box("staal_zwart", (0.1, sy * 0.46, 0.2), (2.5, 0.14, 0.06), rot=sy * 0.05)
    w.box("staal_zwart", (0.1, sy * 0.46, 0.27), (2.5, 0.04, 0.12), rot=sy * 0.05)
for dx in (-1.0, -0.2, 0.7):
    w.box("staal_zwart", (dx, 0, 0.27), (0.1, 0.92, 0.1), rot=0.05)
# ingezakte kap: schuine, deels weggesmolten dozen
w.box("olijf_zwart", (-0.1, 0.05, 0.48), (2.1, 0.96, 0.46), rot=0.06, roty=0.04)
w.box("olijf_zwart", (-0.7, -0.05, 0.78), (0.8, 0.9, 0.18), rot=-0.12, roty=-0.15)
w.box("kool", (-0.1, 0.05, 0.725), (1.5, 0.8, 0.02), rot=0.06)
w.box("olijf_zwart", (0.75, 0.0, 0.68), (0.7, 0.9, 0.06), rot=0.2, roty=0.5)          # schuin ingedeukt dakdeel
w.beam("staal_zwart", (-0.9, -0.4, 0.74), (-0.2, 0.3, 0.55), 0.05)                     # scheve ribben
w.beam("staal_zwart", (0.4, -0.35, 0.7), (1.0, 0.25, 0.5), 0.05)
# losgeraakte deur leunt tegen de voorkant
w.box("olijf_zwart", (0.4, 0.78, 0.38), (1.0, 0.03, 0.72), rotx=0.36)
for i in range(5):
    w.box("staal_zwart", (0.4, 0.8 + i * 0.01, 0.2 + i * 0.12), (0.7, 0.02, 0.012), rotx=0.36)
# uitlaat ligt op de plaat, gebogen buis
w.cyl("staal_zwart", (1.0, -0.65, 0.22), 0.15, 0.5, 14, axis="X")
w.beam("staal_zwart", (0.5, -0.5, 0.2), (0.0, -0.6, 0.12), 0.09)
w.cyl("staal_zwart", (-0.6, -0.8, 0.12), 0.045, 0.7, 10, axis="Y")
# bedieningskast verbogen en geblakerd
w.box("staal_zwart", (-1.43, 0.16, 0.5), (0.4, 0.6, 0.7), rot=0.08, roty=-0.1)
w.box("kool", (-1.25, 0.16, 0.66), (0.03, 0.46, 0.4), rot=0.08)
w.beam("rubber", (-1.3, 0.3, 0.2), (-0.9, 0.9, 0.1), 0.05)
w.beam("rubber", (-0.9, 0.9, 0.1), (-0.2, 1.1, 0.07), 0.05)
# ventilatorkooi hangt scheef, bladen weg
w.cyl("staal_zwart", (1.45, 0.1, 0.55), 0.46, 0.02, 20, axis="X")
w.cyl("staal_zwart", (1.45, 0.1, 0.55), 0.3, 0.014, 20, axis="X")
w.box("staal_zwart", (1.3, 0.05, 0.42), (0.1, 0.9, 0.7), roty=0.2)
# brokstukken
for pos, sz, r in (((0.9, 0.7, 0.1), (0.3, 0.2, 0.08), 0.5), ((-0.4, -0.8, 0.1), (0.25, 0.3, 0.06), -0.3), ((1.2, -0.3, 0.1), (0.2, 0.15, 0.1), 0.9)):
    w.box("olijf_zwart", pos, sz, rot=r)
w.finish(0.006)

for o in scene.objects:
    if o.type == "MESH":
        o.data.update()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "generator.blend"))
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "generator.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          export_materials="EXPORT", export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                          export_cameras=False, export_lights=False)
tris = {"Generator": 0, "Wrak": 0}
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        r = o.parent
        while r.parent:
            r = r.parent
        tris[r.name] += len(o.data.loop_triangles)
print("GENERATOR triangles", tris)
