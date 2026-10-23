#!/usr/bin/env python3
"""Tekent de bladtexturen voor de jungle (kleur+alfa en normal map) naar assets/textures/foliage/.
Eigen tekenwerk (geen foto's): python3 tools/gen_foliage.py. Vraagt numpy en Pillow."""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "foliage")
os.makedirs(OUT, exist_ok=True)
SS = 2  # supersampling


def noise(w, h, scale, seed):
    """Zachte waardenruis 0..1 (bilineair opgeschaald)."""
    rng = np.random.default_rng(seed)
    gw, gh = max(2, int(w / scale) + 2), max(2, int(h / scale) + 2)
    g = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
    return np.asarray(g.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0


def fbm(w, h, seed, base=48):
    return sum(noise(w, h, base / (2 ** i), seed + i) * (0.5 ** i) for i in range(4)) / 1.875


def normal_from_height(hgt, strength):
    gy, gx = np.gradient(hgt)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(hgt)], -1)  # Godot: GL (Y omhoog)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def finish(name, rgb, alpha, hgt, strength):
    """rgb (h,w,3) 0..1, alpha (h,w) 0..1; kleur loopt buiten de vorm door zodat mips geen donkere rand krijgen."""
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    img.putalpha(Image.fromarray(a))
    img.save(os.path.join(OUT, name + "_color.png"), optimize=True)
    normal_from_height(hgt, strength).save(os.path.join(OUT, name + "_normal.png"), optimize=True)


def downsample(arr, w, h):
    return np.asarray(Image.fromarray(arr).resize((w, h), Image.LANCZOS))


# ------------------------------------------------------------------ breed jungleblad
def broadleaf(w=512, h=512, seed=1):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u = x / (w - 1)                    # 0 steel, 1 punt
    v = (y - (h - 1) / 2) / ((h - 1) / 2)  # -1..1 over de breedte
    width = np.sin(np.power(np.clip(u, 0, 1), 0.62) * math.pi) * (1.0 - 0.22 * u)
    av = np.abs(v)
    # ruwe rand + een paar inkepingen
    edge = fbm(w, h, seed + 10, 24)
    inside = av < width * (0.93 + (edge - 0.5) * 0.14) - 0.01
    alpha = np.clip((width * (0.93 + (edge - 0.5) * 0.14) - 0.01 - av) * 60.0, 0, 1) * (u > 0.015)
    # nerven: middenrib + zijnerven die schuin naar de punt lopen
    rib = np.exp(-(v / 0.022) ** 2)
    phase = (u * 11.0 - av * 3.4)
    lat = np.exp(-((np.abs((phase % 1.0) - 0.5) - 0.5) / 0.045) ** 2)
    lat *= np.clip(1.0 - av / np.maximum(width, 0.05), 0, 1) ** 0.4
    # blaadje is tussen de nerven licht bol (quilting)
    cell = 0.5 - 0.5 * np.cos((phase % 1.0) * 2 * math.pi)
    hgt = cell * 0.18 * (1 - rib) + rib * 0.5 - lat * 0.12
    hgt += (fbm(w, h, seed + 20, 10) - 0.5) * 0.06
    # kleur: donker, diep groen; licht langs nerven, geel naar rand en punt, vlekkerig
    mott = fbm(w, h, seed + 30, 40)
    base = np.stack([0.12 + 0.05 * mott, 0.27 + 0.11 * mott, 0.07 + 0.03 * mott], -1)
    base *= (0.78 + 0.34 * cell[..., None])
    lightv = np.stack([0.3, 0.38, 0.16], 0)[None, None] * rib[..., None] * 0.7 + np.stack([0.18, 0.28, 0.1], 0)[None, None] * lat[..., None] * 0.35
    rgb = base + lightv
    edgey = np.clip((av / np.maximum(width, 0.05)) - 0.72, 0, 1)[..., None] * np.array([0.14, 0.1, -0.03])[None, None]
    rgb += edgey * (0.5 + mott[..., None])
    rgb *= (0.78 + 0.32 * np.sqrt(u))[..., None]  # steel wat donkerder (zelfschaduw)
    # verdroogde bruine vlekjes bij de rand
    spot = np.clip((fbm(w, h, seed + 40, 18) - 0.66) * 6, 0, 1) * np.clip(av / np.maximum(width, 0.05) - 0.4, 0, 1)
    rgb = rgb * (1 - spot[..., None] * 0.6) + np.array([0.28, 0.2, 0.08])[None, None] * spot[..., None] * 0.6
    # kleurdoorloop buiten de vorm
    out = rgb.copy()
    finish("leaf", out, alpha, hgt, 3.5)


