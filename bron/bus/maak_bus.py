"""Stadsbus voor de stad (Bloedjungle, VQ2): 10,6 m lange lijnbus met echte PBR-texturen (2K lak met belettering-banen,
regenstrepen, modder, mos op het dak), onderdelen die los kunnen (deurbladen, motorluik, dakluiken, airco, wielen, ruiten),
Blender-animaties en een schadevorm (shape key 'Deuk') plus een verkoold materiaal voor het wrak.
Zelfde bouwwijze als de personenauto (bron/auto/maak_auto.py).

Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden op de grond, voorkant aan +Y (wordt -Z in Godot).
Gebruik:  python3 maak_bus.py <uitmap> [--render]   ->  bus.glb, bus.blend, texturen (PNG) in <uitmap>

Knopen in de GLB (Bus = wortel):
  Carrosserie (leeg; knielt in de clip Knielen) met daarin:
    Romp (shape key Deuk), Voorruit, Achterruit, RuitenL, RuitenR, DeurVA/DeurVB (voordeur, rechts), DeurMA/DeurMB (middendeur),
    Motorluik (achter), DakluikV, DakluikA, Airco, WisserL, WisserR, WrakRef (verborgen: verkoold materiaal),
    Licht* = verlichte lenzen en lichtbakken (rustpositie schaal 0; het spel of een clip zet ze aan).
  Wiel_LV, Wiel_RV (voor), Wiel_LA, Wiel_RA (achter, dubbel lucht).
Clips: VoordeurOpen, MiddendeurOpen, MotorluikOpen, Knielen, LichtenAan, Ruitenwissers-loop, Knipperen-loop, Alarm-loop.
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector, Quaternion

ARGS = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath([a for a in ARGS if not a.startswith("--")][0])
RENDER = "--render" in ARGS
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
FPS = 30
scene.render.fps = FPS

# hoofdmaten
L2 = 5.32          # halve lengte (voorkant +Y)
W2 = 1.25          # halve breedte
H = 3.05           # hoogte van het dak
L_BUS = 2 * L2
WR = 0.50          # wielstraal
WYV, WYA = 3.20, -2.45   # vooras, achteras
WX = 1.08          # midden van de buitenste band


# ============================================================ texturen (numpy)
def noise(size, scale, seed, sy=None):
    sy = sy or scale
    nx, ny = max(size // scale, 1), max(size // sy, 1)
    g = np.random.default_rng(seed).random((ny + 1, nx + 1))
    g[ny, :] = g[0, :]
    g[:, nx] = g[:, 0]
    y, x = np.mgrid[0:size, 0:size]
    x, y = x / scale, y / sy
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


def sm(v, e0, e1):
    return np.clip((v - e0) / (e1 - e0), 0, 1)


def save_img(name, arr, non_color=False):
    h, w = arr.shape[0], arr.shape[1]
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


def scratches(size, seed, count, length):
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size))
    for _ in range(count):
        x, y = rng.random() * size, rng.random() * size
        a = rng.normal(0.0, 0.35) if rng.random() < 0.8 else rng.random() * math.pi
        for t in range(int(length * (0.4 + rng.random()))):
            px, py = int(x + math.cos(a) * t) % size, int(y + math.sin(a) * t) % size
            img[py, px] = max(img[py, px], 0.5 + rng.random() * 0.5)
    return img


# Belettering in hoogte (meters) op de zijkant; dezelfde banen lopen over de voor- en achterkant.
BAND_SKIRT = (0.30, 0.78)     # donkergroene rok
BAND_STRIPE = (1.18, 1.26)    # okergele bies onder de ramen
BAND_WINDOW = (1.26, 2.70)    # zwarte raamband (stijlen tussen de ruiten)
CREAM = np.array([0.84, 0.80, 0.68])
GREEN = np.array([0.17, 0.29, 0.22])
OCHRE = np.array([0.70, 0.50, 0.16])
BLACK = np.array([0.055, 0.058, 0.055])


def lak_textures(size=2048):
    """Buslak, 2K. Indeling: v 0-0,5 = zijkant (u langs de bus, v = hoogte), v 0,52-0,78 = dak (u langs, v over de breedte),
    v 0,80-1 = voor- en achterkant (u over de breedte, v = hoogte). Kleuren zitten in de textuur; het spel tint licht bij."""
    y, x = np.mgrid[0:size, 0:size]
    u, v = x / size, 1 - y / size
    side = v < 0.5
    roof = (v >= 0.5) & (v < 0.79)
    front = v >= 0.79
    z = np.where(side, v / 0.5 * H, np.where(front, (v - 0.80) / 0.2 * H, H))      # hoogte in meters
    w = np.clip((v - 0.52) / 0.26, 0, 1)                                             # dak: 0..1 over de breedte
    n1, n2, n3 = fbm(size, 256, 1), fbm(size, 64, 5), fbm(size, 16, 7)
    # belettering
    img = np.repeat(CREAM[None, None, :], size, axis=0).repeat(size, axis=1) * 1.0
    def band(zr, col, soft=0.004):
        m = sm(z, zr[0] - soft, zr[0] + soft) * (1 - sm(z, zr[1] - soft, zr[1] + soft))
        m = np.where(roof, 0.0, m)
        return m[..., None], col
    for zr, col in ((BAND_SKIRT, GREEN), (BAND_STRIPE, OCHRE), (BAND_WINDOW, BLACK)):
        m, c = band(zr, col)
        img = img * (1 - m) + c[None, None, :] * m
    under = np.where(roof, 0.0, 1 - sm(z, 0.26, 0.32))[..., None]                   # onderkant: vuil donker
    img = img * (1 - under) + np.array([0.07, 0.065, 0.06])[None, None, :] * under
    # lakvariatie en zonverbleking (bovenaan sterker)
    fade = (0.92 + 0.08 * n1)[..., None]
    img = img * fade
    bleach = (np.where(roof, 1.0, sm(z, 1.8, 3.0)) * 0.10 * (0.6 + 0.8 * n2))[..., None]
    img = img * (1 - bleach) + np.array([0.85, 0.84, 0.8])[None, None, :] * bleach
    # plaatnaden op de zijkant (verticaal elke 1,06 m in de onderste panelen) en horizontale naad op 0,78 m
    seam_u = np.abs(((u * L_BUS / 1.06) % 1) - 0.5) > 0.4985
    seam = side & seam_u & (z > 0.32) & (z < 1.18)
    seam |= side & (np.abs(z - 0.78) < 0.006)
    seam |= front & (np.abs(z - 0.78) < 0.006)
    seam = seam.astype(float)
    # klinknagels langs de naden
    rivet = side & (z > 0.34) & (z < 1.16) & (np.abs(((u * L_BUS / 1.06) % 1) - 0.5) > 0.493) & (np.abs(((z / 0.09) % 1) - 0.5) < 0.12)
    rivet = rivet.astype(float)
    img = img * (1 - seam[..., None] * 0.55)
    # modder en vuil onderin, extra spatten rond de wielkasten
    wheel_u = [0.5 - WYV / L_BUS, 0.5 - WYA / L_BUS]
    wiel = sum(np.exp(-((u - c) / 0.05) ** 2) for c in wheel_u) * side
    mud = np.clip(sm(1.0 - z, 0, 0.75) * (0.45 + 0.9 * n2) * side + wiel * sm(1.5 - z, 0, 1.3) * (0.4 + 0.9 * n3), 0, 1)
    mud += front * sm(0.9 - z, 0, 0.6) * (0.3 + 0.7 * n2)
    mud = np.clip(mud, 0, 1) * 0.9
    img = img * (1 - mud[..., None] * 0.8) + np.array([0.24, 0.18, 0.11])[None, None, :] * mud[..., None] * 0.8
    # regenstrepen onder de ramen (lopen naar beneden uit)
    streak_n = sm(noise(size, 4, 9, 512), 0.6, 0.92)
    streak = streak_n * side * sm(z, 0.3, 1.0) * (1 - sm(z, 1.18, 1.22)) * 0.30
    streak += streak_n * side * sm(z, 2.75, 2.95) * 0.18                            # onder de dakrand
    img = img * (1 - streak[..., None]) + np.array([0.20, 0.19, 0.16])[None, None, :] * streak[..., None] * 0.6
    # dak: vuil langs de randen, waterlopen in de lengterichting, groene aanslag (jungle) en bladresten
    edge = np.minimum(w, 1 - w)
    roofgrime = roof * (sm(0.25 - edge, 0, 0.25) * (0.4 + 0.8 * n2) + sm(noise(size, 512, 21, 4), 0.55, 0.85) * 0.35)
    moss = roof * sm(fbm(size, 64, 22), 0.55, 0.72) * sm(0.3 - edge, 0, 0.3)
    img = img * (1 - roofgrime[..., None] * 0.6) + np.array([0.30, 0.27, 0.21])[None, None, :] * roofgrime[..., None] * 0.6
    img = img * (1 - moss[..., None] * 0.75) + np.array([0.20, 0.27, 0.11])[None, None, :] * moss[..., None] * 0.75
    leaf = roof * sm(fbm(size, 8, 23, 2), 0.78, 0.83) * 0.8
    img = img * (1 - leaf[..., None]) + np.array([0.28, 0.20, 0.09])[None, None, :] * leaf[..., None]
    # krassen, afgebladderde lak (vooral op de hoeken en onderin) en roest bij de wielkasten
    sc = scratches(size, 3, 900, 110) * np.where(roof, 0.3, 1.0)
    corner = np.maximum(sm(0.04 - u, 0, 0.04), sm(u - 0.96, 0, 0.04)) * side
    chip = sm(fbm(size, 16, 12), 0.70, 0.78) * np.clip(sm(0.9 - z, 0, 0.6) * side + corner + front * sm(0.7 - z, 0, 0.4), 0, 1)
    img = img * (1 - sc[..., None] * 0.3) + sc[..., None] * np.array([0.5, 0.5, 0.48])[None, None, :] * 0.3
    img = img * (1 - chip[..., None]) + np.array([0.42, 0.41, 0.39])[None, None, :] * chip[..., None]
    rust = sm(fbm(size, 32, 20), 0.62, 0.74) * (sm(0.75 - z, 0, 0.45) * side * (0.4 + wiel) + seam * 0.5)
    rust = np.clip(rust, 0, 1)
    img = img * (1 - rust[..., None] * 0.85) + np.array([0.40, 0.20, 0.09])[None, None, :] * rust[..., None] * 0.85
    # hoogte: naden ingedrukt, klinknagels erop, lakbobbels
    h = 0.35 * fbm(size, 32, 30, 3) + 0.15 * n3 - 0.6 * seam + 0.5 * rivet - 0.12 * sc + 0.25 * chip + 0.2 * rust
    rough = 0.36 + 0.18 * n1 + 0.45 * mud + 0.35 * chip + 0.3 * moss + 0.25 * roofgrime + 0.4 * rust
    metal = np.clip(chip * 0.85, 0, 1)
    orm = np.stack([np.clip(1 - 0.5 * seam - 0.2 * under[..., 0], 0, 1), np.clip(rough, 0, 1), metal], axis=2)
    return (save_img("bus_lak", img), save_img("bus_lak_n", normal_from_height(h, 4.0), True),
            save_img("bus_lak_orm", orm, True))


def rubber_textures(size=512):
    y, x = np.mgrid[0:size, 0:size]
    u, v = x / size * 3 % 1, y / size
    groef = np.where(np.abs(((u * 10 + v * 0.8) % 1) - 0.5) < 0.08, 0.0, 1.0)
    mid = np.where((np.abs(v - 0.33) < 0.03) | (np.abs(v - 0.67) < 0.03), 0.0, 1.0)
    h = 0.15 + 0.85 * np.minimum(groef, mid) * (0.9 + 0.1 * fbm(size, 8, 40))
    img = np.repeat(((0.075 + 0.05 * fbm(size, 16, 41)) * (0.7 + 0.3 * h))[..., None], 3, axis=2)
    dust = sm(fbm(size, 32, 42), 0.5, 0.8) * 0.6
    img = img * (1 - dust[..., None]) + np.array([0.24, 0.20, 0.15])[None, None, :] * dust[..., None] * 0.7
    orm = np.stack([np.ones_like(h) * 0.9, np.clip(0.85 - 0.2 * h + dust * 0.1, 0, 1), np.zeros_like(h)], axis=2)
    return (save_img("bus_rubber", img), save_img("bus_rubber_n", normal_from_height(h, 5.0), True),
            save_img("bus_rubber_orm", orm, True))


def wreck_textures(size=1024):
    """Uitgebrand wrak: roet, as, doorgebrande roest en blank staal. Zelfde UV-indeling als de lak."""
    y, x = np.mgrid[0:size, 0:size]
    v = 1 - y / size
    z = np.where(v < 0.5, v / 0.5 * H, np.where(v >= 0.79, (v - 0.8) / 0.2 * H, H))
    n1, n2, n3, fine = fbm(size, 128, 50), fbm(size, 32, 51), fbm(size, 8, 52), fbm(size, 4, 55, 2)
    base = (0.028 + 0.035 * n1) * (0.75 + 0.5 * fine)
    img = np.repeat(base[..., None], 3, axis=2)
    ash = sm(n2, 0.6, 0.85) * (0.2 + 0.5 * sm(z, 1.2, 3.0)) * 0.55
    img = img * (1 - ash[..., None]) + np.array([0.15, 0.145, 0.14])[None, None, :] * ash[..., None]
    rust = sm(fbm(size, 64, 53), 0.55, 0.8) * sm(1.6 - z, -0.5, 1.4) * 0.6
    img = img * (1 - rust[..., None]) + np.array([0.22, 0.10, 0.05])[None, None, :] * rust[..., None] * (0.6 + 0.8 * n3[..., None])
    bare = sm(fbm(size, 16, 54), 0.76, 0.88) * 0.6
    img = img * (1 - bare[..., None]) + np.array([0.08, 0.075, 0.07])[None, None, :] * bare[..., None]
    # restje van de groene rok dat niet helemaal is verbrand
    ghost = sm(z, 0.3, 0.35) * (1 - sm(z, 0.75, 0.8)) * sm(fbm(size, 32, 56), 0.6, 0.8) * 0.5
    img = img * (1 - ghost[..., None]) + np.array([0.08, 0.11, 0.08])[None, None, :] * ghost[..., None]
    h = 0.4 * n3 + 0.3 * n2 + 0.3 * fine + 0.2 * rust
    rough = np.clip(0.8 + 0.2 * n2 - 0.3 * bare, 0, 1)
    orm = np.stack([np.ones_like(h) * 0.7, rough, bare * 0.4 + rust * 0.1], axis=2)
    return (save_img("bus_wrak", img), save_img("bus_wrak_n", normal_from_height(h, 3.0), True),
            save_img("bus_wrak_orm", orm, True))


def plain_textures(name, rgb, rough, metal, size=256, grain=0.12, seed=60):
    n = fbm(size, 32, seed)
    img = np.array(rgb)[None, None, :] * (1 - grain + 2 * grain * n[..., None])
    h = fbm(size, 8, seed + 1)
    orm = np.stack([np.ones_like(h), np.clip(rough + 0.2 * (n - 0.5), 0, 1), np.ones_like(h) * metal], axis=2)
    return save_img(name, img), save_img(name + "_n", normal_from_height(h, 1.5), True), save_img(name + "_orm", orm, True)


# 5x7-letters voor het lichtbord (oranje leds)
FONT = {
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    " ": ["....."] * 7,
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
}


def bord_texture(text="12  CENTRUM", w=512, h=64):
    """Lichtbord: oranje leds op zwart. Elke led = 4x4 pixels met een donkere rand."""
    img = np.zeros((h, w, 3)) + 0.015
    cols = len(text) * 6
    led = 4
    x0 = (w - cols * led) // 2
    y0 = (h - 7 * led) // 2
    yy, xx = np.mgrid[0:led, 0:led]
    dot = np.exp(-(((xx - 1.5) / 1.4) ** 2 + ((yy - 1.5) / 1.4) ** 2))
    for i, ch in enumerate(text):
        g = FONT.get(ch, FONT[" "])
        for r in range(7):
            for c in range(5):
                px, py = x0 + (i * 6 + c) * led, y0 + r * led
                on = g[r][c] == "#"
                col = np.array([1.0, 0.55, 0.08]) if on else np.array([0.06, 0.035, 0.01])
                img[py:py + led, px:px + led] = np.maximum(img[py:py + led, px:px + led], dot[..., None] * col)
    return save_img("bus_bord", img)


# ============================================================ materialen
def pbr(name, tex=None, color=(1, 1, 1), rough=0.6, metal=0.0, emit=None, strength=0.0, alpha=None, emit_tex=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    L = nt.links
    if tex:
        alb, nor, orm = tex
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = alb
        L.new(t.outputs["Color"], p.inputs["Base Color"])
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = nor
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 1.0
        L.new(tn.outputs["Color"], nm.inputs["Color"])
        L.new(nm.outputs["Normal"], p.inputs["Normal"])
        to = nt.nodes.new("ShaderNodeTexImage")
        to.image = orm
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        L.new(to.outputs["Color"], sep.inputs[0])
        L.new(sep.outputs["Green"], p.inputs["Roughness"])
        L.new(sep.outputs["Blue"], p.inputs["Metallic"])
    else:
        p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
    if emit_tex is not None:
        te = nt.nodes.new("ShaderNodeTexImage")
        te.image = emit_tex
        L.new(te.outputs["Color"], p.inputs["Base Color"])
        L.new(te.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = strength
    elif emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


LAK_T = lak_textures()
RUB_T = rubber_textures()
WRAK_T = wreck_textures()
PLAST_T = plain_textures("bus_plastic", (0.075, 0.075, 0.072), 0.6, 0.0, seed=70)
CHR_T = plain_textures("bus_chroom", (0.62, 0.62, 0.6), 0.3, 1.0, seed=80)
BIN_T = plain_textures("bus_binnen", (0.05, 0.05, 0.048), 0.9, 0.0, seed=90)
VELG_T = plain_textures("bus_velg", (0.46, 0.46, 0.44), 0.42, 1.0, seed=100)
BORD_T = bord_texture()

LAK = pbr("Lak", LAK_T)
RUBBER = pbr("Rubber", RUB_T)
PLASTIC = pbr("Plastic", PLAST_T)
CHROOM = pbr("Chroom", CHR_T)
BINNEN = pbr("Binnen", BIN_T)
VELG = pbr("Velg", VELG_T)
GLAS = pbr("Glas", color=(0.10, 0.15, 0.16), rough=0.05, metal=0.0, alpha=0.42)
LENS_KOP = pbr("LensKoplamp", color=(0.75, 0.78, 0.74), rough=0.08)
LENS_ACHTER = pbr("LensAchter", color=(0.35, 0.03, 0.025), rough=0.1)
LENS_KNIP = pbr("LensKnipper", color=(0.45, 0.22, 0.03), rough=0.1)
LICHT_KOP = pbr("LichtKoplamp", color=(1.0, 0.95, 0.8), emit=(1.0, 0.92, 0.7), strength=6.0)
LICHT_ACHTER = pbr("LichtAchter", color=(1.0, 0.1, 0.05), emit=(1.0, 0.08, 0.03), strength=4.0)
LICHT_KNIP = pbr("LichtKnipper", color=(1.0, 0.6, 0.1), emit=(1.0, 0.55, 0.05), strength=7.0)
LICHT_BORD = pbr("LichtBord", emit_tex=BORD_T, strength=3.0)
LICHT_BINNEN = pbr("LichtBinnen", color=(0.9, 0.95, 1.0), emit=(0.85, 0.92, 1.0), strength=2.5)
WRAK = pbr("Verkoold", WRAK_T)
KENTEKEN = pbr("Kenteken", color=(0.85, 0.72, 0.15), rough=0.5)
MATS = [LAK, RUBBER, PLASTIC, CHROOM, BINNEN, VELG, GLAS, LENS_KOP, LENS_ACHTER, LENS_KNIP, LICHT_KOP, LICHT_ACHTER, LICHT_KNIP,
        LICHT_BORD, LICHT_BINNEN, WRAK, KENTEKEN]
MI = {m.name: i for i, m in enumerate(MATS)}
TEGEL = {"Rubber": 1.0, "Plastic": 0.5, "Chroom": 0.5, "Binnen": 0.6, "Velg": 0.5}


# ============================================================ bouwstenen
class Deel:
    """Eén object: alle delen in één bmesh, per vlak een materiaal. Coördinaten in wereldmaat; pivot wordt bij het maken afgetrokken."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, mat, smooth=True):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = MI[mat.name]
        f.smooth = smooth
        return f

    def quad(self, a, b, c, d, mat, smooth=True):
        return self.face([a, b, c, d], mat, smooth)

    def box(self, c, s, mat, smooth=False):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        v = [(c[0] + p[0], c[1] + p[1], c[2] + p[2]) for p in v]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)):
            self.face([v[i] for i in q], mat, smooth=smooth)

    def side_quad(self, s, x, y0, y1, z0, z1, mat):
        """Plat vlak op een zijkant (s=+1 rechts) op afstand x van het midden, naar buiten gericht."""
        a, b, c, d = (s * x, y0, z0), (s * x, y1, z0), (s * x, y1, z1), (s * x, y0, z1)
        if (y1 < y0) == (s > 0):
            self.quad(a, b, c, d, mat)
        else:
            self.quad(d, c, b, a, mat)

    def front_quad(self, f, y, x0, x1, z0, z1, mat):
        """Plat vlak op de voorkant (f=+1) of achterkant (f=-1), naar buiten gericht."""
        a, b, c, d = (x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)
        if f > 0:
            self.quad(d, c, b, a, mat)
        else:
            self.quad(a, b, c, d, mat)

    def lathe(self, center, profile, segs, mat, flip=False):
        """Draaivlak om de x-as: profile = [(straal, afstand langs de as)]."""
        rings = []
        for r, a in profile:
            ring = []
            for i in range(segs):
                t = i / segs * math.tau
                ring.append(self.bm.verts.new((center[0] + a, center[1] + r * math.sin(t), center[2] + r * math.cos(t))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for i in range(segs):
                j = (i + 1) % segs
                q = [rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]]
                if flip:
                    q = q[::-1]
                try:
                    f = self.bm.faces.new(q)
                    f.material_index = MI[mat.name]
                    f.smooth = True
                except ValueError:
                    pass

    def loft(self, rings, mat, caps=True):
        n = len(rings[0])
        vr = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        for k in range(len(vr) - 1):
            for i in range(n):
                j = (i + 1) % n
                f = self.bm.faces.new([vr[k][i], vr[k + 1][i], vr[k + 1][j], vr[k][j]])
                f.material_index = MI[mat.name]
                f.smooth = True
        if not caps:
            return
        # kap: concentrische ringen naar een middelpunt (vervormbaar voor de deuk, en vlak)
        for ring, rev in ((vr[0], True), (vr[-1], False)):
            cx = sum(v.co.x for v in ring) / n
            cz = sum(v.co.z for v in ring) / n
            yy = ring[0].co.y
            prev = ring
            for s in (0.72, 0.44, 0.18):
                cur = [self.bm.verts.new((cx + (v.co.x - cx) * s, yy, cz + (v.co.z - cz) * s)) for v in ring]
                for i in range(n):
                    j = (i + 1) % n
                    q = [prev[i], prev[j], cur[j], cur[i]]
                    f = self.bm.faces.new(q[::-1] if rev else q)
                    f.material_index = MI[mat.name]
                    f.smooth = False
                prev = cur
            c = self.bm.verts.new((cx, yy, cz))
            for i in range(n):
                j = (i + 1) % n
                q = [prev[i], prev[j], c]
                f = self.bm.faces.new(q[::-1] if rev else q)
                f.material_index = MI[mat.name]
                f.smooth = False

    def finish(self, pivot=(0, 0, 0), sharp=38.0):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=[-pivot[0], -pivot[1], -pivot[2]])
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(sharp):
                e.smooth = False
        for f in bm.faces:
            set_uv(f, self.uv, pivot)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.name, me)
        for m in MATS:
            me.materials.append(m)
        scene.collection.objects.link(ob)
        ob.location = pivot
        return ob


