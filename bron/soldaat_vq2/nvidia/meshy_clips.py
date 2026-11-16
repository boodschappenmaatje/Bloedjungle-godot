"""De NVIDIA-clips (clips.npz, DEF-skelet) omzetten naar het Meshy-speler-skelet (Mixamo) -> assets/nv_bewegingen_meshy.glb.

Draait zonder het NVIDIA-model:  python3 -I meshy_clips.py [viewer.glb]   (vanuit deze map; scipy + numpy nodig)
Zelfde methode als retarget.py: wereldrotatie-delta t.o.v. de rusthouding plus uitlijning van de botrichting.
De Meshy-speler staat in A-houding, ons DEF-skelet in T-houding; de uitlijning vangt dat op.
"""
import sys
from pathlib import Path as _P
sys.path.insert(0, str(_P(__file__).resolve().parent))
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as R
from gltf_skel import Glb
import retarget
from retarget import Skel, maak_uitlijning, zet_om
import bouw_glb

REPO = bouw_glb.REPO
MESHY = REPO / 'assets' / 'meshy_jungle_commando.glb'
UIT = REPO / 'assets' / 'nv_bewegingen_meshy.glb'
M = 'mixamorig:'
PAREN = [(d, M + m) for d, m in [
    ('DEF-hips', 'Hips'), ('DEF-spine001', 'Spine'), ('DEF-spine002', 'Spine1'), ('DEF-spine003', 'Spine2'),
    ('DEF-neck', 'Neck'), ('DEF-head', 'Head'),
    ('DEF-shoulderL', 'LeftShoulder'), ('DEF-upper_armL', 'LeftArm'), ('DEF-forearmL', 'LeftForeArm'), ('DEF-handL', 'LeftHand'),
    ('DEF-shoulderR', 'RightShoulder'), ('DEF-upper_armR', 'RightArm'), ('DEF-forearmR', 'RightForeArm'), ('DEF-handR', 'RightHand'),
    ('DEF-thighL', 'LeftUpLeg'), ('DEF-shinL', 'LeftLeg'), ('DEF-footL', 'LeftFoot'), ('DEF-toeL', 'LeftToeBase'),
    ('DEF-thighR', 'RightUpLeg'), ('DEF-shinR', 'RightLeg'), ('DEF-footR', 'RightFoot'), ('DEF-toeR', 'RightToeBase')]]
retarget.KIND.update({M + a: M + b for a, b in [
    ('Hips', 'Spine'), ('Spine', 'Spine1'), ('Spine1', 'Spine2'), ('Spine2', 'Neck'), ('Neck', 'Head'),
    ('LeftShoulder', 'LeftArm'), ('LeftArm', 'LeftForeArm'), ('LeftForeArm', 'LeftHand'), ('LeftHand', 'LeftHandMiddle4'),
    ('RightShoulder', 'RightArm'), ('RightArm', 'RightForeArm'), ('RightForeArm', 'RightHand'), ('RightHand', 'RightHandMiddle4'),
    ('LeftUpLeg', 'LeftLeg'), ('LeftLeg', 'LeftFoot'), ('LeftFoot', 'LeftToeBase'),
    ('RightUpLeg', 'RightLeg'), ('RightLeg', 'RightFoot'), ('RightFoot', 'RightToeBase')]})


def skel(path):
    g = Glb(str(path)); nodes = g.j['nodes']
    joints = g.j['skins'][0]['joints']; pos = {n: i for i, n in enumerate(joints)}
    par = [pos.get(g.parent.get(n), -1) for n in joints]
    rt, rq = [], []
    for n in joints:
        t, r, s = g.local_rest(n); rt.append(t); rq.append(r.as_quat())
    base = g.world_of(g.parent[joints[0]])
    return Skel([nodes[n]['name'] for n in joints], par, rt, rq, base), joints


def zet_clips():
    ons, _ = skel(bouw_glb.BRON)
    mes, joints = skel(MESHY)
    A = maak_uitlijning(ons, mes, PAREN)
    schaal = mes.rest_wp[mes.idx[M + 'Hips']][1] / ons.rest_wp[ons.idx['DEF-hips']][1]
    uit = {}
    for naam, (LT, LQ) in bouw_glb.laad_npz().items():
        lts, lqs = [], []
        for f in range(LT.shape[0]):
            lt, lr = zet_om(ons, mes, LT[f], R.from_quat(LQ[f]), PAREN, A, schaal)
            lts.append(lt); lqs.append(lr.as_quat())
        uit[naam] = (np.array(lts), np.array(lqs))
    return uit


if __name__ == '__main__':
    clips = zet_clips()
    print('geschreven:', bouw_glb.bouw(clips, uit=UIT, bron=MESHY, heup=M + 'Hips'))
    if len(sys.argv) > 1:
        print('viewer:', bouw_glb.bouw(clips, uit=Path(sys.argv[1]), bron=MESHY, met_mesh=True, heup=M + 'Hips'))
