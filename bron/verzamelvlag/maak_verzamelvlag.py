"""Verzamelvlag (Rally Flag), Blender-bron. Eenheden in meters, Z omhoog in Blender (glTF zet het om naar Y omhoog).

Gebruik (Blender als Python-module, bijvoorbeeld `pip install bpy` in een venv):

    python bron/verzamelvlag/maak_verzamelvlag.py hq      # bewerkbaar bronmodel, .blend + .glb in uit/
    python bron/verzamelvlag/maak_verzamelvlag.py game    # Godot-versie: assets/verzamelvlag.glb
    python bron/verzamelvlag/maak_verzamelvlag.py lod1    # uitgezoomd: assets/verzamelvlag_lod1.glb

Ontwerp: bron/verzamelvlag/ASSET_DESIGN_SPEC.md. Materialen: de goedgekeurde VQ2-sets in assets/textures/vq2/
(canvas, timber, steel); alleen het vlagdoek heeft een eigen gegenereerde textuur (rand, ster, gestikte zoom).
"""
import math
import random
import sys
from pathlib import Path

import bpy  # moet voor bmesh/mathutils
import bmesh
import numpy as np
from mathutils import Euler, Matrix, Vector
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TEX = ROOT / "assets/textures/vq2"
OUT = HERE / "uit"
OUT.mkdir(exist_ok=True)

LEVEL = sys.argv[1] if len(sys.argv) > 1 else "game"
PARAMS = {
    #        paalzijden, doekrooster (x, z), zakschijf (u, v), doektextuur
    "hq":   dict(seg=32, cloth=(28, 16), bag=(28, 18), tex=2048, prop=1024, bone_n=6),
    "game": dict(seg=12, cloth=(12, 7),  bag=(12, 8),  tex=1024, prop=512, bone_n=6),
    "lod1": dict(seg=8,  cloth=(6, 4),   bag=(8, 5),   tex=512,  prop=256, bone_n=3),
}[LEVEL]

POLE_H = 3.0
CLOTH_W, CLOTH_H = 1.1, 0.7
CLOTH_TOP = 2.85
FPS = 30
CLIP_FRAMES = 60  # 2 s


# ------------------------------------------------------------------ materialen
def load_img(path, noncolor=False):
    img = bpy.data.images.load(str(path), check_existing=True)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    return img


def tinted_set(family, tint, res):
    """Tint en verkleining bakken we in de textuur zelf; glTF kent geen vermenigvuldigknoop met een kleur."""
    out = {}
    for kind, ext in (("albedo", "jpg"), ("normal", "jpg"), ("orm", "png")):
        im = Image.open(TEX / family / f"{kind}.{ext}").convert("RGB")
        if res < im.size[0]:
            im = im.resize((res, res), Image.LANCZOS)
        if kind == "albedo" and tint:
            a = np.asarray(im, dtype=np.float32) / 255.0
            a = np.clip(a * np.array(tint, dtype=np.float32), 0, 1)
            im = Image.fromarray((a * 255 + 0.5).astype(np.uint8))
        p = OUT / f"{family}_{'x'.join('%.2f' % t for t in (tint or (1, 1, 1)))}_{kind}_{res}.{ext}"
        im.save(p, quality=92) if ext == "jpg" else im.save(p)
        out[kind] = p
    return out