def lak_uv(w, n):
    """UV in de lak-indeling voor een punt w (wereldmaat) op een vlak met normaal n."""
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 0:
        return (0.5 - w.y / L_BUS, min(max(w.z, 0), H - 0.12) / H * 0.5)    # airco-zijkant: crème net onder de dakrand
    if ax == 2:
        if n.z > 0:
            return (0.5 - w.y / L_BUS, 0.52 + (w.x / (2 * W2) + 0.5) * 0.26)
        return (0.5 - w.y / L_BUS, 0.004)
    return (0.5 + w.x / (2 * W2) * 0.96 * (1 if n.y > 0 else -1), 0.80 + min(max(w.z, 0), H - 0.12) / H * 0.2)


def set_uv(f, uvl, pivot):
    n = f.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    mat = MATS[f.material_index]
    for lp in f.loops:
        w = lp.vert.co + Vector(pivot)
        if mat.name in ("Lak", "Verkoold"):
            uv = lak_uv(w, n)
        elif mat.name == "LichtBord":
            uv = ((w.x + 0.92) / 1.84, (w.z - 2.49) / 0.18)
        elif mat.name == "Rubber":
            c = lp.vert.co
            uv = (math.atan2(c.y, c.z) / math.tau * 3, c.x / 0.30 + 0.5)
        else:
            s = TEGEL.get(mat.name, 1.0)
            uv = (w.y / s, w.z / s) if ax == 0 else (w.x / s, w.z / s) if ax == 1 else (w.x / s, w.y / s)
        lp[uvl].uv = uv


