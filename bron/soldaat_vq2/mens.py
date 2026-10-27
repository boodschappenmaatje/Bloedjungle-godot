"""MakeHuman/MPFB2-basismens (CC0) passend gemaakt op het bestaande DEF-skelet van assets/soldaat.glb.

Geen Blender-afhankelijkheid: alleen numpy. Levert hoekpunten in de rustruimte van het skelet (meters, Z omhoog,
gezicht naar -Y), vlakken, UV's, groepsnamen per vlak en DEF-gewichten per hoekpunt.

Werkwijze:
1. base.obj inlezen (decimeters, Y omhoog) en de macro-targets (man, jong, gespierd) toepassen.
2. Gewrichten = midden van de MakeHuman-gewrichtskubussen; het game_engine-skelet van MPFB2 geeft de botten.
3. Elk MakeHuman-bot wordt met een eigen affiene afbeelding (kleinste draaiing + lengteschaal langs het bot)
   op het overeenkomstige DEF-bot gelegd; hoekpunten volgen met de MPFB2-huidgewichten (linear blend).
   Zo gaat de A-houding naar de T-houding van het DEF-skelet en vallen ellebogen/knieen op de DEF-gewrichten.
"""
import gzip
import json
from pathlib import Path

import numpy as np

# MakeHuman game_engine-bot -> DEF-bot van het soldaatskelet
BONE_MAP = {
    "pelvis": "DEF-hips", "spine_01": "DEF-spine001", "spine_02": "DEF-spine002", "spine_03": "DEF-spine003",
    "neck_01": "DEF-neck", "head": "DEF-head",
}
for s, S in (("l", "L"), ("r", "R")):
    BONE_MAP.update({
        f"clavicle_{s}": f"DEF-shoulder{S}", f"upperarm_{s}": f"DEF-upper_arm{S}", f"lowerarm_{s}": f"DEF-forearm{S}",
        f"hand_{s}": f"DEF-hand{S}", f"thigh_{s}": f"DEF-thigh{S}", f"calf_{s}": f"DEF-shin{S}",
        f"foot_{s}": f"DEF-foot{S}", f"ball_{s}": f"DEF-toe{S}",
    })
    for f in ("index", "middle", "ring", "pinky", "thumb"):
        for i in (1, 2, 3):
            BONE_MAP[f"{f}_0{i}_{s}"] = (f"DEF-thumb0{i}{S}" if f == "thumb" else f"DEF-f_{f}0{i}{S}")


TRUNK = {"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"}


def read_obj(path):
    verts, uvs, faces = [], [], []
    group = ""
    with open(path) as fh:
        for line in fh:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                uvs.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("g "):
                group = line.split()[1]
            elif line.startswith("f "):
                vi, ti = [], []
                for tok in line.split()[1:]:
                    p = tok.split("/")
                    vi.append(int(p[0]) - 1)
                    ti.append(int(p[1]) - 1 if len(p) > 1 and p[1] else -1)
                faces.append((vi, ti, group))
    return np.array(verts, dtype=np.float64), np.array(uvs, dtype=np.float64), faces


def read_target(path):
    idx, delta = [], []
    with gzip.open(path, "rt") as fh:
        for line in fh:
            p = line.split()
            if len(p) == 4 and not line.startswith("#"):
                idx.append(int(p[0]))
                delta.append([float(x) for x in p[1:]])
    return np.array(idx, dtype=np.int64), np.array(delta, dtype=np.float64)


def _ranges(meta, name):
    out = []
    for a, b in meta.get(name, []):
        out.extend(range(a, b + 1))
    return np.array(out, dtype=np.int64)


