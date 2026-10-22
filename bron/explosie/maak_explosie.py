"""Explosie voor Bloedjungle: vuur en rook met Mantaflow, gerenderd als beeldreeks (flipbook) met transparante achtergrond.
Gebruik:  python maak_explosie.py <uitmap> [res] [frames_sim] [stap] [px] [samples]
Schrijft <uitmap>/vuur_%03d.png (één beeld per stap). De plaatjes worden daarna met plak.py tot één vel gezet."""
import bpy, sys, os, math, mathutils

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
args = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else sys.argv[2:]
RES = int(args[0]) if len(args) > 0 else 96
SIM = int(args[1]) if len(args) > 1 else 72
STEP = int(args[2]) if len(args) > 2 else 2
PX = int(args[3]) if len(args) > 3 else 512
SAMPLES = int(args[4]) if len(args) > 4 else 48
os.makedirs(out, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 30
scn.frame_start = 1
scn.frame_end = SIM

# --- domein: 6 x 6 x 7 m, onderkant op de grond
bpy.ops.mesh.primitive_cube_add(size=1.0)
dom = bpy.context.object
dom.name = "Domein"
dom.scale = (6.0, 6.0, 7.0)
dom.location = (0, 0, 3.5 - 0.5)
bpy.ops.object.modifier_add(type='FLUID')
dom.modifiers["Fluid"].fluid_type = 'DOMAIN'
d = dom.modifiers["Fluid"].domain_settings
d.domain_type = 'GAS'
d.resolution_max = RES
d.use_noise = True
d.noise_scale = 2
d.cache_type = 'ALL'
d.cache_directory = os.path.join(out, "cache")
d.use_dissolve_smoke = True
d.dissolve_speed = 60
d.vorticity = 0.9
d.alpha = 0.6        # dichtheid -> opwaartse kracht van rook
d.beta = 1.6         # temperatuur -> opwaartse kracht van vuur
d.burning_rate = 0.6
d.flame_smoke = 0.7
d.flame_vorticity = 0.8
d.flame_max_temp = 3.0
d.flame_ignition = 1.5
d.flame_smoke_color = (0.12, 0.11, 0.10)

# --- bron: bol die de eerste paar beelden brandstof uitstoot
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(0, 0, 0.5))
src = bpy.context.object
src.name = "Bron"
bpy.ops.object.modifier_add(type='FLUID')
src.modifiers["Fluid"].fluid_type = 'FLOW'
f = src.modifiers["Fluid"].flow_settings
f.flow_type = 'BOTH'
f.flow_behavior = 'INFLOW'
f.flow_source = 'MESH'
f.fuel_amount = 1.0
f.temperature = 3.0
f.density = 1.0
f.use_initial_velocity = True
f.velocity_normal = 7.0
f.surface_distance = 1.0
f.smoke_color = (0.1, 0.1, 0.1)
f.subframes = 1
f.use_inflow = True
f.keyframe_insert("use_inflow", frame=1)
f.use_inflow = False
f.keyframe_insert("use_inflow", frame=5)

# --- materiaal van het domein: vuur licht op, rook is donker en neemt licht weg
mat = bpy.data.materials.new("Vuur")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
outn = nt.nodes.new("ShaderNodeOutputMaterial")
vol = nt.nodes.new("ShaderNodeVolumePrincipled")
dens = nt.nodes.new("ShaderNodeAttribute"); dens.attribute_name = "density"
flame = nt.nodes.new("ShaderNodeAttribute"); flame.attribute_name = "flame"
heat = nt.nodes.new("ShaderNodeAttribute"); heat.attribute_name = "temperature"
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (1.0, 0.18, 0.02, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (1.0, 0.85, 0.45, 1)
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 55.0
nt.links.new(dens.outputs["Fac"], vol.inputs["Density"])
vol.inputs["Color"].default_value = (0.07, 0.065, 0.06, 1)
vol.inputs["Anisotropy"].default_value = 0.2
nt.links.new(flame.outputs["Fac"], mul.inputs[0])
nt.links.new(mul.outputs["Value"], vol.inputs["Emission Strength"])
nt.links.new(flame.outputs["Fac"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], vol.inputs["Emission Color"])
nt.links.new(vol.outputs["Volume"], outn.inputs["Volume"])
dom.data.materials.append(mat)
dom.display_type = 'WIRE'

# --- camera van opzij, orthografisch, met het domein in beeld
cam_d = bpy.data.cameras.new("Cam")
cam_d.type = 'ORTHO'
cam_d.ortho_scale = 7.4
cam = bpy.data.objects.new("Cam", cam_d)
scn.collection.objects.link(cam)
cam.location = (0, -20, 3.2)
cam.rotation_euler = (math.radians(90), 0, 0)
scn.camera = cam

# --- renderinstellingen: Cycles, transparante achtergrond
scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = SAMPLES
scn.cycles.use_denoising = False
scn.cycles.volume_bounces = 1
scn.cycles.volume_step_rate = 1.0
scn.render.film_transparent = True
scn.render.resolution_x = PX
scn.render.resolution_y = PX
scn.render.image_settings.file_format = 'PNG'
scn.render.image_settings.color_mode = 'RGBA'
scn.render.image_settings.color_depth = '8'
scn.view_settings.view_transform = 'Standard'

bpy.ops.object.select_all(action='DESELECT')
dom.select_set(True)
bpy.context.view_layer.objects.active = dom
print("bakken ...", flush=True)
bpy.ops.fluid.bake_data()
print("gebakken", flush=True)

n = 0
for fr in range(1, SIM + 1, STEP):
    scn.frame_set(fr)
    scn.render.filepath = os.path.join(out, "vuur_%03d.png" % n)
    bpy.ops.render.render(write_still=True)
    print("beeld", n, "van sim-frame", fr, flush=True)
    n += 1
print("KLAAR", n)