def ring_pts(y, hw, zb, zt, rb, rt, k=3, ns=8, nr=6, nb=4):
    """Doorsnede van de bus: afgeronde rechthoek met kleine hoeken onder (rb) en ruime hoeken boven (rt), rechte stukken onderverdeeld."""
    def arc(cx, cz, r, a0, a1):
        return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / k)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / k))) for i in range(k + 1)]

    def line(p0, p1, n):
        return [(p0[0] + (p1[0] - p0[0]) * i / n, p0[1] + (p1[1] - p0[1]) * i / n) for i in range(1, n)]
    br = arc(hw - rb, zb + rb, rb, -90, 0)
    tr = arc(hw - rt, zt - rt, rt, 0, 90)
    tl = arc(-hw + rt, zt - rt, rt, 90, 180)
    bl = arc(-hw + rb, zb + rb, rb, 180, 270)
    pts = br + line(br[-1], tr[0], ns) + tr + line(tr[-1], tl[0], nr) + tl + line(tl[-1], bl[0], ns) + bl + line(bl[-1], br[0], nb)
    return [(px, y, pz) for px, pz in pts]


# stations langs de bus: y, halve breedte, onder, boven, hoek onder, hoek boven
ST = [(L2, 1.200, 0.36, 2.90, 0.10, 0.30), (L2 - 0.05, 1.235, 0.32, 2.99, 0.10, 0.30), (L2 - 0.14, W2, 0.30, H, 0.10, 0.30)]
for i in range(1, 19):
    ST.append((L2 - 0.14 - i * (2 * L2 - 0.28) / 19, W2, 0.30, H, 0.10, 0.30))