def pbr(name, albedo, normal, orm, tint=None, normal_strength=0.8, emission=None, double_sided=False, scale=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    mapping = None
    if scale:
        tc = n.new("ShaderNodeTexCoord")
        mapping = n.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (scale, scale, scale)
        l.new(tc.outputs["UV"], mapping.inputs["Vector"])

    def tex(path, noncolor):
        t = n.new("ShaderNodeTexImage")
        t.image = load_img(path, noncolor)
        if mapping:
            l.new(mapping.outputs["Vector"], t.inputs["Vector"])
        return t

    base = tex(albedo, False)
    if tint:
        mix = n.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[2].default_value = (*tint, 1.0)
        l.new(base.outputs["Color"], mix.inputs[1])
        l.new(mix.outputs[0], bsdf.inputs["Base Color"])
    else:
        l.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    nm = tex(normal, True)
    nmap = n.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = normal_strength
    l.new(nm.outputs["Color"], nmap.inputs["Color"])
    l.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    o = tex(orm, True)
    sep = n.new("ShaderNodeSeparateColor")
    l.new(o.outputs["Color"], sep.inputs[0])
    l.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    l.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    mat.use_backface_culling = not double_sided
    return mat


def plain(name, color, rough, metal=0.0, emission=None, alpha=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission:
        b.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        b.inputs["Emission Strength"].default_value = emission[1]
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    return mat


# ------------------------------------------------------------------ doektextuur
def make_cloth_textures(res):
    """Olijfgroen canvas met gouden rand, gestikte zoom en een ster. Geeft paden naar albedo, normal en orm."""
    W, H = res, int(res * 0.625)  # 2048x1280, 1024x640, 512x320
    cw = np.asarray(Image.open(TEX / "canvas/albedo.jpg").convert("RGB"), dtype=np.float32) / 255.0
    cn = np.asarray(Image.open(TEX / "canvas/normal.jpg").convert("RGB"), dtype=np.float32) / 255.0
    co = np.asarray(Image.open(TEX / "canvas/orm.png").convert("RGB"), dtype=np.float32) / 255.0

    def tile(a):
        tx = int(math.ceil(W / 1024 * 1.0)) + 1
        ty = int(math.ceil(H / 1024 * 1.0)) + 1
        big = np.tile(a, (ty, tx, 1))
        return big[:H, :W]

    alb, nrm, orm = tile(cw), tile(cn), tile(co)
    lum = alb.mean(axis=2, keepdims=True)
    lum = lum / max(float(lum.mean()), 1e-4)  # weefselcontrast rond 1
    olive = np.array([0.17, 0.20, 0.085], dtype=np.float32)
    gold = np.array([0.72, 0.52, 0.12], dtype=np.float32)

    ppm_x, ppm_y = W / CLOTH_W, H / CLOTH_H
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    mx, my = xx / ppm_x, yy / ppm_y  # meters vanaf de linkerbovenhoek van het doek
    border = 0.045
    inner = 0.060
    dx = np.minimum(mx, CLOTH_W - mx)
    dy = np.minimum(my, CLOTH_H - my)
    d = np.minimum(dx, dy)
    band = (d < border).astype(np.float32)  # gouden zoom
    stitch = ((np.abs(d - inner) < 0.0035) & (((mx * 60).astype(int) % 2) == 0)).astype(np.float32)  # stippellijn
    # ster in het midden (5 punten), straal 0.2 m
    cx, cy, R, r = CLOTH_W * 0.5, CLOTH_H * 0.5, 0.20, 0.08
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    star_img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(star_img).polygon([(px * ppm_x, py * ppm_y) for px, py in pts], fill=255)
    star = np.asarray(star_img, dtype=np.float32) / 255.0
    gold_mask = np.clip(band + star, 0, 1)[..., None]

    col = olive * lum * 1.0
    col = col * (1 - gold_mask) + gold * np.clip(lum * 0.85 + 0.15, 0, 1.4) * gold_mask
    # dunne donkere naad naast de zoom en lichte slijtage/vlekken
    col = col * (1 - 0.35 * stitch[..., None])
    rng = np.random.default_rng(7)
    blot = Image.fromarray((rng.random((H // 16, W // 16)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    blot = np.asarray(blot, dtype=np.float32)[..., None] / 255.0
    col = col * (0.88 + 0.24 * blot)
    col = np.clip(col, 0, 1)

    # hoogtekaart voor rand en ster: licht verheven geborduurd
    hmask = Image.fromarray((np.clip(band + star, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))
    h = np.asarray(hmask, dtype=np.float32) / 255.0
    gy, gx = np.gradient(h)
    k = 9.0
    nx_ = nrm[..., 0] * 2 - 1 - gx * k
    ny_ = nrm[..., 1] * 2 - 1 + gy * k  # OpenGL: groene as omhoog
    nz_ = np.sqrt(np.clip(1 - nx_ ** 2 - ny_ ** 2, 0.01, 1))
    nout = np.stack([nx_ * 0.5 + 0.5, ny_ * 0.5 + 0.5, nz_ * 0.5 + 0.5], axis=2)

    o = orm.copy()
    o[..., 1] = np.clip(o[..., 1] * 0.5 + 0.45, 0, 1) * (1 - 0.35 * gold_mask[..., 0]) + 0.0  # ruw doek, gouden draad iets glanzender
    o[..., 2] = 0.0 + 0.25 * gold_mask[..., 0]  # gouddraad licht metaalachtig
    o[..., 0] = 1.0

    def save(arr, name):
        p = OUT / f"doek_{name}_{res}.png"
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(p)
        return p

    return save(col, "albedo"), save(nout, "normal"), save(o, "orm")


# ------------------------------------------------------------------ geometrie
def new_obj(name, bm, mat, smooth=True, parent=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        mesh.materials.append(mat)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    if parent:
        obj.parent = parent
    return obj


def tapered(bm, r0, r1, z0, z1, seg, cap=True):
    """Afgeknotte kegel/cilinder van z0 naar z1."""
    mat = Matrix.Translation((0, 0, (z0 + z1) / 2))
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=z1 - z0, matrix=mat, calc_uvs=True)


def build_pole(mat_wood, mat_brass, seg, root):
    # paal met lichte conus en kleine schuine afwijking tegen een te perfect uiterlijk
    bm = bmesh.new()
    tapered(bm, 0.043, 0.0275, 0.0, POLE_H, seg)
    pole = new_obj("Paal", bm, mat_wood, parent=root)
    # messing delen: ring onder de doekbevestiging, kraag bovenaan, speerpunt
    bm = bmesh.new()
    tapered(bm, 0.040, 0.040, 2.60, 2.64, seg)          # ring
    tapered(bm, 0.034, 0.034, 2.90, 2.96, seg)          # kraag
    tapered(bm, 0.045, 0.045, 2.96, 3.02, seg)          # lampvoet
    # lampkooi: vier staafjes en twee ringen
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        m = Matrix.Translation((0.052 * math.cos(a), 0.052 * math.sin(a), 3.08))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=max(4, seg // 4), radius1=0.0045, radius2=0.0045, depth=0.12, matrix=m)
    tapered(bm, 0.056, 0.056, 3.13, 3.145, seg)
    # speerpunt: kegel op een klein kraagje
    tapered(bm, 0.022, 0.022, 3.14, 3.17, seg)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=max(6, seg // 2), radius1=0.020, radius2=0.0, depth=0.16, matrix=Matrix.Translation((0, 0, 3.25)))
    brass = new_obj("Messing", bm, mat_brass, parent=root)
    return pole, brass


def build_lamp(mat_glass, seg, root):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=max(8, seg // 2 + 4), v_segments=max(6, seg // 3 + 3), radius=0.046, matrix=Matrix.Translation((0, 0, 3.075)) @ Matrix.Diagonal((1, 1, 1.15, 1)), calc_uvs=True)
    return new_obj("Lamp", bm, mat_glass, parent=root)


def build_loops(mat_rope, seg, root):
    bm = bmesh.new()
    for z in (CLOTH_TOP - 0.03, CLOTH_TOP - CLOTH_H * 0.5, CLOTH_TOP - CLOTH_H + 0.03):
        bmesh.ops.create_cone(bm, cap_ends=False, segments=max(8, seg // 2), radius1=0.0475, radius2=0.0475, depth=0.018, matrix=Matrix.Translation((0, 0, z)))
    return new_obj("Touwlussen", bm, mat_rope, smooth=True, parent=root)


def build_bags(mat_bag, uv, root):
    rng = random.Random(11)
    bm = bmesh.new()
    n_u, n_v = uv

    def bag(cx, cy, cz, yaw, sx, sy, sz):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=n_u, v_segments=n_v, radius=1.0, calc_uvs=True)
        for v in tmp.verts:
            x, y, z = v.co
            ax = abs(x)
            # zak als afgeronde balk: vlakke boven- en onderkant, uiteinden dichtgeknepen tot een gevouwen naad met oortjes
            x2 = math.copysign(ax ** 0.72, x)
            fold = 1.0 - 0.80 * max(0.0, (ax - 0.62) / 0.38) ** 1.6
            zz = max(z, -0.62)
            zz = math.copysign(abs(zz) ** 0.80, zz)
            y2 = y * fold
            z2 = zz * fold
            # doorzakken in het midden en bobbels van de zandvulling
            z2 -= 0.10 * (1 - ax ** 2) * (1 - abs(y))
            bump = 0.028 * math.sin(x * 7.0 + y * 3.0) + 0.020 * math.sin(y * 9.0 - z * 5.0)
            v.co = Vector((x2 * sx, y2 * sy * (1 + bump), z2 * sz * (1 + bump * 1.5)))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.004
        rot = Euler((rng.uniform(-0.05, 0.05), rng.uniform(-0.04, 0.04), yaw), "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=Matrix.Translation((cx, cy, cz)) @ rot, verts=tmp.verts)
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)

    # onderste ring: 9 zakken tangentieel, bovenste ring: 6 zakken verschoven, daarbovenop 2 kleine
    for i in range(9):
        a = i * 2 * math.pi / 9 + rng.uniform(-0.04, 0.04)
        bag(0.43 * math.cos(a), 0.43 * math.sin(a), 0.115, a + math.pi / 2, 0.29, 0.17, 0.115)
    for i in range(6):
        a = i * 2 * math.pi / 6 + math.pi / 9
        bag(0.27 * math.cos(a), 0.27 * math.sin(a), 0.30, a + math.pi / 2 + rng.uniform(-0.1, 0.1), 0.26, 0.16, 0.105)
    # vulling in het midden zodat je niet door de zakken heen naar de paal kijkt
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.30, radius2=0.20, depth=0.44, matrix=Matrix.Translation((0, 0, 0.22)))
    return new_obj("Zandzakken", bm, mat_bag, parent=root)


def build_cloth(mat_cloth, grid, nb, root):
    nx, nz = grid
    bm = bmesh.new()
    verts = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / nz
            x = 0.048 + u * CLOTH_W
            z = CLOTH_TOP - v * CLOTH_H
            # licht doorhangen en een zachte rustplooi, de animatie doet de rest
            y = 0.012 * math.sin(u * math.pi * 1.5) * (0.4 + v)
            z -= 0.02 * u * (0.6 + v) * 0.5
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    uv = bm.loops.layers.uv.new("UVMap")
    for j in range(nz):
        for i in range(nx):
            f = bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
            for loop, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                loop[uv].uv = (ii / nx, 1.0 - jj / nz)
    cloth = new_obj("Doek", bm, mat_cloth, parent=None)
    cloth.parent = root
    return cloth


def rig_cloth(cloth, root, nb):
    """Keten van nb botten langs het doek, doek aan de paal. Wappert via de clip Wapperen-loop."""
    arm_data = bpy.data.armatures.new("Doek_Rig")
    rig = bpy.data.objects.new("Doek_Rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    rig.parent = root
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    seg_len = CLOTH_W / nb
    z_mid = CLOTH_TOP - CLOTH_H * 0.5
    prev = None
    names = []
    for i in range(nb):
        b = arm_data.edit_bones.new(f"Doek{i}")
        b.head = Vector((0.048 + i * seg_len, 0, z_mid))
        b.tail = Vector((0.048 + (i + 1) * seg_len, 0, z_mid))
        b.roll = 0.0
        if prev:
            b.parent = prev
            b.use_connect = True
        prev = b
        names.append(b.name)
    bpy.ops.object.mode_set(mode="OBJECT")
    # vertex groups: gewicht per bot, lineair geblend tussen buren
    for nme in names:
        cloth.vertex_groups.new(name=nme)
    for v in cloth.data.vertices:
        t = (v.co.x - 0.048) / CLOTH_W * nb
        i0 = int(min(max(math.floor(t), 0), nb - 1))
        f = min(max(t - i0, 0), 1)
        if i0 + 1 < nb and f > 0.0:
            cloth.vertex_groups[names[i0]].add([v.index], 1 - f, "REPLACE")
            cloth.vertex_groups[names[i0 + 1]].add([v.index], f, "REPLACE")
        else:
            cloth.vertex_groups[names[i0]].add([v.index], 1.0, "REPLACE")
    mod = cloth.modifiers.new("Skin", "ARMATURE")
    mod.object = rig
    # clip
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    rig.animation_data_create()
    act = bpy.data.actions.new("Wapperen-loop")
    rig.animation_data.action = act
    for f in range(CLIP_FRAMES + 1):
        t = f / CLIP_FRAMES * 2 * math.pi  # precies 1 periode -> naadloze lus
        for i, nme in enumerate(names):
            pb = rig.pose.bones[nme]
            amp = 0.10 + 0.17 * (i / max(nb - 1, 1))            # rand wappert het meest
            yaw = amp * math.sin(t - i * 0.95)
            roll = 0.05 * math.sin(t * 2 - i * 0.6) * (i / max(nb - 1, 1))
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (roll, 0.0, yaw)
            pb.keyframe_insert("rotation_euler", frame=f)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = CLIP_FRAMES
    bpy.context.scene.render.fps = FPS
    return rig


# ------------------------------------------------------------------ opbouw
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    P = PARAMS
    t_alb, t_nrm, t_orm = make_cloth_textures(P["tex"])
    pr = P["prop"]
    w = tinted_set("timber", (1.00, 0.90, 0.78), pr)
    b = tinted_set("steel", (1.0, 0.72, 0.26), pr)
    z = tinted_set("canvas", (0.86, 0.74, 0.50), pr)
    mat_wood = pbr("VQ2_timber", w["albedo"], w["normal"], w["orm"], normal_strength=0.8)
    mat_brass = pbr("VQ2_brass", b["albedo"], b["normal"], b["orm"], normal_strength=0.5)
    mat_bag = pbr("VQ2_sandbag", z["albedo"], z["normal"], z["orm"], normal_strength=1.7, scale=3.0)
    mat_cloth = pbr("Vlagdoek_olijf_goud", t_alb, t_nrm, t_orm, normal_strength=1.0, double_sided=True)
    mat_rope = mat_bag  # touwlussen: dezelfde canvasband als de zakken, dus een materiaal minder
    mat_glass = plain("Lamp_Emissive", (1.0, 0.62, 0.16), 0.3, emission=((1.0, 0.55, 0.10), 6.0))

    root = bpy.data.objects.new("Verzamelvlag", None)
    sc.collection.objects.link(root)
    seg = P["seg"]
    build_pole(mat_wood, mat_brass, seg, root)
    build_lamp(mat_glass, seg, root)
    build_loops(mat_rope, seg, root)
    build_bags(mat_bag, P["bag"], root)
    cloth = build_cloth(mat_cloth, P["cloth"], P["bone_n"], root)
    rig_cloth(cloth, root, P["bone_n"])

    tris = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            dg = bpy.context.evaluated_depsgraph_get()
            m = o.evaluated_get(dg).to_mesh()
            tris += sum(len(p.vertices) - 2 for p in m.polygons)
    print(f"[{LEVEL}] triangles: {tris}, materialen: {len(bpy.data.materials)}")

    stem = {"hq": "Verzamelvlag_HQ", "game": "verzamelvlag", "lod1": "verzamelvlag_lod1"}[LEVEL]
    blend = OUT / f"{stem}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    glb = (OUT if LEVEL == "hq" else ROOT / "assets") / f"{stem}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=True, export_animation_mode="ACTIONS",
        export_materials="EXPORT", export_image_format="AUTO", export_lights=False, export_cameras=False,
    )
    print("geschreven:", glb)
    if LEVEL == "hq":
        usdz = OUT / "Verzamelvlag.usdz"
        try:
            bpy.ops.wm.usd_export(filepath=str(usdz), export_materials=True, export_animation=True, generate_preview_surface=True, export_textures_mode="NEW" if hasattr(bpy.types, "x") else "NEW")
            print("geschreven:", usdz)
        except Exception as exc:  # noqa
            print("USDZ-export mislukt:", exc)


main()
