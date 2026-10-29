"""Napalm-vlam als flipbook: echte vuursimulatie (Mantaflow) in Blender 4.3, gerenderd als atlas met alpha.
Gebruik: blender --background --python bron/napalm/maak_vlam.py -- <uitmap> [--snel]
Uit: vlam_atlas.png (COLS x ROWS beelden), vlam.blend
"""
import bpy, sys, os, math

arg = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = arg[0] if arg else "/tmp/vlam"
snel = "--snel" in arg
os.makedirs(out, exist_ok=True)
COLS, ROWS = (4, 4) if snel else (8, 8)
FR = COLS * ROWS
RES = 48 if snel else 80      # simulatieraster
PX = 128 if snel else 256     # px per beeld
SAMPLES = 24 if snel else 48
FLAME_DICHT = 4.0   # hoe ondoorzichtig de vlam zelf is
ROET = 1.5          # zwarte rook
EMISSIE = 2.2      # gloed

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = False
sc.render.resolution_x = PX
sc.render.resolution_y = PX
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.frame_start = 1
sc.frame_end = FR + 24     # 24 beelden inlooptijd, daarna FR beelden vastleggen
sc.render.fps = 24

# brandstof: een lage plas op de bodem; quick_smoke maakt het domein en een werkend vuurmateriaal
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 0.1), segments=16, ring_count=8)
fl = bpy.context.object
fl.name = "Brandstof"
fl.scale = (1.0, 1.0, 0.35)
bpy.ops.object.select_all(action="DESELECT")
fl.select_set(True)
bpy.context.view_layer.objects.active = fl
bpy.ops.object.quick_smoke(style="FIRE")
dom = [o for o in bpy.data.objects if "Fluid" in o.modifiers and o.modifiers["Fluid"].fluid_type == "DOMAIN"][0]
dom.name = "Domein"
dom.location = (0, 0, 1.5)
dom.scale = (1.5, 1.0, 1.5)      # 3 x 2 x 3 m (kubus van 2 m)
d = dom.modifiers["Fluid"].domain_settings
d.resolution_max = RES
d.use_noise = False
d.noise_scale = 2
d.cache_directory = os.path.join(out, "cache")
sc.frame_start = 1
sc.frame_end = FR + 24
d.cache_type = "ALL"
d.cache_data_format = "OPENVDB"
d.cache_noise_format = "OPENVDB"
d.cache_frame_start = 1
d.cache_frame_end = FR + 24
d.beta = 1.4                       # hitte-drijfkracht: hoge, snelle tongen
d.vorticity = 0.5
d.burning_rate = 0.6
d.flame_smoke = 0.25
d.flame_vorticity = 0.8
d.dissolve_speed = 15
d.use_dissolve_smoke = True
f = fl.modifiers["Fluid"].flow_settings
f.surface_distance = 0.6
fl.hide_render = False
fl.visible_camera = False

# camera: orthografisch, van opzij, kijkt over het hele domein
cam_d = bpy.data.cameras.new("Cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 2.3
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
cam.location = (0, -6, 0.95)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "vlam.blend"))
bpy.ops.object.select_all(action="DESELECT")
dom.select_set(True)
bpy.context.view_layer.objects.active = dom
sc.frame_set(1)
bpy.ops.fluid.bake_data()


# de bake staat als VDB-reeks op schijf; die laden we als gewoon volume (rendert betrouwbaar zonder fluid-modifier)
dom.hide_render = True
dom.visible_camera = False
dom.modifiers["Fluid"].show_render = False
vol = bpy.data.volumes.new("VlamVolume")
vol.filepath = os.path.join(out, "cache", "data", "fluid_data_0001.vdb")
vol.is_sequence = True
vol.frame_start = 1
vol.frame_duration = sc.frame_end
vol.frame_offset = 0
vol.sequence_mode = "CLIP"
vo = bpy.data.objects.new("VlamVolume", vol)
sc.collection.objects.link(vo)
# de VDB-roosters beginnen in de hoek van het domein (niet in het midden)
vo.location = (dom.location.x - dom.dimensions.x / 2, dom.location.y - dom.dimensions.y / 2, dom.location.z - dom.dimensions.z / 2)

# materiaal: vlamintensiteit -> kleur (rood -> oranje -> geel -> witheet); roet uit de dichtheid
m = bpy.data.materials.new("Vuur")
m.use_nodes = True
nt = m.node_tree
nt.nodes.clear()
o = nt.nodes.new("ShaderNodeOutputMaterial")
pv = nt.nodes.new("ShaderNodeVolumePrincipled")
fa = nt.nodes.new("ShaderNodeAttribute"); fa.attribute_name = "flame"
da = nt.nodes.new("ShaderNodeAttribute"); da.attribute_name = "density"
ramp = nt.nodes.new("ShaderNodeValToRGB")
cr = ramp.color_ramp
cr.elements[0].position = 0.02; cr.elements[0].color = (0.45, 0.02, 0.0, 1)
cr.elements[1].position = 1.0; cr.elements[1].color = (1.0, 0.7, 0.2, 1)
e = cr.elements.new(0.35); e.color = (1.0, 0.15, 0.01, 1)
e = cr.elements.new(0.65); e.color = (1.0, 0.4, 0.04, 1)
mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = FLAME_DICHT
add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
mulr = nt.nodes.new("ShaderNodeMath"); mulr.operation = "MULTIPLY"; mulr.inputs[1].default_value = ROET
mule = nt.nodes.new("ShaderNodeMath"); mule.operation = "MULTIPLY"; mule.inputs[1].default_value = EMISSIE
nt.links.new(fa.outputs["Fac"], ramp.inputs["Fac"])
nt.links.new(fa.outputs["Fac"], mul.inputs[0])
nt.links.new(da.outputs["Fac"], mulr.inputs[0])
nt.links.new(mul.outputs[0], add.inputs[0])
nt.links.new(mulr.outputs[0], add.inputs[1])
nt.links.new(fa.outputs["Fac"], mule.inputs[0])
nt.links.new(add.outputs[0], pv.inputs["Density"])
nt.links.new(ramp.outputs["Color"], pv.inputs["Emission Color"])
nt.links.new(mule.outputs[0], pv.inputs["Emission Strength"])
pv.inputs["Color"].default_value = (0.04, 0.03, 0.03, 1)
pv.inputs["Density Attribute"].default_value = ""
nt.links.new(pv.outputs["Volume"], o.inputs["Volume"])
vol.materials.append(m)

# beelden renderen
frames = []
for i in range(FR):
    sc.frame_set(25 + i)
    p = os.path.join(out, "f%03d.png" % i)
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    frames.append(p)
print("KLAAR", len(frames))

# atlas: COLS x ROWS beelden, rij 0 bovenaan
try:
    from PIL import Image
    atlas = Image.new("RGBA", (COLS * PX, ROWS * PX), (0, 0, 0, 0))
    for i, p in enumerate(frames):
        atlas.paste(Image.open(p).convert("RGBA"), ((i % COLS) * PX, (i // COLS) * PX))
    atlas.save(os.path.join(out, "vlam_atlas.png"))
except ImportError:
    print("PIL ontbreekt in Blender-python: atlas losse beelden f###.png")
