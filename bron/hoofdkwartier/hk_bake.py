"""Bakeketen van het hoofdkwartier: verweerde procedurele materialen -> één 2K-atlas (albedo, ORM, normal).

Alle statische/bewegende onderdelen die een 'bakeable' materiaal hebben krijgen een tweede UV-laag ('Atlas', Smart UV
Project, samen verpakt). De bronmaterialen gebruiken de eerste laag ('UVMap', wereldgebonden herhaling) voor de
PBR-brontexturen en voegen met Cycles-knopen AO-vuil, randslijtage, regenstrepen en modder toe. Daarna bakken we:
albedo (kleur), roughness, metallic (via emissie), normal en AO, en pakken ze in glTF-vorm (ORM: R=AO, G=rough, B=metal).
"""
import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageFilter

KINDS = {
    # chip = kleur onder afgesleten laag, chip_metal = metaalgehalte daar, dirt/mud/streak = hoeveelheid vuil,
    # rust = roest in de slijtage, moss = algengroei onderaan, dust = stof op bovenvlakken, metal_scale = metallic-factor
    "concrete": dict(chip=(0.52, 0.51, 0.47), chip_metal=0.0, dirt=1.15, mud=1.1, streak=1.25, edge=0.6, rust=0.0, moss=0.9, dust=0.5, metal_scale=0.0, bump=0.7),
    "paint": dict(chip=(0.17, 0.15, 0.13), chip_metal=0.2, dirt=0.95, mud=0.9, streak=1.0, edge=1.0, rust=0.8, moss=0.35, dust=0.55, metal_scale=0.25, bump=0.28),
    "metal": dict(chip=(0.30, 0.28, 0.25), chip_metal=0.12, dirt=0.9, mud=0.6, streak=0.8, edge=0.6, rust=0.45, moss=0.15, dust=0.45, metal_scale=0.35, bump=0.14),
    "rubber": dict(chip=(0.07, 0.07, 0.07), chip_metal=0.0, dirt=0.6, mud=0.5, streak=0.4, edge=0.25, rust=0.0, moss=0.0, dust=0.5, metal_scale=0.0, bump=0.3),
}


def _img(path, noncolor):
    im = bpy.data.images.load(str(path), check_existing=True)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    return im


def _wire(nt, a, b):
    nt.links.new(a, b)


