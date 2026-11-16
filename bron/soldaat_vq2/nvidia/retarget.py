"""Omzetten tussen het SOMA-skelet (NVIDIA) en ons soldatenskelet (DEF-*).
Beide: Y omhoog, gezicht +Z, links = +X, T-houding. Methode: wereldrotatie-delta t.o.v. rust,
plus per bot een uitlijning van de rust-botrichting."""
import numpy as np
from scipy.spatial.transform import Rotation as R

PAREN = [  # SOMA, ons
    ("Hips", "DEF-hips"), ("Spine1", "DEF-spine001"), ("Spine2", "DEF-spine002"), ("Chest", "DEF-spine003"),
    ("Neck1", "DEF-neck"), ("Head", "DEF-head"),
    ("LeftShoulder", "DEF-shoulderL"), ("LeftArm", "DEF-upper_armL"), ("LeftForeArm", "DEF-forearmL"), ("LeftHand", "DEF-handL"),
    ("RightShoulder", "DEF-shoulderR"), ("RightArm", "DEF-upper_armR"), ("RightForeArm", "DEF-forearmR"), ("RightHand", "DEF-handR"),
    ("LeftLeg", "DEF-thighL"), ("LeftShin", "DEF-shinL"), ("LeftFoot", "DEF-footL"), ("LeftToeBase", "DEF-toeL"),
    ("RightLeg", "DEF-thighR"), ("RightShin", "DEF-shinR"), ("RightFoot", "DEF-footR"), ("RightToeBase", "DEF-toeR"),
]
KIND = {  # kind om botrichting te bepalen
    "Hips": "Spine1", "Spine1": "Spine2", "Spine2": "Chest", "Chest": "Neck1", "Neck1": "Head",
    "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "LeftHandMiddle1",
    "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "RightHand": "RightHandMiddle1",
    "LeftLeg": "LeftShin", "LeftShin": "LeftFoot", "LeftFoot": "LeftToeBase",
    "RightLeg": "RightShin", "RightShin": "RightFoot", "RightFoot": "RightToeBase",
    "DEF-hips": "DEF-spine001", "DEF-spine001": "DEF-spine002", "DEF-spine002": "DEF-spine003", "DEF-spine003": "DEF-neck", "DEF-neck": "DEF-head",
    "DEF-shoulderL": "DEF-upper_armL", "DEF-upper_armL": "DEF-forearmL", "DEF-forearmL": "DEF-handL", "DEF-handL": "DEF-f_middle01L",
    "DEF-shoulderR": "DEF-upper_armR", "DEF-upper_armR": "DEF-forearmR", "DEF-forearmR": "DEF-handR", "DEF-handR": "DEF-f_middle01R",
    "DEF-thighL": "DEF-shinL", "DEF-shinL": "DEF-footL", "DEF-footL": "DEF-toeL",
    "DEF-thighR": "DEF-shinR", "DEF-shinR": "DEF-footR", "DEF-footR": "DEF-toeR",
}

class Skel:
    """names, parents (index of -1), rest_t (n,3), rest_r (R, n) lokaal; base: wereld-matrix boven de wortel."""
    def __init__(self, names, parents, rest_t, rest_q, base=np.eye(4), base_scale=1.0):
        self.names = list(names); self.idx = {n: i for i, n in enumerate(self.names)}
        self.parents = np.array(parents); self.rest_t = np.array(rest_t, float)
        self.rest_r = R.from_quat(np.array(rest_q, float)); self.base = base
        self.rest_wr, self.rest_wp = self.world(self.rest_t, self.rest_r)
    def world(self, lt, lr):
        n = len(self.names); wr = [None] * n; wp = np.zeros((n, 3))
        B = R.from_matrix(self.base[:3, :3]); bt = self.base[:3, 3]
        for i in range(n):
            p = self.parents[i]
            if p < 0: wr[i] = B * lr[i]; wp[i] = bt + B.apply(lt[i])
            else: wr[i] = wr[p] * lr[i]; wp[i] = wp[p] + wr[p].apply(lt[i])
        return wr, wp
    def local(self, wr, heup, heup_wp):
        """wereldrotaties -> lokaal; het heupgewricht krijgt translatie zodat het op heup_wp staat."""
        n = len(self.names); lr = []; lt = self.rest_t.copy()
        B = R.from_matrix(self.base[:3, :3]); bt = self.base[:3, 3]
        for i in range(n):
            p = self.parents[i]
            lr.append((B.inv() if p < 0 else wr[p].inv()) * wr[i])
        lr = R.concatenate(lr)
        wr0, wp0 = self.world(lt, lr)
        p = self.parents[heup]
        lt[heup] = (B.inv().apply(heup_wp - bt) if p < 0 else wr0[p].inv().apply(heup_wp - wp0[p]))
        return lt, lr

def _richting(sk, name):
    k = KIND.get(name)
    if k is None or k not in sk.idx: return None
    v = sk.rest_wp[sk.idx[k]] - sk.rest_wp[sk.idx[name]]
    return v / np.linalg.norm(v)

def maak_uitlijning(src, tgt, paren):
    A = {}
    for s, t in paren:
        a, b = _richting(src, s), _richting(tgt, t)
        A[(s, t)] = R.identity() if a is None or b is None else R.align_vectors([a], [b])[0]
    return A

def zet_om(src, tgt, src_lt, src_lr, paren, A, schaal):
    """één houding van src naar tgt. paren = [(src_naam, tgt_naam)]. Geeft (lt, lr) van tgt."""
    wr_s, wp_s = src.world(src_lt, src_lr)
    wr_t = list(tgt.rest_wr)  # tijdelijk, daarna niet-gekoppelde opnieuw via ouder
    gezet = {}
    for s, t in paren:
        i, j = src.idx[s], tgt.idx[t]
        gezet[j] = wr_s[i] * src.rest_wr[i].inv() * A[(s, t)] * tgt.rest_wr[j]
    for j in range(len(tgt.names)):
        if j in gezet: wr_t[j] = gezet[j]
        else:
            p = tgt.parents[j]
            wr_t[j] = (R.from_matrix(tgt.base[:3, :3]) if p < 0 else wr_t[p]) * tgt.rest_r[j]
    hs, ht = src.idx[paren[0][0]], tgt.idx[paren[0][1]]
    heup = tgt.rest_wp[ht] + (wp_s[hs] - src.rest_wp[hs]) * schaal
    return tgt.local(wr_t, ht, heup)