# ------------------------------------------------------------------ palmtak met bladpunten
def frond(name, w, h, nleaf, leaf_len, width_px, seed, droop=0.35, dark=(0.1, 0.24, 0.07), light=(0.32, 0.46, 0.17), fine=False):
    """Tak loopt links->rechts, bladpunten hangen schuin naar achteren aan beide kanten."""
    rng = random.Random(seed)
    big = (w * SS, h * SS)
    col = Image.new("RGB", big, tuple(int(c * 255 * 0.8) for c in dark))
    cd = ImageDraw.Draw(col)
    al = Image.new("L", big, 0)
    ad = ImageDraw.Draw(al)
    hm = Image.new("L", big, 128)
    hd = ImageDraw.Draw(hm)
    cy = h * SS / 2

    def lerpc(a, b, t):
        return tuple(int(255 * (a[i] + (b[i] - a[i]) * t)) for i in range(3))

    # bladpunten: eerst de verste (onderaan getekend), dan naar de steel toe
    leaves = []
    for i in range(nleaf):
        t0 = 0.03 + 0.95 * i / nleaf + rng.uniform(-0.004, 0.004)
        for s in (-1, 1):
            leaves.append((t0, s))
    leaves.sort(key=lambda p: -p[0])
    for t0, s in leaves:
        x0 = t0 * (w - 4) * SS + 2 * SS
        reach = leaf_len * (math.sin(min(1.0, t0 * 1.1 + 0.04) * math.pi) ** 0.6) * rng.uniform(0.8, 1.08) * SS
        reach = max(reach, 10 * SS)
        sweep = reach * rng.uniform(0.38, 0.62)  # leunt naar de punt van de tak
        wd = width_px * SS * rng.uniform(0.85, 1.15) * (0.6 + 0.6 * math.sin(min(1.0, t0 + 0.1) * math.pi))
        n = 10
        left, right, mid = [], [], []
        for k in range(n + 1):
            f = k / n
            px = x0 + sweep * f
            py = cy + s * reach * f - s * (droop * reach * f * f * 0.4)
            ww = wd * (math.sin(math.pi * min(1.0, f * 0.75 + 0.05)) ** 0.7) * (1 - 0.65 * f ** 2) * 0.5
            dx, dy = sweep / n, s * reach / n
            nrm = math.hypot(dx, dy)
            nx, ny = -dy / nrm, dx / nrm
            left.append((px + nx * ww, py + ny * ww))
            right.append((px - nx * ww, py - ny * ww))
            mid.append((px, py))
        poly = left + right[::-1]
        shade = rng.uniform(0.0, 1.0)
        c_a = lerpc(dark, light, 0.15 + 0.3 * t0 + 0.12 * shade)
        cd.polygon(poly, fill=c_a)
        # lichtere helft (gevouwen blad vangt licht aan een kant)
        half = left + mid[::-1]
        cd.polygon(half, fill=lerpc(dark, light, 0.35 + 0.35 * t0 + 0.15 * shade))
        cd.line(mid, fill=lerpc(dark, light, 0.75), width=max(1, int(1.2 * SS)))
        ad.polygon(poly, fill=255)
        hd.polygon(half, fill=int(128 + 45))
        hd.polygon(right + mid[::-1], fill=int(128 - 45))
        hd.line(mid, fill=int(128 + 70), width=max(1, SS))
    # hoofdnerf
    cd.line([(0, cy), (w * SS, cy)], fill=lerpc(dark, light, 0.8), width=int(3.5 * SS))
    ad.line([(0, cy), (w * SS, cy)], fill=255, width=int(3.5 * SS))
    hd.line([(0, cy), (w * SS, cy)], fill=235, width=int(3.5 * SS))
    col_s = np.asarray(col.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    al_s = np.asarray(al.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    hm_s = np.asarray(hm.filter(ImageFilter.GaussianBlur(SS * 0.8)).resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    mott = fbm(w, h, seed + 5, 30)
    col_s *= (0.85 + 0.3 * mott)[..., None]
    # schaduw onderaan de tak: donker bij de steel, licht aan de punt
    u = (np.arange(w, dtype=np.float32) / w)[None, :, None]
    col_s *= 0.8 + 0.3 * np.sqrt(u)
    # kleur buiten de vorm uitsmeren zodat mips niet donker worden
    finish(name, col_s, al_s, hm_s, 5.0)


# ------------------------------------------------------------------ gras
def grass(w=256, h=256, seed=4):
    rng = random.Random(seed)
    big = (w * SS, h * SS)
    col = Image.new("RGB", big, (30, 60, 18))
    cd = ImageDraw.Draw(col)
    al = Image.new("L", big, 0)
    ad = ImageDraw.Draw(al)
    hm = Image.new("L", big, 128)
    hd = ImageDraw.Draw(hm)
    blades = []
    for i in range(34):
        bx = rng.uniform(0.06, 0.94) * w * SS
        top_y = rng.uniform(0.04, 0.55) * h * SS
        lean = rng.uniform(-0.2, 0.2) * w * SS
        wd = rng.uniform(5.0, 9.5) * SS
        blades.append((top_y, bx, lean, wd))
    blades.sort(reverse=True)  # lage (korte) eerst, hoge erachter... korte vooraan getekend
    for top_y, bx, lean, wd in blades[::-1][::-1]:
        n = 14
        left, right, mid = [], [], []
        for k in range(n + 1):
            f = k / n
            y = h * SS - (h * SS - top_y) * f
            xm = bx + lean * (f ** 1.8)
            ww = wd * (1 - f ** 1.4) * 0.5 + 0.4 * SS * (1 - f)
            left.append((xm - ww, y))
            right.append((xm + ww, y))
            mid.append((xm, y))
        poly = left + right[::-1]
        g = rng.uniform(0, 1)
        dark = (0.1 + 0.04 * g, 0.22 + 0.06 * g, 0.05)
        light = (0.34 + 0.12 * g, 0.46 + 0.08 * g, 0.16 + 0.04 * g)
        # kleurverloop in 8 stroken van onder naar boven
        for k in range(n):
            f = (k + 0.5) / n
            seg = [left[k], left[k + 1], right[k + 1], right[k]]
            c = tuple(int(255 * (dark[i] + (light[i] - dark[i]) * f ** 0.9)) for i in range(3))
            cd.polygon(seg, fill=c)
        cd.line(mid, fill=tuple(int(255 * (light[i] * 0.95)) for i in range(3)), width=max(1, SS))
        ad.polygon(poly, fill=255)
        hd.polygon(left + mid[::-1], fill=170)
        hd.polygon(right + mid[::-1], fill=90)
    col_s = np.asarray(col.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    al_s = np.asarray(al.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    hm_s = np.asarray(hm.filter(ImageFilter.GaussianBlur(SS * 0.6)).resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0
    col_s *= (0.85 + 0.3 * fbm(w, h, seed + 3, 28))[..., None]
    finish("grass", col_s, al_s, hm_s, 4.0)


if __name__ == "__main__":
    broadleaf()
    frond("palm", 512, 256, 46, 112, 17, 7, droop=0.5)
    frond("fern", 512, 256, 40, 112, 13, 3, droop=0.15, dark=(0.1, 0.26, 0.06), light=(0.3, 0.46, 0.15))
    grass()
    print("klaar:", sorted(os.listdir(OUT)))
