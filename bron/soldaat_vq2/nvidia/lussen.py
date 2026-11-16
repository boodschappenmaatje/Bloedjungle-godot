"""Ruwe NVIDIA-beweging -> clips voor ons skelet: lus knippen, op de plek zetten, naad gladmaken."""
import numpy as np, pickle
from pathlib import Path
from scipy.spatial.transform import Rotation as R, Slerp
from motionbricks_bron import ONS, ons_uit_soma, SOMA

HEUP = ONS.idx['DEF-hips']
BENEN = [ONS.idx[n] for n in ['DEF-thighL', 'DEF-shinL', 'DEF-footL', 'DEF-thighR', 'DEF-shinR', 'DEF-footR', 'DEF-spine001', 'DEF-upper_armL', 'DEF-upper_armR']]

from motionbricks_bron import g, sample_ons
_STIL = sample_ons(g.clip('stil'), 0.5)[1].as_quat()
ARMEN = [i for i, n in enumerate(ONS.names) if n.endswith(('L', 'R')) and not any(x in n for x in ('thigh', 'shin', 'foot', 'toe'))]

def naar_ons(M, armen_stil=True):
    LT, LQ = [], []
    for f in M:
        lt, lr = ons_uit_soma(f); q = lr.as_quat()
        if armen_stil: q[ARMEN] = _STIL[ARMEN]
        LT.append(lt); LQ.append(q)
    LQ = np.array(LQ)
    for i in range(1, len(LQ)):   # quaternion-tekens doorlopend houden
        flip = (LQ[i] * LQ[i - 1]).sum(-1) < 0; LQ[i][flip] *= -1
    return np.array(LT), LQ

def heup_wereld(LT, LQ):
    out = []
    for lt, q in zip(LT, LQ):
        wr, wp = ONS.world(lt, R.from_quat(q)); out.append((wp[HEUP], wr[HEUP]))
    return out

def afstand(LQ, LT, i, j):
    d = 0.0
    for b in BENEN:
        d += (R.from_quat(LQ[i, b]).inv() * R.from_quat(LQ[j, b])).magnitude()
    return d + 5 * abs(LT[i, HEUP, 2] - LT[j, HEUP, 2])

def zoek_lus(LT, LQ, van, tot, minl=24, maxl=46):
    best = (1e9, 0, 0)
    for i in range(van, tot - minl):
        for j in range(i + minl, min(tot, i + maxl)):
            d = afstand(LQ, LT, i, j)
            if d < best[0]: best = (d, i, j)
    return best

def op_de_plek(LT, LQ, yaw_ook=False):
    """wereld-XZ van de heup -> alleen de schommeling rond een rechte lijn; optioneel ook de draaiing eruit."""
    LT = LT.copy(); LQ = LQ.copy(); F = len(LT)
    hw = heup_wereld(LT, LQ)
    P = np.array([p for p, _ in hw]); t = np.arange(F) / max(1, F - 1)
    lijn = P[0] + (P[-1] - P[0]) * t[:, None]
    for k in range(F):
        lt, q = LT[k], LQ[k]
        wr, wp = ONS.world(lt, R.from_quat(q))
        doel = wp[HEUP].copy(); doel[[0, 2]] = (P[k] - lijn[k])[[0, 2]] + ONS.rest_wp[HEUP][[0, 2]]
        nwr = list(wr)
        if yaw_ook:
            yaw0 = R.from_quat(LQ[0][0:1]) if False else None
            hy = [R.from_matrix(x.as_matrix()).as_euler('YXZ')[0] for _, x in hw]
            d = -(hy[0] + (hy[-1] - hy[0]) * t[k]) + hy[0]
            Y = R.from_euler('y', d)
            nwr = [Y * x for x in wr]
            doel = ONS.rest_wp[HEUP] + Y.apply(doel - ONS.rest_wp[HEUP])
        nlt, nlr = ONS.local(nwr, HEUP, doel)
        LT[k] = nlt; LQ[k] = nlr.as_quat()
    return LT, LQ

def naad(LT, LQ, n=5):
    """laatste n frames naar het eerste frame toe laten vloeien (lus zonder sprong)."""
    LT = LT.copy(); LQ = LQ.copy(); F = len(LT)
    for k in range(n):
        a = (k + 1) / (n + 1); i = F - n + k
        for b in range(LQ.shape[1]):
            LQ[i, b] = Slerp([0, 1], R.from_quat([LQ[i, b], LQ[0, b]]))([a]).as_quat()[0]
        LT[i] = LT[i] * (1 - a) + LT[0] * a
    return LT, LQ

def spiegel_soma(M):
    """links <-> rechts spiegelen in SOMA-ruimte (X spiegelen, Left*/Right* wisselen)."""
    M = np.array(M, float).copy(); namen = SOMA.names
    paar = [namen.index(n.replace('Left', 'Right')) if n.startswith('Left') else namen.index(n.replace('Right', 'Left')) if n.startswith('Right') else i for i, n in enumerate(namen)]
    M = M[:, paar]
    M[..., 0] *= -1; M[..., 4] *= -1; M[..., 5] *= -1
    return M

