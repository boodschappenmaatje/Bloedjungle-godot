"""Tankschot-flipbooks voor Bloedjungle: vuur en rook met Mantaflow, gerenderd als beeldreeks met transparante achtergrond.
Gebruik:  python maak_tankfx.py <preset> <uitmap> [res] [px] [samples]
Presets:
  mond   mondingsvuur van bovenaf (kanon wijst naar +Y van het beeld): vuurtong naar voren + twee zijtongen (mondingsrem)
  rook   rookwolk van bovenaf: dik, donker, drijft naar voren en lost op
  stof   stofwaaier van bovenaf: bruin, breed, laag
  aarde  aardfontein van opzij (inslag): vuur onderin, bruine rook en stof die omhoog spuiten
Schrijft <uitmap>/<preset>_%03d.png. plak.py (bron/explosie) zet ze daarna op een vel."""
import bpy, sys, os, math

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
PRESET, OUT = args[0], args[1]
RES = int(args[2]) if len(args) > 2 else 80
PX = int(args[3]) if len(args) > 3 else 384
SAMPLES = int(args[4]) if len(args) > 4 else 32
os.makedirs(OUT, exist_ok=True)

# preset: domein (m), simframes, stap, bron(nen), camera, vuur?, rookkleur, rook-dichtheid
P = {
 "mond":  dict(dom=(7, 9, 3), sim=34, step=2, top=True, fire=True,  smoke=(0.10, 0.09, 0.08), orth=8.6, cam_c=(0, 2.6)),
 "rook":  dict(dom=(8, 10, 3), sim=96, step=6, top=True, fire=False, smoke=(0.26, 0.25, 0.24), orth=9.6, cam_c=(0, 3.0)),
 "stof":  dict(dom=(10, 8, 2.5), sim=72, step=4.5, top=True, fire=False, smoke=(0.50, 0.40, 0.28), orth=10.4, cam_c=(0, 2.4)),
 "aarde": dict(dom=(6, 3, 7), sim=60, step=3.75, top=False, fire=True, smoke=(0.30, 0.22, 0.14), orth=7.6, cam_c=(0, 3.4)),
}[PRESET]
STEP = P["step"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 24
scn.frame_start, scn.frame_end = 1, P["sim"]
dx, dy, dz = P["dom"]

# domein: onderkant op de grond (z=0); de bron staat bij het midden van de x-as en vlak bij de voorrand van y=0
bpy.ops.mesh.primitive_cube_add(size=1.0)
dom = bpy.context.object; dom.name = "Domein"
dom.scale = (dx, dy, dz)
cy = dy / 2 - 1.2 if P["top"] else 0.0
dom.location = (0, cy, dz / 2)
bpy.ops.object.modifier_add(type='FLUID')
dom.modifiers["Fluid"].fluid_type = 'DOMAIN'
d = dom.modifiers["Fluid"].domain_settings
d.domain_type = 'GAS'
d.resolution_max = RES
d.use_noise = True
d.noise_scale = 2
d.cache_type = 'ALL'
d.cache_directory = os.path.join(OUT, "cache_" + PRESET)
d.use_dissolve_smoke = True
d.dissolve_speed = {"mond": 30, "rook": 140, "stof": 100, "aarde": 70}[PRESET]
d.vorticity = {"mond": 0.5, "rook": 0.7, "stof": 0.5, "aarde": 0.8}[PRESET]
d.alpha = 0.3
d.beta = 1.2 if P["fire"] else 0.2
d.burning_rate = 0.9
d.flame_smoke = 0.5
d.flame_vorticity = 0.6
d.flame_max_temp = 3.0
d.flame_ignition = 1.5
d.flame_smoke_color = P["smoke"]
if not P["top"]:
    d.gravity = (0, 0, -3.0)
else:
    d.gravity = (0, 0, 0)

def source(name, loc, radius, vel, frames, fuel=1.0, dens=1.0, temp=3.0, color=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc)
    s = bpy.context.object; s.name = name
    bpy.ops.object.modifier_add(type='FLUID')
    s.modifiers["Fluid"].fluid_type = 'FLOW'
    f = s.modifiers["Fluid"].flow_settings
    f.flow_type = 'BOTH' if P["fire"] and fuel > 0 else 'SMOKE'
    f.flow_behavior = 'INFLOW'
    f.flow_source = 'MESH'
    f.fuel_amount = fuel
    f.temperature = temp
    f.density = dens
    f.use_initial_velocity = True
    f.velocity_coord = vel
    f.surface_distance = 1.0
    f.smoke_color = color or P["smoke"]
    f.use_inflow = True
    f.keyframe_insert("use_inflow", frame=1)
    f.use_inflow = False
    f.keyframe_insert("use_inflow", frame=frames)

if PRESET == "mond":
    source("Tong", (0, 0.0, 0.6), 0.34, (0, 16, 0), 5, fuel=1.2)
    source("ZijL", (-0.2, 0.2, 0.6), 0.22, (-12, 3, 0), 4, fuel=1.0)
    source("ZijR", (0.2, 0.2, 0.6), 0.22, (12, 3, 0), 4, fuel=1.0)
    source("Rook", (0, 0.3, 0.6), 0.3, (0, 6, 0), 10, fuel=0.0, dens=0.8)
elif PRESET == "rook":
    source("Wolk", (0, 0.3, 0.6), 0.45, (0, 7, 0), 14, fuel=0.0, dens=1.6)
    source("Pluim", (0, 0.2, 0.7), 0.25, (0, 2.0, 1.2), 60, fuel=0.0, dens=0.5)
elif PRESET == "stof":
    source("Waaier", (0, 0.2, 0.35), 0.5, (0, 9, 0), 10, fuel=0.0, dens=1.4)
    source("WaaierL", (-0.3, 0.2, 0.35), 0.35, (-7, 5, 0), 8, fuel=0.0, dens=1.2)
    source("WaaierR", (0.3, 0.2, 0.35), 0.35, (7, 5, 0), 8, fuel=0.0, dens=1.2)
else:
    source("Fontein", (0, 0, 0.5), 0.6, (0, 0, 9), 6, fuel=0.8, dens=1.6)
    source("Aarde", (0, 0, 0.4), 0.7, (0, 0, 6), 12, fuel=0.0, dens=2.0)

# materiaal: vuur licht op, rook neemt licht weg
mat = bpy.data.materials.new("Vuur")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
outn = nt.nodes.new("ShaderNodeOutputMaterial")
vol = nt.nodes.new("ShaderNodeVolumePrincipled")
dens = nt.nodes.new("ShaderNodeAttribute"); dens.attribute_name = "density"
flame = nt.nodes.new("ShaderNodeAttribute"); flame.attribute_name = "flame"
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (1.0, 0.16, 0.02, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (1.0, 0.86, 0.5, 1)
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 60.0
dmul = nt.nodes.new("ShaderNodeMath"); dmul.operation = 'MULTIPLY'; dmul.inputs[1].default_value = {"mond": 4.0, "rook": 5.0, "stof": 4.0, "aarde": 5.0}[PRESET]
nt.links.new(dens.outputs["Fac"], dmul.inputs[0])
nt.links.new(dmul.outputs["Value"], vol.inputs["Density"])
vol.inputs["Color"].default_value = (*P["smoke"], 1)
vol.inputs["Anisotropy"].default_value = 0.2
nt.links.new(flame.outputs["Fac"], mul.inputs[0])
nt.links.new(mul.outputs["Value"], vol.inputs["Emission Strength"])
nt.links.new(flame.outputs["Fac"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], vol.inputs["Emission Color"])
nt.links.new(vol.outputs["Volume"], outn.inputs["Volume"])
dom.data.materials.append(mat)
dom.display_type = 'WIRE'

# licht voor de rook (zon schuin van linksboven)
sun_d = bpy.data.lights.new("Zon", 'SUN'); sun_d.energy = 4.0
sun = bpy.data.objects.new("Zon", sun_d); scn.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))

