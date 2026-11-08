"""Indeling van Dennis' Meshy-wagen (8x8 bouwwagen met dozerschild, lege laadbak) in bewegende delen.
Bronassen (Blender na glTF-import, geschaald met SCHAAL naar meters): X = lengte (voorkant = -X), Y = breedte, Z = omhoog, grond op Z = GROND.
`naar_spel` zet dat om naar de assen van het spel (Blender: x = breedte, +y = voorkant, z = omhoog, grond z = 0); de glTF-export maakt daar -Z (voor) van."""
import numpy as np

SCHAAL = 4.47            # bronmaat -> meter: lengte 1,9 -> 8,5 m
GROND = -1.361           # Z van de grond (geschaald)
WIEL_R = 0.55            # buitenstraal band (m)
WIEL_Z = GROND + WIEL_R  # hoogte naafas
# assen (X), van voor naar achter; de eerste twee sturen
ASSEN = [("A1", -2.31, True), ("A2", -0.62, True), ("A3", 1.65, False), ("A4", 2.99, False)]
WIEL_Y0, WIEL_Y1 = 0.62, 1.20     # |Y| binnen- en buitenkant van de banden
SCHILD_X = -3.88                  # alles voor dit punt hoort bij het dozerschild
SCHILD_DRAAI = (-3.60, -0.55)     # X, Z van het scharnier waar het schild omhoog klapt

ROMP, SCHILD, WIEL = 0, 1, 100


def indelen(c):
    """c: Nx3 zwaartepunten (geschaalde bronassen). Label per vlak (WIEL + as*2 + zijde, zijde 1 = Y > 0)."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.zeros(len(c), np.int16)
    lab[x < SCHILD_X] = SCHILD
    for i, (_, xc, _s) in enumerate(ASSEN):
        d = np.hypot(x - xc, z - WIEL_Z)
        m = (d < WIEL_R + 0.02) & (np.abs(y) > WIEL_Y0) & (np.abs(y) < WIEL_Y1)
        lab[m] = WIEL + i * 2 + (y > 0).astype(np.int16)[m]
    return lab


def naar_spel(co):
    out = np.empty_like(co)
    out[:, 0] = co[:, 1]
    out[:, 1] = -co[:, 0]
    out[:, 2] = co[:, 2] - GROND
    return out


def bron_matrix():
    """4x4 (rijen) van de ruwe glTF-import (Blender-assen, bronmaat) naar spelassen in meters."""
    k = SCHAAL
    return ((0, k, 0, 0), (-k, 0, 0, 0), (0, 0, k, -GROND), (0, 0, 0, 1))
BAK_RAY = 0.12
BAK_CAGE = 0.06
