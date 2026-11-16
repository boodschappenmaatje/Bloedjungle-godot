"""NVIDIA MotionBricks op de CPU, aangestuurd met ONZE soldatenhoudingen (zie README.md)."""
import sys, json, struct, math
import cpu_shim
import numpy as np, warp as wp
from scipy.spatial.transform import Rotation as R, Slerp
from motionbricks.io.usd import load_skeleton_from_usd
from motionbricks.io.utils import SOMA_SKELETON_PRIM_PATH, get_asset_file
from motionbricks.model.soma.contract import SOMA_N1_FP32_ONNX_PATH
from motionbricks.model.soma.engine import MotionBricksSOMAEngine
from motionbricks.model.config import MotionBricksInferenceConfig
from gltf_skel import Glb
from retarget import Skel, PAREN, maak_uitlijning, zet_om

from pathlib import Path
GLB = str(Path(__file__).resolve().parents[3] / 'assets' / 'soldaat_vq2.glb')
g = Glb(GLB); nodes = g.j['nodes']
joints = g.j['skins'][0]['joints']; jpos = {n: i for i, n in enumerate(joints)}
par = [jpos.get(g.parent.get(n), -1) for n in joints]
rt, rq = [], []
for n in joints:
    t, r, s = g.local_rest(n); rt.append(t); rq.append(r.as_quat())
base = g.world_of(g.parent[joints[0]])
ONS = Skel([nodes[n]['name'] for n in joints], par, rt, rq, base)

msk = load_skeleton_from_usd(get_asset_file("human", "soma_base_skel_minimal_no_root.usd"), SOMA_SKELETON_PRIM_PATH)
ref = msk.reference_local_transforms.numpy()
SOMA = Skel([msk.joint_name(i) for i in range(msk.num_joints)], msk.parent_indices.numpy(), ref[:, :3], ref[:, 3:7])

P_OS = [(t, s) for s, t in PAREN]
A_OS = maak_uitlijning(ONS, SOMA, P_OS); A_SO = maak_uitlijning(SOMA, ONS, PAREN)
been = lambda sk, h, f: sk.rest_wp[sk.idx[h]][1] - sk.rest_wp[sk.idx[f]][1]
S_OS = been(SOMA, 'LeftLeg', 'LeftFoot') / been(ONS, 'DEF-thighL', 'DEF-footL'); S_SO = 1 / S_OS

def sample_ons(clip, t):
    lt = ONS.rest_t.copy(); q = ONS.rest_r.as_quat()
    for node, ch in clip.items():
        if node not in jpos: continue
        i = jpos[node]
        if 't' in ch:
            T, V = ch['t']; tt = min(max(t, T[0]), T[-1]); lt[i] = [np.interp(tt, T, V[:, k]) for k in range(3)]
        if 'r' in ch:
            T, V = ch['r']; tt = min(max(t, T[0]), T[-1])
            q[i] = V[0] if len(T) == 1 else Slerp(T, R.from_quat(V))([tt]).as_quat()[0]
    return lt, R.from_quat(q)

def soma_pose(lt, lr, dx=0.0, dz=0.0, yaw=0.0):
    """ons -> SOMA, dan op de grond verplaatsen/draaien (graden)."""
    st, sr = zet_om(ONS, SOMA, lt, lr, P_OS, A_OS, S_OS)
    Y = R.from_euler('y', yaw, degrees=True)
    st[0] = Y.apply(st[0]) + [dx, 0, dz]; q = sr.as_quat(); q[0] = (Y * sr[0]).as_quat()
    return np.concatenate([st, q], 1)

def ons_uit_soma(pose77):
    lt, lr = zet_om(SOMA, ONS, pose77[:, :3].astype(float), R.from_quat(pose77[:, 3:7]), PAREN, A_SO, S_SO)
    return lt, lr

eng = MotionBricksSOMAEngine(SOMA_N1_FP32_ONNX_PATH)
ctx = eng.create_input(msk); tgt = eng.create_input(msk); out = eng.create_output(msk)

def tok(poses):
    return wp.array(np.asarray(poses, np.float32), dtype=wp.transform, device='cpu')

def genereer(context4, targets, tokens=None):
    ctx.update_from_poses(tok(context4)); tgt.update_from_poses(tok(targets))
    eng.generate_animation(ctx, tgt, out, config=MotionBricksInferenceConfig(allowed_token_counts=tokens) if tokens else MotionBricksInferenceConfig())
    return out.poses.numpy()[:out.num_frames].copy()

def keten(context4, doelen):
    """meerdere generaties achter elkaar."""
    alles = []
    c = context4
    for d in doelen:
        m = genereer(c, d); alles.append(m); c = m[-4:]
    return np.concatenate(alles)
