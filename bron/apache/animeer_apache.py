"""Voegt vlieganimaties toe aan apache.blend en exporteert apache.glb met losse clips voor Godot.
Gebruik: python3 animeer_apache.py <map met apache.blend>
Hiërarchie wordt Apache > Body > (RompMesh, Rotor, Staartrotor); de clips bewegen alleen Body en
de rotors, zodat het spel zelf de positie van 'Apache' kan bepalen."""
import math, os, sys
import bpy

DIR = os.path.abspath(sys.argv[1])
bpy.ops.wm.open_mainfile(filepath=os.path.join(DIR, "apache.blend"))
scene = bpy.context.scene
FPS = 30
scene.render.fps = FPS

body = bpy.data.objects["Apache"]
body.name = "Body"
top = bpy.data.objects.new("Apache", None)
scene.collection.objects.link(top)
body.parent = top
rotor = bpy.data.objects["Rotor"]
staart = bpy.data.objects["Staartrotor"]
for o in (body, rotor, staart):
    o.rotation_mode = "XYZ"
ROTOR_BASE = rotor.location.copy()
STAART_BASE = staart.location.copy()

ROTOR_RPS = 4.0      # hoofdrotor omwentelingen per seconde (echt ~4,8)
STAART_RPS = 12.0    # staartrotor
HOVER_Z = 3.0


def ease(t):
    return t * t * (3 - 2 * t)


def clip(name, seconds, pose, rotor_speed=lambda t: 1.0):
    """pose(t) -> (x, y, z, pitch, roll, yaw) voor Body; t in seconden. rotor_speed(t) 0..1."""
    frames = int(seconds * FPS)
    acts = {}
    for o in (body, rotor, staart):
        o.animation_data_create()
        a = bpy.data.actions.new(f"{name}_{o.name}")
        o.animation_data.action = a
        acts[o] = a
    angle_r = angle_s = 0.0
    for f in range(frames + 1):
        t = f / FPS
        x, y, z, pitch, roll, yaw = pose(t)
        body.location = (x, y, z)
        body.rotation_euler = (pitch, roll, yaw)
        body.keyframe_insert("location", frame=f)
        body.keyframe_insert("rotation_euler", frame=f)
        if f:
            sp = rotor_speed(t)
            angle_r += 2 * math.pi * ROTOR_RPS * sp / FPS
            angle_s += 2 * math.pi * STAART_RPS * sp / FPS
        rotor.rotation_euler = (0, 0, angle_r)
        staart.rotation_euler = (angle_s, 0, 0)
        rotor.keyframe_insert("rotation_euler", frame=f)
        staart.keyframe_insert("rotation_euler", frame=f)
    for o, a in acts.items():
        for layer in getattr(a, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for k in fc.keyframe_points:
                            k.interpolation = "LINEAR"
        for fc in getattr(a, "fcurves", []):
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        tr = o.animation_data.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, a)
        st.name = name
        o.animation_data.action = None
    return frames


def sway(t, period, amp, phase=0.0):
    return amp * math.sin(2 * math.pi * t / period + phase)


# Clip-lengtes zijn veelvouden van 1/ROTOR_RPS en van elke golfperiode, zodat lussen naadloos zijn.
# Grond: stationair draaiende rotor, de heli staat stil.
clip("Grond-loop", 4.0, lambda t: (0, 0, 0.004 * math.sin(2 * math.pi * t * 8), 0.0015 * math.sin(2 * math.pi * t * 8), 0, 0), lambda t: 0.25)

# Opstijgen: rotor op toeren, eerst licht worden, neus iets omhoog, dan rustig naar zweefhoogte.
def opstijgen(t):
    k = ease(max(0.0, min(1.0, (t - 1.0) / 3.0)))
    z = HOVER_Z * k
    pitch = math.radians(3) * math.sin(math.pi * k)
    roll = math.radians(1.2) * math.sin(math.pi * k * 2) * (1 - k)
    return (0, 0, z, pitch, roll, 0)
clip("Opstijgen", 4.0, opstijgen, lambda t: min(1.0, 0.25 + t * 0.75))

# Zweven: kleine deining en schommeling, zoals een piloot die op zijn plek blijft hangen.
clip("Zweven-loop", 4.0, lambda t: (
    sway(t, 4.0, 0.12), sway(t, 2.0, 0.06, 1.0), HOVER_Z + sway(t, 2.0, 0.14),
    sway(t, 4.0, math.radians(1.2), 0.5), sway(t, 2.0, math.radians(1.5)), sway(t, 4.0, math.radians(2.0), 1.3)))

# Vliegen: neus omlaag voor snelheid, lichte rol en deining door de luchtstroom.
clip("Vliegen-loop", 4.0, lambda t: (
    0, 0, HOVER_Z + sway(t, 2.0, 0.1),
    math.radians(-11) + sway(t, 2.0, math.radians(0.8)), sway(t, 4.0, math.radians(2.0)), sway(t, 4.0, math.radians(1.0))))

# Bocht: in de bocht hangen (rol 22 graden), neus iets omlaag.
clip("Bocht-loop", 4.0, lambda t: (
    0, 0, HOVER_Z + sway(t, 2.0, 0.08),
    math.radians(-7) + sway(t, 2.0, math.radians(0.6)), math.radians(22) + sway(t, 4.0, math.radians(1.5)), 0))

scene.frame_start, scene.frame_end = 1, 121
body.location = (0, 0, 0)
body.rotation_euler = (0, 0, 0)
rotor.rotation_euler = staart.rotation_euler = (0, 0, 0)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(DIR, "apache.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR, "apache_anim.blend"))
print("KLAAR")
