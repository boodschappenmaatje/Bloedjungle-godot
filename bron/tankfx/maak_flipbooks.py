"""Tankschot-flipbooks voor Bloedjungle, procedureel (numpy + Pillow), geen Blender nodig.
Gebruik:  python maak_flipbooks.py <uitmap> [px_per_beeld]
Schrijft vier 4x4-vellen (RGBA, 16 beelden):
  tankfx_mond.png    mondingsvuur van bovenaf, kanon wijst omhoog in het beeld: vuurtong + twee zijtongen (mondingsrem). Voor blend_add.
  tankfx_rook.png    rookwolk van bovenaf, donker en dan lichter, drijft naar voren. Voor blend_mix.
  tankfx_stof.png    stofwaaier van bovenaf, bruin, breed. Voor blend_mix.
  tankfx_aarde.png   aardfontein van opzij (inslag): vuur onderin, bruine rook en stof omhoog. Voor blend_mix.
Het vuur en de rook zijn gedraaide, vervormde fBm-ruis (domain warping) met een tijdsverloop; seed is vast, dus herhaalbaar.
(De Mantaflow-versie, bron/tankfx/maak_tankfx.py, rendert in headless Blender 5.2 geen volume; die staat er voor een Blender met venster.)"""
import sys, os
import numpy as np
from PIL import Image

OUT = sys.argv[1]
PX = int(sys.argv[2]) if len(sys.argv) > 2 else 256
os.makedirs(OUT, exist_ok=True)
N = PX
rng = np.random.default_rng(1944)


def fbm_tile(size, beta=2.3):
    """Periodieke wolkenruis via een 1/f^beta-spectrum (geen naden bij herhalen)."""
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx ** 2 + fy ** 2)
    k[0, 0] = 1.0
    spec = (rng.standard_normal((size, size)) + 1j * rng.standard_normal((size, size))) / k ** (beta / 1.0)
    spec[0, 0] = 0
    t = np.real(np.fft.ifft2(spec)).astype(np.float32)
    lo, hi = np.percentile(t, 1), np.percentile(t, 99)
    return np.clip((t - lo) / (hi - lo), 0, 1)


BIG = 1024
NOISE_A = fbm_tile(BIG, 2.2)
NOISE_B = fbm_tile(BIG, 2.6)


def sample(tex, u, v):
    """Bilinaire opzoeking met herhaling; u en v in beeldpunten van BIG."""
    u = np.mod(u, BIG); v = np.mod(v, BIG)
    x0 = np.floor(u).astype(int); y0 = np.floor(v).astype(int)
    fx = u - x0; fy = v - y0
    x1 = (x0 + 1) % BIG; y1 = (y0 + 1) % BIG
    return (tex[y0, x0] * (1 - fx) * (1 - fy) + tex[y0, x1] * fx * (1 - fy) +
            tex[y1, x0] * (1 - fx) * fy + tex[y1, x1] * fx * fy)


yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
X = (xx / (N - 1)) * 2 - 1          # -1 links .. 1 rechts
Y = 1 - (yy / (N - 1)) * 2          # 1 boven .. -1 onder


