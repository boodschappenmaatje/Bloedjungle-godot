"""Munitiekist uit Meshy (text-to-3D) opgeschoond voor Bloedjungle (VQ2).
Bron: meshy_bron.glb (Meshy refine, ~6.9k driehoeken, 2K albedo/normal/metallic-ruwheid, zie README.md).
Meshy levert een versnipperde UV-atlas: gewoon decimeren laat de textuur schuiven. Daarom:
  1. bron op echte maat (70 cm lang, lengte langs X, pivot midden onder), naden samenvoegen;
  2. de onleesbare AI-stencilletters (geel) uit de albedo poetsen;
  3. lage versie (decimeren) met nieuwe, nette UV's;
  4. albedo, normal, ruwheid en metallic van hoog naar laag bakken (Cycles CPU, 2K).
Uit: munitiekist_meshy.blend (hoog + laag, 2K-bakresultaat ingepakt) en munitiekist_meshy.glb (alleen laag, 1K).
Gebruik: python3 maak_munitiekist.py [uitmap] [driehoeken] [bakmaat]"""
import os, sys
import bpy
import numpy as np
from pathlib import Path

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
HERE = Path(__file__).resolve().parent
OUT = Path(os.path.abspath(ARGS[0] if ARGS else str(HERE / "uit")))
TARGET_TRIS = int(ARGS[1]) if len(ARGS) > 1 else 2500
BAKE = int(ARGS[2]) if len(ARGS) > 2 else 2048
LENGTH = 0.70        # echte houten munitiekist: ongeveer 70 cm lang
GAME_TEX = 1024      # VQ2: 1K in de game, de 2K-bake blijft in de .blend
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
view = bpy.context.view_layer


def select_only(*objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = active or objs[0]


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


# ---------- 1. bron op maat ----------
bpy.ops.import_scene.gltf(filepath=str(HERE / "meshy_bron.glb"))
meshes = [o for o in scene.objects if o.type == "MESH"]
select_only(*meshes)
if len(meshes) > 1:
    bpy.ops.object.join()
hoog = view.objects.active
hoog.parent = None
for o in list(scene.objects):          # lege knopen van de import weg
    if o is not hoog:
        bpy.data.objects.remove(o)
hoog.name = hoog.data.name = "Munitiekist_Meshy_HQ"
select_only(hoog)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if hoog.dimensions.y > hoog.dimensions.x:      # lengte langs X
    hoog.rotation_euler.z = 1.5707963
    bpy.ops.object.transform_apply(rotation=True)
k = LENGTH / hoog.dimensions.x
hoog.scale = (k, k, k)
bpy.ops.object.transform_apply(scale=True)
co = np.array([v.co[:] for v in hoog.data.vertices])
off = ((co[:, 0].min() + co[:, 0].max()) / 2, (co[:, 1].min() + co[:, 1].max()) / 2, co[:, 2].min())
for v in hoog.data.vertices:
    v.co.x -= off[0]; v.co.y -= off[1]; v.co.z -= off[2]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0002)
bpy.ops.object.mode_set(mode="OBJECT")
hoog_tris = tris(hoog)

# ---------- 2. AI-stencil weg ----------
mat_hoog = hoog.data.materials[0]
bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
albedo = bsdf.inputs["Base Color"].links[0].from_node.image
w, h = albedo.size
px = np.array(albedo.pixels[:], dtype=np.float32).reshape(h, w, 4)
r, g, b = px[..., 0], px[..., 1], px[..., 2]
mask = (r > 0.35) & (g > 0.25) & (b < 0.55 * g) & (r - b > 0.22) & (np.abs(r - g) < 0.35 * r + 0.08)
for _ in range(3):   # iets ruimer, ook de zachte randen van de letters
    m = mask.copy()
    m[1:] |= mask[:-1]; m[:-1] |= mask[1:]; m[:, 1:] |= mask[:, :-1]; m[:, :-1] |= mask[:, 1:]
    mask = m
fill = px.copy()
known = ~mask
for _ in range(80):  # opvullen met de omliggende verf (diffusie vanuit de rand)
    acc = np.zeros_like(fill[..., :3]); cnt = np.zeros((h, w, 1), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(fill[..., :3], (dy, dx), (0, 1)); kn = np.roll(known, (dy, dx), (0, 1))[..., None]
        acc += sh * kn; cnt += kn
    new = mask & ~known & (cnt[..., 0] > 0)
    fill[new, :3] = acc[new] / cnt[new]
    known = known | new
    if known.all():
        break
albedo.pixels.foreach_set(fill.ravel())
albedo.update()
# Meshy heeft de letters ook in de normal map gestempeld: daar vlak maken
nimg = mat_hoog.node_tree.nodes.get("Normal Map")
nimg = nimg.inputs["Color"].links[0].from_node.image if nimg and nimg.inputs["Color"].links else None
if nimg and tuple(nimg.size) == (w, h):
    npx = np.array(nimg.pixels[:], dtype=np.float32).reshape(h, w, 4)
    npx[mask, 0] = 0.5; npx[mask, 1] = 0.5; npx[mask, 2] = 1.0
    nimg.pixels.foreach_set(npx.ravel()); nimg.update()
stencil_px = int(mask.sum())

# ---------- 3. lage versie met nette UV's ----------
laag = hoog.copy()
laag.data = hoog.data.copy()
scene.collection.objects.link(laag)
laag.name = laag.data.name = "Munitiekist"
select_only(laag)
dec = laag.modifiers.new("Decimate", "DECIMATE")
dec.ratio = TARGET_TRIS / hoog_tris
dec.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=dec.name)
while len(laag.data.uv_layers):
    laag.data.uv_layers.remove(laag.data.uv_layers[0])
