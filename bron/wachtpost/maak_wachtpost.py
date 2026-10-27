"""Poortwachtpost voor Bloedjungle (VQ2): slagboom (kast, draaiende arm met contragewicht, steunvork) en wachthuisje.
Z = omhoog (Godot Y), 1 eenheid = 1 meter. Twee wortelknopen in één glb:
  Slagboom  oorsprong = midden van de poortopening op de grond; de arm ligt langs X (draaipunt X = -3,75, hoogte 0,95 m),
            de kast staat op -X, de steunvork op +X. Kindknoop Boom draait; clip "Open" (1,5 s) tilt de arm 82 graden op, terugspelen = sluiten.
            Maat past op Data.GATE_GAP = 3,4 (opening 6,8 m).
  Wachthuis oorsprong = midden van de vloer op de grond (in de glb 4,5 m naar -Y/+Z Godot verschoven), 2,3 x 2,3 m, 2,5 m hoog (tot dakrand). Voorkant (raam, luifel) = +Y in Blender (= -Z in Godot).
            Geen clips: deur en luik zijn vast (de wacht staat buiten).
Materialen: de VQ2-families (olive, steel, concrete, roof, timber, canvas) + eigen rood-wit verf (slagboomverf_*.jpg/png uit maak_slagboomverf.py).
Gebruik: python3 maak_slagboomverf.py uit/ && python3 maak_wachtpost.py uit/   ->  wachtpost.glb, wachtpost.blend"""
import math, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vq2_common import pbr, finish_mesh, corrugated, bolt, image, export_and_save

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(ARGS[0] if ARGS else str(Path(__file__).parent / "uit"))
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

G = 3.4                 # halve poortopening (Data.GATE_GAP)
PIV_X, PIV_Z = -(G + 0.35), 0.95
ARM_LEN = 7.2
OPEN_DEG = 82.0


def paint_mat():
    m = bpy.data.materials.new("Slagboomverf")
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    b = n["Principled BSDF"]
    t = n.new("ShaderNodeTexImage"); t.image = image(Path(OUT) / "slagboomverf_albedo.jpg")
    l.new(t.outputs["Color"], b.inputs["Base Color"])
    t2 = n.new("ShaderNodeTexImage"); t2.image = image(Path(OUT) / "slagboomverf_normal.jpg", True)
    nm = n.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 0.6
    l.new(t2.outputs["Color"], nm.inputs["Color"]); l.new(nm.outputs["Normal"], b.inputs["Normal"])
    t3 = n.new("ShaderNodeTexImage"); t3.image = image(Path(OUT) / "slagboomverf_orm.png", True)
    sp = n.new("ShaderNodeSeparateColor")
    l.new(t3.outputs["Color"], sp.inputs[0]); l.new(sp.outputs["Green"], b.inputs["Roughness"]); l.new(sp.outputs["Blue"], b.inputs["Metallic"])
    return m


def flat(name, color, rough=0.6, metal=0.0, emit=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 1.5
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


MAT = {"olive": pbr("olive"), "steel": pbr("steel"), "concrete": pbr("concrete"), "roof": pbr("roof"),
       "timber": pbr("timber"), "canvas": pbr("canvas"), "verf": paint_mat(),
       "glas": flat("Glas", (0.05, 0.08, 0.08), 0.1, 0.0, alpha=0.3), "reflector": flat("Reflector", (0.9, 0.08, 0.05), 0.25, 0.0, emit=(0.9, 0.1, 0.05))}
FAM = {"olive": "olive", "steel": "steel", "concrete": "concrete", "roof": "roof", "timber": "timber", "canvas": "canvas",
       "verf": "steel", "glas": "steel", "reflector": "steel"}


class Part:
    """Eén mesh per materiaal onder een ouderknoop."""
    def __init__(self, name, parent):
        self.name, self.parent, self.bm = name, parent, {}

    def b(self, k):
        if k not in self.bm:
            self.bm[k] = bmesh.new()
        return self.bm[k]

    def box(self, k, c, size, rot=0.0):
        bm = self.b(k)
        r = bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=size, verts=r["verts"])
        if rot:
            bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(rot, 3, "Z"))
        bmesh.ops.translate(bm, verts=r["verts"], vec=c)

    def beam(self, k, p0, p1, w=0.1, w2=None):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        bm = self.b(k)
        r = bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(w, w2 or w, d.length), verts=r["verts"])
        bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix())
        bmesh.ops.translate(bm, verts=r["verts"], vec=(p0 + p1) / 2)

    def cyl(self, k, c, r, h, seg=14, axis="Z"):
        bm = self.b(k)
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
        if axis == "X":
            bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
        elif axis == "Y":
            bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
        bmesh.ops.translate(bm, verts=res["verts"], vec=c)

    def finish(self, bevel=0.006):
        out = []
        for k, bm in self.bm.items():
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            me = bpy.data.meshes.new(self.name + "_" + k)
            bm.to_mesh(me); bm.free()
            me.materials.append(MAT[k])
            o = bpy.data.objects.new(self.name + "_" + k, me)
            scene.collection.objects.link(o)
            o.parent = self.parent
            finish_mesh(o, FAM[k], 0 if k in ("glas", "reflector") else bevel)
            out.append(o)
        return out