ST += [(-L2 + 0.14, W2, 0.30, H, 0.10, 0.30), (-L2 + 0.05, 1.235, 0.32, 2.99, 0.10, 0.30), (-L2, 1.205, 0.36, 2.92, 0.10, 0.30)]
XS = W2           # vlakke zijkant tussen z 0,40 en 2,75
YF, YR = L2, -L2  # voor- en achtervlak

# ---------- Romp: schaal, wielkasten (boolean) en dan de opgelegde details
shell = Deel("Romp")
shell.loft([ring_pts(*s) for s in ST], LAK)
# stootlijst langs de zijkant (onderbroken bij de deuren), onderplaat en bumpers: gesloten blokken, mogen mee door de boolean
for s in (1, -1):
    gaps = [(4.02, 5.08), (-0.18, 1.08)] if s > 0 else []
    segs, y = [], L2 - 0.2
    for g0, g1 in sorted(gaps, reverse=True):
        segs.append((y, g1))
        y = g0
    segs.append((y, -L2 + 0.2))
    for y0, y1 in segs:
        if y0 - y1 > 0.05:
            shell.box((s * (XS + 0.02), (y0 + y1) / 2, 0.60), (0.05, y0 - y1, 0.07), PLASTIC)
    shell.box((s * (XS + 0.005), 0, 0.33), (0.03, 2 * L2 - 0.4, 0.08), PLASTIC)      # dorpel
