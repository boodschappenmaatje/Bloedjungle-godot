"""Indeling van Dennis' Meshy-steunpoot (hydraulische poot met voetplaat, schuin) in twee delen: buitenbuis met kop (PootBoven, zit vast aan de wagen)
en binnenbuis met voetplaat (PootOnder, schuift uit langs de lijn van de poot).
Bronassen (Blender na glTF-import, geschaald met SCHAAL): X = leunrichting (voet naar +X, kop naar -X), Y = breedte, Z = omhoog.
`naar_spel` zet de onderkant op z = 0 en laat de assen staan: voor een poot aan de rechterkant van de wagen wijst +x naar buiten."""
import numpy as np

SCHAAL = 0.8
GROND = -0.762                     # Z van de onderkant van de voetplaat (geschaald)
VOET = np.array([0.30, -0.72])     # (x, z) midden van de voet
KOP = np.array([-0.45, 0.55])      # (x, z) bovenkant van de kop
AS = (KOP - VOET) / np.linalg.norm(KOP - VOET)
NAAD = 0.64                        # afstand langs de as (vanaf de voet) waar de binnenbuis in de buitenbuis zit
BOVEN, ONDER = 0, 1
NAMEN = {BOVEN: "PootBoven", ONDER: "PootOnder"}


def indelen(c):
    s = (c[:, 0] - VOET[0]) * AS[0] + (c[:, 2] - VOET[1]) * AS[1]
    lab = np.where(s > NAAD, BOVEN, ONDER).astype(np.int16)
    return lab


def naar_spel(co):
    out = np.array(co, np.float32)
    out[:, 2] -= GROND
    return out


def bron_matrix():
    k = SCHAAL
    return ((k, 0, 0, 0), (0, k, 0, 0), (0, 0, k, -GROND), (0, 0, 0, 1))


BAK_RAY = 0.03
BAK_CAGE = 0.015