def arm_uv(o, length):
    """Rood-wit verf: U loopt 1 m per textuurbreedte langs de arm, V dwars."""
    me = o.data
    uv = me.uv_layers.active or me.uv_layers.new(name="VQ2_UV")
    for f in me.polygons:
        n = f.normal
        for li in f.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            along = p.x
            across = p.z if abs(n.y) > 0.5 else p.y
            uv.data[li].uv = (along / 1.0, across / 0.5 + 0.25)


# ================= Slagboom =================
root = bpy.data.objects.new("Slagboom", None)
scene.collection.objects.link(root)
fix = Part("Slagboom", root)
# betonvoet + kast (olijf staal) met deurpaneel, scharnieren, bouten en dakje
fix.box("concrete", (PIV_X - 0.2, 0, 0.07), (1.0, 0.8, 0.14))
fix.box("olive", (PIV_X - 0.2, 0, 0.64), (0.52, 0.42, 1.0))
fix.box("olive", (PIV_X - 0.2, 0, 1.2), (0.6, 0.5, 0.06))                     # dakplaat met overstek
fix.box("olive", (PIV_X - 0.2, 0.215, 0.62), (0.4, 0.014, 0.8))               # deurpaneel
fix.box("steel", (PIV_X - 0.06, 0.226, 0.62), (0.03, 0.02, 0.12))             # handgreep
for dz in (0.28, 0.96):
    fix.box("steel", (PIV_X - 0.38, 0.215, dz), (0.03, 0.03, 0.12))           # scharnieren
for sx in (-1, 1):
    for sy in (-1, 1):
        bolt(fix.b("steel"), (PIV_X - 0.2 + sx * 0.4, sy * 0.3, 0.15), (0, 0, 1), 0.03)   # ankerbouten
fix.cyl("steel", (PIV_X, 0.0, PIV_Z), 0.07, 0.62, axis="Y")                    # as door de kast
fix.cyl("steel", (PIV_X, 0.28, PIV_Z), 0.1, 0.05, seg=16, axis="Y")            # flens
for a in range(6):
    t = a * math.tau / 6
    bolt(fix.b("steel"), (PIV_X + math.cos(t) * 0.075, 0.31, PIV_Z + math.sin(t) * 0.075), (0, 1, 0), 0.012)
# steunvork aan de overkant: paal met U-vork en rubberblokken
SX = G + 0.45
fix.box("concrete", (SX, 0, 0.05), (0.5, 0.5, 0.1))
fix.box("steel", (SX, 0, 0.5), (0.12, 0.12, 0.9))
fix.box("steel", (SX, 0, 0.99), (0.22, 0.3, 0.05))
for sy in (-1, 1):
    fix.box("steel", (SX, sy * 0.13, 1.06), (0.2, 0.025, 0.14))
fix.box("steel", (SX, 0, 1.025), (0.18, 0.22, 0.02))
for dz in (0.35, 0.75):
    fix.box("steel", (SX + 0.075, 0, dz), (0.03, 0.14, 0.03))
for o in fix.finish():
    pass
