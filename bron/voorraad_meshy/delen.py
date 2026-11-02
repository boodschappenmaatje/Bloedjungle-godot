"""Indeling van het Meshy-vrachtwagenmodel (Dennis, 3,73 miljoen driehoeken, één samengesmolten mesh) in bewegende delen.
Bronassen (Blender na glTF-import): X = lengte (voorkant = -X), Y = breedte (+Y = rechts, kijkend naar de voorkant), Z = omhoog, in bronmaat
(1,903 lang, grond op Z = -0,4795). `naar_spel` zet dat op ware grootte (SCHAAL) in het Godot-assenstelsel van bron/voorraad/vc.py
(Blender: x = breedte, -y = voorkant, z = omhoog; de glTF-export maakt daar +Z (voor) en +Y (omhoog) van), grond op z = 0."""
import numpy as np

SCHAAL = 3.5                 # bronmaat -> meter (1,903 -> 6,66 m, band 0,137 -> 0,48 m)
GROND = -0.4795              # Z van de grond in bronmaat
# wielassen (bronmaat): naam, X, Z, |Y| binnenkant, |Y| buitenkant, straal
WIELEN = [
    ("F", -0.722, -0.3425, 0.170, 0.268),     # voorwiel (enkel)
    ("M", 0.325, -0.3425, 0.130, 0.268),      # middenas (dubbel)
    ("R", 0.600, -0.3425, 0.130, 0.268),      # achteras (dubbel)
]
WIEL_R = 0.1365              # buitenstraal band (bronmaat)
WIEL_KNIP = 0.142            # alles binnen deze straal (en binnen de Y-band) hoort bij het wiel

# labels
BODY, KOLOM, GIEK, GIEKUIT, GRIJPER, KLAUW_LV, KLAUW_LA, KLAUW_RV, KLAUW_RA, LADING, WIEL = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 100
NAMEN = {BODY: "Body", KOLOM: "Kolom", GIEK: "Giek", GIEKUIT: "GiekUit", GRIJPER: "Grijper", KLAUW_LV: "Klauw_LV", KLAUW_LA: "Klauw_LA",
         KLAUW_RV: "Klauw_RV", KLAUW_RA: "Klauw_RA", LADING: "Lading"}
# draaipunten (bronmaat)
ZWENK_AS = (0.035, 0.0)      # X, Y van de verticale zwenkas van de kraan
GIEK_DRAAI = (0.115, 0.27)   # X, Z van het giekscharnier (as langs Y)
GIEK_SPLIT_X = 0.50          # de giek wordt hier doorgesneden: daarachter schuift hij uit
KLAUW_AS = (0.82, 0.0)       # X, Y van de verticale as van de grijper
KLAUW_SCHARNIER_Z = 0.235


KLAUW_ASPUNT = (0.829, -0.059)   # X, Y van de verticale as van de grijper (de grijper hangt 6 cm links van de gieklijn: zo is het bronmodel)
ARMEN = {KLAUW_LV: (118.5, 242.5), KLAUW_RV: (11.0, 118.5), KLAUW_LA: (-117.5, 11.0)}   # sectoren (graden, atan2(dy, dx)) rond de grijperas
ARM_HOEK = {KLAUW_LV: 170.0, KLAUW_RV: 67.0, KLAUW_LA: -45.0}                              # hart van elke arm (twee klauwen naast elkaar)


def indelen(c):
    """c: Nx3 zwaartepunten (bronmaat). Geeft een label per vlak (WIEL: 100 + as-index*2 + zijde)."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.zeros(len(c), np.int16)
    # ---- lading: alles in de laadbak boven de vloer (kisten en zakken; de vloer zelf blijft bij de romp)
    bak = (x > 0.115) & (x < 0.925) & (np.abs(y) < 0.268) & (z > -0.034) & (z < 0.10)
    lab[bak] = LADING
    # ---- kraan: kolom + cilinder + gieken + grijper (alles boven de zwenkplaat)
    lijn = 0.19 + 0.27 * (x - 0.17) - 0.03                      # onderkant van de giek (bronmaat)
    kolom = (x > -0.085) & (x < 0.17) & (np.abs(y) < 0.13) & (z > 0.012) & (z < 0.37)
    cilinder = (x >= 0.17) & (x < 0.34) & (np.abs(y) < 0.11) & (z > 0.10) & (z <= lijn)
    giek = (x >= 0.17) & (np.abs(y) < 0.11) & (z > lijn) & (z < 0.52) & (x < 0.99)
    klauw = (x > 0.60) & (x < 1.0) & (np.abs(y) < 0.24) & (z > 0.085) & (z < 0.36)
    lab[kolom | cilinder] = KOLOM
    lab[giek] = GIEK
    lab[giek & (x > GIEK_SPLIT_X)] = GIEKUIT
    lab[klauw & (z < 0.345)] = GRIJPER
    # klauwarmen: onder het scharnier, per sector rond de grijperas
    arm = klauw & (z < KLAUW_SCHARNIER_Z + 0.012)
    az = np.degrees(np.arctan2(y - KLAUW_ASPUNT[1], x - KLAUW_ASPUNT[0]))
    az2 = np.where(az < -117.5, az + 360.0, az)
    for l, (a0, a1) in ARMEN.items():
        sel = az2 if l != KLAUW_LA else az
        lab[arm & (sel >= a0) & (sel < a1)] = l
    # ---- wielen
    for i, (_, xc, zc, y0, y1) in enumerate(WIELEN):
        d = np.hypot(x - xc, z - zc)
        m = (d < WIEL_KNIP) & (np.abs(y) > y0) & (np.abs(y) < y1)
        lab[m] = WIEL + i * 2 + (y > 0).astype(np.int16)[m]
    return lab


def naar_spel(co):
    """bronmaat (x,y,z) -> spelmaat in meter, Blender-assen van vc.py: x' = -y (rechts = -x), y' = x (voorkant = -y), z' = z - GROND."""
    out = np.empty_like(co)
    out[:, 0] = -co[:, 1] * SCHAAL
    out[:, 1] = co[:, 0] * SCHAAL
    out[:, 2] = (co[:, 2] - GROND) * SCHAAL
    return out
