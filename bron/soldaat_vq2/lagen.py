"""Procedurele PBR-lagen per kleding-/huidsoort, geevalueerd per texel uit 3D-rustpositie (T-houding, meters,
Z omhoog, gezicht -Y) en rustnormaal. Elke laag geeft albedo (sRGB 0..1), hoogte (voor de detailnormaal) en ruwheid.
"""
import numpy as np
from textuur import fbm3, vnoise3, smooth, srgb

# lagen
SKIN, CAMO, SHIRT_E, PANTS_E, GLOVE, BOOT, BOOT_E, TANK, EYE = range(9)
TINTED = {CAMO, SHIRT_E, PANTS_E}

# kledingdikte (m) waarmee het lichaam naar buiten gaat
OFFSET = {SKIN: 0.0, CAMO: 0.010, SHIRT_E: 0.011, PANTS_E: 0.012, GLOVE: 0.003, BOOT: 0.013, BOOT_E: 0.012,
          TANK: 0.004, EYE: 0.0}

# lichaamsgebieden (op rustpositie)
HEAD, HAND, FORE, UPPER, TORSO, LEGS, FEET = range(7)


def region(p):
    x, z = p[:, 0], p[:, 2]
    ax = np.abs(x)
    r = np.full(len(p), TORSO, dtype=np.int8)
    r[z < 1.0] = LEGS
    r[z < 0.27] = FEET
    r[(ax > 0.20) & (z > 1.25)] = UPPER
    r[(ax > 0.47) & (z > 1.25)] = FORE
    r[(ax > 0.725) & (z > 1.25)] = HAND
    r[(z > 1.505) & (ax < 0.16)] = HEAD
    return r


VARIANTS = {
    # naam: laag per gebied (HEAD, HAND, FORE, UPPER, TORSO, LEGS, FEET)
    "Uniform": (SKIN, GLOVE, CAMO, CAMO, CAMO, CAMO, BOOT),
    "Bloot": (SKIN, SKIN, SKIN, SKIN, SKIN, CAMO, BOOT),
    "Mouwloos": (SKIN, SKIN, SKIN, SKIN, TANK, CAMO, BOOT),
    "Vijand": (SKIN, SKIN, SKIN, SHIRT_E, SHIRT_E, PANTS_E, BOOT_E),
}


def layer_of(variant, p, is_eye):
    reg = region(p)
    lay = np.array(VARIANTS[variant], dtype=np.int8)[reg]
    if variant == "Vijand":   # opgerolde mouwen tot net onder de elleboog
        ax = np.abs(p[:, 0])
        lay[(reg == FORE) & (ax < 0.515)] = SHIRT_E
    lay[is_eye] = EYE
    return lay


def offsets(variant, p, lay):
    off = np.array([OFFSET[int(l)] for l in range(9)])[lay]
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    cloth = np.isin(lay, list(TINTED) + [TANK])
    off = off + cloth * 0.004 * (fbm3(p, 9.0, 41, 2) - 0.5)       # losse plooien
    off += (lay == CAMO) * 0.006 * smooth(0.30 - np.abs(z - 0.70), 0.0, 0.25) * (z < 1.0)   # ruimere broekspijpen
    off += np.isin(lay, [CAMO, PANTS_E]) * 0.010 * smooth(0.04 - np.abs(z - 0.30), 0, 0.04)  # broek over de laars
    off += (lay == CAMO) * (z > 1.0) * 0.008 * smooth(0.05 - np.abs(z - 1.47), 0, 0.03) * (ax < 0.16)  # kraag
    if variant == "Vijand":
        off += (lay == SHIRT_E) * 0.012 * smooth(0.025 - np.abs(ax - 0.50), 0, 0.02) * (z > 1.25)   # opgerolde mouw
    if variant == "Uniform":
        off += (lay == CAMO) * 0.006 * smooth(0.03 - np.abs(ax - 0.715), 0, 0.02) * (z > 1.25)   # mouwboord
    return off


# ---------------- texturen ----------------
def _grain(p, uv, seed):
    return fbm3(p, 180.0, seed, 2) * 0.6 + vnoise3(np.concatenate([uv * 900, np.zeros((len(uv), 1))], 1), seed + 5) * 0.4


def _seam(d, w=0.0025):
    return smooth(w - np.abs(d), 0, w)


def _rect(a, b, a0, a1, b0, b1, soft=0.004):
    return smooth(a - a0, 0, soft) * smooth(a1 - a, 0, soft) * smooth(b - b0, 0, soft) * smooth(b1 - b, 0, soft)


