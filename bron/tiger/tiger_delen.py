"""Indeling van de Tiger-bron (Meshy, 2,2 miljoen hoekpunten) in bewegende delen. Gedeeld door de stappen van maak_tiger.py.
Bron-assen (Blender na import): X = lengte (voorkant = -X), Y = breedte, Z = omhoog, in eenheden van het bronmodel (1,905 lang).
Na `naar_spel()`: voorkant = +Y (wordt -Z in Godot), X = breedte, op ware grootte in meters (Tiger I: ~8,45 m met kanon)."""
import numpy as np

SCHAAL = 4.435          # bronmodel 1,905 -> 8,45 m (ware lengte met kanon)
# wielassen in bronmaat: (x, z, straal, naam). Buitenste rij (rubberen velgen) en binnenste rij schuiven in elkaar
NAVEN = [
    (-0.217, -0.236, 0.090, "w1"), (-0.110, -0.236, 0.090, "w2"), (0.020, -0.236, 0.090, "w3"), (0.143, -0.236, 0.090, "w4"),
    (0.263, -0.236, 0.090, "w5"), (0.385, -0.236, 0.090, "w6"), (0.506, -0.236, 0.090, "w7"), (0.648, -0.236, 0.090, "w8"),
    (-0.390, -0.176, 0.083, "aandrijf"), (0.783, -0.206, 0.065, "spanwiel"),
]
BUITEN = ("w1", "w3", "w5", "w7")
BINNEN = ("w2", "w4", "w6", "w8")
# onderstel (romp + rupsen) in spelmaat: x ±1,95 | y van -4,2 (achter) tot +2,35 (voor) | z van -1,57 (grond) tot +0,7
MIDDEN_Y = 0.93         # m: onderstel naar het midden schuiven (anders ligt de oorsprong ver achter het midden)
GROND_Z = 1.57          # m: onderkant rupsen op y = 0 zetten
TOREN_AS = (0.184, 0.098)       # x, z van het torenlager (bron)
LOOP_AS = (-0.12, 0.217)        # x, z van de kanonsteunen (bron)
# labels
ROMP, TOREN, KANON = 0, 1, 2
RUPS_L, RUPS_R = 3, 4           # y < 0 = links (kijkend naar de voorkant)
WIEL0 = 10                      # links: 10 + naaf-index, rechts: 110 + naaf-index


# baan van de rupsband (bronmaat): bolle omhullende van cirkels om aandrijfwiel, spanwiel en de onderste wielen
BAAN_STRAAL = {"aandrijf": 0.098, "spanwiel": 0.085, "w": 0.116}


def baan_polygon():
    """bolle veelhoek (x, z) tegen de klok in; geeft ook de naaf-cirkels terug"""
    pts = []
    for hx, hz, r, n in NAVEN:
        rr = BAAN_STRAAL.get(n, BAAN_STRAAL["w"])
        if n.startswith("w") and n not in ("w1", "w3", "w5", "w7"):
            continue
        for a in np.linspace(0, 2 * np.pi, 72, endpoint=False):
            pts.append((hx + rr * np.cos(a), hz + rr * np.sin(a)))
    pts = sorted(set((round(x, 5), round(z, 5)) for x, z in pts))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return np.array(lo[:-1] + up[:-1])


def afstand_tot_baan(x, z, poly):
    """getekende afstand tot de bolle veelhoek: negatief binnen"""
    best = np.full(len(x), -1e9)
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        e = b - a
        nor = np.array([e[1], -e[0]]) / np.hypot(*e)       # naar buiten bij tegen-de-klok-in
        best = np.maximum(best, (x - a[0]) * nor[0] + (z - a[1]) * nor[1])
    return best


def indelen(c):
    """c: Nx3 zwaartepunten van de vlakken (bronmaat). Geeft een label per vlak."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    ay = np.abs(y)
    lab = np.zeros(len(c), np.int16)
    for i, (hx, hz, r, n) in enumerate(NAVEN):
        d = np.hypot(x - hx, z - hz)
        if n in BUITEN:
            band = ay > 0.335
        elif n in BINNEN:
            band = (ay > 0.20) & (ay <= 0.335)
        else:
            band = ay > 0.2
        m = (d < r) & band
        lab[m] = WIEL0 + i
        lab[m & (y > 0)] = WIEL0 + 100 + i
    rad = np.hypot(x - TOREN_AS[0], y)
    tur = (z > TOREN_AS[1]) & ((rad < 0.335) | ((x < 0.184) & (x > -0.16) & (ay < 0.26)) | ((x > 0.38) & (x < 0.62) & (ay < 0.16)))
    lab[tur & (lab == 0)] = TOREN
    lab[(x < -0.14) & (ay < 0.065) & (z > 0.14) & (z < 0.30)] = KANON
    dist = afstand_tot_baan(x, z, baan_polygon())
    rups = (lab == 0) & (ay > 0.25) & (dist > -0.05) & (dist < 0.015)
    lab[rups] = RUPS_L
    lab[rups & (y > 0)] = RUPS_R
    return lab


def naar_spel(co):
    """bronmaat (x,y,z) -> spelmaat in meters met voorkant +Y: (x',y',z') = (y, -x, z) * SCHAAL"""
    out = np.empty_like(co)
    out[:, 0] = co[:, 1] * SCHAAL
    out[:, 1] = -co[:, 0] * SCHAAL
    out[:, 2] = co[:, 2] * SCHAAL
    return out
