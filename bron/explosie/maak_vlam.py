"""Lus-vlam voor brandende vaten en wrakken: een smalle, flikkerende vlam met opstijgende ruis, als beeldreeks met transparante achtergrond.
Er worden N + OVERLAP beelden gerenderd; plak_lus.py laat het einde in het begin overvloeien, zodat de reeks naadloos herhaalt.
Gebruik:  python maak_vlam.py <uitmap> [N] [overlap] [px] [samples]"""
import bpy, sys, os, math

out = sys.argv[1]
A = sys.argv[2:]
N = int(A[0]) if len(A) > 0 else 16
OVERLAP = int(A[1]) if len(A) > 1 else 8
PX = int(A[2]) if len(A) > 2 else 256
SAMPLES = int(A[3]) if len(A) > 3 else 24
os.makedirs(out, exist_ok=True)
TOTAL = N + OVERLAP

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 30
scn.frame_start = 0
scn.frame_end = TOTAL - 1

bpy.ops.mesh.primitive_cube_add(size=1.0)
dom = bpy.context.object
dom.scale = (2.4, 2.4, 3.2)
dom.location = (0, 0, 1.6)
mat = bpy.data.materials.new("Vlam")
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


def math_(op, a, b=None, clamp=False):
    n = new("ShaderNodeMath", operation=op, use_clamp=clamp)
    for i, x in enumerate((a, b)):
        if x is None:
            continue
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = x
        else:
            links.new(x, n.inputs[i])
    return n.outputs[0]


def smooth(x, lo, hi):
    m = new("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    links.new(x, m.inputs[0])
    m.inputs[1].default_value, m.inputs[2].default_value = lo, hi
    m.inputs[3].default_value, m.inputs[4].default_value = 0.0, 1.0
    m.clamp = True
    return m.outputs[0]


# tijd 0..1 over de hele reeks, via een waarde met sleutelbeelden
tn = new("ShaderNodeValue", label="t")
tn.outputs[0].default_value = 0.0
tn.outputs[0].keyframe_insert("default_value", frame=0)
tn.outputs[0].default_value = float(TOTAL) / float(N)  # N beelden = één omloop
tn.outputs[0].keyframe_insert("default_value", frame=TOTAL - 1)
for fc in nt.animation_data.action.layers[0].strips[0].channelbags[0].fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'LINEAR'
T = tn.outputs[0]

P = new("ShaderNodeNewGeometry").outputs["Position"]
sep = new("ShaderNodeSeparateXYZ")
links.new(P, sep.inputs[0])
X, Y, Z = sep.outputs[0], sep.outputs[1], sep.outputs[2]

# de ruis scrolt omhoog: het coordinaat zakt met de tijd, dus de vlam lijkt te stijgen; W laat hem ook veranderen
scroll = new("ShaderNodeCombineXYZ")
links.new(X, scroll.inputs[0])
links.new(Y, scroll.inputs[1])
links.new(math_('ADD', Z, math_('MULTIPLY', T, -2.4)), scroll.inputs[2])
nz = new("ShaderNodeTexNoise", noise_dimensions='4D', noise_type='FBM', normalize=True)
nz.inputs["Scale"].default_value = 3.6
nz.inputs["Detail"].default_value = 4.0
nz.inputs["Roughness"].default_value = 0.55
links.new(scroll.outputs[0], nz.inputs["Vector"])
links.new(math_('MULTIPLY', T, 2.2), nz.inputs["W"])
# FBM-ruis zit dicht om 0,5: uitrekken, anders zie je geen tongen
rm = new("ShaderNodeMapRange")
links.new(nz.outputs["Fac"], rm.inputs[0])
rm.inputs[1].default_value, rm.inputs[2].default_value = 0.35, 0.65
rm.inputs[3].default_value, rm.inputs[4].default_value = 0.0, 1.0
rm.clamp = True
n_f = rm.outputs[0]

# kegelvorm: smal boven, breed onder; ruis verschuift de rand zijwaarts en vreet de top weg
h = math_('DIVIDE', Z, 2.4)
radius = math_('MULTIPLY', math_('MAXIMUM', math_('SUBTRACT', 1.0, math_('POWER', math_('MAXIMUM', h, 0.0), 0.8)), 0.0), 0.62)  # breed: de vlam vult de hele opening van het vat
sway = math_('MULTIPLY', math_('SUBTRACT', n_f, 0.5), math_('MULTIPLY', math_('ADD', h, 0.2), 2.8))
rr = math_('POWER', math_('ADD', math_('MULTIPLY', X, X), math_('MULTIPLY', Y, Y)), 0.5)
d = math_('DIVIDE', rr, math_('MAXIMUM', radius, 0.02))
body = math_('SUBTRACT', 1.0, math_('ADD', d, sway))
flick = math_('ADD', body, math_('MULTIPLY', math_('SUBTRACT', n_f, 0.45), 1.8))
dens_raw = smooth(flick, 0.05, 0.5)
above = smooth(math_('SUBTRACT', 1.0, h), 0.0, 0.35)  # boven de top uitlopen
dens = math_('MULTIPLY', math_('MULTIPLY', dens_raw, above), 5.0)

heat = math_('MULTIPLY', smooth(math_('SUBTRACT', 1.0, math_('ADD', d, math_('MULTIPLY', h, 1.1))), 0.0, 1.0), 0.6)
emis = math_('MULTIPLY', math_('MULTIPLY', dens_raw, above), 16.0)
ramp = new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (0.75, 0.08, 0.01, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (1.0, 0.85, 0.4, 1)
e = ramp.color_ramp.elements.new(0.5)
e.color = (1.0, 0.4, 0.04, 1)
links.new(heat, ramp.inputs[0])
vol = new("ShaderNodeVolumePrincipled")
links.new(dens, vol.inputs["Density"])
vol.inputs["Color"].default_value = (0.05, 0.04, 0.04, 1)
links.new(emis, vol.inputs["Emission Strength"])
links.new(ramp.outputs[0], vol.inputs["Emission Color"])
outn = new("ShaderNodeOutputMaterial")
links.new(vol.outputs[0], outn.inputs["Volume"])
dom.data.materials.append(mat)

cam_d = bpy.data.cameras.new("Cam")
cam_d.type = 'ORTHO'
cam_d.ortho_scale = 3.2
cam = bpy.data.objects.new("Cam", cam_d)
scn.collection.objects.link(cam)
cam.location = (0, -12, 1.6)
cam.rotation_euler = (1.5708, 0, 0)
scn.camera = cam
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
scn.world = world

scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = SAMPLES
scn.cycles.use_denoising = False
scn.cycles.volume_step_rate = 2.0
scn.cycles.volume_max_steps = 128
scn.render.film_transparent = True
scn.render.resolution_x = PX
scn.render.resolution_y = int(PX * 1.0)
scn.render.image_settings.file_format = 'PNG'
scn.render.image_settings.color_mode = 'RGBA'
scn.view_settings.view_transform = 'Standard'

for i in range(TOTAL):
    scn.frame_set(i)
    scn.render.filepath = os.path.join(out, "vlam_%03d.png" % i)
    bpy.ops.render.render(write_still=True)
    print("beeld", i, flush=True)
print("KLAAR")