def _wrinkles(p, n):
    """Plooibanden bij ellebogen, knieen, kruis, taille en enkels."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    w = fbm3(p * np.array([1, 3, 3]), 7.0, 77, 2)
    arm = (z > 1.25) * smooth(0.07 - np.abs(ax - 0.466), 0, 0.06) * np.sin(ax * 260 + w * 9)
    knee = (z < 1.0) * smooth(0.08 - np.abs(z - 0.53), 0, 0.07) * np.sin(z * 230 + w * 10)
    ankle = (z < 1.0) * smooth(0.06 - np.abs(z - 0.31), 0, 0.05) * np.sin(z * 300 + w * 8)
    crotch = (z < 1.0) * smooth(0.10 - np.abs(z - 0.86), 0, 0.08) * smooth(0.06 - ax, 0, 0.05) * np.sin((ax + z) * 200 + w * 6)
    waist = smooth(0.03 - np.abs(z - 1.04), 0, 0.03) * np.sin(ax * 180 + w * 12)
    shoulder = (z > 1.25) * smooth(0.05 - np.abs(ax - 0.22), 0, 0.05) * np.sin(z * 160 + w * 8)
    big = (fbm3(p * np.array([1.0, 1.0, 2.2]), 11.0, 13, 3) - 0.5)
    return (arm + knee + ankle + crotch * 0.7 + waist * 0.6 + shoulder * 0.5) * 0.5 + big * 0.9


def _dirt(p, n, amount=1.0):
    z = p[:, 2]
    ax = np.abs(p[:, 0])
    nz = fbm3(p, 14.0, 91, 4)
    mud = smooth(0.50 - z, 0, 0.35) * (0.45 + nz) * (z < 1.0)
    knees = smooth(0.08 - np.abs(z - 0.53), 0, 0.06) * (n[:, 1] < -0.2) * (0.4 + nz)
    elbows = (z > 1.25) * smooth(0.06 - np.abs(ax - 0.466), 0, 0.05) * (n[:, 1] > 0.2) * 0.6
    seat = (z < 1.0) * (z > 0.80) * (n[:, 1] > 0.5) * 0.35
    speck = smooth(fbm3(p, 60.0, 17, 2), 0.62, 0.75) * 0.5
    return np.clip((mud + knees + elbows + seat + speck) * amount, 0, 1)


def _sweat(p, n):
    z = p[:, 2]
    ax = np.abs(p[:, 0])
    pits = smooth(0.08 - np.hypot(ax - 0.17, z - 1.36), 0, 0.07)
    back = (n[:, 1] > 0.4) * smooth(0.12 - np.abs(z - 1.30), 0, 0.12) * smooth(0.10 - ax, 0, 0.08)
    chest = (n[:, 1] < -0.4) * smooth(0.05 - ax, 0, 0.05) * smooth(0.12 - np.abs(z - 1.33), 0, 0.10)
    return np.clip((pits + back * 0.8 + chest * 0.5) * (0.6 + fbm3(p, 20.0, 5, 2) * 0.6), 0, 1)


def camo(p, n, uv):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    q = p * np.array([1.0, 1.0, 0.65])
    # bijna neutraal patroon met een zweem kleur per vlek; de uniformkleur (Godot: genormaliseerde tint) kleurt het
    base = np.tile(srgb("b4b2a6"), (len(p), 1))
    col = base.copy()
    for seed, thr, c in ((3, 0.54, "838c70"), (11, 0.56, "5a604c"), (29, 0.60, "7a6650"), (47, 0.64, "252523")):
        m = smooth(fbm3(q, 6.0 if seed != 47 else 8.5, seed, 3), thr, thr + 0.02)
        col = col * (1 - m[:, None]) + srgb(c) * m[:, None]
    g = _grain(p, uv, 1)
    col *= (0.90 + 0.14 * g)[:, None]
    h = _wrinkles(p, n) * 0.6 + g * 0.25
    # naden en zakken
    seams = np.zeros(len(p))
    legs = z < 1.0
    seams += legs * _seam(y - 0.0, 0.002) * (np.abs(n[:, 0]) > 0.75)                 # buitennaad
    pocket = legs * _rect(y, z, -0.075, 0.055, 0.56, 0.78) * (np.abs(n[:, 0]) > 0.55) * (np.sign(x) * n[:, 0] > 0)
    flap = legs * _rect(y, z, -0.080, 0.060, 0.735, 0.785) * (np.abs(n[:, 0]) > 0.55) * (np.sign(x) * n[:, 0] > 0)
    front = (n[:, 1] < -0.55) & (z > 1.0) & (ax < 0.18)
    chest = front * _rect(ax, z, 0.035, 0.145, 1.27, 1.40)
    cflap = front * _rect(ax, z, 0.032, 0.148, 1.375, 1.41)
    placket = front * _rect(x, z, -0.014, 0.014, 1.04, 1.47, 0.002)
    buttons = placket * smooth(0.006 - np.hypot(x, ((z - 1.06) % 0.085) - 0.04), 0, 0.002)
    cuffs = (z > 1.25) * smooth(0.012 - np.abs(ax - 0.705), 0, 0.006)
    waistband = smooth(0.022 - np.abs(z - 1.00), 0, 0.004)
    collar = (z > 1.0) * smooth(0.02 - np.abs(z - 1.475), 0, 0.006) * (ax < 0.17)
    flag = (z > 1.25) * (np.sign(x) > 0) * (n[:, 1] < -0.2) * _rect(ax, z, 0.25, 0.32, 1.40, 1.46, 0.002)
    h += pocket * 0.8 + flap * 0.6 + chest * 0.7 + cflap * 0.5 + placket * 0.4 + buttons * 0.8 + cuffs * 0.6 + waistband * 0.5 + collar * 0.6
    for e in (pocket, flap, chest, cflap, placket):
        rim = np.clip(e * (1 - e) * 4, 0, 1)
        seams += rim
    col *= (1 - 0.30 * np.clip(seams, 0, 1))[:, None]
    col *= (1 - 0.08 * flap - 0.06 * cflap)[:, None]
    col = col * (1 - flag[:, None]) + (srgb("3b3d33") + 0.08 * ((np.sin(z * 300) > 0) * flag)[:, None]) * flag[:, None]
    col = col * (1 - buttons[:, None] * 0.6)
    d = _dirt(p, n)
    col = col * (1 - 0.55 * d[:, None]) + srgb("5a4a35") * (0.45 * d[:, None])
    s = _sweat(p, n)
    col *= (1 - 0.18 * s)[:, None]
    rough = 0.86 + 0.06 * g - 0.10 * s + 0.05 * d
    return col, h, rough


def shirt_enemy(p, n, uv, pants=False):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    g = _grain(p, uv, 7)
    base = srgb("8a8578") if pants else srgb("c8c1ae")
    fade = fbm3(p, 3.0, 23, 3)
    col = base[None, :] * (0.86 + 0.20 * fade + 0.10 * g)[:, None]
    # zonverbleekte schouders, oude reparatielappen
    col *= (1 + 0.10 * (n[:, 2] > 0.5) * (z > 1.3))[:, None]
    patch = np.zeros(len(p))
    if pants:
        patch += _rect(ax, z, 0.03, 0.14, 0.47, 0.60) * (n[:, 1] < -0.4)    # kniestukken
        patch += _rect(ax, z, 0.03, 0.12, 0.84, 0.95) * (n[:, 1] > 0.5) * (x > 0)  # zitvlak
    else:
        patch += _rect(x, z, -0.15, -0.06, 1.12, 1.20) * (n[:, 1] < -0.5)
        patch += (z > 1.25) * _rect(ax, z, 0.33, 0.40, 1.41, 1.48) * (x > 0) * (n[:, 2] > 0.2)
    col = col * (1 - 0.22 * patch[:, None])
    h = _wrinkles(p, n) * 0.7 + g * 0.3 + patch * 0.5
    seams = np.clip(patch * (1 - patch) * 4, 0, 1)
    if not pants:
        front = (n[:, 1] < -0.5) & (z > 1.0) & (ax < 0.18)
        placket = front * _rect(x, z, -0.012, 0.012, 1.04, 1.47, 0.002)
        buttons = placket * smooth(0.006 - np.hypot(x, ((z - 1.06) % 0.09) - 0.045), 0, 0.002)
        pocket = front * (x > 0) * _rect(x, z, 0.04, 0.14, 1.28, 1.39)
        rolled = (z > 1.25) * smooth(0.022 - np.abs(ax - 0.50), 0, 0.01)
        collar = smooth(0.02 - np.abs(z - 1.475), 0, 0.006) * (ax < 0.17) * (z > 1.0)
        h += placket * 0.4 + buttons + pocket * 0.6 + rolled * 1.2 + collar * 0.6
        seams += np.clip(pocket * (1 - pocket) * 4, 0, 1) + _seam(np.abs(ax - 0.50) - 0.022, 0.002) * (z > 1.25)
        col *= (1 - 0.5 * buttons)[:, None]
        col *= (1 - 0.10 * rolled)[:, None]
    else:
        seams += (z < 1.0) * _seam(y, 0.002) * (np.abs(n[:, 0]) > 0.75)
        h += smooth(0.022 - np.abs(z - 1.00), 0, 0.004) * 0.5
    col *= (1 - 0.30 * np.clip(seams, 0, 1))[:, None]
    d = _dirt(p, n, 1.3)
    col = col * (1 - 0.55 * d[:, None]) + srgb("5b4632") * (0.40 * d[:, None])
    s = _sweat(p, n)
    col *= (1 - 0.25 * s)[:, None]
    rough = 0.88 + 0.05 * g - 0.12 * s
    return col, h, rough


def tank(p, n, uv):
    x, z = p[:, 0], p[:, 2]
    ang = np.arctan2(p[:, 1], x)
    g = _grain(p, uv, 31)
    rib = np.sin(ang * 260) * 0.5 + 0.5
    col = srgb("4f5638")[None, :] * (0.92 + 0.08 * rib + 0.08 * g)[:, None]
    s = _sweat(p, n)
    col *= (1 - 0.30 * s)[:, None]
    d = _dirt(p, n, 0.8)
    col = col * (1 - 0.4 * d[:, None]) + srgb("5a4a35") * (0.3 * d[:, None])
    hem = smooth(0.012 - np.abs(z - 1.02), 0, 0.004) + smooth(0.010 - np.abs(z - 1.47), 0, 0.004) * (np.abs(x) < 0.12)
    h = rib * 0.25 + g * 0.2 + hem * 0.6 + _wrinkles(p, n) * 0.3
    return col, h, 0.9 - 0.15 * s


def glove(p, n, uv):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    g = _grain(p, uv, 61)
    col = np.tile(srgb("7d6a4e"), (len(p), 1))
    palm = n[:, 2] < -0.3
    col[palm] = srgb("4e3f2e")
    knuckle = (n[:, 2] > 0.4) * _rect(ax, y, 0.80, 0.865, -0.01, 0.12, 0.006)
    col = col * (1 - 0.35 * knuckle[:, None])
    cuff = smooth(0.012 - np.abs(ax - 0.735), 0, 0.006)
    col *= (1 - 0.25 * cuff)[:, None]
    col *= (0.9 + 0.15 * g)[:, None]
    h = g * 0.4 + knuckle * 0.8 + cuff * 0.6 + fbm3(p, 90, 3, 2) * 0.3
    rough = np.where(palm, 0.6, 0.8) + 0.05 * g
    return col, h, rough


def boot(p, n, uv, enemy=False):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    fx = np.abs(x) - 0.089
    g = _grain(p, uv, 71)
    leather = srgb("4a3b2e") if enemy else srgb("1f1d1b")
    canvas = srgb("3d3a2c") if enemy else srgb("4b5038")
    upper = smooth(z - 0.11, 0, 0.01)
    col = leather[None, :] * (1 - upper[:, None]) + canvas[None, :] * upper[:, None]
    col *= (0.88 + 0.2 * g)[:, None]
    sole = smooth(0.03 - z, 0, 0.006)
    col = col * (1 - sole[:, None]) + srgb("15130f") * sole[:, None]
    front = (n[:, 1] < -0.4) & (z > 0.06) & (z < 0.26)
    laces = front * smooth(0.016 - np.abs(fx), 0, 0.004)
    criss = laces * (np.abs(np.sin(z * 260 + fx * 120)) > 0.6)
    col = col * (1 - 0.6 * criss[:, None])
    toecap = smooth(0.10 - z, 0, 0.02) * (y < -0.12)
    d = np.clip(smooth(0.18 - z, 0, 0.16) * (0.5 + fbm3(p, 25, 9, 3)) * (1.4 if enemy else 1.0), 0, 1)
    col = col * (1 - 0.6 * d[:, None]) + srgb("6b5a40") * (0.55 * d[:, None])
    h = g * 0.3 + criss * 0.8 + sole * 0.4 + toecap * 0.3 + fbm3(p, 50, 21, 2) * 0.3
    rough = np.clip(0.55 + 0.30 * upper + 0.25 * d - 0.1 * toecap, 0.35, 1)
    return col, h, rough


def skin(p, n, uv, eyes, variant):
    """eyes: (links, rechts) middelpunt van de oogbollen in rustruimte."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    el, er = eyes
    ez = (el[2] + er[2]) / 2
    ex = abs(el[0])
    g = fbm3(p, 40.0, 101, 3)
    col = srgb("94705a")[None, :] * (0.93 + 0.10 * g)[:, None]
    red = smooth(0.03 - np.hypot(ax - 0.04, z - (ez - 0.035)), 0, 0.03) * (n[:, 1] < -0.3)
    col = col * (1 - 0.1 * red[:, None]) + srgb("b06a58") * (0.1 * red[:, None])
    head = (z > 1.48) & (ax < 0.16)
    front = n[:, 1] < -0.35
    hair_col = srgb("2a2019")
    # haar: korte coupe, haarlijn boven het voorhoofd, aan de zijkant boven het oor
    hairline = ez + 0.045 + 0.02 * smooth(ax - 0.03, 0, 0.05)
    back = y > -0.03
    hair = head & ((z > hairline) | (back & (z > ez - 0.065)) | ((ax > 0.06) & (z > ez + 0.012) & (y > -0.06)))
    hair_m = hair * (0.75 + 0.25 * fbm3(p, 200, 33, 2))
    brow = head & front & (np.abs(ax - ex - 0.002) < 0.022) & (z > ez + 0.016) & (z < ez + 0.027 - 0.1 * (ax - ex) ** 2 * 30)
    lips = head * front * smooth(0.024 - ax, 0, 0.006) * (np.abs(z - (ez - 0.078)) < 0.008)
    socket = head * front * smooth(0.022 - np.hypot(ax - ex, z - ez), 0, 0.012)
    col = col * (1 - 0.30 * socket[:, None])
    col = col * (1 - 0.35 * lips[:, None] * 1.0) + srgb("8a4a42") * (0.35 * lips[:, None])
    beard = np.zeros(len(p))
    if variant == "Vijand":
        jaw = head & (z < ez - 0.05 - 0.02 * smooth(ax - 0.02, 0, 0.04)) & (z > ez - 0.14) & (y < 0.02) & (lips < 0.5)
        mous = head & front & (ax < 0.028) & (np.abs(z - (ez - 0.065)) < 0.006)
        beard = (jaw | mous) * (0.35 + 0.25 * fbm3(p, 150, 3, 2))
    else:
        jaw = head & (z < ez - 0.04) & (z > ez - 0.13) & (y < 0.02) & (lips < 0.5)
        beard = jaw * 0.12 * (0.6 + 0.4 * fbm3(p, 150, 3, 2))           # stoppels
    hm = np.clip(hair_m + brow * 0.9 + beard, 0, 1)
    col = col * (1 - hm[:, None] * 0.85) + hair_col * (hm[:, None] * 0.85)
    if variant == "Uniform":    # camouflageverf op het gezicht
        paint = head & front & (z < ez + 0.04) & (z > ez - 0.12)
        st = smooth(np.sin((z * 1.0 + ax * 0.6) * 140 + fbm3(p, 30, 8, 2) * 4), 0.2, 0.6)
        m = paint * st * 0.35 * smooth(ax - 0.035, 0, 0.02)
        col = col * (1 - m[:, None]) + srgb("3a4428") * m[:, None]
        m2 = paint * smooth(0.016 - np.abs(z - ez + 0.004), 0, 0.01) * 0.35
        col = col * (1 - m2[:, None]) + srgb("1d1f19") * m2[:, None]
    # vuil en zweet op de huid
    grime = smooth(fbm3(p, 9.0, 55, 3), 0.58, 0.8) * 0.22 * (1 - 0.8 * head)
    col = col * (1 - grime[:, None]) + srgb("5a4a35") * (grime[:, None] * 0.7)
    knuck = smooth(0.02 - np.abs(ax - 0.83), 0, 0.02) * (n[:, 2] > 0.4) * (z > 1.25)
    col = col * (1 - 0.1 * knuck[:, None]) + srgb("a05a48") * (0.1 * knuck[:, None])
    h = g * 0.15 + hair * fbm3(p, 300, 7, 1) * 0.5 + beard * 0.3
    rough = np.clip(0.55 - 0.1 * smooth(fbm3(p, 12, 66, 2), 0.5, 0.7) + 0.3 * hm, 0.35, 0.95)
    return col, h, rough


def eye(p, n, eyes):
    el, er = eyes
    c = np.where((p[:, 0] > 0)[:, None], el[None, :], er[None, :])
    d = p - c
    d /= np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    f = -d[:, 1]
    col = np.tile(srgb("cfc6b8"), (len(p), 1))
    iris = smooth(f - 0.86, 0, 0.02)
    pupil = smooth(f - 0.965, 0, 0.01)
    col = col * (1 - iris[:, None]) + srgb("4a3424") * iris[:, None]
    col = col * (1 - pupil[:, None]) + srgb("0c0a09") * pupil[:, None]
    return col, np.zeros(len(p)), np.full(len(p), 0.15)