def weathered(name, kind, *, albedo=None, normal=None, orm=None, color=(0.5, 0.5, 0.5), rough=0.7, metal=0.0,
              nstrength=1.0, seed=1.0, wear=1.0):
    """Verweerd bakemateriaal. Zonder textuurpaden is het een egale verf met alleen de verweringslagen."""
    K = KINDS[kind]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    nodes.clear()
    new = nodes.new
    out = new("ShaderNodeOutputMaterial")
    bsdf = new("ShaderNodeBsdfPrincipled")
    emit = new("ShaderNodeEmission")
    uv = new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    geo = new("ShaderNodeNewGeometry")

    def math_node(op, a=None, b=None, clamp=False):
        m = new("ShaderNodeMath")
        m.operation = op
        m.use_clamp = clamp
        if a is not None:
            if isinstance(a, (int, float)):
                m.inputs[0].default_value = a
            else:
                _wire(nt, a, m.inputs[0])
        if b is not None:
            if isinstance(b, (int, float)):
                m.inputs[1].default_value = b
            else:
                _wire(nt, b, m.inputs[1])
        return m.outputs[0]

    def rng(v, lo, hi, a=0.0, b=1.0, clamp=True):
        r = new("ShaderNodeMapRange")
        r.clamp = clamp
        _wire(nt, v, r.inputs["Value"])
        r.inputs["From Min"].default_value = lo
        r.inputs["From Max"].default_value = hi
        r.inputs["To Min"].default_value = a
        r.inputs["To Max"].default_value = b
        return r.outputs["Result"]

    def noise(scale, mapping_scale=(1, 1, 1), detail=6.0, rough_=0.55, offset=(0, 0, 0)):
        mp = new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = tuple(s * scale for s in mapping_scale)
        mp.inputs["Location"].default_value = (offset[0] + seed * 7.3, offset[1] + seed * 3.1, offset[2])
        _wire(nt, geo.outputs["Position"], mp.inputs["Vector"])
        t = new("ShaderNodeTexNoise")
        t.inputs["Detail"].default_value = detail
        t.inputs["Roughness"].default_value = rough_
        _wire(nt, mp.outputs["Vector"], t.inputs["Vector"])
        return t.outputs["Factor"]

    def mix(fac, a, b):
        m = new("ShaderNodeMixRGB")
        m.blend_type = "MIX"
        _wire(nt, fac, m.inputs[0])
        for i, v in ((1, a), (2, b)):
            if isinstance(v, tuple):
                m.inputs[i].default_value = (*v, 1.0)
            else:
                _wire(nt, v, m.inputs[i])
        return m.outputs[0]

    def mult(a, b):
        m = new("ShaderNodeMixRGB")
        m.blend_type = "MULTIPLY"
        m.inputs[0].default_value = 1.0
        _wire(nt, a, m.inputs[1])
        if isinstance(b, tuple):
            m.inputs[2].default_value = (*b, 1.0)
        else:
            _wire(nt, b, m.inputs[2])
        return m.outputs[0]

    # ---- basis uit brontextuur of egale kleur
    if albedo:
        t = new("ShaderNodeTexImage")
        t.image = _img(albedo, False)
        _wire(nt, uv.outputs["UV"], t.inputs["Vector"])
        base = t.outputs["Color"]
    else:
        v = new("ShaderNodeRGB")
        v.outputs[0].default_value = (*color, 1.0)
        base = v.outputs[0]
    if orm:
        t = new("ShaderNodeTexImage")
        t.image = _img(orm, True)
        _wire(nt, uv.outputs["UV"], t.inputs["Vector"])
        sep = new("ShaderNodeSeparateColor")
        _wire(nt, t.outputs["Color"], sep.inputs[0])
        r0, m0 = sep.outputs["Green"], sep.outputs["Blue"]
    else:
        r = new("ShaderNodeValue")
        r.outputs[0].default_value = rough
        mv = new("ShaderNodeValue")
        mv.outputs[0].default_value = metal
        r0, m0 = r.outputs[0], mv.outputs[0]

    # ---- maskers
    ao = new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.7
    ao.samples = 12
    cavity = ao.outputs["AO"]                                   # 1 = open, 0 = dichtgeknepen
    inv_cav = math_node("SUBTRACT", 1.0, cavity, clamp=True)    # 1 = in de hoek

    bev = new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.022
    bev.samples = 6
    dot = new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    _wire(nt, bev.outputs["Normal"], dot.inputs[0])
    _wire(nt, geo.outputs["Normal"], dot.inputs[1])
    edge_raw = math_node("SUBTRACT", 1.0, dot.outputs["Value"], clamp=True)
    edge = rng(edge_raw, 0.004, 0.06)                            # 1 = op een rand
    chip_noise = rng(noise(38.0, detail=4.0), 0.44, 0.58)
    chip = math_node("MULTIPLY", edge, chip_noise, clamp=True)
    chip = math_node("MULTIPLY", chip, K["edge"] * wear, clamp=True)

    z = new("ShaderNodeSeparateXYZ")
    _wire(nt, geo.outputs["Position"], z.inputs[0])
    zh = z.outputs["Z"]
    low = rng(zh, 0.15, 1.35, 1.0, 0.0)                          # 1 = bij de grond
    mud_n = rng(noise(3.4, detail=7.0), 0.30, 0.72)
    mud = math_node("MULTIPLY", low, mud_n, clamp=True)
    mud = math_node("MULTIPLY", mud, 1.15 * K["mud"], clamp=True)
    splash = math_node("MULTIPLY", rng(zh, 0.0, 0.7, 1.0, 0.0), rng(noise(14.0, detail=4.0), 0.4, 0.7), clamp=True)
    mud = math_node("ADD", mud, math_node("MULTIPLY", splash, 0.6 * K["mud"]), clamp=True)

    # regenstrepen: ruis die sterk in Z is uitgerekt, sterker onder randen/kozijnen (AO) en hoger op de wand
    streak_n = rng(noise(7.0, mapping_scale=(1.0, 1.0, 0.07), detail=5.0), 0.46, 0.74)
    streak = math_node("MULTIPLY", streak_n, math_node("ADD", 0.25, math_node("MULTIPLY", inv_cav, 1.4)), clamp=True)
    streak = math_node("MULTIPLY", streak, 0.85 * K["streak"], clamp=True)

    grime_macro = rng(noise(0.9, detail=3.0), 0.25, 0.75, 0.82, 1.12)   # grote kleurvlakken per paneel
    island = rng(geo.outputs["Random Per Island"], 0.0, 1.0, 0.93, 1.07)

    # stof op bovenvlakken, algen onderaan, roest in de slijtage
    nz = new("ShaderNodeSeparateXYZ")
    _wire(nt, geo.outputs["Normal"], nz.inputs[0])
    up = rng(nz.outputs["Z"], 0.5, 0.95)
    dust = math_node("MULTIPLY", up, rng(noise(6.0, detail=5.0), 0.30, 0.65), clamp=True)
    dust = math_node("MULTIPLY", dust, 0.62 * K["dust"], clamp=True)
    moss_n = rng(noise(5.0, detail=6.0), 0.42, 0.66)
    moss = math_node("MULTIPLY", rng(zh, 0.1, 1.7, 1.0, 0.0), moss_n, clamp=True)
    moss = math_node("MULTIPLY", moss, math_node("ADD", 0.4, math_node("MULTIPLY", inv_cav, 1.2)), clamp=True)
    moss = math_node("MULTIPLY", moss, 0.75 * K["moss"], clamp=True)
    rust_n = rng(noise(11.0, detail=6.0), 0.40, 0.62)
    rust = math_node("MULTIPLY", math_node("ADD", chip, math_node("MULTIPLY", streak, 0.55), clamp=True), rust_n, clamp=True)
    rust = math_node("MULTIPLY", rust, K["rust"], clamp=True)

    # ---- kleur
    col = mult(base, grime_macro)
    col = mult(col, island)
    col = mix(math_node("MULTIPLY", inv_cav, 0.48 * K["dirt"], clamp=True), col, (0.050, 0.046, 0.040))      # vuil in de hoeken
    col = mix(streak, col, (0.070, 0.064, 0.055))                                                             # regenstrepen
    col = mix(moss, col, (0.085, 0.120, 0.045))                                                                # algen en mos
    col = mix(dust, col, (0.30, 0.255, 0.19))                                                                  # stof op bovenvlakken
    col = mix(mud, col, (0.19, 0.135, 0.085))                                                                  # modder onderaan
    col = mix(chip, col, K["chip"])                                                                            # afgesleten randen
    col = mix(rust, col, (0.30, 0.125, 0.05))                                                                  # roest
    _wire(nt, col, bsdf.inputs["Base Color"])

    # ---- roughness en metallic
    r1 = math_node("ADD", r0, math_node("MULTIPLY", math_node("ADD", mud, streak), 0.22), clamp=True)
    r1 = math_node("ADD", r1, math_node("MULTIPLY", math_node("ADD", dust, rust), 0.3), clamp=True)
    r1 = math_node("SUBTRACT", r1, math_node("MULTIPLY", chip, 0.30), clamp=True)
    _wire(nt, r1, bsdf.inputs["Roughness"])
    m1 = math_node("MULTIPLY", m0, K["metal_scale"])
    m1 = math_node("ADD", m1, math_node("MULTIPLY", chip, K["chip_metal"]), clamp=True)
    m1 = math_node("MULTIPLY", m1, math_node("SUBTRACT", 1.0, math_node("ADD", math_node("MULTIPLY", mud, 0.9), math_node("ADD", rust, dust)), clamp=True), clamp=True)
    _wire(nt, m1, bsdf.inputs["Metallic"])

    # ---- microreliëf: putjes, korrel en afgesprongen verf; bump bovenop de normal-map
    bump = new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.012
    bump.inputs["Strength"].default_value = K.get("bump", 0.5)
    hmix = math_node("SUBTRACT", noise(85.0, detail=9.0, rough_=0.6), math_node("MULTIPLY", chip, 0.45))
    hmix = math_node("ADD", hmix, math_node("MULTIPLY", rng(noise(23.0, detail=6.0), 0.4, 0.6), 0.35))
    _wire(nt, hmix, bump.inputs["Height"])
    _wire(nt, bump.outputs["Normal"], bsdf.inputs["Normal"])

    # ---- normal uit de brontextuur (tangentruimte van laag UVMap)
    if normal:
        t = new("ShaderNodeTexImage")
        t.image = _img(normal, True)
        _wire(nt, uv.outputs["UV"], t.inputs["Vector"])
        nm = new("ShaderNodeNormalMap")
        nm.uv_map = "UVMap"
        nm.inputs["Strength"].default_value = nstrength
        _wire(nt, t.outputs["Color"], nm.inputs["Color"])
        _wire(nt, nm.outputs["Normal"], bump.inputs["Normal"])

    # emissie-uitgang voor het metallic-pass (grijswaarde = metallic)
    comb = new("ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"):
        _wire(nt, m1, comb.inputs[k])
    _wire(nt, comb.outputs["Color"], emit.inputs["Color"])

    _wire(nt, bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat["bake_kind"] = kind
    mat["_bsdf"] = bsdf.name
    mat["_emit"] = emit.name
    mat["_out"] = out.name
    return mat


def set_pass(mats, which):
    """Koppel Material Output aan de BSDF ('bsdf') of aan de emissie ('emit')."""
    for m in mats:
        nt = m.node_tree
        out = nt.nodes[m["_out"]]
        src = nt.nodes[m["_bsdf"] if which == "bsdf" else m["_emit"]]
        sock = src.outputs["BSDF"] if which == "bsdf" else src.outputs["Emission"]
        for lk in list(out.inputs["Surface"].links):
            nt.links.remove(lk)
        nt.links.new(sock, out.inputs["Surface"])


def make_atlas_uvs(objs, margin=0.003, fresh=True):
    """Tweede UV-laag 'Atlas' met Smart UV Project, voor alle objecten samen verpakt (alleen 0/90 graden)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        if fresh and "Atlas" in o.data.uv_layers:
            o.data.uv_layers.remove(o.data.uv_layers["Atlas"])
        uvl = o.data.uv_layers.get("Atlas") or o.data.uv_layers.new(name="Atlas")
        o.data.uv_layers.active = uvl
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), margin_method="FRACTION", island_margin=margin,
                             rotate_method="AXIS_ALIGNED", area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, rotate_method="CARDINAL", margin_method="FRACTION", margin=margin,
                            shape_method="AABB", scale=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        o.data.uv_layers.active = o.data.uv_layers["Atlas"]
        o.data.uv_layers["Atlas"].active_render = True


def cull_hidden(objs, res=1024, thr=0.06):
    """Verwijder vlakken die nergens zichtbaar zijn (rugvlakken van panelen, binnenkanten, ondervlakken bij de grond).
    Een snelle AO-bake op voorlopige UV's wijst vlakken aan zonder licht; die gaan eruit en de atlas wordt opnieuw gemaakt."""
    import bmesh
    img = bpy.data.images.new("cull_ao", res, res, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    _target(objs, img)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    # Onderdelen die Godot per niveau aan/uit zet (Niveau2_*, Niveau3_*) mogen geen schaduw werpen op wat op elk niveau zichtbaar is:
    # anders verdwijnen vlakken die alleen door de dikke wal van niveau 3 bedekt worden (de kniemuur!) ook voor niveau 1 en 2.
    # Daarom twee snoeibakes: de vaste onderdelen beoordelen we met de niveau-onderdelen onzichtbaar voor stralen, de niveau-onderdelen
    # zelf met alles zichtbaar (hun eigen onderlinge bedekking mag wel).
    flags = ("visible_diffuse", "visible_glossy", "visible_transmission", "visible_shadow", "visible_volume_scatter")
    toggled = [o for o in objs if o.name.startswith("Niveau")]
    saved = [(o, {f: getattr(o, f) for f in flags}) for o in toggled]

    def ao_pixels(hide_levels):
        for o, vals in saved:
            for f, v in vals.items():
                setattr(o, f, False if hide_levels else v)
        bpy.ops.object.bake(type="AO", margin=1, margin_type="EXTEND", use_clear=True)
        return np.array(img.pixels[:], dtype=np.float32).reshape(res, res, 4)[..., 0]

    px_fixed = ao_pixels(True) if toggled else None
    px_all = ao_pixels(False)
    for o, vals in saved:
        for f, v in vals.items():
            setattr(o, f, v)
    if px_fixed is None:
        px_fixed = px_all
    removed = 0
    total = 0
    for o in objs:
        px = px_all if o.name.startswith("Niveau") else px_fixed
        bm = bmesh.new()
        bm.from_mesh(o.data)
        uvl = bm.loops.layers.uv["Atlas"]
        mw = o.matrix_world
        dead = []
        for f in bm.faces:
            total += 1
            us = [lp[uvl].uv for lp in f.loops]
            cx = sum(u[0] for u in us) / len(us)
            cy = sum(u[1] for u in us) / len(us)
            # Meetpunten: midden, halverwege en vlak bij elke hoek, en de randmidden. Een groot vlak dat deels door panelen
            # bedekt wordt (de kniemuur onder de ramen) mag niet verdwijnen omdat alleen het bedekte midden donker is.
            pts = [(cx, cy)]
            for p in us:
                for t in (0.5, 0.9):
                    pts.append((cx + (p[0] - cx) * t, cy + (p[1] - cy) * t))
            for i in range(len(us)):
                a, b = us[i], us[(i + 1) % len(us)]
                pts.append((cx + ((a[0] + b[0]) / 2 - cx) * 0.9, cy + ((a[1] + b[1]) / 2 - cy) * 0.9))
            if len(us) == 4 and f.calc_area() > 0.4:      # groot vierhoekig vlak: ook een raster over het hele vlak
                for i in range(1, 6):
                    for j in range(1, 6):
                        s_, t_ = i / 6.0, j / 6.0
                        pts.append((
                            (1 - s_) * (1 - t_) * us[0][0] + s_ * (1 - t_) * us[1][0] + s_ * t_ * us[2][0] + (1 - s_) * t_ * us[3][0],
                            (1 - s_) * (1 - t_) * us[0][1] + s_ * (1 - t_) * us[1][1] + s_ * t_ * us[2][1] + (1 - s_) * t_ * us[3][1]))
            vals = []
            for (u, v) in pts:
                ix = min(res - 1, max(0, int(u * res)))
                iy = min(res - 1, max(0, int(v * res)))
                vals.append(px[iy, ix])
            hidden = max(vals) < thr
            n = mw.to_3x3() @ f.normal
            c = mw @ f.calc_center_median()
            if n.z < -0.95 and c.z < 0.45:
                hidden = True
            if hidden:
                dead.append(f)
        if dead and len(dead) >= len(bm.faces):
            dead = []          # nooit een heel object weggooien
        if dead:
            bmesh.ops.delete(bm, geom=dead, context="FACES")
            removed += len(dead)
        bm.to_mesh(o.data)
        bm.free()
    bpy.data.images.remove(img)
    print(f"[cull] {removed} van {total} vlakken verwijderd (niet zichtbaar)")
    return removed


def _target(objs, img):
    """Zet in alle materialen van objs een actieve Image Texture-knoop met het doelbeeld."""
    for o in objs:
        for slot in o.material_slots:
            nt = slot.material.node_tree
            node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "BakeTarget"
            node.image = img
            nt.nodes.active = node


def _bake(objs, mats, kind, img, samples, **kw):
    sc = bpy.context.scene
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    _target(objs, img)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type=kind, margin=10, margin_type="EXTEND", use_clear=True, **kw)


def run(objs, res, out_dir, samples=32, tag="hk"):
    """Bak de atlas en geef paden naar albedo, orm en normal terug."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    mats = []
    for o in objs:
        for s in o.material_slots:
            if s.material not in mats:
                mats.append(s.material)
    out_dir = Path(out_dir)

    def new_img(name, color_space):
        im = bpy.data.images.new(name, res, res, alpha=False, float_buffer=False)
        im.colorspace_settings.name = color_space
        return im

    paths = {}

    def save(im, nm):
        p = out_dir / f"{tag}_{nm}_{res}.png"
        im.filepath_raw = str(p)
        im.file_format = "PNG"
        im.save()
        paths[nm] = p

    set_pass(mats, "bsdf")
    alb = new_img("bk_albedo", "sRGB")
    _bake(objs, mats, "DIFFUSE", alb, samples, pass_filter={"COLOR"})
    save(alb, "albedo_raw")
    rgh = new_img("bk_rough", "Non-Color")
    _bake(objs, mats, "ROUGHNESS", rgh, 8)
    save(rgh, "rough")
    nrm = new_img("bk_normal", "Non-Color")
    _bake(objs, mats, "NORMAL", nrm, 8, normal_space="TANGENT")
    save(nrm, "normal")
    ao = new_img("bk_ao", "Non-Color")
    _bake(objs, mats, "AO", ao, 40)
    save(ao, "ao")
    set_pass(mats, "emit")
    met = new_img("bk_metal", "Non-Color")
    _bake(objs, mats, "EMIT", met, 4)
    save(met, "metal")
    set_pass(mats, "bsdf")
    return paths


ALBEDO_GAIN = 2.4


def compose(paths, res, out_dir, tag="hk", jpeg=False):
    """Combineer de passes tot albedo (met lichte AO), ORM en normal; vul gaten tussen eilanden."""
    out_dir = Path(out_dir)

    def load(nm):
        return np.asarray(Image.open(paths[nm]).convert("RGB"), dtype=np.float32) / 255.0

    alb, rgh, met, ao = load("albedo_raw"), load("rough"), load("metal"), load("ao")
    ao1 = ao[..., :1]
    # AO zit ook in de ORM-textuur (glTF-occlusie); in de albedo daarom maar licht (30%). Lineaire winst 2,4: de brontexturen zijn
    # donker (gemiddeld 60/255) en de spelcamera (ACES, contrast 1,2) maakt het nog donkerder dan de vliegvelden (87-96/255).
    lin = np.where(alb <= 0.04045, alb / 12.92, ((alb + 0.055) / 1.055) ** 2.4) * (0.7 + 0.3 * ao1) * ALBEDO_GAIN
    lin = np.clip(lin, 0.0, 1.0)
    alb_f = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(np.maximum(lin, 1e-9), 1 / 2.4) - 0.055)
    orm = np.concatenate([ao1, rgh[..., 1:2], met[..., 2:3]], axis=2)

    def save(arr, nm):
        im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
        if jpeg:
            p = out_dir / f"{tag}_{nm}_{res}.jpg"
            im.save(p, quality=92, subsampling=0)
        else:
            p = out_dir / f"{tag}_{nm}_{res}.png"
            im.save(p, optimize=True)
        return p

    p_alb = save(alb_f, "albedo")
    p_orm = save(orm, "orm")
    nrm = np.asarray(Image.open(paths["normal"]).convert("RGB"), dtype=np.float32) / 255.0
    p_nrm = save(nrm, "normal_c")
    return p_alb, p_orm, p_nrm


def baked_material(name, albedo, orm, normal, gltf_ao=True):
    """Eén PBR-materiaal met de gebakken atlas; AO gaat via de glTF-uitvoerknoop mee in de ORM-textuur."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    uv = n.new("ShaderNodeUVMap")
    uv.uv_map = "Atlas"

    def tex(p, nc):
        t = n.new("ShaderNodeTexImage")
        t.image = _img(p, nc)
        t.interpolation = "Linear"
        l.new(uv.outputs["UV"], t.inputs["Vector"])
        return t

    l.new(tex(albedo, False).outputs["Color"], bsdf.inputs["Base Color"])
    nm = n.new("ShaderNodeNormalMap")
    nm.uv_map = "Atlas"
    l.new(tex(normal, True).outputs["Color"], nm.inputs["Color"])
    l.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    o = tex(orm, True)
    sep = n.new("ShaderNodeSeparateColor")
    l.new(o.outputs["Color"], sep.inputs[0])
    l.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    l.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    if gltf_ao:
        grp = bpy.data.node_groups.get("glTF Material Output")
        if grp is None:
            grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
            grp.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        g = n.new("ShaderNodeGroup")
        g.node_tree = grp
        g.name = "glTF Material Output"
        l.new(sep.outputs["Red"], g.inputs["Occlusion"])
    mat.use_backface_culling = True
    return mat
