#!/usr/bin/env python3
"""Wapeneffecten AAA: maakt de vlam-flipbooks en de rookpluim voor shotgun en M1911.

Reproduceerbaar (vaste seeds), alleen numpy en PIL. Uitvoer in assets/wapenfx/:
  flash_pistool_4x4.png, flash_shotgun_4x4.png  4x4 beelden van 128 px. Het loopeinde zit bovenaan in het midden (v = 0,03),
                                                 de vlam wijst naar beneden (v loopt mee met +Z in het spel, dus naar voren).
  rook.png                                       zachte rookwolk met ruis (voor ook stof en gras).
Gebruik: python3 bron/wapenfx/maak_wapenfx.py
"""
import os
import numpy as np
from PIL import Image

UIT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "wapenfx")
CEL = 128


def ruis(n, seed, oct=4):
    """Fractale waardenruis in [0,1], n x n."""
    rng = np.random.default_rng(seed)
    uit = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(oct):
        g = 3 * 2 ** o
        raster = rng.random((g + 1, g + 1))
        img = Image.fromarray((raster * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        uit += amp * np.asarray(img, dtype=float) / 255.0
        tot += amp
        amp *= 0.5
    return uit / tot


def kleur(i):
    """Vuurkleur: donkerrood -> oranje -> geel -> witte kern. i in [0, ~1.3]."""
    stops = [(0.0, (0.35, 0.05, 0.0)), (0.3, (1.0, 0.36, 0.05)), (0.6, (1.0, 0.7, 0.22)), (0.85, (1.0, 0.93, 0.6)), (1.1, (1.0, 1.0, 0.95))]
    r = np.zeros_like(i); g = np.zeros_like(i); b = np.zeros_like(i)
    xs = [s[0] for s in stops]
    for c, idx in ((r, 0), (g, 1), (b, 2)):
        c[:] = np.interp(i, xs, [s[1][idx] for s in stops])
    return r, g, b


def frame(k, profiel, seed):
    t = k / 15.0
    L, W, bol, zij, rays, korrel = profiel
    # tijdverloop: snel groeien (frames 0 tot 3), kort vasthouden, dan krimpen en doven
    groei = min(1.0, 0.3 + t * 4.5)
    krimp = 1.0 - max(0.0, (t - 0.3)) * 0.85
    helder = 1.0 if t < 0.22 else float(np.exp(-(t - 0.22) * 5.5))
    sc = groei * max(krimp, 0.12)
    y, x = np.mgrid[0:CEL, 0:CEL] / (CEL - 1.0)
    x = x - 0.5          # dwars op de loop
    v = y - 0.03         # langs de loop (0 = loopmond)
    n1 = ruis(CEL, seed + k * 7)
    n2 = ruis(CEL, seed + 100 + k * 13, 3)
    vuur = np.zeros((CEL, CEL))
    # pluim: smal bij de loop, breed op 40 procent, taps toelopend; ruis bijt de rand uit
    vl = np.clip(v / (L * sc + 1e-6), 0, 1.5)
    breedte = W * sc * (np.sin(np.clip(vl, 0, 1) * np.pi) ** 0.65) + 0.012
    pluim = np.exp(-(x / breedte) ** 2 * 2.2) * (v > -0.01) * np.clip(1.25 - vl, 0, 1) ** 0.8
    vuur += pluim * (0.55 + 0.7 * n1)
    # bol vlak bij de loop (vuurbal)
    r2 = (x / (bol * sc + 1e-6)) ** 2 + ((v - 0.10 * sc) / (bol * 0.9 * sc + 1e-6)) ** 2
    vuur += np.exp(-r2 * 1.6) * 0.95
    # hete kern, lang en smal
    kern = np.exp(-(x / (0.030 * sc + 1e-6)) ** 2 * 2.0) * np.exp(-(np.clip(v, 0, None) / (L * 0.42 * sc + 1e-6)) ** 2) * (v > -0.005)
    vuur += kern * 0.75
    # zijvlammen (shotgun: de bekende zijwaartse flits) en stralen (pistool)
    for hoek, lengte, dik in rays:
        a = np.deg2rad(hoek)
        dx, dy = np.sin(a), np.cos(a)
        langs = x * dx + v * dy
        dwars = -x * dy + v * dx
        straal = np.exp(-(dwars / (dik * sc + 1e-6)) ** 2 * 2.0) * (langs > 0) * np.clip(1.0 - langs / (lengte * sc + 1e-6), 0, 1) ** 1.4
        vuur += straal * 0.9
    for sgn in (-1, 1):
        if zij > 0:
            lang = np.clip(1.0 - np.abs(x - sgn * zij * sc * 0.55) / (zij * sc * 0.55 + 1e-6), 0, 1)
            dik = np.exp(-((v - 0.07 * sc) / (0.035 * sc + 1e-6)) ** 2)
            vuur += lang ** 1.5 * dik * 0.85
    # korrelige vonkjes naast de pluim
    if korrel > 0:
        rng = np.random.default_rng(seed + 900 + k)
        for _ in range(korrel):
            px = rng.uniform(-0.3, 0.3) * sc
            py = rng.uniform(0.05, 0.55) * sc
            d = ((x - px) ** 2 + (v - py) ** 2) ** 0.5
            vuur += np.exp(-(d / 0.011) ** 2) * 0.9 * (1.0 - t) * rng.uniform(0.5, 1.0)
    vuur *= helder * (0.75 + 0.5 * n2)
    vuur *= 0.82
    alpha = np.clip(vuur * 1.2, 0, 1)
    r, g, b = kleur(vuur)
    rgba = np.stack([r, g, b, alpha], axis=-1)
    rgba[..., :3] *= (alpha[..., None] > 0.003)
    return np.clip(rgba, 0, 1)


PISTOOL = (0.60, 0.11, 0.095, 0.0, [(-32, 0.30, 0.018), (32, 0.30, 0.018), (-62, 0.20, 0.014), (62, 0.20, 0.014), (0, 0.78, 0.016)], 6)
SHOTGUN = (0.78, 0.30, 0.27, 0.40, [(-24, 0.52, 0.030), (24, 0.52, 0.030), (-48, 0.40, 0.024), (48, 0.40, 0.024), (-12, 0.7, 0.028), (12, 0.7, 0.028)], 14)


def atlas(profiel, seed, pad):
    img = np.zeros((CEL * 4, CEL * 4, 4))
    for k in range(16):
        f = frame(k, profiel, seed)
        cx, cy = (k % 4) * CEL, (k // 4) * CEL
        img[cy:cy + CEL, cx:cx + CEL] = f
        # rand dicht, zodat mipmaps niet in het buurbeeld lekken
        img[cy:cy + 2, cx:cx + CEL] = 0
        img[cy + CEL - 2:cy + CEL, cx:cx + CEL] = 0
        img[cy:cy + CEL, cx:cx + 2] = 0
        img[cy:cy + CEL, cx + CEL - 2:cx + CEL] = 0
    return Image.fromarray((img * 255).astype(np.uint8), "RGBA")


def rook():
    n = 128
    y, x = np.mgrid[0:n, 0:n] / (n - 1.0) - 0.5
    d = np.sqrt(x ** 2 + y ** 2) * 2.0
    r = ruis(n, 4242, 5)
    r2 = ruis(n, 777, 4)
    vorm = np.clip(1.0 - d, 0, 1) ** 0.9
    wolk = np.clip(vorm * (0.35 + 1.1 * r) - 0.12 * r2, 0, 1)
    wolk = np.clip(wolk * 1.5, 0, 1) ** 1.2
    schaduw = np.clip(0.8 + 0.25 * (r - 0.5) - 0.35 * y, 0.35, 1.0)   # onderkant iets donkerder
    rgb = np.stack([schaduw, schaduw * 0.97, schaduw * 0.92], axis=-1)
    rgba = np.concatenate([rgb, wolk[..., None] * 0.9], axis=-1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    os.makedirs(UIT, exist_ok=True)
    atlas(PISTOOL, 11, 0).save(os.path.join(UIT, "flash_pistool_4x4.png"), optimize=True)
    atlas(SHOTGUN, 23, 0).save(os.path.join(UIT, "flash_shotgun_4x4.png"), optimize=True)
    rook().save(os.path.join(UIT, "rook.png"), optimize=True)
    print("klaar:", sorted(os.listdir(UIT)))
