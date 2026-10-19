"""Rendert een filmpje: de Apache start op een helipad in de jungle, stijgt op, draait, vliegt langs de camera
en zwenkt weg. Gebruik: python3 vlucht_film.py <apache_anim.blend> <uitmap> [start eind] [--test]"""
import math, os, sys, random
import bpy
from mathutils import Vector, Euler

blend, OUT = sys.argv[1], os.path.abspath(sys.argv[2])
args = [a for a in sys.argv[3:] if not a.startswith("--")]
TEST = "--test" in sys.argv
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
FPS = 24
DUR = 13.0
scene.render.fps = FPS
N = int(DUR * FPS)
scene.frame_start, scene.frame_end = 1, N

body = bpy.data.objects["Body"]
rotor = bpy.data.objects["Rotor"]
staart = bpy.data.objects["Staartrotor"]
for o in (body, rotor, staart):
    if o.animation_data:
        for tr in list(o.animation_data.nla_tracks):
            o.animation_data.nla_tracks.remove(tr)


def mat(name, color, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    return m


def noise_mat(name, c1, c2, scale):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 1.0
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = 8
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (*[c ** 2.2 for c in c1], 1)
    r.color_ramp.elements[1].color = (*[c ** 2.2 for c in c2], 1)
    r.color_ramp.elements[0].position = 0.4
    r.color_ramp.elements[1].position = 0.65
    nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    return m


# ---------- wereld: jungle-bodem, helipad, palmen en struiken ----------
bpy.ops.mesh.primitive_plane_add(size=900, location=(0, 0, 0))
grond = bpy.context.active_object
grond.data.materials.append(noise_mat("Bodem", (0.12, 0.18, 0.07), (0.26, 0.21, 0.12), 0.05))

bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0.02))
pad = bpy.context.active_object
pad.scale = (16, 16, 1)
pad.data.materials.append(noise_mat("Beton", (0.38, 0.37, 0.33), (0.48, 0.47, 0.42), 2.0))
wit = mat("Wit", (0.85, 0.85, 0.8), 0.7)
for loc, sc in (((-1.6, 0, 0.03), (0.35, 2.4, 1)), ((1.6, 0, 0.03), (0.35, 2.4, 1)), ((0, 0, 0.03), (1.6, 0.35, 1))):
    bpy.ops.mesh.primitive_plane_add(size=2, location=loc)
    b = bpy.context.active_object
    b.scale = sc
    b.data.materials.append(wit)
bpy.ops.mesh.primitive_torus_add(major_radius=6.0, minor_radius=0.12, location=(0, 0, 0.03))
bpy.context.active_object.scale.z = 0.05
bpy.context.active_object.data.materials.append(wit)

stam_m = mat("Stam", (0.30, 0.24, 0.17))
blad_m = noise_mat("Blad", (0.10, 0.20, 0.05), (0.20, 0.33, 0.08), 3.0)
struik_m = noise_mat("Struik", (0.08, 0.16, 0.05), (0.16, 0.27, 0.07), 2.0)
bib = bpy.data.collections.new("Bibliotheek")
scene.collection.children.link(bib)
layer_coll = bpy.context.view_layer.layer_collection.children["Bibliotheek"]


def palm(name, h):
    coll = bpy.data.collections.new(name)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.35, radius2=0.2, depth=h, location=(0, 0, h / 2))
    st = bpy.context.active_object
    st.data.materials.append(stam_m)
    parts = [st]
    from mathutils import Matrix
    for i in range(9):
        a = i * math.tau / 9 + (i % 2) * 0.2
        beta = math.radians(100 + (i % 3) * 12)
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.7, radius2=0.04, depth=4.4)
        f = bpy.context.active_object
        f.scale = (1, 0.1, 1)
        R = Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(beta, 4, "Y")
        f.matrix_world = Matrix.Translation((0, 0, h)) @ R @ Matrix.Translation((0, 0, 2.0)) @ Matrix.Diagonal((1, 0.1, 1, 1))
        f.data.materials.append(blad_m)
        parts.append(f)
    for p in parts:
        for c in p.users_collection:
            c.objects.unlink(p)
        coll.objects.link(p)
    bib.children.link(coll)
    return coll


def struik(name):
    coll = bpy.data.collections.new(name)
    for i in range(3):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.3, location=(i * 0.8 - 0.8, (i % 2) * 0.6, 0.7))
        s = bpy.context.active_object
        s.scale = (1, 1, 0.75)
        s.data.materials.append(struik_m)
        for c in s.users_collection:
            c.objects.unlink(s)
        coll.objects.link(s)
    bib.children.link(coll)
    return coll


soorten = [palm("PalmA", 9), palm("PalmB", 12), palm("PalmC", 7), struik("Struik")]
layer_coll.exclude = True
rng = random.Random(4)
n = 0
while n < (400 if TEST else 3600):
    r = 22 + rng.expovariate(1 / 45.0)
    a = rng.uniform(0, math.tau)
    x, y = math.cos(a) * r, math.sin(a) * r + 40
    # open plek rond het platform en vrij zicht vanaf de camera
    u = max(0.0, min(1.0, (x * 26 + y * 34) / (26 * 26 + 34 * 34)))
    if math.hypot(x, y) < 30 or math.hypot(x - 26 * u, y - 34 * u) < 12:
        continue
    k = rng.choice(soorten + [soorten[3]])
    e = bpy.data.objects.new(f"Boom{n}", None)
    e.instance_type = "COLLECTION"
    e.instance_collection = k
    e.location = (x, y, 0)
    e.rotation_euler.z = rng.uniform(0, math.tau)
    s = rng.uniform(0.8, 1.3)
    e.scale = (s, s, s)
    scene.collection.objects.link(e)
    n += 1

