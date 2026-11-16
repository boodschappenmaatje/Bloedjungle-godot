"""Maakt de vijf basisbewegingen met MotionBricks vanuit onze eigen 'stil'-houding."""
import numpy as np, pickle
from scipy.spatial.transform import Rotation as R
from motionbricks_bron import *

clip = g.clip('stil')
STIL = [soma_pose(*sample_ons(clip, i / 30)) for i in range(4)]

def stil_op(dx=0.0, dz=0.0, yaw=0.0):
    return [soma_pose(*sample_ons(clip, 0.5), dx=dx, dz=dz, yaw=yaw)]

def verschuif(win, d):
    w = np.array(win).copy(); w[:, 0, 0] += d[0]; w[:, 0, 2] += d[1]; return w

def lange_gang(richting, v=1.7, n=6, tok=(14,)):
    """continu lopen in richting (x,z) zonder te draaien: eerst vanuit stil, daarna doorlopen met bewegende doelen."""
    r = np.array(richting, float)
    A = genereer(STIL, stil_op(dx=r[0] * v * 1.9, dz=r[1] * v * 1.9), tok)
    m = len(A) // 2; W = A[m - 2:m + 2]
    alles = [A[:m + 2]]; c = A[m - 2:m + 2]; pos = W[:, 0, [0, 2]].mean(0)
    for k in range(n):
        doel = verschuif(W, r * v * (50 / 30) * (k + 1))
        B = genereer(c, doel, tok); alles.append(B[4:]); c = B[-4:]
    return np.concatenate(alles)

def snelheid(M):
    p = M[:, 0, [0, 2]]; return np.linalg.norm(p[-1] - p[0]) / ((len(M) - 1) / 30)

res = {}
for naam, r, v in [('zij_links', (1, 0), 2.7), ('zij_rechts', (-1, 0), 2.7), ('terug', (0, -1), 2.2)]:
    M = lange_gang(r, v=v); res[naam] = M
    print(naam, len(M), 'frames', 'gem. snelheid', round(snelheid(M[30:]), 2))
res['draai_links'] = np.concatenate([genereer(STIL, stil_op(yaw=90)), ])
res['draai_rechts'] = genereer(STIL, stil_op(yaw=-90))
# stoppen: vanuit onze eigen loopcyclus ('lopen', 2,4 m/s op de plek -> met voortgang) naar stilstand
lopen = g.clip('lopen')
c = []
for i in range(4):
    t = 0.6 + i / 30; lt, lr = sample_ons(lopen, t)
    c.append(soma_pose(lt, lr, dz=2.4 * t))
res['stoppen_ctx'] = np.array(c)
res['stoppen_bron'] = genereer(c, stil_op(dz=2.4 * (0.6 + 3 / 30) + 1.3), (8, 9, 10, 11))
from pathlib import Path
pickle.dump(res, open(Path(__file__).resolve().parent / 'ruw.pkl', 'wb'))