def turb(cx, cy, scale, t, drift=(0.0, 0.0), warp=0.35, ofs=0.0):
    """Ruis met domain warping; t is het tijdsverloop, drift de verschuiving per tijdseenheid (in ruimte-eenheden)."""
    u = (cx - drift[0] * t) * scale * BIG * 0.25 + ofs * 311
    v = (cy - drift[1] * t) * scale * BIG * 0.25 + ofs * 173
    wx = sample(NOISE_B, u + 97, v + 41) - 0.5
    wy = sample(NOISE_B, u + 211, v + 133) - 0.5
    return sample(NOISE_A, u + wx * warp * BIG * 0.25, v + wy * warp * BIG * 0.25)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def ramp(v, stops):
    """stops: [(pos, (r,g,b)), ...] oplopend; v in 0..1 -> kleur (N,N,3)."""
    out = np.zeros(v.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(v, [s[0] for s in stops], [s[1][c] for s in stops])
    return out


FIRE = [(0.0, (0.05, 0.0, 0.0)), (0.25, (0.55, 0.08, 0.0)), (0.5, (1.0, 0.38, 0.04)), (0.75, (1.0, 0.75, 0.25)), (1.0, (1.0, 1.0, 0.9))]


def shade(n, strength=0.55):
    """Nep-licht voor rook: lichter waar de ruis naar linksboven stijgt (zon schuin van linksboven)."""
    gy, gx = np.gradient(n)
    return np.clip(0.62 + (-gx - gy) * strength * 18.0, 0.25, 1.25)


def frame_mond(i, u):
    # u: 0..1 over 16 beelden. Het schot duurt kort: vuur is vroeg groot en dooft snel.
    grow = np.sqrt(u) if u < 0.5 else np.sqrt(0.5) + (u - 0.5) * 0.4
    L = 0.25 + 1.35 * grow                      # lengte van de vuurtong (van de loop af)
    life = (1 - sstep(0.15, 1.0, u)) ** 1.3
    fy = Y + 0.88                               # 0 bij de loopmond (onderkant van het vel)
    # hoofdtong: smal bij de mond, breder eromheen, scherp aan het eind
    w = 0.10 + 0.20 * np.clip(fy / max(L, 0.1), 0, 1) ** 0.7
    tong = np.exp(-(X / w) ** 2) * sstep(-0.02, 0.05, fy) * (1 - sstep(L * 0.55, L, fy))
    # zijtongen van de mondingsrem: twee kegels naar links/rechts en een beetje naar voren
    side = np.zeros_like(X)
    for s in (-1, 1):
        sx = (X * s - 0.04)
        sl = 0.15 + 0.55 * grow
        wy = 0.06 + 0.06 * np.clip(sx / max(sl, 0.1), 0, 1)
        side += np.exp(-((fy - 0.10 - sx * 0.35) / wy) ** 2) * sstep(0.0, 0.06, sx) * (1 - sstep(sl * 0.4, sl, sx))
    # bolletje bij de mond (de flits zelf)
    flash = np.exp(-((X / 0.20) ** 2 + ((fy - 0.05) / 0.16) ** 2)) * (1 - sstep(0.0, 0.5, u))
    n = turb(X, Y, 1.3, u, drift=(0, 2.2), warp=0.55, ofs=i * 0.17)
    env = np.clip(tong + side * 0.9, 0, 1.4)
    v = (env * 1.25 - (1 - n) * 0.75) * life
    v = np.clip(v * 1.6 + flash * 1.1 * life, 0, 1)
    rgb = ramp(v, FIRE) * sstep(0.04, 0.3, v)[..., None]
    a = sstep(0.05, 0.4, v)
    return rgb, a


def frame_rook(i, u):
    cy = -0.55 + 1.05 * np.sqrt(u)               # drijft naar voren (omhoog in het beeld)
    r = 0.22 + 0.58 * np.sqrt(u)
    n = turb(X, Y, 1.5, u, drift=(0.05, 0.6), warp=0.5, ofs=i * 0.07 + 3)
    d = np.sqrt((X / (r * 1.1)) ** 2 + ((Y - cy) / r) ** 2) + (0.5 - n) * 0.75
    env = 1 - sstep(0.3, 1.0, d)
    dens = sstep(0.02, 0.55, env * (0.4 + 0.9 * n) - 0.05)
    life = (1 - sstep(0.55, 1.0, u)) * (0.55 + 0.45 * sstep(0.0, 0.12, u))
    a = dens * life * 0.92
    base = (0.30 + 0.28 * sstep(0.0, 0.7, u))        # eerst donker kruitzwart, daarna grijsbruin
    col = np.stack([base * 1.04, base * 0.98, base * 0.9], -1) * shade(n)[..., None]
    return col, a


def frame_stof(i, u):
    r = 0.15 + 0.85 * np.sqrt(u)
    fy = Y + 0.85
    ang = np.arctan2(np.abs(X), np.maximum(fy, 0.001))      # 0 recht vooruit, 90 graden opzij
    rad = np.sqrt(X ** 2 + fy ** 2)
    fan = (1 - sstep(1.05, 1.5, ang)) * (1 - sstep(r * 0.55, r, rad))
    n = turb(X, Y, 1.7, u, drift=(0, 0.4), warp=0.6, ofs=i * 0.11 + 7)
    dens = sstep(0.02, 0.5, fan * (0.4 + 0.9 * n) - 0.12 + (n - 0.5) * 0.3)
    life = (1 - sstep(0.4, 1.0, u)) * sstep(0.0, 0.08, u)
    a = dens * life * 0.8
    col = np.stack([0.52, 0.42, 0.29], -1) * np.ones_like(X)[..., None] * shade(n, 0.4)[..., None]
    return col, a


def frame_aarde(i, u):
    h = 0.18 + 1.55 * np.sqrt(u)                       # hoogte van de fontein
    fy = Y + 1.0                                       # 0 aan de grond
    t = np.clip(fy / max(h, 0.1), 0, 1.2)
    w = (0.12 + 0.55 * t ** 0.6) * (0.5 + 0.7 * np.sqrt(u))   # smal onderin, breder bovenin (paddenstoel)
    env = np.exp(-(X / np.maximum(w, 0.05)) ** 2) * sstep(-0.02, 0.05, fy) * (1 - sstep(0.75, 1.1, t))
    n = turb(X, Y, 1.4, u, drift=(0, 1.8), warp=0.5, ofs=i * 0.13 + 11)
    dens = sstep(0.02, 0.5, env * (0.5 + 0.9 * n) - 0.2 + (n - 0.5) * 0.35)
    life = (1 - sstep(0.5, 1.0, u)) * sstep(0.0, 0.05, u)
    a = dens * life * 0.95
    dirt = np.stack([0.34, 0.24, 0.15], -1) * np.ones_like(X)[..., None] * shade(n, 0.45)[..., None]
    # donkere kluiten: ruis met hoge drempel
    clods = sstep(0.6, 0.9, turb(X, Y, 3.2, u, drift=(0, 2.4), warp=0.3, ofs=i * 0.31)) * env
    dirt = dirt * (1 - 0.35 * clods[..., None])
    # vuur onderin de eerste beelden
    fire_amt = np.exp(-((X / 0.32) ** 2 + ((fy - 0.2) / 0.36) ** 2)) * (1 - sstep(0.0, 0.42, u))
    fv = np.clip((fire_amt * 1.3 - (1 - n) * 0.55) * 1.7, 0, 1)
    fire_rgb = ramp(fv, FIRE)
    k = sstep(0.1, 0.5, fv)[..., None]
    col = dirt * (1 - k) + fire_rgb * k
    a = np.maximum(a, sstep(0.1, 0.5, fv) * 0.95)
    return col, a


def sheet(name, fn, premult_for_add=False):
    out = np.zeros((N * 4, N * 4, 4), np.float32)
    for i in range(16):
        u = i / 15.0
        rgb, a = fn(i, u)
        a = np.clip(a, 0, 1)
        r, c = divmod(i, 4)
        if premult_for_add:
            rgb = rgb * a[..., None]      # vuur wordt opgeteld: transparant = zwart
            out[r * N:(r + 1) * N, c * N:(c + 1) * N, :3] = np.clip(rgb, 0, 1)
            out[r * N:(r + 1) * N, c * N:(c + 1) * N, 3] = 1.0   # opgeteld: zwart = niets; vol dekkend, anders vult Godot de rand onder alpha 0 met kleur
        else:
            out[r * N:(r + 1) * N, c * N:(c + 1) * N, :3] = np.clip(rgb, 0, 1)
            out[r * N:(r + 1) * N, c * N:(c + 1) * N, 3] = a
    # sRGB-kleur: de bouwstenen hierboven zijn al in schermkleur gekozen
    img = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size, os.path.getsize(os.path.join(OUT, name)) // 1024, "KB")


sheet("tankfx_mond.png", frame_mond, premult_for_add=True)
sheet("tankfx_rook.png", frame_rook)
sheet("tankfx_stof.png", frame_stof)
sheet("tankfx_aarde.png", frame_aarde)
