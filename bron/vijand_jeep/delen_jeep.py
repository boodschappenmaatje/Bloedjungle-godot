"""Indeling van Dennis' Meshy-jeep (open 4x4 met .50 MG, vijandversie) in bewegende delen.
Bronassen (Blender na glTF-import, geschaald met SCHAAL naar meters): X = lengte (voorkant = -X), Y = breedte, Z = omhoog, grond op Z = GROND.
`naar_spel` zet dat om naar de assen van het spel (Blender: x = breedte, +y = voorkant, z = omhoog, grond z = 0, oorsprong midden tussen de assen);
de glTF-export maakt daar -Z (voor) van. Alle getallen zijn gemeten aan de bron (plots van de hoekpunten, wielcirkels gefit)."""
import numpy as np

SCHAAL = 2.2105          # bronmaat -> meter: lengte 1,9 -> 4,2 m
GROND = -0.4755 * SCHAAL # Z van de grond (onderkant banden)
WIEL_R = 0.405           # buitenstraal band (m)
WIEL_Z = GROND + WIEL_R  # hoogte naafas
XV, XA = -0.615 * SCHAAL, 0.46 * SCHAAL     # voor- en achteras (bron-X)
X0 = (XV + XA) / 2.0                       # oorsprong in het spel: midden tussen de assen
ASSEN = [("V", XV, True), ("A", XA, False)]   # de voorwielen sturen
WIEL_Y0, WIEL_Y1 = 0.45, 1.02              # |Y| binnen- en buitenkant van de banden
# het MG (loop, huis, patronenband, draaikop) draait om de steunpaal; alles erboven telt mee
MG_Z0 = 0.20 * SCHAAL
MG_Y = 0.28 * SCHAAL
MG_X0, MG_X1 = -0.25 * SCHAAL, 0.65 * SCHAAL
MG_DRAAI = (0.322 * SCHAAL, 0.0, 0.239 * SCHAAL)    # draaipunt (bron-X, Y, Z)
MONDING = (-0.235 * SCHAAL, 0.0, 0.417 * SCHAAL)    # uiteinde van de loop

ROMP, MG, WIEL = 0, 1, 100


def indelen(c):
    """c: Nx3 zwaartepunten (geschaalde bronassen). Label per vlak (WIEL + as*2 + zijde, zijde 1 = Y > 0)."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.zeros(len(c), np.int16)
    for i, (_, xc, _s) in enumerate(ASSEN):
        d = np.hypot(x - xc, z - WIEL_Z)
        m = (d < WIEL_R + 0.02) & (np.abs(y) > WIEL_Y0) & (np.abs(y) < WIEL_Y1)
        lab[m] = WIEL + i * 2 + (y > 0).astype(np.int16)[m]
    mg = (z > MG_Z0) & (np.abs(y) < MG_Y) & (x > MG_X0) & (x < MG_X1)
    lab[mg & (lab == ROMP)] = MG
    return lab


def naar_spel(co):
    out = np.empty_like(co)
    out[:, 0] = co[:, 1]
    out[:, 1] = -(co[:, 0] - X0)
    out[:, 2] = co[:, 2] - GROND
    return out


def punt_naar_spel(p):
    return (p[1], -(p[0] - X0), p[2] - GROND)


def bron_matrix():
    """4x4 (rijen) van de ruwe glTF-import (Blender-assen, bronmaat) naar spelassen in meters."""
    k = SCHAAL
    return ((0, k, 0, 0), (-k, 0, 0, k * 0 + X0 * 1.0), (0, 0, k, -GROND), (0, 0, 0, 1))
BAK_RAY = 0.08
BAK_CAGE = 0.04
