"""M-47 rook- en stof-flipbooks (4x4 atlas, 768x768 RGBA) met domeinvervormde fBm-ruis.

De Blender/Mantaflow-simulatie bleek te traag en gaf geen bruikbare wolken (statische bol), daarom nu procedureel:
elke frame is een uitdijende wolk waarvan de rand wordt weggevreten met ruis, met zijlicht en een blauw randlicht.
Gebruik: python3 bron/m47/maak_rook.py   (schrijft assets/m47/rook_sliert.png en assets/m47/rook_stof.png)
"""
import numpy as np
from PIL import Image

N = 192
rng = np.random.default_rng(47)


def noise(scale, seed):
    r = np.random.default_rng(seed)
    g = r.random((scale + 1, scale + 1)).astype(np.float32)
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0


def fbm(seed, base=4, octaves=5):
    out = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * noise(base * 2 ** o, seed * 31 + o)
        tot += amp
        amp *= 0.5
    return out / tot


def warp(field, dx, dy, k):
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    sx = np.clip(xx + dx * k, 0, N - 1).astype(np.int32)
    sy = np.clip(yy + dy * k, 0, N - 1).astype(np.int32)
    return field[sy, sx]


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def frames(kind, seed):
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    cx, cy = N / 2, N / 2
    base = fbm(seed, 6, 6)
    wx, wy = fbm(seed + 1, 4, 4) - 0.5, fbm(seed + 2, 4, 4) - 0.5
    out = []
    for i in range(16):
        t = i / 15.0
        if kind == "sliert":
            # lange, golvende sliert die uitdijt en wegtrekt (as horizontaal)
            rx = 40 + 34 * np.sqrt(t)
            ry = 36 + 30 * np.sqrt(t)
            ox = (t - 0.4) * 18
            wob = np.sin(xx * 0.07 + t * 5.0) * (4 + 10 * t)
            d = np.sqrt(((xx - cx - ox) / rx) ** 2 + ((yy - cy - wob) / ry) ** 2)
            kern = 1.0 - smooth(0.25, 1.0, d)
            strength = 1.0 - smooth(0.6, 1.0, t)
            dens_noise = warp(base, wx * 90, wy * 90 + t * 25, 1.0)
        else:
            # ronde stofwolk: rolt omhoog en uit elkaar
            r = 52 + 36 * np.sqrt(t)
            d = np.sqrt(((xx - cx) / r) ** 2 + ((yy - cy + 14 * t) / (r * 0.82)) ** 2)
            kern = 1.0 - smooth(0.3, 1.0, d)
            strength = 1.0 - smooth(0.7, 1.0, t)
            dens_noise = warp(base, wx * 70 * (0.4 + t), wy * 70 * (0.4 + t) - t * 30, 1.0)
        n = np.clip((dens_noise - 0.5) * 3.0 + 0.62 - 0.22 * t, 0, 1)      # veel contrast: pluimen en gaten
        dens = np.clip(kern * (0.22 + 1.1 * n), 0, 1) * np.clip(strength * 1.15, 0, 1)
        # belichting uit de ruis zelf: zijlicht van linksboven, blauw randlicht rechtsonder
        gy, gx = np.gradient(dens_noise * kern)
        lit = np.clip(0.7 - (gx + gy) * 9.0, 0.3, 1.0)
        rim = np.clip((gx + gy) * 10.0, 0, 0.7)
        if kind == "sliert":
            col = np.stack([0.62 * lit + 0.10 * rim, 0.72 * lit + 0.30 * rim, 0.88 * lit + 0.75 * rim], -1)
        else:
            col = np.stack([0.66 * lit + 0.05 * rim, 0.62 * lit + 0.12 * rim, 0.56 * lit + 0.40 * rim], -1)
        rgba = np.dstack([np.clip(col, 0, 1), dens])
        out.append((rgba * 255).astype(np.uint8))
    return out


for kind, seed, name in (("sliert", 7, "rook_sliert"), ("stof", 11, "rook_stof")):
    atlas = Image.new("RGBA", (N * 4, N * 4), (0, 0, 0, 0))
    for i, f in enumerate(frames(kind, seed)):
        atlas.paste(Image.fromarray(f, "RGBA"), ((i % 4) * N, (i // 4) * N))
    atlas.save(f"assets/m47/{name}.png", optimize=True)
    print(name, atlas.size)
