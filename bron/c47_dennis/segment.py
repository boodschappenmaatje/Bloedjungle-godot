"""Leest Dennis' C-47-GLB (Skytrain, 277.780 driehoeken, één scan-mesh van ~650 losse stukjes, geen onderdelen, geen animaties) met numpy en
verdeelt de driehoeken in bewegende onderdelen. glTF-assen van de bron: neus = -x, boven = +y, spanwijdte = z (bakboord/links = +z).
Alle grenzen zijn gemeten op rasterbeelden van de puntenwolk en renders van de bron (deurkozijn met scharnieren, scharnierlijnen van
roer en hoogteroer, propellerbladen vóór de motorkap). Blender-meters: B = S * (-z, -(x - cx), y - cy), voorkant = +Y."""
import json, struct
import numpy as np

SCHAAL = 15.0            # model-eenheden -> meter (spanwijdte 1,906 -> 28,6 m; echte C-47: 29,1 m)
CG = np.array([0.0, -0.005, 0.0])
DELEN = ["Body", "PropL", "PropR", "Deur", "Roer", "Elev"]
# naaf (kegelpunt van de spinner) per motor; L = bakboord (+z). De rechtermotor staat in de scan 0,028 verder naar voren.
NAAF = {"L": np.array([-0.562, -0.0127, 0.2012]), "R": np.array([-0.590, -0.040, -0.2031])}
PROP_X = {"L": -0.522, "R": -0.550}        # achter deze x begint de motorkap
PROP_R = 0.17
DEUR = dict(x=(0.0815, 0.1625), y=(-0.096, 0.034))     # kozijn van de laaddeur (bakboord), met scharnieren op de achterrand
ROER_X = 0.554
ELEV_X = 0.592


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
    pm = mat["pbrMetallicRoughness"]
    kleur = imgs[tex[pm["baseColorTexture"]["index"]]["source"]]
    mr = imgs[tex[pm["metallicRoughnessTexture"]["index"]]["source"]]
    normaal = imgs[tex[mat["normalTexture"]["index"]]["source"]]
    return (acc(p["attributes"]["POSITION"]).astype(np.float64), acc(p["attributes"]["TEXCOORD_0"]).astype(np.float64),
            acc(p["indices"]).astype(np.int64).reshape(-1, 3), kleur, mr, normaal)


def componenten(P, I):
    """Losse stukjes van de scan (verbonden hoekpunten): de neuskegel van de romp bestaat uit zulke stukjes."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    n = len(P)
    g = coo_matrix((np.ones(2 * len(I)), (np.concatenate([I[:, 0], I[:, 1]]), np.concatenate([I[:, 1], I[:, 2]]))), shape=(n, n))
    return connected_components(g, directed=False)[1]


def labels(P, I):
    comp = componenten(P, I)
    tl = comp[I[:, 0]]
    neus = np.zeros(comp.max() + 1, bool)
    for c in np.unique(tl):
        V = P[comp == c]
        if np.abs(V[:, 2]).max() < 0.09 and V[:, 0].min() < -0.46:
            neus[c] = True
    nt = neus[tl]
    C = P[I].mean(1)
    x, y, z = C[:, 0], C[:, 1], C[:, 2]
    lab = np.zeros(len(I), np.int64)
    for k, tag in ((1, "L"), (2, "R")):
        h = NAAF[tag]
        r = np.hypot(y - h[1], z - h[2])
        zij = (z > 0) if tag == "L" else (z < 0)
        lab[zij & (x < PROP_X[tag]) & (r < PROP_R) & ~nt] = k
    d = (x > DEUR["x"][0]) & (x < DEUR["x"][1]) & (y > DEUR["y"][0]) & (y < DEUR["y"][1]) & (z > 0.05) & (z < 0.125)
    lab[d & (lab == 0)] = 3
    lab[(x > ROER_X) & (np.abs(z) < 0.03) & (y > -0.05) & (lab == 0)] = 4
    lab[(x > ELEV_X) & (np.abs(z) > 0.05) & (y > -0.115) & (y < -0.03) & (lab == 0)] = 5
    return lab


def bouw_b(P):
    q = P - CG
    return SCHAAL * np.stack([-q[:, 2], -q[:, 0], q[:, 1]], axis=1)


def p2b(p):
    q = np.asarray(p, float) - CG
    return SCHAAL * np.array([-q[2], -q[0], q[1]])
