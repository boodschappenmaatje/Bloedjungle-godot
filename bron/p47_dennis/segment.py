"""Leest Dennis' P-47-GLB (één samengesmolten mesh, 500k driehoeken) met numpy en verdeelt de driehoeken in onderdelen.

Bronassen (glTF): neus = -x, boven = +y, spanwijdte = z. De scan staat in grondhouding (neus 8,3 graden omhoog); we draaien het toestel
om de naaf zodat de motoras horizontaal ligt (Q-coördinaten: naaf in de oorsprong, neus = -x). Alle grenzen hieronder zijn in Q gemeten
(rasterbeelden van de puntenwolk; de scharnierlijnen van roer, elevators en rolroeren zijn in de scan als sleuf zichtbaar)."""
import json, struct
import numpy as np

TILT_DEG = 8.3
NAAF = np.array([-0.784, 0.1095, 0.0])
CG_Q = np.array([0.52, -0.02, 0.0])        # nieuwe oorsprong (zwaartepunt) in Q
SCHAAL = 12.44 / 1.9026                    # model-eenheden -> meter (spanwijdte van de echte P-47D: 12,44 m)
DELEN = ["Body", "Propeller", "Spinner", "Roer", "ElevatorR", "ElevatorL", "AileronR", "AileronL", "GearR", "GearL", "GearStaart"]   # R = +X in Blender (qz < 0), L = -X (qz > 0)


def lees_glb(pad):
    d = open(pad, "rb").read()
    L = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + L])
    b = d[20 + L + 8:]

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        ct = {5126: "f4", 5125: "u4", 5123: "u2"}[a["componentType"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
        s = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        x = np.frombuffer(b, dtype=ct, count=a["count"] * n, offset=s)
        return x.reshape(-1, n) if n > 1 else x
    p = j["meshes"][0]["primitives"][0]
    imgs = []
    for im in j["images"]:
        bv = j["bufferViews"][im["bufferView"]]
        o = bv.get("byteOffset", 0)
        imgs.append(bytes(b[o:o + bv["byteLength"]]))
    tex = j["textures"]
    mat = j["materials"][0]
    kleur = imgs[tex[mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    normaal = imgs[tex[mat["normalTexture"]["index"]]["source"]]
    return (acc(p["attributes"]["POSITION"]).astype(np.float64), acc(p["attributes"]["TEXCOORD_0"]).astype(np.float64),
            acc(p["indices"]).astype(np.int64).reshape(-1, 3), kleur, normaal)


def naar_q(P):
    a = np.radians(TILT_DEG)
    c, s = np.cos(a), np.sin(a)
    R = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    return (P - NAAF) @ R.T


def labels(Q, I):
    """Deel-index (uit DELEN) per driehoek, op de zwaartepunten van de driehoeken (Q-coördinaten)."""
    C = Q[I].mean(1)
    x, y, z = C[:, 0], C[:, 1], C[:, 2]
    az = np.abs(z)
    lab = np.zeros(len(I), np.int64)                       # 0 = Body
    r = np.hypot(y, z)
    # propeller: bladen en naaf vóór de motorkap; spinner = kleine straal rond de as
    prop = (x < 0.060) | ((x < 0.12) & (r > 0.205))
    lab[prop & (r >= 0.062)] = 1
    lab[prop & (r < 0.062)] = 2
    # staartvlakken: hinge op x = 1,535. Roer boven het horizontale vlak, elevators links/rechts
    staart = x > 1.535
    lab[staart & (y > -0.015) & (az < 0.06)] = 3
    elev = staart & (az > 0.03) & (y > -0.14) & (y < -0.0)
    lab[elev & (z < 0)] = 4   # R
    lab[elev & (z > 0)] = 5   # L
    # rolroeren: achter de scharnierlijn (rijgt van x=0,62 bij z=0,83 naar x=0,695 bij z=0,50), buitenste vleugel
    hx = 0.62 + (0.83 - az) * (0.075 / 0.33)
    ail = (az > 0.50) & (x > hx + 0.004) & (x < 1.0) & (y > -0.2) & (y < 0.05)
    lab[ail & (z < 0)] = 6   # R
    lab[ail & (z > 0)] = 7   # L
    # hoofdgestel: poot en wiel onder de vleugel
    gear = (x > 0.28) & (x < 0.50) & (az > 0.28) & (az < 0.44) & (y < -0.13)
    gear |= (x > 0.40) & (x < 0.47) & (az > 0.33) & (az < 0.40) & (y < -0.075) & (y >= -0.13)
    lab[gear & (z < 0)] = 8   # R
    lab[gear & (z > 0)] = 9   # L
    # staartwiel
    lab[(x > 1.25) & (x < 1.50) & (y < -0.15) & (az < 0.05)] = 10
    return lab


def bouw_b(P):
    """Q -> Blender-meters: voorkant +Y, boven +Z, oorsprong in het zwaartepunt. B = s * (-qz, -qx, qy)."""
    q = P - CG_Q
    return SCHAAL * np.stack([-q[:, 2], -q[:, 0], q[:, 1]], axis=1)