shell.box((0, YF + 0.06, 0.48), (2.36, 0.16, 0.28), PLASTIC)                          # voorbumper
shell.box((0, YR - 0.06, 0.48), (2.36, 0.16, 0.28), PLASTIC)                          # achterbumper
shell.box((0, 0, 0.27), (2.2, 2 * L2 - 0.5, 0.06), PLASTIC)                          # onderplaat
romp = shell.finish()
KASTEN = [(s, WYV, 0.58, 1.00) for s in (1, -1)] + [(s, WYA, 0.58, 0.60) for s in (1, -1)]   # (zijde, y, straal, binnenkant x)
bpy.context.view_layer.objects.active = romp
for s, y, r, inner in KASTEN:
    depth = 2 * (XS + 0.3 - inner)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=28, radius1=r, radius2=r, depth=depth,
                          matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("snijder")
    bm.to_mesh(me)
    bm.free()
    cut = bpy.data.objects.new("snijder", me)
    scene.collection.objects.link(cut)
    cut.location = (s * (inner + depth / 2), y, WR)
    mod = romp.modifiers.new("gat", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cut
    mod.solver = "EXACT"
    mod.use_self = True          # stootlijsten en dorpels overlappen de schaal
    mod.use_self = True          # stootlijsten en dorpels overlappen de schaal
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cut)
# binnenkant van de wielkasten donker
bm = bmesh.new()
bm.from_mesh(romp.data)
uvl = bm.loops.layers.uv["UVMap"]
for f in bm.faces:
    c = f.calc_center_median()
    for s, y, r, inner in KASTEN:
        d = math.hypot(c.y - y, c.z - WR)
        if d < r + 0.03 and abs(c.x) < XS - 0.004 and c.x * s > 0:
            f.material_index = MI["Binnen"]
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.y / 0.6, lp.vert.co.z / 0.6)
bm.to_mesh(romp.data)
bm.free()

# ---------- opgelegde details (open vlakken): ramen-binnenkant, deurnissen, lampen, roosters, spiegels
det = Deel("RompDetail")
OFF_IN = 0.004       # donkere binnenkant net boven de lak
RAAM = (1.30, 2.64)  # onder- en bovenkant van de zijruiten


def panes(y0, y1, n, gap=0.08):
    w = (y0 - y1 - gap * (n - 1)) / n
    return [(y0 - i * (w + gap), y0 - i * (w + gap) - w) for i in range(n)]


PANES = {1: panes(3.86, 1.16, 2) + panes(-0.26, -4.86, 4),
         -1: [(5.06, 4.10)] + panes(4.02, -4.86, 7)}
for s, lst in PANES.items():
    for y0, y1 in lst:
        det.side_quad(s, XS + OFF_IN, y0, y1, RAAM[0], RAAM[1], BINNEN)
DOORS_Y = {"V": (5.06, 4.04), "M": (1.07, -0.17)}
for y0, y1 in DOORS_Y.values():
    det.side_quad(1, XS + OFF_IN, y0, y1, 0.34, 2.74, BINNEN)              # deurnis
    det.box((XS - 0.12, (y0 + y1) / 2, 0.40), (0.26, y0 - y1 - 0.02, 0.05), PLASTIC)   # instaptree
# voorruit en achterruit: donkere binnenkant, bestemmingsbord-kast
det.front_quad(1, YF + OFF_IN, -1.10, 1.10, 1.12, 2.74, BINNEN)
det.front_quad(-1, YR - OFF_IN, -0.95, 0.95, 1.86, 2.70, BINNEN)
# koplampen, knipperlichten, achterlichten (lenzen; de verlichte delen zijn aparte knopen)
for s in (1, -1):
    det.box((s * 0.86, YF + 0.03, 0.80), (0.42, 0.05, 0.17), PLASTIC)
    det.box((s * 0.80, YF + 0.05, 0.80), (0.24, 0.04, 0.12), LENS_KOP)
    det.box((s * 1.00, YF + 0.05, 0.80), (0.10, 0.04, 0.12), LENS_KOP)
    det.box((s * 1.11, YF + 0.04, 0.80), (0.07, 0.04, 0.13), LENS_KNIP)
    det.box((s * 1.10, YR - 0.03, 1.10), (0.16, 0.05, 0.92), PLASTIC)
    det.box((s * 1.10, YR - 0.05, 1.28), (0.12, 0.04, 0.42), LENS_ACHTER)
    det.box((s * 1.10, YR - 0.05, 0.86), (0.12, 0.04, 0.22), LENS_KNIP)
    det.box((s * (XS + 0.01), 4.70 if s < 0 else 3.95, 0.92), (0.03, 0.12, 0.06), LENS_KNIP)   # knipperlicht opzij
    # spiegels aan 'konijnenoren'
    det.box((s * 1.24, YF - 0.12, 2.58), (0.05, 0.05, 0.08), PLASTIC)
    arm = [Vector((s * 1.24, YF - 0.12, 2.6)), Vector((s * 1.40, YF + 0.30, 2.42))]
    mid = (arm[0] + arm[1]) / 2
    dvec = arm[1] - arm[0]
    det.box(tuple(mid), (abs(dvec.x) + 0.03, abs(dvec.y) + 0.03, 0.03), PLASTIC)
    det.box((s * 1.40, YF + 0.30, 2.12), (0.14, 0.08, 0.50), PLASTIC)
    det.box((s * 1.40, YF + 0.255, 2.12), (0.11, 0.012, 0.44), CHROOM)
# grille, kenteken, embleem
det.box((0, YF + 0.02, 0.98), (0.9, 0.04, 0.12), PLASTIC)
for i in range(4):
    det.box((0, YF + 0.045, 0.93 + i * 0.03), (0.86, 0.012, 0.012), CHROOM)
det.box((0, YF + 0.15, 0.46), (0.52, 0.02, 0.11), KENTEKEN)
det.box((0, YR - 0.15, 0.46), (0.52, 0.02, 0.11), KENTEKEN)
# motorruimte achter het luik: donkere nis met motorblok, riem en luchtfilter
det.front_quad(-1, YR - OFF_IN, -0.84, 0.84, 0.48, 1.44, BINNEN)
det.box((0.0, YR + 0.002, 0.88), (1.1, 0.012, 0.5), PLASTIC)
det.box((-0.45, YR - 0.002, 1.18), (0.32, 0.012, 0.26), CHROOM)
det.box((0.42, YR - 0.002, 0.70), (0.2, 0.012, 0.2), CHROOM)
# motorrooster opzij (achterin links en rechts) en tankklep links
for s in (1, -1):
    for i in range(7):
        det.box((s * (XS + 0.012), -4.0 - i * 0.12, 0.98), (0.02, 0.07, 0.36), PLASTIC)