def build(data: Path, muscle=0.8, weight=0.55, race=(0.55, 0.15, 0.30), proportions=0.6):
    """race = (caucasian, african, asian)."""
    data = Path(data)
    V, UV, faces = read_obj(data / "3dobjs/base.obj")
    meta = json.loads((data / "mesh_metadata/basemesh_vertex_groups.json").read_text())
    tg = data / "targets/macrodetails"

    def lvl(v, names):  # MakeHuman-macro: lineair tussen min/gemiddeld/max
        if v < 0.5:
            return {names[0]: 1 - 2 * v, names[1]: 2 * v}
        return {names[1]: 2 - 2 * v, names[2]: 2 * v - 1}
    mus = lvl(muscle, ("minmuscle", "averagemuscle", "maxmuscle"))
    wei = lvl(weight, ("minweight", "averageweight", "maxweight"))
    applied = []
    for m, wm in mus.items():
        for w, ww in wei.items():
            k = wm * ww
            if k > 1e-6:
                applied.append((tg / f"universal-male-young-{m}-{w}.target.gz", k))
                applied.append((tg / f"proportions/male-young-{m}-{w}-idealproportions.target.gz", k * proportions))
    for name, k in zip(("caucasian", "african", "asian"), race):
        if k > 0:
            applied.append((tg / f"{name}-male-young.target.gz", k))
    for path, k in applied:
        idx, d = read_target(path)
        if len(idx):
            V[idx] += d * k

    # decimeters, Y omhoog, gezicht +Z  ->  meters, Z omhoog, gezicht -Y (Blender/DEF-rustruimte)
    P = np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1) * 0.1

    def joint(name):
        return P[_ranges(meta, name)].mean(axis=0)

    rig = json.loads((data / "rigs/standard/rig.game_engine.json").read_text())

    def end(spec):
        if spec["strategy"] == "CUBE":
            return joint(spec["cube_name"])
        return P[spec["vertex_indices"]].mean(axis=0)
    bones = {b: (end(d["head"]), end(d["tail"])) for b, d in rig.items()}
    wj = json.loads((data / "rigs/standard/weights.game_engine.json").read_text())["weights"]
    return dict(P=P, UV=UV, faces=faces, meta=meta, bones=bones, weights=wj,
                targets=[(str(p.relative_to(data)), round(k, 4)) for p, k in applied])


def _rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = np.cross(a, [1, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0, 1, 0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx / (1 + c)


def fit(h, def_bones, n_verts_body):
    """def_bones: {naam: (head, tail)} in rustruimte. Geeft hoekpunten in DEF-ruimte + DEF-gewichtenmatrix."""
    P, bones = h["P"], h["bones"]
    # 1. uniforme schaal: hoogte van het hoofdgewricht boven de vloer
    floor = P[:n_verts_body, 2].min()
    s = (def_bones["DEF-head"][0][2] - 0.0) / (bones["head"][0][2] - floor)
    off = np.array([0, 0, -floor])

    def norm_pt(p):
        return (np.asarray(p) + off) * s
    Pn = norm_pt(P)
    nb = {b: (norm_pt(a), norm_pt(t)) for b, (a, t) in bones.items()}

    names = [b for b in BONE_MAP]
    mats = []
    for b in names:
        ha, ta = nb[b]
        hb, tb = (np.asarray(x, dtype=np.float64) for x in def_bones[BONE_MAP[b]])
        if b in TRUNK:
            # romp en hoofd staan al rechtop en vallen binnen ~2 cm samen; andere botindeling, dus niet per bot rekken
            mats.append((np.eye(3), np.zeros(3)))
            continue
        da, db = ta - ha, tb - hb
        R = _rot_between(da, db)
        u = da / np.linalg.norm(da)
        ratio = np.linalg.norm(db) / np.linalg.norm(da)
        S = np.eye(3) + (ratio - 1) * np.outer(u, u)   # alleen langs het bot rekken
        A = R @ S
        mats.append((A, hb - A @ ha))
    nv = len(Pn)
    W = np.zeros((nv, len(names)))
    for j, b in enumerate(names):
        for vi, w in h["weights"].get(b, []):
            if vi < nv:
                W[vi, j] = w
    tot = W.sum(axis=1)
    # hoekpunten zonder gewicht (hulpgeometrie) krijgen het gewicht van de dichtstbijzijnde gewogen buur
    missing = np.where(tot < 1e-6)[0]
    if len(missing):
        have = np.where(tot >= 1e-6)[0]
        for i in range(0, len(missing), 512):
            chunk = missing[i:i + 512]
            d = ((Pn[chunk, None, :] - Pn[None, have, :]) ** 2).sum(axis=2)
            W[chunk] = W[have[d.argmin(axis=1)]]
        tot = W.sum(axis=1)
    W /= tot[:, None]
    out = np.zeros_like(Pn)
    for j, (A, t) in enumerate(mats):
        out += W[:, j:j + 1] * (Pn @ A.T + t)
    return out, W, [BONE_MAP[b] for b in names], s