# arm: balk 0,1 x 0,14 m, rood-wit; contragewicht en reflectoren
boom = bpy.data.objects.new("Boom", None)
scene.collection.objects.link(boom)
boom.parent = root
boom.location = (PIV_X, 0, PIV_Z)
bp = Part("Boom", boom)
bp.box("verf", (ARM_LEN / 2 - 0.55, 0, 0.0), (ARM_LEN, 0.18, 0.15))
bp.box("verf", (-0.28, 0, 0.0), (0.36, 0.22, 0.2))                             # voetstuk tegen het contragewicht
bp.box("steel", (-0.42, 0, -0.04), (0.5, 0.28, 0.26))                           # contragewicht
bp.box("steel", (-0.42, 0, 0.11), (0.5, 0.16, 0.04))
for dx in (-0.6, -0.24):
    bolt(bp.b("steel"), (dx, 0.145, -0.04), (0, 1, 0), 0.025)
for sy in (-1, 1):
    bp.box("steel", (0.0, sy * 0.12, 0.0), (0.16, 0.025, 0.24))               # klemplaten rond de as
for rx in (1.8, 3.4, 5.0):
    bp.box("reflector", (rx, 0.092, 0.0), (0.12, 0.006, 0.06))
    bp.box("reflector", (rx, -0.092, 0.0), (0.12, 0.006, 0.06))
bp.box("steel", (ARM_LEN - 0.55 + 0.03, 0, 0.0), (0.04, 0.18, 0.16))           # eindkap
arm_objs = bp.finish(0.004)
for o in arm_objs:
    if o.name.endswith("_verf"):
        arm_uv(o, ARM_LEN)

# clip "Open": arm van waterpas naar 82 graden (rotatie om Y, + X omhoog = negatieve hoek)
boom.rotation_mode = "XYZ"
act = bpy.data.actions.new("Open")
act.use_fake_user = True
boom.animation_data_create()
boom.animation_data.action = act
for fr, ang in ((0, 0.0), (45, -math.radians(OPEN_DEG))):
    boom.rotation_euler = (0, ang, 0)
    boom.keyframe_insert("rotation_euler", frame=fr)
for lay in act.layers:
    for st in lay.strips:
        for cb in st.channelbags:
            for fc in cb.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "BEZIER"
                    kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
scene.frame_start, scene.frame_end = 0, 45
boom.rotation_euler = (0, 0, 0)

# ================= Wachthuis =================
hut = bpy.data.objects.new("Wachthuis", None)
scene.collection.objects.link(hut)
hp = Part("Wachthuis", hut)
W, D, H, T = 2.3, 2.3, 2.5, 0.08
hp.box("concrete", (0, 0, 0.09), (W + 0.3, D + 0.3, 0.18))                      # betonplaat
hp.box("concrete", (0, 0, 0.19), (W + 0.04, D + 0.04, 0.03))
# vuil/modderrand onderaan (iets groter dan de wand): donker beton, 3 mm
hp.box("concrete", (0, 0, 0.27), (W + 0.012, D + 0.012, 0.18))
z0 = 0.2
wall_h = H - z0 - 0.12
cz = z0 + wall_h / 2
hp.box("olive", (-(W / 2 - T / 2), 0, cz), (T, D, wall_h))                       # achter... (zij -X)
hp.box("olive", (0, -(D / 2 - T / 2), cz), (W, T, wall_h))                       # achterwand (-Y)
# +X zijde met deur (deur 0,8 breed, in het midden-achter)
hp.box("olive", ((W / 2 - T / 2), -0.65, cz), (T, 1.0, wall_h))
hp.box("olive", ((W / 2 - T / 2), 0.85, cz), (T, 0.6, wall_h))
hp.box("olive", ((W / 2 - T / 2), 0.2, z0 + 2.05 + (wall_h - 2.05) / 2), (T, 0.8, wall_h - 2.05))
hp.box("steel", ((W / 2 + 0.005), 0.2, z0 + 1.0), (0.04, 0.78, 2.0))               # deurblad (dicht)
hp.box("steel", ((W / 2 + 0.04), -0.1, z0 + 1.0), (0.03, 0.07, 0.03))              # kruk
for dz in (0.35, 1.7):
    hp.box("steel", ((W / 2 + 0.03), 0.62, z0 + dz), (0.03, 0.04, 0.15))             # scharnieren
# voorwand (+Y) met raam 1,5 x 0,8 op 1,0 m
FY = D / 2 - T / 2
wx0, wx1 = -0.75, 0.75
sill, top = z0 + 0.95, z0 + 1.8
hp.box("olive", (0, FY, z0 + (sill - z0) / 2), (W, T, sill - z0))
hp.box("olive", (0, FY, top + (z0 + wall_h - top) / 2), (W, T, z0 + wall_h - top))
for sx in (-1, 1):
    hp.box("olive", (sx * ((W / 2 + wx1) / 2), FY, (sill + top) / 2), (W / 2 - wx1, T, top - sill))
