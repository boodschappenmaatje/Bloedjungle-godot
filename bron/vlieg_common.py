"""Gedeelde bouwstenen voor Blender-vliegtuigen van Bloedjungle (afgeleid van bron/f16/maak_f16.py):
procedurele PBR-texturen (numpy), materiaalhelper, loft/vleugel/cilinder/doos, animatie-sampler (NLA-clips).
Gebruik: import vlieg_common as vc; vc.init(uitmap, texmaat)  (in Blender: --python script.py)."""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = "."
TEX = 1024
FPS = 30
scene = None
ALLE = []


def init(out, tex=1024):
    global OUT, TEX, scene
    OUT = os.path.abspath(out)
    TEX = tex
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    ALLE.clear()
    return scene


def noise(size, scale, seed):
    n = max(size // scale, 1)
    g = np.random.default_rng(seed).random((n + 1, n + 1))
    g[n, :] = g[0, :]
    g[:, n] = g[:, 0]
    scale = size / n   # past precies n keer in de tegel: de textuur herhaalt naadloos
    y, x = np.mgrid[0:size, 0:size]
    x, y = x / scale, y / scale
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def fbm(size, base, seed, octs=4):
    out, amp, tot = np.zeros((size, size)), 1.0, 0.0
    for i in range(octs):
        out += amp * noise(size, max(base >> i, 2), seed + i)
        tot += amp
        amp *= 0.5
    return out / tot


def sm(v, a, b):
    return np.clip((v - a) / (b - a), 0, 1)


def save_img(name, arr, non_color=False):
    h, w = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=2)
    im = bpy.data.images.new(name, w, h)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def lak_textures(naam, kleuren, camo, size=1024, seed=1, vlek=0.18, roet_k=0.35):
    """Tegel van 4 x 4 m: camouflagevlekken (of effen), plaatnaden met klinknagels, vuil, afgesleten verf.
    Geeft albedo, normal en ORM (occlusion/roughness/metallic) terug."""
    y, x = np.mgrid[0:size, 0:size]
    base = fbm(size, 128, seed)
    var = fbm(size, 32, seed + 10)
    if camo:
        a = sm(fbm(size, 512, seed + 3), 0.46, 0.50)   # harde vlekken
        b = sm(fbm(size, 256, seed + 5), 0.52, 0.56)
        img = np.zeros((size, size, 3)) + np.array(kleuren[0])
        img = img * (1 - a[..., None]) + np.array(kleuren[1]) * a[..., None]
        img = img * (1 - b[..., None]) + np.array(kleuren[2]) * b[..., None]
    else:
        img = np.zeros((size, size, 3)) + np.array(kleuren[0])
    img *= (1.0 - vlek / 2 + vlek * var)[..., None]
    h = np.zeros((size, size))
    # plaatnaden elke 1,0 x 1,3 m (4 m = 1024 px, dus 256 px per meter)
    s = max(size // 1024, 1)   # 1 of 2: constantes in pixels voor een tegel van 1024; 2K schaalt mee zodat naden even groot blijven
    naad = (((x % (256 * s)) < 2 * s) | ((x % (256 * s)) > 254 * s - 1)) | (((y % (333 * s)) < 2 * s) | ((y % (333 * s)) > 331 * s - 1))
    h -= naad * 0.6
    img[naad] *= 0.72
    # klinknagelrijen langs de naden
    for off in (10 * s, 246 * s):
        rij = ((x % (256 * s)) // s == off // s) & ((y % (14 * s)) < 3 * s)
        h += rij * 0.5
        rij2 = ((y % (333 * s)) // s == (off + 10 * s) // s) & ((x % (14 * s)) < 3 * s)
        h += rij2 * 0.5
        img[rij | rij2] *= 1.12
    # afgesleten verf op de randen van de naden: lichter metaal
    slijt = sm(fbm(size, 24 * s, seed + 20) * (naad | ((x % (256 * s)) < 6 * s)), 0.30, 0.45)
    img = img * (1 - slijt[..., None] * 0.7) + np.array([0.46, 0.46, 0.44]) * slijt[..., None] * 0.7
    # vuil en uitlaatroet: strepen in de lengterichting (v), mat
    streep = fbm(size, 8, seed + 30)
    roet = sm(noise(size, 64, seed + 40), 0.55, 0.9) * (0.4 + 0.6 * streep)
    img *= (1 - roet_k * roet)[..., None]
    h += (fbm(size, 6, seed + 50) - 0.5) * 0.35
    rough = np.clip(0.52 + 0.22 * fbm(size, 32, seed + 60) + 0.25 * slijt + 0.15 * roet, 0, 1)
    metal = np.clip(slijt * 0.9, 0, 1)
    orm = np.stack([np.ones((size, size)) * 0.95, rough, metal], axis=2)
    return (save_img(naam + "_albedo", np.clip(img, 0, 1)), save_img(naam + "_normal", normal_from_height(h, 2.2), True),
            save_img(naam + "_orm", orm, True))


def metaal_textures(naam, kleur, size=512, seed=70, ruw=0.45, metaal=0.85):
    h = fbm(size, 16, seed) * 0.5 + fbm(size, 4, seed + 1) * 0.5
    krassen = sm(noise(size, 3, seed + 2), 0.7, 1.0)
    img = np.zeros((size, size, 3)) + np.array(kleur)
    img *= (0.85 + 0.3 * fbm(size, 32, seed + 3))[..., None]
    img *= (1 - 0.3 * sm(fbm(size, 64, seed + 4), 0.55, 0.9))[..., None]
    orm = np.stack([np.ones((size, size)) * 0.9, np.clip(ruw + 0.25 * h + 0.2 * krassen, 0, 1), np.ones((size, size)) * metaal], axis=2)
    return (save_img(naam + "_albedo", np.clip(img, 0, 1)), save_img(naam + "_normal", normal_from_height(h * 0.6 + krassen * 0.2, 1.4), True),
            save_img(naam + "_orm", orm, True))


def pbr(naam, tex=None, color=(1, 1, 1), rough=0.6, metal=0.0, emit=None, strength=0.0, alpha=None):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if tex:
        alb, nor, orm = tex
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = alb
        nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = nor
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.8
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
        o = nt.nodes.new("ShaderNodeTexImage")
        o.image = orm
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(o.outputs["Color"], sep.inputs[0])
        nt.links.new(sep.outputs["Green"], p.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], p.inputs["Metallic"])
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m



def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    ALLE.append(obj)
    return obj


def leeg(naam, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(naam, None)
    o.location = loc
    return link(o, parent)


def uv_box(me, tegel=4.0):
    """Metrische boxprojectie per vlak (dominante normaalas), zodat naden en nagels overal even groot zijn."""
    uv = me.uv_layers.new(name="UV")
    for f in me.polygons:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in f.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uvv = (p.y, p.z)
            elif ax == 1:
                uvv = (p.x, p.z)
            else:
                uvv = (p.x, p.y)
            uv.data[li].uv = (uvv[0] / tegel, uvv[1] / tegel)


def mesh_obj(naam, bm, mat_boven, mat_onder=None, parent=None, loc=(0, 0, 0), smooth=True, sharp=40):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(naam)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat_boven)
    if mat_onder:
        me.materials.append(mat_onder)
        for f in me.polygons:
            f.material_index = 1 if f.normal.z < -0.25 else 0
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    uv_box(me)
    o = bpy.data.objects.new(naam, me)
    o.location = loc
    return link(o, parent)


def loft(naam, secties, mat, onder=None, parent=None, loc=(0, 0, 0), segs=16, dicht=(True, True)):
    """secties: (y, breedte, hoogte, z_midden, rondheid[, x_midden]); rondheid 2 = ellips, hoger = hoekiger."""
    bm = bmesh.new()
    ringen = []
    for s in secties:
        y, w, h, zc, p = s[:5]
        xc = s[5] if len(s) > 5 else 0.0
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs + math.pi / segs
            c, sn = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((xc + w / 2 * math.copysign(abs(c) ** (2 / p), c), y, zc + h / 2 * math.copysign(abs(sn) ** (2 / p), sn))))
        ringen.append(ring)
    for r0, r1 in zip(ringen, ringen[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    if dicht[0]:
        bm.faces.new(ringen[0])
    if dicht[1]:
        bm.faces.new(list(reversed(ringen[-1])))
    return mesh_obj(naam, bm, mat, onder, parent, loc)


def cyl(naam, r, lengte, mat, parent=None, loc=(0, 0, 0), as_="y", segs=12, r2=None):
    """Cilinder (of kegel als r2 gezet is) langs een as; oorsprong in het midden."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=lengte)
    if as_ == "y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    elif as_ == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    return mesh_obj(naam, bm, mat, None, parent, loc, smooth=True)


def doos(naam, maat, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, verts=bm.verts, vec=maat)
    o = mesh_obj(naam, bm, mat, None, parent, loc, smooth=False)
    o.rotation_euler = rot
    return o


def profiel(c):
    """Halve dikte van een symmetrisch profiel (0..1 over de koorde), relatief aan de maximale dikte (=1)."""
    return 5 * (0.2969 * math.sqrt(c) - 0.1260 * c - 0.3516 * c * c + 0.2843 * c ** 3 - 0.1015 * c ** 4) / 0.0594 * 0.5


def vleugel(naam, secties, c0, c1, mat, onder, parent=None, loc=(0, 0, 0), n=7):
    """Vleugelstuk tussen koordefracties c0 (voor) en c1 (achter).
    secties: (x, y_voorrand, koorde, dikte, z). Dikte is de maximale dikte in meters."""
    bm = bmesh.new()
    cs = [c0 + (c1 - c0) * i / n for i in range(n + 1)]
    ringen = []
    for (x, y0, koorde, dikte, z) in secties:
        ring = []
        for c in cs:                                  # bovenkant, voor naar achter
            ring.append(bm.verts.new((x, y0 - c * koorde, z + profiel(c) * dikte * 0.5 + 0.02 * dikte * (1 - c))))
        for c in reversed(cs):                        # onderkant, achter naar voor
            ring.append(bm.verts.new((x, y0 - c * koorde, z - profiel(c) * dikte * 0.5 * 0.9 + 0.02 * dikte * (1 - c))))
        ringen.append(ring)
    m = len(ringen[0])
    for r0, r1 in zip(ringen, ringen[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    bm.faces.new(ringen[0])
    bm.faces.new(list(reversed(ringen[-1])))
    return mesh_obj(naam, bm, mat, onder, parent, loc, sharp=60)


def verfijn(sec, per=3):
    """Catmull-Rom tussen de stuurdoorsneden, zodat de romp glad loopt zonder veel handwerk."""
    out = []
    n = len(sec)
    for i in range(n - 1):
        p0, p1, p2, p3 = sec[max(i - 1, 0)], sec[i], sec[i + 1], sec[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            out.append(tuple(0.5 * ((2 * a1) + (-a0 + a2) * t + (2 * a0 - 5 * a1 + 4 * a2 - a3) * t * t + (-a0 + 3 * a1 - 3 * a2 + a3) * t ** 3)
                             for a0, a1, a2, a3 in zip(p0, p1, p2, p3)))
    out.append(sec[-1])
    return out


def pivot_vleugel(naam, secties, c0, c1, mat, onder, parent, gem):
    """Vleugelstuk waarvan de oorsprong op de scharnier `gem` ligt (draait om de X-as)."""
    o = vleugel(naam, secties, c0, c1, mat, onder, parent)
    gem = Vector(gem)
    for v in o.data.vertices:
        v.co -= gem
    o.location = gem
    o.rotation_mode = "XYZ"
    return o



def hoek(graden):
    return math.radians(graden)


def zet_actie(clip, frames, pose, doelen):
    """pose(t) -> {object: {'rot': (x,y,z), 'loc': (x,y,z), 'scale': (x,y,z)}}; t in seconden."""
    acts = {}
    for o in doelen:
        o.animation_data_create()
        a = bpy.data.actions.new(f"{clip}_{o.name}")
        o.animation_data.action = a
        acts[o] = a
    for f in range(frames + 1):
        t = f / FPS
        stand = pose(t)
        for o, w in stand.items():
            if "rot" in w:
                o.rotation_euler = w["rot"]
                o.keyframe_insert("rotation_euler", frame=f)
            if "loc" in w:
                o.location = w["loc"]
                o.keyframe_insert("location", frame=f)
            if "scale" in w:
                o.scale = w["scale"]
                o.keyframe_insert("scale", frame=f)
    for o, a in acts.items():
        fcs = []
        for layer in getattr(a, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    fcs.extend(bag.fcurves)
        fcs.extend(getattr(a, "fcurves", []))
        for fc in fcs:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        tr = o.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, 0, a)
        st.name = clip
        o.animation_data.action = None


def sin(t, periode, amp, fase=0.0):
    return amp * math.sin(math.tau * t / periode + fase)


def smooth(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


def bump(t, midden, breedte):
    return math.exp(-((t - midden) / breedte) ** 2)