det.box((-(XS + 0.006), -1.4, 0.95), (0.012, 0.30, 0.22), LAK)
# uitlaat (rechthoekige pijp onder de achterbumper links)
det.box((-0.80, YR + 0.05, 0.30), (0.12, 0.22, 0.09), CHROOM)
# dakrand: regengoot langs beide zijden
for s in (1, -1):
    det.box((s * (W2 - 0.06), 0, H - 0.03), (0.035, 2 * L2 - 0.5, 0.035), PLASTIC)
detail = det.finish()
bpy.ops.object.select_all(action="DESELECT")
detail.select_set(True)
romp.select_set(True)
bpy.context.view_layer.objects.active = romp
bpy.ops.object.join()
romp = bpy.context.view_layer.objects.active
romp.name = "Romp"
romp.data.name = "Romp"


# ---------- shape key Deuk: aanrijding voor, dak ingedeukt, flanken, achterhoek
DEUKEN = (
    (0.65, L2, 1.4, 1.1, 0.42),          # voorhoek rechts ingedrukt
    (0.0, 1.6, H, 1.6, 0.42),             # dak vooraan
    (0.2, -2.2, H, 1.9, 0.55),            # dak achteraan zakt in
    (-W2, 0.8, 1.0, 1.2, 0.34),           # linker flank
    (W2, -2.9, 0.9, 1.0, 0.30),           # rechter flank achter
    (-0.8, -L2, 1.2, 1.0, 0.36),          # achterhoek links
    (W2, 2.5, 2.4, 0.9, 0.22),            # rechter dakrand
)


def deuk_kaart(co, nrm):
    d = 0.0
    for (cx, cy, cz, r, diep) in DEUKEN:
        dist = math.sqrt((co.x - cx) ** 2 + (co.y - cy) ** 2 + (co.z - cz) ** 2)
        if dist < r:
            f = (0.5 + 0.5 * math.cos(math.pi * dist / r)) ** 1.2
            k = 0.65 + 0.35 * math.sin(co.x * 13.0 + co.y * 9.0) * math.sin(co.z * 11.0 + co.x * 7.0)
            d += diep * f * k
    return -nrm * d


romp.shape_key_add(name="Basis")
sk = romp.shape_key_add(name="Deuk")
me = romp.data
vn = {}
for lp in me.loops:
    vn[lp.vertex_index] = lp.normal if hasattr(lp, "normal") else me.vertices[lp.vertex_index].normal
for v in me.vertices:
    sk.data[v.index].co = v.co + deuk_kaart(v.co, vn.get(v.index, v.normal))
sk.value = 0.0


# ---------- Ruiten
def glas_zijde(name, s):
    g = Deel(name)
    for y0, y1 in PANES[s]:
        g.side_quad(s, XS + 0.014, y0 - 0.01, y1 + 0.01, RAAM[0] + 0.01, RAAM[1] - 0.01, GLAS)
    return g.finish()


ruit_r = glas_zijde("RuitenR", 1)
ruit_l = glas_zijde("RuitenL", -1)
vr = Deel("Voorruit")
vr.front_quad(1, YF + 0.014, -1.09, 1.09, 1.13, 2.73, GLAS)
voorruit = vr.finish()
ar = Deel("Achterruit")
ar.front_quad(-1, YR - 0.014, -0.94, 0.94, 1.87, 2.69, GLAS)
achterruit = ar.finish()


# ---------- Deuren: twee bladen per deur, scharnier aan de buitenrand, zwaaien naar buiten
def deurblad(naam, y_hinge, y_free):
    d = Deel(naam)
    xo, xi = XS + 0.03, XS + 0.008
    lo, hi = min(y_hinge, y_free), max(y_hinge, y_free)
    fw = 0.05
    # buitenkant: onderpaneel, kader rond het glas
    d.side_quad(1, xo, hi, lo, 0.36, 1.02, LAK)
    d.side_quad(1, xo, hi, lo, 2.64, 2.73, LAK)
    d.side_quad(1, xo, hi, hi - fw, 1.02, 2.64, LAK)
    d.side_quad(1, xo, lo + fw, lo, 1.02, 2.64, LAK)
    d.side_quad(1, xo - 0.006, hi - fw, lo + fw, 1.02, 2.64, GLAS)
    # binnenkant en randen
    d.side_quad(-1, -xi, hi, lo, 0.36, 2.73, BINNEN)      # naar binnen gericht (x negatief vanuit de deur gezien)
    for z in (0.36, 2.73):
        a, b = (xi, hi, z), (xo, hi, z)
        c, e = (xo, lo, z), (xi, lo, z)
        d.quad(a, b, c, e, PLASTIC) if z > 1 else d.quad(e, c, b, a, PLASTIC)
    for y in (hi, lo):
        d.quad((xi, y, 0.36), (xo, y, 0.36), (xo, y, 2.73), (xi, y, 2.73), PLASTIC)
    # rubberen sluitrand aan de vrije kant, greep binnen
    d.box((xo + 0.008, y_free + (0.012 if y_free < y_hinge else -0.012), 1.55), (0.02, 0.025, 2.3), PLASTIC)
    d.box((xi - 0.03, (lo + hi) / 2, 1.6), (0.025, 0.02, 0.6), CHROOM)
    return d.finish(pivot=(XS + 0.03, y_hinge, 0.0))


DEUREN = {}
for key, (y0, y1) in DOORS_Y.items():
    mid = (y0 + y1) / 2
    DEUREN["Deur%sA" % key] = (deurblad("Deur%sA" % key, y0, mid), 1)     # scharnier voor, zwaait met de klok mee
    DEUREN["Deur%sB" % key] = (deurblad("Deur%sB" % key, y1, mid), -1)


# ---------- Motorluik (achter, scharnier boven)
ml = Deel("Motorluik")
yo, yi = YR - 0.04, YR - 0.012
ml.front_quad(-1, yo, -0.86, 0.86, 0.46, 1.46, LAK)
ml.front_quad(1, yi, -0.86, 0.86, 0.46, 1.46, BINNEN)
ml.quad((-0.86, yi, 0.46), (0.86, yi, 0.46), (0.86, yo, 0.46), (-0.86, yo, 0.46), PLASTIC)
ml.quad((-0.86, yo, 1.46), (0.86, yo, 1.46), (0.86, yi, 1.46), (-0.86, yi, 1.46), PLASTIC)
ml.quad((0.86, yi, 0.46), (0.86, yi, 1.46), (0.86, yo, 1.46), (0.86, yo, 0.46), PLASTIC)
ml.quad((-0.86, yo, 0.46), (-0.86, yo, 1.46), (-0.86, yi, 1.46), (-0.86, yi, 0.46), PLASTIC)
for i in range(8):                                                     # roosterlamellen
    ml.box((0, yo - 0.012, 0.62 + i * 0.075), (1.3, 0.022, 0.03), PLASTIC)
ml.box((0, yo - 0.02, 1.38), (0.2, 0.025, 0.04), CHROOM)              # greep
motorluik = ml.finish(pivot=(0, yo, 1.46))


# ---------- Dak: airco-unit en twee dakluiken
ac = Deel("Airco")
ac.box((0, 1.0, H + 0.13), (1.70, 2.6, 0.26), LAK, smooth=False)
ac.box((0, 1.0, H + 0.265), (1.5, 2.3, 0.012), PLASTIC)
for i in range(2):
    ac.box((0, 0.35 + i * 1.3, H + 0.275), (0.62, 0.62, 0.012), CHROOM)  # ventilatorrooster
    for j in range(5):
        ac.box((0, 0.35 + i * 1.3 - 0.24 + j * 0.12, H + 0.285), (0.58, 0.02, 0.01), PLASTIC)