# ---------- licht: tropische zon en lucht ----------
world = bpy.data.worlds.new("Lucht")
scene.world = world
world.use_nodes = True
sky = world.node_tree.nodes.new("ShaderNodeTexSky")
try:
    sky.sky_type = "NISHITA"
except TypeError:
    pass
sky.sun_elevation = math.radians(38)
sky.sun_rotation = math.radians(130)
world.node_tree.links.new(sky.outputs["Color"], world.node_tree.nodes["Background"].inputs["Color"])
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18
zon = bpy.data.objects.new("Zon", bpy.data.lights.new("Zon", "SUN"))
zon.data.energy = 3.0
scene.view_settings.exposure = -0.6
zon.data.angle = math.radians(2)
zon.rotation_euler = (math.radians(52), 0, math.radians(130 + 90))
scene.collection.objects.link(zon)
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast" if "AgX - Medium High Contrast" in [i.identifier for i in scene.view_settings.bl_rna.properties["look"].enum_items] else "None"


# ---------- vliegroute: snelheid, koers en hoogte; standen volgen uit de versnelling ----------
def smooth(a, b, t0, t1, t):
    k = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
    return a + (b - a) * k * k * (3 - 2 * k)


def stuur(t):
    hoogte = smooth(0, 7.0, 2.0, 5.5, t) + smooth(0, 9.0, 7.5, 12.0, t)
    snelheid = smooth(0, 9.0, 6.5, 8.5, t) + smooth(0, 22.0, 8.5, 12.0, t)
    draai = (math.sin(math.pi * min(1, max(0, (t - 4.5) / 2.5))) * -0.12) + smooth(0, 0.34, 9.0, 10.5, t)
    return hoogte, snelheid, draai


pos = Vector((0, 0, 0))
koers = 0.0
prev_v = 0.0
rol = pitch = 0.0
hang_y = 0.0
rotor_a = staart_a = 0.0
dt = 1.0 / FPS
pad_pts = []
for f in range(N + 1):
    t = f * dt
    h, v, w = stuur(t)
    koers += w * dt
    fwd = Vector((-math.sin(koers), math.cos(koers), 0))
    pos += fwd * v * dt
    acc = (v - prev_v) / dt
    prev_v = v
    want_pitch = -math.radians(1.6) * acc - math.radians(0.28) * v + (math.radians(2.5) if 2.0 < t < 4.0 else 0)
    want_rol = -math.atan(v * w / 9.81) * 0.9 + math.radians(1.5) * w * (v < 2)
    pitch += (want_pitch - pitch) * min(1.0, dt * 3.0)
    rol += (want_rol - rol) * min(1.0, dt * 2.5)
    lucht = smooth(0, 1, 2.2, 3.5, t)
    wiebel = Vector((math.sin(t * 1.7) * 0.10, math.sin(t * 1.3 + 1) * 0.08, math.sin(t * 2.1) * 0.12)) * lucht
    body.location = (pos.x + wiebel.x, pos.y + wiebel.y, h + wiebel.z)
    body.rotation_euler = (pitch + math.sin(t * 1.1) * 0.012 * lucht, rol + math.sin(t * 1.6) * 0.015 * lucht, koers)
    body.keyframe_insert("location", frame=f + 1)
    body.keyframe_insert("rotation_euler", frame=f + 1)
    toeren = smooth(0.25, 1.0, 0.0, 2.2, t)
    rotor_a += math.tau * 4.4 * toeren * dt
    staart_a += math.tau * 13.0 * toeren * dt
    rotor.rotation_euler = (0, 0, rotor_a)
    staart.rotation_euler = (staart_a, 0, 0)
    rotor.keyframe_insert("rotation_euler", frame=f + 1)
    staart.keyframe_insert("rotation_euler", frame=f + 1)
    pad_pts.append(Vector(body.location))

# ---------- camera: laag naast het platform, volgt soepel met vertraging ----------
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 40
cam.data.sensor_width = 36
mik = Vector(pad_pts[0]) + Vector((0, 0, 2))
cpos = Vector((26, 34, 2.4))
for f, p in enumerate(pad_pts):
    t = f * dt
    doel = p + Vector((0, 0, 1.6))
    mik += (doel - mik) * min(1.0, dt * 2.2)
    # vanaf 9 s schuift de camera mee zodat de heli niet te klein wordt
    volg = smooth(0, 1, 8.5, 13.0, t)
    want = cpos.lerp(p + Vector((26, -34, 3.5)), volg * 0.8)
    cam.location = want + Vector((math.sin(t * 0.9) * 0.05, 0, math.sin(t * 1.3) * 0.04))
    cam.rotation_euler = (mik - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.keyframe_insert("location", frame=f + 1)
    cam.keyframe_insert("rotation_euler", frame=f + 1)

# ---------- render ----------
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 8 if TEST else 16
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 4
scene.render.use_motion_blur = True
scene.render.motion_blur_shutter = 0.5
scene.render.resolution_x, scene.render.resolution_y = (640, 360) if TEST else (960, 540)
scene.render.image_settings.file_format = "JPEG"
scene.render.image_settings.quality = 92
if len(args) >= 2:
    scene.frame_start, scene.frame_end = int(args[0]), int(args[1])
scene.frame_step = int(os.environ.get("STEP", "1"))
scene.render.filepath = os.path.join(OUT, "f")
bpy.ops.render.render(animation=True)
print("KLAAR", N)