ROMP = [ONS.idx[n] for n in ['DEF-spine001', 'DEF-spine002', 'DEF-spine003', 'DEF-neck', 'DEF-head']]
_STIL_LT = sample_ons(g.clip('stil'), 0.5)[0]

def romp_als_stil(LT, LQ):
    """romp vast in de 'stil'-richting zetten (voor de gespiegelde clip, zodat het geweer de goede kant op wijst)."""
    swr, _ = ONS.world(_STIL_LT, R.from_quat(_STIL))
    S1 = ONS.idx['DEF-spine001']
    H = HEUP; TH = [ONS.idx['DEF-thighL'], ONS.idx['DEF-thighR']]
    yaw_s = swr[H].as_euler('YXZ')[0]
    for k in range(len(LT)):
        wr, _ = ONS.world(LT[k], R.from_quat(LQ[k]))
        # bekken halverwege tussen de gespiegelde benen en de 'stil'-romp draaien; benen houden hun richting
        d = angle = (yaw_s - wr[H].as_euler('YXZ')[0] + np.pi) % (2 * np.pi) - np.pi
        nh = R.from_euler('y', 0.5 * d) * wr[H]
        ph = ONS.parents[H]; LQ[k, H] = (wr[ph].inv() * nh).as_quat()
        for t in TH: LQ[k, t] = (nh.inv() * wr[t]).as_quat()
        wr, _ = ONS.world(LT[k], R.from_quat(LQ[k]))
        p = ONS.parents[S1]
        LQ[k, S1] = (wr[p].inv() * swr[S1]).as_quat()
        for b in ROMP[1:]: LQ[k, b] = _STIL[b]
    return LT, LQ

def spiegel_ons(LT, LQ):
    """links <-> rechts spiegelen via wereld-delta's t.o.v. rust (werkt ook als botassen niet symmetrisch zijn)."""
    namen = ONS.names
    paar = [namen.index(n[:-1] + ('R' if n.endswith('L') else 'L')) if n.startswith('DEF-') and n[-1] in 'LR' and (n[:-1] + ('R' if n.endswith('L') else 'L')) in namen else i for i, n in enumerate(namen)]
    m = lambda r: R.from_quat(r.as_quat() * np.array([1, -1, -1, 1]))
    NT, NQ = LT.copy(), LQ.copy()
    for k in range(len(LT)):
        wr, wp = ONS.world(LT[k], R.from_quat(LQ[k]))
        nwr = [None] * len(namen)
        for j in range(len(namen)):
            D = wr[j] * ONS.rest_wr[j].inv()
            nwr[paar[j]] = m(D) * ONS.rest_wr[paar[j]]
        hp = wp[HEUP].copy(); hp[0] = 2 * ONS.rest_wp[HEUP][0] - hp[0]
        lt, lr = ONS.local(nwr, HEUP, hp); NT[k] = lt; NQ[k] = lr.as_quat()
    return NT, NQ

if __name__ == '__main__':
    ruw = pickle.load(open(Path(__file__).resolve().parent / 'ruw.pkl', 'rb'))
    uit = {}
    for naam in ['zij_links', 'zij_rechts', 'terug']:
        if naam == 'zij_rechts':
            LT, LQ = naar_ons(ruw['zij_links'], armen_stil=False); LT, LQ = spiegel_ons(LT, LQ); LT, LQ = romp_als_stil(LT, LQ)
            LQ[:, ARMEN] = _STIL[ARMEN]
        else:
            LT, LQ = naar_ons(ruw[naam])
        d, i, j = zoek_lus(LT, LQ, 100, 290)
        p = [x for x, _ in heup_wereld(LT[i:j + 1], LQ[i:j + 1])]
        v = np.linalg.norm((p[-1] - p[0])[[0, 2]]) / ((j - i) / 30)
        lt, lq = op_de_plek(LT[i:j + 1], LQ[i:j + 1])
        lt, lq = naad(lt[:-1], lq[:-1])
        uit[naam] = (lt, lq, v); print(naam, 'lus', i, j, 'fout', round(d, 3), 'snelheid', round(v, 2), 'm/s')
    for naam in ['draai_links', 'draai_rechts']:
        LT, LQ = naar_ons(ruw[naam]); lt, lq = op_de_plek(LT, LQ, yaw_ook=True)
        uit[naam] = (lt, lq, 0.0); print(naam, len(lt))
    LT, LQ = naar_ons(ruw['stoppen_bron'])
    lt, lq = op_de_plek(LT, LQ)
    uit['stoppen'] = (lt, lq, 2.4); print('stoppen', len(lt))
    np.savez_compressed(Path(__file__).resolve().parent / 'clips.npz', namen=np.array(list(uit)),
                        snelheid=np.array([uit[k][2] for k in uit]),
                        **{k + '_t': v[0].astype(np.float32) for k, v in uit.items()},
                        **{k + '_q': v[1].astype(np.float32) for k, v in uit.items()})
    print('clips.npz geschreven')