airco = ac.finish(pivot=(0, 1.0, H))
LUIKEN = {}
for naam, y in (("DakluikV", 3.6), ("DakluikA", -2.0)):
    dl = Deel(naam)
    dl.box((0, y, H + 0.04), (0.82, 0.82, 0.07), PLASTIC)
    dl.box((0, y, H + 0.08), (0.70, 0.70, 0.015), GLAS)
    LUIKEN[naam] = dl.finish(pivot=(0, y, H))


# ---------- Ruitenwissers (draaien in het vlak van de voorruit)
def wisser(naam, lengte):
    d = Deel(naam)
    d.box((lengte / 2, 0, 0.015), (lengte, 0.02, 0.014), PLASTIC)
    d.box((lengte * 0.55, 0, 0.03), (lengte * 0.8, 0.016, 0.014), PLASTIC)
    d.box((0.0, 0, 0.02), (0.05, 0.05, 0.04), CHROOM)
    return d


# lokale assen: x = langs het glas (naar links), y = omhoog langs het glas, z = ruitnormaal (naar voren)
ws_basis = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
wissers = []
for naam, x0 in (("WisserL", 0.04), ("WisserR", 1.04)):
    w = wisser(naam, 0.95).finish()
    w.rotation_mode = "QUATERNION"
    w.location = Vector((x0, YF + 0.03, 1.18))
    q0 = ws_basis.to_quaternion()
    w.rotation_quaternion = q0
    wissers.append((w, q0))


# ---------- Wielen (voor enkel, achter dubbel lucht)
def wiel(naam, s, y, dual):
    d = Deel(naam)
    c = (s * WX, y, WR)
    prof = [(0.30, 0.13), (0.38, 0.145), (0.46, 0.145), (0.495, 0.12), (0.50, 0.07), (0.50, -0.07), (0.495, -0.12), (0.46, -0.145),
            (0.38, -0.145), (0.30, -0.13)]
    offs = [0.0, -0.31] if dual else [0.0]
    for o in offs:
        cc = (c[0] + s * o, c[1], c[2])
        d.lathe(cc, [(r, s * a) for r, a in prof], 30, RUBBER, flip=(s < 0))
    vprof = [(0.30, 0.13 * s), (0.30, 0.10 * s), (0.27, 0.11 * s), (0.17, 0.09 * s), (0.10, 0.12 * s), (0.0, 0.12 * s)]
    if dual:
        vprof = [(0.30, 0.13 * s), (0.30, 0.10 * s), (0.27, 0.04 * s), (0.17, 0.02 * s), (0.10, 0.06 * s), (0.0, 0.06 * s)]
    d.lathe(c, vprof, 24, VELG, flip=(s < 0))
    for i in range(10):                                   # wielmoeren
        t = i / 10 * math.tau
        p = Vector((0, math.sin(t), math.cos(t))) * 0.135
        d.box((c[0] + s * (0.10 if not dual else 0.04), c[1] + p.y, c[2] + p.z), (0.03, 0.035, 0.035), CHROOM)
    for i in range(8):                                    # gaten in de velg (donker)
        t = (i + 0.5) / 8 * math.tau
        p = Vector((0, math.sin(t), math.cos(t))) * 0.225
        d.box((c[0] + s * (0.106 if not dual else 0.03), c[1] + p.y, c[2] + p.z), (0.012, 0.07, 0.07), BINNEN)
    d.lathe(c, [(0.06, 0.12 * s if not dual else 0.06 * s), (0.07, 0.14 * s if not dual else 0.08 * s), (0.02, 0.15 * s if not dual else 0.09 * s)], 10, CHROOM, flip=(s < 0))
    return d.finish(pivot=(s * WX, y, WR))


WIELEN = {"Wiel_RV": wiel("Wiel_RV", 1, WYV, False), "Wiel_LV": wiel("Wiel_LV", -1, WYV, False),
          "Wiel_RA": wiel("Wiel_RA", 1, WYA, True), "Wiel_LA": wiel("Wiel_LA", -1, WYA, True)}

# ---------- Verlichte delen (rustpositie: schaal ~0, aan = schaal 1)
LICHTEN = {}


def lens_obj(naam, mat, c, size, quad=None):
    d = Deel(naam)
    if quad:
        quad(d)
    else:
        d.box(c, size, mat)
    ob = d.finish(pivot=c)
    ob.scale = (0.001, 0.001, 0.001)
    return ob


for s, t in ((1, "R"), (-1, "L")):
    LICHTEN["LichtKop" + t] = lens_obj("LichtKop" + t, LICHT_KOP, (s * 0.86, YF + 0.075, 0.80), (0.38, 0.02, 0.12))
    LICHTEN["LichtAchter" + t] = lens_obj("LichtAchter" + t, LICHT_ACHTER, (s * 1.10, YR - 0.075, 1.28), (0.11, 0.02, 0.40))
    LICHTEN["LichtKnipV" + t] = lens_obj("LichtKnipV" + t, LICHT_KNIP, (s * 1.11, YF + 0.065, 0.80), (0.06, 0.02, 0.12))
    LICHTEN["LichtKnipA" + t] = lens_obj("LichtKnipA" + t, LICHT_KNIP, (s * 1.10, YR - 0.075, 0.86), (0.11, 0.02, 0.20))
    LICHTEN["LichtKnipZ" + t] = lens_obj("LichtKnipZ" + t, LICHT_KNIP, (s * (XS + 0.03), 4.70 if s < 0 else 3.95, 0.92), (0.02, 0.11, 0.05))
    LICHTEN["LichtBinnen" + t] = lens_obj("LichtBinnen" + t, LICHT_BINNEN, (s * (XS + 0.008), -0.5, 2.58), None,
                                          quad=lambda d, s=s: [d.side_quad(s, XS + 0.008, y0, y1, 2.55, 2.61, LICHT_BINNEN) for y0, y1 in PANES[s]])
LICHTEN["LichtBord"] = lens_obj("LichtBord", LICHT_BORD, (0, YF + 0.008, 2.58), None,
                                quad=lambda d: d.front_quad(1, YF + 0.008, -0.92, 0.92, 2.49, 2.67, LICHT_BORD))

# ---------- Referentie voor het wrakmateriaal (verborgen, 1 vlak)
wd = Deel("WrakRef")
wd.quad((-0.02, 0, -0.5), (0.02, 0, -0.5), (0.02, 0, -0.46), (-0.02, 0, -0.46), WRAK)
wrakref = wd.finish(pivot=(0, 0, -0.5))
wrakref.scale = (0.001, 0.001, 0.001)

# ---------- Hiërarchie
root = bpy.data.objects.new("Bus", None)
scene.collection.objects.link(root)
carr = bpy.data.objects.new("Carrosserie", None)
scene.collection.objects.link(carr)
carr.parent = root
body = [romp, voorruit, achterruit, ruit_l, ruit_r, motorluik, airco, wrakref] + list(LUIKEN.values()) + [d[0] for d in DEUREN.values()] \
    + [w[0] for w in wissers] + list(LICHTEN.values())
