"""Texturen in de MakeHuman-UV-ruimte, berekend uit de 3D-rustpositie van elke texel (numpy, geen Blender).

Elke texel weet via rasterisatie op welk vlak hij ligt en waar dat punt in 3D zit (T-houding van het DEF-skelet).
Daardoor lopen camouflagevlekken, naden, zakken, vuil en gezichtstrekken door over UV-naden heen.
"""
import numpy as np
from PIL import Image


def rasterize(uv_tris, size):
    """uv_tris: (T,3,2) in 0..1. Geeft per texel driehoeknummer (-1 = leeg) en barycentrische coordinaten."""
    tri_id = np.full((size, size), -1, dtype=np.int32)
    bary = np.zeros((size, size, 3), dtype=np.float32)
    pts = uv_tris * size
    pts[..., 1] = size - pts[..., 1]  # beeld-y loopt naar beneden
    for t, (a, b, c) in enumerate(pts):
        x0 = max(int(np.floor(min(a[0], b[0], c[0]))), 0)
        x1 = min(int(np.ceil(max(a[0], b[0], c[0]))), size - 1)
        y0 = max(int(np.floor(min(a[1], b[1], c[1]))), 0)
        y1 = min(int(np.ceil(max(a[1], b[1], c[1]))), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        px, py = xs + 0.5, ys + 0.5
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l0 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / den
        l1 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / den
        l2 = 1 - l0 - l1
        m = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
        tri_id[ys[m], xs[m]] = t
        bary[ys[m], xs[m]] = np.stack([l0[m], l1[m], l2[m]], axis=1)
    return tri_id, bary


def dilate_index(tri_id, steps=12):
    """Vult lege texels rond eilanden met de buurtexel (tegen mipmap-randen)."""
    src_y, src_x = np.mgrid[0:tri_id.shape[0], 0:tri_id.shape[1]]
    filled = tri_id >= 0
    sy, sx = src_y.copy(), src_x.copy()
    for _ in range(steps):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nf = np.roll(filled, (dy, dx), axis=(0, 1))
            take = ~filled & nf
            sy[take] = np.roll(sy, (dy, dx), axis=(0, 1))[take]
            sx[take] = np.roll(sx, (dy, dx), axis=(0, 1))[take]
            filled = filled | take
    return sy, sx, filled


# ---------- ruis ----------
def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)


def vnoise3(p, seed=0):
    """Waarderuis 0..1 met gladde interpolatie. p: (...,3)."""
    f = np.floor(p)
    t = p - f
    t = t * t * (3 - 2 * t)
    i = f.astype(np.int64)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[..., 0] if dx else 1 - t[..., 0]) * (t[..., 1] if dy else 1 - t[..., 1]) * (t[..., 2] if dz else 1 - t[..., 2])
                out = out + w * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    return out


def fbm3(p, freq, seed, octaves=4, gain=0.5):
    tot, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        tot = tot + amp * vnoise3(p * freq * (2 ** o), seed + o * 17)
        norm += amp
        amp *= gain
    return tot / norm


def smooth(x, e0, e1):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def blend_normals(base, detail):
    """Whiteout-menging van twee raakruimtenormalen (-1..1)."""
    n = np.stack([base[..., 0] + detail[..., 0], base[..., 1] + detail[..., 1], base[..., 2] * detail[..., 2]], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def save_rgb(path, arr):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path)


def srgb(c):
    return np.array([int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)
