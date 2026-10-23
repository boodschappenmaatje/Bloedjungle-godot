"""Zit-animatie "zitten" voor het mannetje (assets/soldaat.glb): zittend op een bank in de vrachtwagen, geweer
in de handen zoals in "stil". Het bovenlijf komt uit de clip "stil", de benen worden geknikt; een rustige lus
met wat deinen van de rit.
Gebruik: python3 maak_zitten.py uit/   -> uit/zitten.blend en uit/zitten.glb (alleen skelet + animatie)
De heup blijft op dezelfde hoogte als staand (0,93 m boven de voeten): de zitting moet dus 0,85 m boven de
oorsprong van het mannetje liggen (in mannetjesmaat, het spel schaalt nog met SOLDIER_SCALE)."""
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
LUS = 60  # 2 s

# bovenlijf uit "stil" (frame 0) overnemen
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions["stil"]
scene.frame_set(0)
bpy.context.view_layer.update()
basis = {pb.name: pb.matrix_basis.copy() for pb in pose}
arm.animation_data.action = None


def aim(name, d):
    """Draai bot `name` langs richting d (ruimte van het skelet), met zo min mogelijk draaiing."""
    pb = pose[name]
    pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    head = pb.matrix.translation.copy()
    rest = arm.data.bones[name].matrix_local.to_3x3()
    q = Vector(rest.col[1]).rotation_difference(Vector(d).normalized())
    pb.matrix = Matrix.Translation(head) @ (q.to_matrix() @ rest).to_4x4()
    bpy.context.view_layer.update()


F = -1.0  # vooruit = -Y


def v(x, y, z):
    return (x, F * y, z)


def set_pose(t):
    """t = 0..1 over de lus: het lijf deint wat mee met de rit."""
    for pb in pose:
        pb.matrix_basis = basis[pb.name].copy()
    bpy.context.view_layer.update()
    for s in (1, -1):
        sd = "L" if s > 0 else "R"
        # dijen vooruit en iets uit elkaar, schenen naar beneden, voeten plat
        aim("DEF-thigh" + sd, v(0.22 * s, 1.0, -0.06))
        aim("DEF-shin" + sd, v(0.04 * s, 0.22, -1.0))
        aim("DEF-foot" + sd, v(0.0, 0.95, -0.3))
        aim("DEF-toe" + sd, v(0.0, 1.0, -0.05))
    # deinen: het bovenlijf knikt een beetje voor- en achterover en opzij
    a = math.sin(t * math.tau)
    b = math.sin(t * math.tau * 2 + 0.8)
    for n, k in (("DEF-spine001", 1.0), ("DEF-spine002", 0.7), ("DEF-neck", 0.5)):
        pb = pose[n]
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = pb.rotation_quaternion @ Matrix.Rotation(0.035 * a * k, 3, 'X').to_quaternion() \
            @ Matrix.Rotation(0.02 * b * k, 3, 'Z').to_quaternion()
    bpy.context.view_layer.update()


act = bpy.data.actions.new("zitten")
act.use_fake_user = True
arm.animation_data.action = act
for fr in range(0, LUS + 1, 10):
    set_pose(fr / LUS)
    for pb in pose:
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert("rotation_quaternion", frame=fr)
        pb.keyframe_insert("location", frame=fr)
act.frame_range = (0, LUS)
scene.frame_start, scene.frame_end = 0, LUS
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "zitten.blend"))

for o in list(bpy.data.objects):
    if o.type == 'MESH':
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name != "zitten":
        bpy.data.actions.remove(a)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "zitten.glb"), export_format='GLB', export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_apply=False)