laag.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0)
bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")
for p in laag.data.polygons:
    p.use_smooth = True
wn = laag.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
wn.keep_sharp = True
bpy.ops.object.modifier_apply(modifier=wn.name)
laag.data.validate(clean_customdata=False)
laag_tris = tris(laag)

# ---------- 4. bakken ----------
mat = bpy.data.materials.new("Munitiekist_Meshy")
mat.use_nodes = True
mat.use_backface_culling = True      # dichte kist: niet dubbelzijdig
laag.data.materials.clear()
laag.data.materials.append(mat)
nt = mat.node_tree
pr = nt.nodes["Principled BSDF"]


def new_image(name, color):
    im = bpy.data.images.new(name, BAKE, BAKE, alpha=False, float_buffer=False)
    im.colorspace_settings.name = "sRGB" if color else "Non-Color"
    return im


def bake_into(im, kind, **kw):
    node = nt.nodes.new("ShaderNodeTexImage"); node.image = im
    nt.nodes.active = node
    select_only(hoog, laag, active=laag)
    bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.012, max_ray_distance=0.04,
                        margin=8, **kw)
    return node


scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4
img_alb = new_image("Munitiekist_albedo", True)
n_alb = bake_into(img_alb, "DIFFUSE", pass_filter={"COLOR"})
img_nrm = new_image("Munitiekist_normal", False)
n_nrm = bake_into(img_nrm, "NORMAL", normal_space="TANGENT")


def bake_channel(socket_name):
    """ruwheid/metallic van de bron als emissie bakken (Cycles heeft geen metallic-pas)"""
    src = bsdf.inputs[socket_name]
    from_socket = src.links[0].from_socket if src.links else None
    em = mat_hoog.node_tree.nodes.new("ShaderNodeEmission")
    out = next(n for n in mat_hoog.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    old = out.inputs["Surface"].links[0].from_socket
    if from_socket:
        mat_hoog.node_tree.links.new(from_socket, em.inputs["Color"])
    else:
        v = src.default_value; em.inputs["Color"].default_value = (v, v, v, 1)
    mat_hoog.node_tree.links.new(em.outputs[0], out.inputs["Surface"])
    im = new_image("tmp_" + socket_name, False)
    node = bake_into(im, "EMIT")
    mat_hoog.node_tree.links.new(old, out.inputs["Surface"])
    mat_hoog.node_tree.nodes.remove(em)
    nt.nodes.remove(node)
    return np.array(im.pixels[:], np.float32).reshape(-1, 4)[:, 0], im


rough, im_r = bake_channel("Roughness")
metal, im_m = bake_channel("Metallic")
img_orm = new_image("Munitiekist_orm", False)
orm = np.ones((BAKE * BAKE, 4), np.float32)
# Meshy zet veel geverfd hout op half-metallic (glanst als blik). Alleen het donkere, grijze beslag is metaal;
# verf en hout worden mat-dielectrisch, zoals de VQ2-sets.
alb = np.array(img_alb.pixels[:], np.float32).reshape(-1, 4)[:, :3]
steel = (alb.max(1) - alb.min(1) < 0.05) & (alb.max(1) < 0.22)
metal = np.where(steel, np.clip(metal, 0.55, 0.85), 0.0)
rough = np.where(steel, np.clip(rough, 0.35, 0.7), np.clip(rough, 0.62, 0.95))
orm[:, 1] = rough; orm[:, 2] = metal
img_orm.pixels.foreach_set(orm.ravel())
for im in (im_r, im_m):
    bpy.data.images.remove(im)

# materiaal zoals de glTF-exporter het verwacht
lk = nt.links
lk.new(n_alb.outputs["Color"], pr.inputs["Base Color"])
n_orm = nt.nodes.new("ShaderNodeTexImage"); n_orm.image = img_orm
sep = nt.nodes.new("ShaderNodeSeparateColor")
lk.new(n_orm.outputs["Color"], sep.inputs["Color"])
lk.new(sep.outputs["Green"], pr.inputs["Roughness"])
lk.new(sep.outputs["Blue"], pr.inputs["Metallic"])
nm = nt.nodes.new("ShaderNodeNormalMap")
lk.new(n_nrm.outputs["Color"], nm.inputs["Color"])
lk.new(nm.outputs["Normal"], pr.inputs["Normal"])

for im in (img_alb, img_nrm, img_orm):
    im.pack()
hoog.hide_render = True
hoog.hide_set(True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "munitiekist_meshy.blend"))

# ---------- game-export: alleen de lage kist, texturen 1K ----------
for im in (img_alb, img_nrm, img_orm):
    im.scale(GAME_TEX, GAME_TEX)
hoog.hide_set(False)
select_only(laag)
bpy.ops.export_scene.gltf(filepath=str(OUT / "munitiekist_meshy.glb"), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False,
                          export_lights=False, export_image_format="JPEG", export_jpeg_quality=90)
d = laag.dimensions
print("MESHY_EXPORT munitiekist hoog %d laag %d driehoeken, maat %.2f x %.2f x %.2f m, stencilpixels %d, bake %d, game %d"
      % (hoog_tris, laag_tris, d.x, d.y, d.z, stencil_px, BAKE, GAME_TEX))