hp.box("glas", (0, FY - 0.01, (sill + top) / 2), (wx1 - wx0, 0.02, top - sill))
for dx in (wx0, wx1, 0):
    hp.box("timber", (dx, FY + 0.01, (sill + top) / 2), (0.05, 0.05, top - sill))
hp.box("timber", (0, FY + 0.01, sill), (wx1 - wx0 + 0.1, 0.07, 0.05))
hp.box("timber", (0, FY + 0.01, top), (wx1 - wx0 + 0.1, 0.07, 0.05))
hp.box("timber", (0, FY + 0.08, sill - 0.04), (wx1 - wx0 + 0.3, 0.18, 0.04))      # vensterbank
# luifel: schuin canvas met twee houten steunarmen
for sx in (-1, 1):
    hp.beam("timber", (sx * 0.9, D / 2 + 0.02, z0 + 1.95), (sx * 0.9, D / 2 + 0.95, z0 + 1.55), 0.06)
    hp.beam("timber", (sx * 0.9, D / 2 + 0.95, z0 + 1.55), (sx * 0.9, D / 2 + 0.95, z0 + 0.0), 0.07)
cb = hp.b("canvas")
a, b2 = Vector((-1.2, D / 2 + 0.0, z0 + 2.05)), Vector((1.2, D / 2 + 1.05, z0 + 1.6))
vs = [cb.verts.new(p) for p in ((a.x, a.y, a.z), (b2.x, a.y, a.z), (b2.x, b2.y, b2.z), (a.x, b2.y, b2.z))]
for i, v in enumerate(vs):
    pass
vs2 = [cb.verts.new((v.co.x, v.co.y, v.co.z - 0.025)) for v in vs]
cb.faces.new(vs); cb.faces.new(vs2[::-1])
for i in range(4):
    cb.faces.new((vs[i], vs[(i + 1) % 4], vs2[(i + 1) % 4], vs2[i]))
# hoekpalen, dakrand en dak
for sx in (-1, 1):
    for sy in (-1, 1):
        hp.box("timber", (sx * (W / 2 + 0.01), sy * (D / 2 + 0.01), z0 + wall_h / 2), (0.1, 0.1, wall_h))
hp.box("timber", (0, 0, z0 + wall_h + 0.04), (W + 0.1, D + 0.1, 0.1))            # dakrand
roof = hp.b("roof")
corrugated(roof, W + 0.5, D / 2 + 0.25, z0 + wall_h + 0.22, z0 + wall_h + 0.09, 1)
corrugated(roof, W + 0.5, D / 2 + 0.25, z0 + wall_h + 0.22, z0 + wall_h + 0.09, -1)
bmesh.ops.translate(roof, verts=roof.verts, vec=(0, 0, 0))
hp.box("steel", (-0.6, -0.5, z0 + wall_h + 0.4), (0.4, 0.4, 0.3))                   # ventilatiekast
hp.cyl("steel", (0.55, -0.55, z0 + wall_h + 0.55), 0.06, 0.6, 10)                    # schoorsteenpijp
hp.cyl("steel", (0.55, -0.55, z0 + wall_h + 0.88), 0.09, 0.05, 10)
# lamp boven de deur (kooi) + kabel
hp.box("steel", ((W / 2 + 0.1), 0.2, z0 + 2.2), (0.16, 0.14, 0.14))
hp.beam("steel", ((W / 2 + 0.01), 0.2, z0 + 2.3), ((W / 2 + 0.01), 0.2, z0 + wall_h), 0.02)
# kleine leunende details: een oud krat naast de deur en een brandblusser aan de wand
hp.cyl("reflector", (-(W / 2 + 0.07), 0.6, z0 + 1.0), 0.07, 0.35, 10)
hp.box("steel", (-(W / 2 + 0.04), 0.6, z0 + 1.1), (0.03, 0.06, 0.25))
hp.finish(0.006)
hut.location = (0, -4.5, 0)   # in de glb naast de slagboom, zodat beide zichtbaar zijn; de game zet hem zelf neer
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "wachtpost.blend"))
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "wachtpost.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          export_materials="EXPORT", export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                          export_cameras=False, export_lights=False)
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("WACHTPOST triangles", tris)
