"""Indeling van Dennis' Meshy-module (opgevouwen veldhoofdkwartier: container met dakpanelen, schaarmast en schotel) in bewegende delen.
Bronassen (Blender na glTF-import, geschaald met SCHAAL naar meters): X = lengte, Y = breedte, Z = omhoog. De module ligt op de laadbak van de wagen
(voorkant van de wagen = -X van de module) en wordt bij het uitklappen een commandokern aan de achterkant van het hoofdkwartier.
`naar_spel`: spelassen (Blender: x = breedte, +y = voorkant, z = omhoog, onderkant z = 0)."""
import numpy as np

SCHAAL = 1.95
GROND = -0.5864 * 1.95        # Z van de onderkant van de container (geschaald)
DAK_Z = 0.58 * 1.95 / 2.5      # bovenkant van de container: alles daarboven is dakpaneel, mast of schotel
SCHOTEL_X = -1.90 * 1.95 / 2.5     # schotel links (bronassen x < dit) boven het dak
MAST_X = (-1.25 * 1.95 / 2.5, 0.95 * 1.95 / 2.5)
MAST_Y = 0.55 * 1.95 / 2.5
MAST_Z = 0.78 * 1.95 / 2.5
KERN, DAK_L, DAK_R, MAST, SCHOTEL = 0, 1, 2, 3, 4
NAMEN = {KERN: "Kern", DAK_L: "Dak_L", DAK_R: "Dak_R", MAST: "Mast", SCHOTEL: "Schotel"}


def indelen(c):
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.zeros(len(c), np.int16)
    boven = z > DAK_Z
    lab[boven & (y >= 0)] = DAK_L
    lab[boven & (y < 0)] = DAK_R
    lab[boven & (x > MAST_X[0]) & (x < MAST_X[1]) & (np.abs(y) < MAST_Y) & (z > MAST_Z)] = MAST
    lab[boven & (x < SCHOTEL_X) & (z > 0.70 * 1.95 / 2.5)] = SCHOTEL
    return lab


def bron_matrix():
    """ruwe glTF-import (Blender-assen, bronmaat) -> spelassen in meters. De module ligt met zijn lengte langs de wagen: bron-X wordt spel-y
    (voorkant van de wagen = +y, de schotel zit dus aan de voorkant, achter de cabine)."""
    k = SCHAAL
    return ((0, k, 0, 0), (-k, 0, 0, 0), (0, 0, k, -GROND), (0, 0, 0, 1))


BAK_RAY = 0.06
BAK_CAGE = 0.03


def naar_spel(co):
    out = np.empty_like(co)
    out[:, 0] = co[:, 1]
    out[:, 1] = -co[:, 0]
    out[:, 2] = co[:, 2] - GROND
    return out
