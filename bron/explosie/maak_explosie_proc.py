"""Explosie voor Bloedjungle zonder vloeistofsimulatie: een volume in Cycles waarvan vorm, turbulentie, hitte en rook
over de tijd lopen (vuurbal met verstoorde rand, opstijgende rookpluim, stofring over de grond).
Gebruik:  python maak_explosie_proc.py <uitmap> [beelden] [px] [samples] [eerste] [laatste]
Schrijft <uitmap>/vuur_%03d.png met transparante achtergrond; plak.py zet ze tot één vel."""
import bpy, sys, os, math

out = sys.argv[1]
A = sys.argv[2:]
N = int(A[0]) if len(A) > 0 else 36
PX = int(A[1]) if len(A) > 1 else 512
SAMPLES = int(A[2]) if len(A) > 2 else 48
FIRST = int(A[3]) if len(A) > 3 else 0
LAST = int(A[4]) if len(A) > 4 else N - 1
VARIANT = int(A[5]) if len(A) > 5 else 0  # 0 = de eerste explosie; 1 = hoog en smal; 2 = laag en breed (grondexplosie)
SEED = VARIANT * 13.7
HIGH = {0: 1.0, 1: 1.25, 2: 0.7}[VARIANT]
WIDE = {0: 1.0, 1: 0.85, 2: 1.3}[VARIANT]
os.makedirs(out, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 30
scn.frame_start = 0
scn.frame_end = N - 1

# --- het volume: een kubus van 8 x 8 x 8 m met de onderkant op de grond
bpy.ops.mesh.primitive_cube_add(size=1.0)
dom = bpy.context.object
dom.scale = (8.0, 8.0, 8.0)
dom.location = (0, 0, 4.0)
mat = bpy.data.materials.new("Explosie")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
nodes, links = nt.nodes, nt.links


def new(kind, **kw):
    n = nodes.new(kind)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def val(name, keys):
    """Een waarde die in de tijd verandert: keys = [(t, waarde), ...] met t van 0 tot 1."""
    n = new("ShaderNodeValue", label=name)
    n.name = name
    for t, v in keys:
        n.outputs[0].default_value = v
        n.outputs[0].keyframe_insert("default_value", frame=t * (N - 1))
    for fc in nt.animation_data.action.layers[0].strips[0].channelbags[0].fcurves if hasattr(nt.animation_data.action, "layers") else nt.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
    return n.outputs[0]


def math(op, a, b=None, clamp=False):
    n = new("ShaderNodeMath", operation=op, use_clamp=clamp)
    for i, x in enumerate((a, b)):
        if x is None:
            continue
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = x
        else:
            links.new(x, n.inputs[i])
    return n.outputs[0]


def vmath(op, a, b=None):
    n = new("ShaderNodeVectorMath", operation=op)
    for i, x in enumerate((a, b)):
        if x is None:
            continue
        if isinstance(x, (tuple, list)):
            n.inputs[i].default_value = x
        else:
            links.new(x, n.inputs[i])
    return n


def smooth(x, lo, hi):
    return math('SMOOTH_STEP' if False else 'DIVIDE', 1, 1) if False else _smooth(x, lo, hi)


def _smooth(x, lo, hi):
    m = new("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    links.new(x, m.inputs[0])
    m.inputs[1].default_value = lo
    m.inputs[2].default_value = hi
    m.inputs[3].default_value = 0.0
    m.inputs[4].default_value = 1.0
    m.clamp = True
    return m.outputs[0]


def mapr(x, a, b, c, d):
    m = new("ShaderNodeMapRange")
    links.new(x, m.inputs[0])
    m.inputs[1].default_value, m.inputs[2].default_value = a, b
    m.inputs[3].default_value, m.inputs[4].default_value = c, d
    m.clamp = True
    return m.outputs[0]


geo = new("ShaderNodeNewGeometry")
P = geo.outputs["Position"]

# tijdgestuurde waarden (t = 0 begin, 1 einde van het beeldreeks)
Tt = val("t", [(0, 0.0), (1, 1.0)])
R_fire = val("fire_radius", [(0, 0.35), (0.08, 1.9 * WIDE), (0.3, 2.5 * WIDE), (1, 2.9 * WIDE)])
Z_fire = val("fire_height", [(0, 1.0), (0.3, 1.0 + 0.9 * HIGH), (1, 1.0 + 2.2 * HIGH)])
E_fire = val("fire_power", [(0, 0.0), (0.03, 1.0), (0.18, 0.6), (0.42, 0.1), (1, 0.0)])
R_smoke = val("smoke_radius", [(0, 0.2), (0.1, 1.1), (0.4, 2.0), (1, 2.6)])
Z_smoke = val("smoke_height", [(0, 1.0), (0.15, 1.0 + 1.0 * HIGH), (0.5, 1.0 + 2.8 * HIGH), (1, 1.0 + 4.3 * HIGH)])
D_smoke = val("smoke_density", [(0, 0.0), (0.06, 0.9), (0.7, 0.8), (1, 0.0)])
R_ring = val("ring_radius", [(0, 0.4), (0.08, 2.0), (0.4, 2.7), (1, 3.0)])
D_ring = val("ring_density", [(0, 0.0), (0.04, 1.0), (0.45, 0.5), (1, 0.0)])


def warped(P_in, scale_, amp_out, w_scale, seed_off):
    """Verstoor de plek met ruis, zodat bollen zich als woeste wolken gedragen."""
    w = math('MULTIPLY', Tt, w_scale)
    w = math('ADD', w, seed_off)
    nz = new("ShaderNodeTexNoise", noise_dimensions='4D', noise_type='FBM', normalize=True)
    nz.inputs["Scale"].default_value = scale_
    nz.inputs["Detail"].default_value = 3.0
    nz.inputs["Roughness"].default_value = 0.6
    nz.inputs["Lacunarity"].default_value = 2.1
    links.new(P_in, nz.inputs["Vector"])
    links.new(w, nz.inputs["W"])
    off = vmath('SUBTRACT', nz.outputs["Color"], (0.5, 0.5, 0.5))
    off = vmath('SCALE', off.outputs[0])
    links.new(amp_out, off.inputs["Scale"])
    return vmath('ADD', P_in, off.outputs[0]).outputs[0], nz.outputs["Fac"]


def sphere_field(center_z, radius, warp_amp, noise_scale, w_scale, seed_off, hard):
    cz = center_z
    c = new("ShaderNodeCombineXYZ")
    c.inputs[0].default_value = 0.0
    c.inputs[1].default_value = 0.0
    links.new(cz, c.inputs[2])
    amp = math('MULTIPLY', radius, warp_amp)
    Pw, fac = warped(P, noise_scale, amp, w_scale, seed_off)
    dv = vmath('SUBTRACT', Pw, c.outputs[0])
    dist = vmath('LENGTH', dv.outputs[0]).outputs["Value"]
    d = math('DIVIDE', dist, radius)
    return d, fac


# --- vuurbal: dichtheid van binnen naar buiten afnemend, aan de rand weggevreten door fijne ruis
d_f, n_f = sphere_field(Z_fire, R_fire, 1.25, 1.5, 2.5, SEED, 0.5)
body = math('SUBTRACT', 1.0, d_f)
eaten = math('ADD', body, math('MULTIPLY', math('SUBTRACT', n_f, 0.5), 1.1))
fire_dens = _smooth(eaten, 0.12, 0.42)
core = _smooth(math('SUBTRACT', 1.0, math('MULTIPLY', d_f, 1.25)), 0.0, 0.8)

# --- rookpluim: opstijgende bollen, donkerder en traag
d_s, n_s = sphere_field(Z_smoke, R_smoke, 1.2, 0.9, 1.2, 7.3 + SEED, 0.4)
sm_body = math('SUBTRACT', 1.0, d_s)
sm_eat = math('ADD', sm_body, math('MULTIPLY', math('SUBTRACT', n_s, 0.5), 1.3))
smoke1 = _smooth(sm_eat, 0.05, 0.6)
# een tweede, lagere bol als stam van de pluim
Z_low = math('MULTIPLY', Z_smoke, 0.55)
R_low = math('MULTIPLY', R_smoke, 0.7)
d_l, n_l = sphere_field(Z_low, R_low, 1.1, 1.0, 1.4, 3.1 + SEED, 0.4)
lo_body = math('SUBTRACT', 1.0, d_l)
lo_eat = math('ADD', lo_body, math('MULTIPLY', math('SUBTRACT', n_l, 0.5), 1.3))
smoke2 = _smooth(lo_eat, 0.05, 0.6)
smoke = math('MAXIMUM', smoke1, math('MULTIPLY', smoke2, 0.8))

# --- stofring: lage schijf die over de grond uitwaaiert
xy = new("ShaderNodeSeparateXYZ")
links.new(P, xy.inputs[0])
rad = math('POWER', math('ADD', math('MULTIPLY', xy.outputs[0], xy.outputs[0]), math('MULTIPLY', xy.outputs[1], xy.outputs[1])), 0.5)
Pw_r, n_r = warped(P, 1.3, math('MULTIPLY', R_ring, 0.35), 1.8, 11.0)
xy2 = new("ShaderNodeSeparateXYZ")
links.new(Pw_r, xy2.inputs[0])
rad2 = math('POWER', math('ADD', math('MULTIPLY', xy2.outputs[0], xy2.outputs[0]), math('MULTIPLY', xy2.outputs[1], xy2.outputs[1])), 0.5)
dr = math('DIVIDE', math('ABSOLUTE', math('SUBTRACT', rad2, R_ring)), 0.7)
ring_r = math('SUBTRACT', 1.0, _smooth(dr, 0.0, 1.0))
zh = math('DIVIDE', xy2.outputs[2], math('ADD', 0.3, math('MULTIPLY', R_ring, 0.18)))
ring_z = math('SUBTRACT', 1.0, _smooth(math('ABSOLUTE', math('SUBTRACT', zh, 0.35)), 0.0, 1.0))
ring = math('MULTIPLY', math('MULTIPLY', ring_r, ring_z), math('MULTIPLY', math('ADD', 0.5, n_r), 1.2))

# --- samenstellen
smoke_d = math('MULTIPLY', math('MULTIPLY', smoke, D_smoke), 9.0)
fire_d = math('MULTIPLY', math('MULTIPLY', fire_dens, E_fire), 4.0)  # vuur dooft uit en geeft de rook de ruimte
ring_d = math('MULTIPLY', math('MULTIPLY', ring, D_ring), 0.0)  # de stofring staat uit: geeft een harde lijn aan de grond; het spel tekent zelf stof
dens = math('ADD', math('ADD', smoke_d, fire_d), ring_d)

heat = math('MULTIPLY', core, E_fire)
pocket = math('ADD', math('MULTIPLY', math('POWER', n_f, 2.0), 4.0), 0.25)
emis = math('MULTIPLY', math('MULTIPLY', math('MULTIPLY', fire_dens, E_fire), pocket), 6.5)
ramp = new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (0.55, 0.05, 0.005, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (1.0, 0.72, 0.3, 1)
e = ramp.color_ramp.elements.new(0.45)
e.color = (1.0, 0.3, 0.03, 1)
links.new(math('ADD', math('MULTIPLY', heat, 1.0), math('MULTIPLY', math('SUBTRACT', n_f, 0.5), 0.5)), ramp.inputs[0])

vol = new("ShaderNodeVolumePrincipled")
links.new(dens, vol.inputs["Density"])
vol.inputs["Color"].default_value = (0.09, 0.08, 0.07, 1)
vol.inputs["Anisotropy"].default_value = 0.3
links.new(emis, vol.inputs["Emission Strength"])
links.new(ramp.outputs[0], vol.inputs["Emission Color"])
outn = new("ShaderNodeOutputMaterial")
links.new(vol.outputs[0], outn.inputs["Volume"])
dom.data.materials.append(mat)

# --- licht: zon van linksboven en een zachte wereld, zodat de rook vorm heeft
sun_d = bpy.data.lights.new("Zon", 'SUN')
sun_d.energy = 4.0
sun_d.angle = math.radians(8) if False else 0.15
sun = bpy.data.objects.new("Zon", sun_d)
scn.collection.objects.link(sun)
sun.rotation_euler = (math.radians(55), 0, math.radians(35)) if False else (0.95, 0.0, 0.6)
world = bpy.data.worlds.new("Wereld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.5, 0.55, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
scn.world = world

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = 'ORTHO'
cam_d.ortho_scale = 8.0
cam = bpy.data.objects.new("Cam", cam_d)
scn.collection.objects.link(cam)
cam.location = (0, -20, 4.0)
cam.rotation_euler = (1.5708, 0, 0)
scn.camera = cam

scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = SAMPLES
scn.cycles.use_denoising = False
scn.cycles.volume_bounces = 2
scn.cycles.volume_step_rate = 3.0
scn.cycles.volume_max_steps = 160
scn.render.film_transparent = True
scn.render.resolution_x = PX
scn.render.resolution_y = PX
scn.render.image_settings.file_format = 'PNG'
scn.render.image_settings.color_mode = 'RGBA'
scn.view_settings.view_transform = 'Standard'

for i in range(FIRST, LAST + 1):
    scn.frame_set(i)
    scn.render.filepath = os.path.join(out, "vuur_%03d.png" % i)
    bpy.ops.render.render(write_still=True)
    print("beeld", i, flush=True)
print("KLAAR")
