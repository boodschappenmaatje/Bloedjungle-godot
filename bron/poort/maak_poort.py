"""Stalen schuifpoort voor Bloedjungle. Opening van -2,4 tot +2,4 m (x), buitenkant = +Y (Godot -Z), 1 eenheid = 1 meter.
De poort hangt VOOR de muur (y = 0,55) en schuift bij openen 4,8 m naar +X langs de buitenkant van de muur.
Animatie "openen" (2,5 s, 30 fps): paneel schuift open, de wielen draaien mee. Terugspelen = sluiten."""
import math, sys, os
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

G = 2.4            # halve opening
W = 2 * G + 0.2    # paneelbreedte
Y = 0.55           # afstand voor de muur
TRAVEL = 2 * G
FR = 75            # frames openen (2,5 s)

def mat(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

M = {
    "staal": mat("Staal", (0.52, 0.55, 0.58), 0.38, 0.9),
    "donker": mat("StaalDonker", (0.30, 0.32, 0.35), 0.45, 0.85),
    "geel": mat("Geel", (0.80, 0.62, 0.10), 0.6),
    "zwart": mat("Zwart", (0.05, 0.05, 0.05), 0.7),
    "metaal": mat("Metaal", (0.38, 0.39, 0.40), 0.4, 0.9),
}

def boxmesh(bm, loc, size, rot=(0, 0, 0)):
    r = bmesh.ops.create_cube(bm, size=1)
    v = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=v)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(bm, verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(bm, verts=v, vec=loc)

def make(name, bm, m, parent=None, origin=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    ob.location = origin
    return ob

root = bpy.data.objects.new("Poort", None)
scene.collection.objects.link(root)
pan = bpy.data.objects.new("Paneel", None)
scene.collection.objects.link(pan)
pan.parent = root

# ---- paneel: lijst, plaat, spijlen, schuine verstevigingen en een geel-zwarte band
b = {k: bmesh.new() for k in ("staal", "donker", "geel", "zwart")}
Z0, Z1 = 0.30, 1.52
boxmesh(b["donker"], (0, Y, Z1 - 0.07), (W, 0.16, 0.14))
boxmesh(b["donker"], (0, Y, Z0 + 0.08), (W, 0.16, 0.16))
boxmesh(b["donker"], (0, Y, 0.86), (W, 0.15, 0.08))
for sx in (-1, 1):
    boxmesh(b["donker"], (sx * (W / 2 - 0.06), Y, (Z0 + Z1) / 2), (0.12, 0.16, Z1 - Z0))
boxmesh(b["staal"], (0, Y, 0.57), (W - 0.2, 0.07, 0.56))
x = -W / 2 + 0.3
while x < W / 2 - 0.2:
    boxmesh(b["donker"], (x, Y, 1.19), (0.05, 0.05, 0.6))
    x += 0.3
for sx in (-1, 1):
    boxmesh(b["donker"], (sx * W / 4, Y + 0.03, 0.57), (0.07, 0.09, 0.78), (0, math.radians(sx * -52), 0))
n = 0
x = -W / 2 + 0.2
while x < W / 2 - 0.1:
    boxmesh(b["zwart" if n % 2 else "geel"], (x + 0.12, Y, Z0 + 0.08), (0.24, 0.18, 0.12))
    x += 0.24
    n += 1
for k, bm in b.items():
    make("Poort_" + k, bm, M[k], pan)

# ---- wielen onder het paneel (draaien mee tijdens het schuiven)
wheels = []
for i, wx in enumerate((-1.7, -1.3, 1.3, 1.7)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.14, radius2=0.14, depth=0.1)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    # spaken zodat je het draaien ziet
    boxmesh(bm, (0, 0, 0), (0.22, 0.12, 0.03))
    boxmesh(bm, (0, 0, 0), (0.03, 0.12, 0.22))
    w = make("Wiel%d" % i, bm, M["metaal"], pan, (wx, Y, 0.14))
    wheels.append(w)
    # beugel van wiel naar paneel
    bb = bmesh.new()
    boxmesh(bb, (wx, Y, 0.27), (0.1, 0.2, 0.1))
    make("Beugel%d" % i, bb, M["donker"], pan)

# ---- vaste delen: rails op de grond, bovenrail en motorkast
bs = {k: bmesh.new() for k in ("metaal", "donker", "staal")}
L0, L1 = -3.0, 3.0 + TRAVEL
boxmesh(bs["metaal"], ((L0 + L1) / 2, Y, 0.025), (L1 - L0, 0.07, 0.05))
for sx in range(int(L0), int(L1) + 1):
    boxmesh(bs["donker"], (sx + 0.5, Y, 0.012), (0.16, 0.34, 0.025))
boxmesh(bs["donker"], (-3.15, Y + 0.02, 0.32), (0.5, 0.42, 0.64))
boxmesh(bs["staal"], (-3.15, Y + 0.02, 0.66), (0.54, 0.46, 0.06))
boxmesh(bs["metaal"], (-3.15, Y + 0.24, 0.35), (0.22, 0.03, 0.22))
for k, bm in bs.items():
    make("Vast_" + k, bm, M[k], root)

# ---- animatie "openen": paneel schuift TRAVEL meter naar +X, wielen rollen mee
act = bpy.data.actions.new("openen")
act.use_fake_user = True
pan.animation_data_create()
pan.animation_data.action = act
for fr, v in ((0, 0.0), (FR, TRAVEL)):
    pan.location = (v, 0, 0)
    pan.keyframe_insert("location", frame=fr)
for w in wheels:
    w.animation_data_create()
    w.animation_data.action = bpy.data.actions.new("openen_" + w.name)
    w.rotation_mode = "XYZ"
    for fr, v in ((0, 0.0), (FR, TRAVEL / 0.14)):
        w.rotation_euler = (0, v, 0)
        w.keyframe_insert("rotation_euler", frame=fr)
# vloeiend: langzaam op gang komen en zacht stoppen
for a in [act] + [w.animation_data.action for w in wheels]:
    for lay in a.layers:
        for st in lay.strips:
            for cb in st.channelbags:
                for fc in cb.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = "BEZIER"
                        kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
scene.frame_start, scene.frame_end = 0, FR
pan.location = (0, 0, 0)
for w in wheels:
    w.rotation_euler = (0, 0, 0)
scene.frame_set(0)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "poort.blend"))
# alle animaties naar glb: voor de wielen ook een eigen actie, die de exporter in dezelfde clip samenvoegt
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "poort.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          export_animation_mode="SCENE", export_force_sampling=True)
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("TRIS", tris)