for ob in body:
    ob.parent = carr
    ob.matrix_parent_inverse = Matrix.Identity(4)
for ob in WIELEN.values():
    ob.parent = root
    ob.matrix_parent_inverse = Matrix.Identity(4)
alle = body + list(WIELEN.values())

# ============================================================ animaties (NLA-stroken, echte transform-tracks)
bpy.context.view_layer.update()


def zet_actie(obj, clip, frames, vals, quat=False, smooth=False):
    act = bpy.data.actions.new("%s_%s" % (clip, obj.name))
    obj.animation_data_create()
    obj.animation_data.action = act
    for f, (loc, rot, sc) in zip(frames, vals):
        obj.location = loc
        if quat:
            obj.rotation_mode = "QUATERNION"
            obj.rotation_quaternion = rot
        else:
            obj.rotation_mode = "XYZ"
            obj.rotation_euler = rot
        obj.scale = sc
        obj.keyframe_insert("location", frame=f)
        obj.keyframe_insert("rotation_quaternion" if quat else "rotation_euler", frame=f)
        obj.keyframe_insert("scale", frame=f)
    tr = obj.animation_data.nla_tracks.new()
    tr.name = clip
    tr.strips.new(clip, 0, act)
    obj.animation_data.action = None


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def rust(obj):
    return tuple(obj.location), tuple(obj.rotation_euler), tuple(obj.scale)


N = 36
frames = list(range(N + 1))
# Voordeur / middendeur: twee bladen zwaaien 88 graden naar buiten, middendeur iets later
for clip, keys, delay in (("VoordeurOpen", ("DeurVA", "DeurVB"), 0), ("MiddendeurOpen", ("DeurMA", "DeurMB"), 4)):
    for k in keys:
        ob, sgn = DEUREN[k]
        r0 = rust(ob)
        vals = []
        for f in frames:
            t = ease((f - delay) / 22.0)
            over = 1.0 + 0.03 * math.sin(min(max((f - delay - 22) / 6.0, 0), 1) * math.pi)
            vals.append((r0[0], (0, 0, sgn * math.radians(88) * t * over), r0[2]))
        zet_actie(ob, clip, frames, vals)
# Motorluik: klapt 70 graden omhoog
mr = rust(motorluik)
zet_actie(motorluik, "MotorluikOpen", frames, [(mr[0], (-math.radians(70) * ease(f / 26.0), 0, 0), mr[2]) for f in frames])
# Knielen: de carrosserie zakt 6 cm en helt 2,5 graden naar de deurkant (rechts)
cr = rust(carr)
zet_actie(carr, "Knielen", frames, [((0, 0, -0.06 * ease(f / 30.0)), (0, math.radians(2.5) * ease(f / 30.0), 0), (1, 1, 1)) for f in frames])
# LichtenAan: koplampen, achterlichten (rem uit = gedimd in het spel), lichtbord en binnenverlichting gaan aan
NL = 12
fl = list(range(NL + 1))
for naam, ob in LICHTEN.items():
    if naam.startswith(("LichtKop", "LichtBord", "LichtBinnen")):
        r0 = rust(ob)
        delay = 0 if naam.startswith("LichtKop") else (4 if naam == "LichtBord" else 7)
        vals = []
        for f in fl:
            on = f >= delay + 1
            # tl-buizen flikkeren even voor ze aangaan
            if naam.startswith("LichtBinnen") and delay <= f < delay + 4:
                on = (f - delay) % 2 == 1
            vals.append((r0[0], r0[1], (1, 1, 1) if on else (0.001, 0.001, 0.001)))
        zet_actie(ob, "LichtenAan", fl, vals)
# Ruitenwissers (lus 1,33 s)
NW = 40
fw = list(range(NW + 1))
for w, q0 in wissers:
    vals = []
    for f in fw:
        a = math.radians(84) * (0.5 - 0.5 * math.cos(f / NW * math.tau))
        vals.append((tuple(w.location), q0 @ Quaternion(Vector((0, 0, 1)), a), tuple(w.scale)))
    zet_actie(w, "Ruitenwissers-loop", fw, vals, quat=True)
# Knipperen links (lus 1,0 s) en Alarm (alle knipperlichten plus koplampen); beide beginnen "uit", zodat de rustpose in de glb uit is
NK = 30
fk = list(range(NK + 1))
AAN, UIT = (1, 1, 1), (0.001, 0.001, 0.001)
for naam, ob in LICHTEN.items():
    r0 = rust(ob)
    if "Knip" in naam:
        zet_actie(ob, "Knipperen-loop", fk, [(r0[0], r0[1], AAN if (f % NK) >= NK / 2 and naam.endswith("L") else UIT) for f in fk])
        zet_actie(ob, "Alarm-loop", fk, [(r0[0], r0[1], AAN if (f % NK) >= NK / 2 else UIT) for f in fk])
    elif naam.startswith(("LichtKop", "LichtAchter")):
        zet_actie(ob, "Alarm-loop", fk, [(r0[0], r0[1], AAN if (f % NK) >= NK / 2 else UIT) for f in fk])
for ob in alle + [carr]:
    if ob.animation_data:
        ob.animation_data.action = None
scene.frame_start, scene.frame_end = 0, N
scene.frame_set(0)

# ============================================================ export
bpy.ops.object.select_all(action="DESELECT")
for ob in alle + [root, carr]:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "bus.glb"), export_format="GLB", export_apply=False, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False, export_morph=True, export_morph_normal=False, export_image_format="JPEG",
                          export_jpeg_quality=88, export_lights=False, export_cameras=False)
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "bus.blend"))
tris, tot = {}, 0
for ob in alle:
    ob.data.calc_loop_triangles()
    tris[ob.name] = len(ob.data.loop_triangles)
    tot += tris[ob.name]
print("TRIS", tris, "TOTAAL", tot, "MATERIALEN", len(MATS))

# ============================================================ studiorenders (Cycles CPU)
if RENDER:
    scene.render.engine = "CYCLES"
    scene.cycles.samples = int(os.environ.get("SAMPLES", 48))
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.40, 0.45, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)
    gr = bpy.data.objects.new("grond", bpy.data.meshes.new("grond"))
    bmg = bmesh.new()
    bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=40)
    bmg.to_mesh(gr.data)
    scene.collection.objects.link(gr)
    gr.data.materials.append(pbr("grondmat", color=(0.18, 0.2, 0.12), rough=1.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    def foto(naam, pos, target, lens=40):
        cam.data.lens = lens
        cam.location = pos
        cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, naam)
        bpy.ops.render.render(write_still=True)

    foto("bus_schuin.png", (9.5, 11.5, 4.6), (0, 0.5, 1.3))
    if not os.environ.get("ONE"):
        foto("bus_boven.png", (0, -15, 24), (0, 0, 1.0), 32)        # ongeveer de gamecamera (58 graden)
        foto("bus_achter.png", (-8.5, -11.0, 3.8), (0, -1, 1.2))
        scene.frame_set(30)                                         # nla: deuren, luik open, knielen, lichten
        foto("bus_open.png", (9.0, 6.5, 3.2), (0, 0.5, 1.3))
