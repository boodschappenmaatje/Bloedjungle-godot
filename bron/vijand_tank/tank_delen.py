"""Indeling van Dennis' Meshy-tank (Tiger I, olijfgroen met gele tekens, 5,3 miljoen driehoeken) in bewegende delen.
Gedeeld door de stappen 1 t/m 4. Alle getallen zijn gemeten aan de bron (plots van de hoekpunten, cirkels gefit aan de wielen,
rupsbaan in baan.json door meet_baan.py).
Bronassen (Blender na glTF-import): X = lengte (voorkant = -X), Y = breedte, Z = omhoog, in eenheden van het bronmodel (1,90 lang).
Na `naar_spel()`: voorkant = +Y (wordt -Z in Godot), X = breedte, op ware grootte in meters (ca. 8,0 m met kanon)."""
import json
from pathlib import Path
import numpy as np

SCHAAL = 4.2            # bronmodel 1,90 -> 8,0 m met kanon
# wielassen in bronmaat: (x, z, labelstraal, naam). Buitenste rij en binnenste rij schuiven in elkaar; de rups loopt er buitenom
NAVEN = [
    (-0.196, -0.3554, 0.086, "w1"), (-0.103, -0.351, 0.084, "w2"), (-0.0114, -0.3554, 0.086, "w3"), (0.0885, -0.351, 0.084, "w4"),
    (0.186, -0.3554, 0.086, "w5"), (0.293, -0.351, 0.084, "w6"), (0.385, -0.3554, 0.086, "w7"), (0.489, -0.351, 0.084, "w8"),
    (0.5886, -0.3554, 0.086, "w9"),
    (-0.425, -0.303, 0.082, "aandrijf"), (0.7236, -0.2978, 0.080, "spanwiel"),
]
BUITEN = ("w1", "w3", "w5", "w7", "w9")
BINNEN = ("w2", "w4", "w6", "w8")
# onderstel in spelmaat: naar het midden schuiven en de onderkant van de rupsen op y = 0 zetten (Blender-wortelknoop)
MIDDEN_Y = 0.617        # m
GROND_Z = 1.96          # m
TOREN_AS = (0.295, -0.012)      # x, z van de koepelkrans (bron)
TOREN_R = 0.375                 # straal van de koepel om de krans (bron)
KANON_X0 = -0.205               # het kanon begint voor de schild (bron-X, voorkant is -X)
KANON_Z0, KANON_HEL = 0.0649, 0.0529     # as van het kanon: z = Z0 + HEL * (-0,22 - x); de loop wijst 3 graden omhoog
ANTENNE = ((0.55, 0.62), (-0.26, -0.20), 0.275)     # (x-bereik, y-bereik, z-grens): de zweepantenne boven de koepel verdwijnt
# labels
ROMP, TOREN, KANON, ANT = 0, 1, 2, 9
RUPS_L, RUPS_R = 3, 4           # y < 0 = links (kijkend naar de voorkant)
WIEL0 = 10                      # links: 10 + naaf-index, rechts: 110 + naaf-index

_BAAN = json.loads((Path(__file__).resolve().parent / "baan.json").read_text())
BAAN_PUNTEN = np.array(_BAAN["punten"], np.float64)      # buitenrand van de rups (bron x, z), gesloten veelhoek
BAAN_LENGTE = float(_BAAN["lengte"])


def afstand_tot_baan(x, z, chunk=40000):
    """getekende afstand tot de buitenrand van de rups (bronmaat): negatief binnen de lus"""
    A = BAAN_PUNTEN
    B = np.roll(A, -1, axis=0)
    E = B - A
    L2 = (E ** 2).sum(1)
    ez = np.where(E[:, 1] == 0, 1e-12, E[:, 1])
    out = np.empty(len(x))
    for s in range(0, len(x), chunk):
        px = np.asarray(x[s:s + chunk], np.float64)[:, None]
        pz = np.asarray(z[s:s + chunk], np.float64)[:, None]
        t = np.clip(((px - A[:, 0]) * E[:, 0] + (pz - A[:, 1]) * E[:, 1]) / L2, 0.0, 1.0)
        dx = px - (A[:, 0] + t * E[:, 0])
        dz = pz - (A[:, 1] + t * E[:, 1])
        d = np.sqrt(dx * dx + dz * dz).min(1)
        kruis = ((A[:, 1] <= pz) & (B[:, 1] > pz)) | ((B[:, 1] <= pz) & (A[:, 1] > pz))
        xi = A[:, 0] + (pz - A[:, 1]) * E[:, 0] / ez
        binnen = ((kruis & (px < xi)).sum(1) % 2) == 1
        out[s:s + chunk] = np.where(binnen, -d, d)
    return out


def kanon_as(x):
    """z van de kanonas op bron-X x"""
    return KANON_Z0 + KANON_HEL * (-0.22 - x)


def indelen(c):
    """c: Nx3 zwaartepunten van de vlakken (bronmaat). Geeft een label per vlak."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    ay = np.abs(y)
    lab = np.zeros(len(c), np.int16)
    for i, (hx, hz, r, n) in enumerate(NAVEN):
        d = np.hypot(x - hx, z - hz)
        if n in BUITEN:
            band = ay > 0.34
        elif n in BINNEN:
            band = (ay > 0.27) & (ay <= 0.34)
        else:
            band = ay > 0.27
        m = (d < r) & band & (lab == 0)
        lab[m] = WIEL0 + i
        lab[m & (y > 0)] = WIEL0 + 100 + i
    ax = ANTENNE
    ant = (x > ax[0][0]) & (x < ax[0][1]) & (y > ax[1][0]) & (y < ax[1][1]) & (z > ax[2])
    lab[ant & (lab == 0)] = ANT
    rad = np.hypot(x - TOREN_AS[0], y)
    tur = (z > TOREN_AS[1]) & ((rad < TOREN_R) | ((x > -0.21) & (x < TOREN_AS[0]) & (ay < 0.235)) | ((x > 0.5) & (x < 0.72) & (ay < 0.23)))
    lab[tur & (lab == 0)] = TOREN
    kan = (x < KANON_X0) & (x > -1.0) & (ay < 0.06) & (np.abs(z - kanon_as(x)) < 0.06)
    lab[kan & (lab == 0)] = KANON
    kand = np.nonzero((lab == 0) & (ay > 0.222) & (ay < 0.42) & (z < -0.12))[0]
    if len(kand):
        dist = afstand_tot_baan(x[kand], z[kand])
        r = kand[(dist > -0.032) & (dist < 0.010)]
        lab[r] = RUPS_L
        lab[r[y[r] > 0]] = RUPS_R
    return lab


def naar_spel(co):
    """bronmaat (x,y,z) -> spelmaat in meters met voorkant +Y: (x',y',z') = (y, -x, z) * SCHAAL"""
    out = np.empty_like(co)
    out[:, 0] = co[:, 1] * SCHAAL
    out[:, 1] = -co[:, 0] * SCHAAL
    out[:, 2] = co[:, 2] * SCHAAL
    return out


def bron_matrix():
    """4x4 (rijen): ruwe glTF-import (Blender-assen, bronmaat) -> spelassen in meters (zelfde omzetting als naar_spel)"""
    k = SCHAAL
    return ((0, k, 0, 0), (-k, 0, 0, 0), (0, 0, k, 0), (0, 0, 0, 1))


BAK_RAY = 0.30
BAK_CAGE = 0.14
