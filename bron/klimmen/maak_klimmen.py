"""Klim-animatie "klimmen" voor het mannetje (assets/soldaat.glb): een rij haken-en-stappen op een ladder.
Gebruik: python3 maak_klimmen.py uit/   -> uit/klimmen.blend en uit/klimmen.glb (alleen skelet + animatie)
De houding wordt per bot ingesteld met een richting in ruimte van het skelet (-Y is vooruit, +Z omhoog)."""
import sys, os, math, bpy
from mathutils import Vector, Matrix

out = sys.argv[1] if len(sys.argv) > 1 else "uit/"
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(here, "../../assets/soldaat.glb"))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pose = arm.pose.bones
scene = bpy.context.scene
scene.render.fps = 30
FPS_CYCLE = 20  # frames voor een stap links + stap rechts

ORDER = [b.name for b in arm.data.bones]  # ouders komen voor kinderen


def aim(name, d):
    """Draai bot `name` zodat hij langs richting d wijst (ruimte van het skelet), met zo min mogelijk draaiing."""
    pb = pose[name]
    pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    head = pb.matrix.translation.copy()
    rest = arm.data.bones[name].matrix_local.to_3x3()
    ydir = rest.col[1]
    q = Vector(ydir).rotation_difference(Vector(d).normalized())
    rot = q.to_matrix() @ rest
    pb.matrix = Matrix.Translation(head) @ rot.to_4x4()
    bpy.context.view_layer.update()


def side(n, s):
    return n + ("L" if s > 0 else "R")


F = -1.0  # vooruit = -Y


def v(x, y, z):
    return (x, F * y, z)


def set_pose(t):
    """t = 0 .. 1: halve cyclus; t=0 linkerhand hoog, t=1 rechterhand hoog."""
    # torso blijft rechtop met een lichte voorwaartse hang
    for n, lean in (("DEF-hips", 0.0), ("DEF-spine001", 0.12), ("DEF-spine002", 0.14), ("DEF-spine003", 0.14)):
        aim(n, v(0, lean, 1))
    aim("DEF-neck", v(0, 0.2, 1))
    aim("DEF-head", v(0, 0.35, 1))
    for s in (1, -1):
        hi = t if s < 0 else 1 - t       # 1 = hoog gereikt
        lo = 1 - hi
        # arm: hoog = gestrekt omhoog naar de sport; laag = elleboog gebogen, hand bij de borst
        up = Vector(v(0.30 * s, 0.35, 0.89))
        dn = Vector(v(0.40 * s, 0.05, -0.91))
        bump = math.sin(math.pi * hi)  # onderweg de armen voor het lijf langs, niet zijwaarts
        u = (dn.lerp(up, hi) + Vector(v(-0.25 * s, 0.9 * bump, 0.0))).normalized()
        fup = Vector(v(0.10 * s, 0.35, 0.93))
        fdn = Vector(v(-0.10 * s, 0.85, 0.52))
        f = (fdn.lerp(fup, hi) + Vector(v(0.0, 0.5 * bump, 0.4 * bump))).normalized()
        aim(side("DEF-shoulder", s), v(1.0 * s, 0, 0.1))
        aim(side("DEF-upper_arm", s), (u.x, u.y, u.z))
        aim(side("DEF-forearm", s), (f.x, f.y, f.z))
        aim(side("DEF-hand", s), (f.x, f.y, f.z + 0.1))
        # been: de tegenovergestelde kant van de hand staat hoog (knie omhoog), de andere strekt naar beneden
        kn = 1 - hi                          # knie hoog als deze arm laag is
        th_hi = Vector(v(0.05 * s, 0.75, -0.66))
        th_lo = Vector(v(0.02 * s, 0.10, -0.99))
        th = th_lo.lerp(th_hi, kn).normalized()
        sh_hi = Vector(v(0.0, -0.15, -0.99))
        sh_lo = Vector(v(0.0, 0.12, -0.99))
        sh = sh_lo.lerp(sh_hi, kn).normalized()
        aim(side("DEF-thigh", s), (th.x, th.y, th.z))
        aim(side("DEF-shin", s), (sh.x, sh.y, sh.z))
        aim(side("DEF-foot", s), v(0.0, 0.7, -0.35))
        aim(side("DEF-toe", s), v(0.0, 0.8, -0.1))


act = bpy.data.actions.new("klimmen")
act.use_fake_user = True
arm.animation_data_create()
arm.animation_data.action = act
frames = [(0, 0.0), (FPS_CYCLE // 4, 0.5), (FPS_CYCLE // 2, 1.0), (3 * FPS_CYCLE // 4, 0.5), (FPS_CYCLE, 0.0)]
for fr, t in frames:
    # tussenstand: licht omhoog bij de wissel (de romp "duwt")
    set_pose(t)
    for pb in pose:
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert("rotation_quaternion", frame=fr)
        pb.keyframe_insert("location", frame=fr)
    pose["DEF-hips"].location = pose["DEF-hips"].location
act.frame_range = (0, FPS_CYCLE)
for fc in act.layers[0].strips[0].channelbags[0].fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'BEZIER'
        kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
scene.frame_start, scene.frame_end = 0, FPS_CYCLE
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "klimmen.blend"))

# alleen skelet + animatie naar glb: de game haalt het filmpje eruit en hangt het aan het mannetje
for o in list(bpy.data.objects):
    if o.type == 'MESH':
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name != "klimmen":
        bpy.data.actions.remove(a)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "klimmen.glb"), export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True, export_apply=False)