# camera: van boven (kijkt naar -Z) of van opzij
cam_d = bpy.data.cameras.new("Cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = P["orth"]
cam = bpy.data.objects.new("Cam", cam_d); scn.collection.objects.link(cam)
if P["top"]:
    cam.location = (0, P["cam_c"][1], 20); cam.rotation_euler = (0, 0, 0)
else:
    cam.location = (0, -20, P["cam_c"][1]); cam.rotation_euler = (math.radians(90), 0, 0)
scn.camera = cam

scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = SAMPLES
scn.cycles.use_denoising = False
scn.cycles.volume_bounces = 1
scn.cycles.volume_step_rate = 1.0
scn.render.film_transparent = True
scn.render.resolution_x = PX; scn.render.resolution_y = PX
scn.render.image_settings.file_format = 'PNG'
scn.render.image_settings.color_mode = 'RGBA'
scn.view_settings.view_transform = 'Standard'

bpy.ops.object.select_all(action='DESELECT')
dom.select_set(True); bpy.context.view_layer.objects.active = dom
print("bakken ...", flush=True)
bpy.ops.fluid.bake_data()
print("gebakken", flush=True)
n = 0
fr = 1.0
while int(round(fr)) <= P["sim"] and n < 16:
    scn.frame_set(int(round(fr)))
    scn.render.filepath = os.path.join(OUT, "%s_%03d.png" % (PRESET, n))
    bpy.ops.render.render(write_still=True)
    print("beeld", n, flush=True)
    n += 1; fr += STEP
print("KLAAR", n)
