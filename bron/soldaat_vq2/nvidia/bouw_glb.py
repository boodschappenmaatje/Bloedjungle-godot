"""clips.npz -> assets/nv_bewegingen.glb: alleen het skelet van soldaat_vq2.glb (geen mesh) met de NVIDIA-clips.

Draait zonder het NVIDIA-model:  python3 -I bouw_glb.py  (vanuit deze map)
Godot hangt de clips aan elk VQ2-mannetje (scripts/soldier_model.gd, NV_PAD), net als acties.glb.
"""
import json, struct, sys
from pathlib import Path
import numpy as np

HIER = Path(__file__).resolve().parent
REPO = HIER.parents[2]
BRON = REPO / 'assets' / 'soldaat_vq2.glb'
UIT = REPO / 'assets' / 'nv_bewegingen.glb'
FPS = 30.0


def lees(path):
    d = path.read_bytes()
    n = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + n])
    off = 20 + n
    bl = struct.unpack('<I', d[off:off + 4])[0]
    return j, d[off + 8: off + 8 + bl]


def bouw(clips, uit=UIT, bron=BRON, met_mesh=False, heup='DEF-hips'):
    """clips: {naam: (LT (F,n,3), LQ (F,n,4))} in de volgorde van skin.joints. met_mesh=True: volledige soldaat (viewer)."""
    j, b = lees(bron)
    if met_mesh:
        nj = j; nb = bytearray(b); nj['animations'] = []
        joints = nj['skins'][0]['joints']
    else:
        skin = j['skins'][0]
        ouder = {c: i for i, nd in enumerate(j['nodes']) for c in nd.get('children', [])}
        houden = set(skin['joints'])
        for k in list(houden):
            while k in ouder:
                k = ouder[k]; houden.add(k)
        oud = sorted(houden); nieuw = {o: i for i, o in enumerate(oud)}
        nodes = []
        for o in oud:
            nd = {k: v for k, v in j['nodes'][o].items() if k in ('name', 'translation', 'rotation', 'scale')}
            ch = [nieuw[c] for c in j['nodes'][o].get('children', []) if c in nieuw]
            if ch: nd['children'] = ch
            nodes.append(nd)
        ibm = j['accessors'][skin['inverseBindMatrices']]; bv = j['bufferViews'][ibm['bufferView']]
        o0 = bv.get('byteOffset', 0) + ibm.get('byteOffset', 0)
        nb = bytearray(b[o0:o0 + ibm['count'] * 64])
        joints = [nieuw[x] for x in skin['joints']]
        nj = {'asset': {'version': '2.0', 'generator': 'bloedjungle nvidia/bouw_glb.py'},
              'scene': 0, 'scenes': [{'name': 'Scene', 'nodes': [nieuw[o] for o in oud if o not in ouder]}],
              'nodes': nodes, 'buffers': [{'byteLength': 0}],
              'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(nb)}],
              'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': ibm['count'], 'type': 'MAT4'}],
              'skins': [{'name': skin.get('name', 'Rig'), 'joints': joints, 'inverseBindMatrices': 0,
                         **({'skeleton': nieuw[skin['skeleton']]} if 'skeleton' in skin else {})}],
              'animations': []}
        # Godot maakt alleen een Skeleton3D als de skin aan een knoop hangt: lege mesh-loze knoop met skin
        nj['nodes'].append({'name': 'NV_Skin', 'skin': 0}); nj['scenes'][0]['nodes'].append(len(nj['nodes']) - 1)
    names = [nj['nodes'][k]['name'] for k in joints]

    def add(arr, typ, minmax=False):
        nonlocal nb
        while len(nb) % 4: nb.append(0)
        a = np.ascontiguousarray(arr, np.float32); o = len(nb); nb += a.tobytes()
        nj['bufferViews'].append({'buffer': 0, 'byteOffset': o, 'byteLength': a.nbytes})
        acc = {'bufferView': len(nj['bufferViews']) - 1, 'componentType': 5126, 'count': int(a.shape[0]), 'type': typ}
        if minmax: acc['min'] = a.min(0).tolist(); acc['max'] = a.max(0).tolist()
        nj['accessors'].append(acc); return len(nj['accessors']) - 1

    for naam, (LT, LQ) in clips.items():
        F = LT.shape[0]; ti = add(np.arange(F)[:, None] / FPS, 'SCALAR', True)
        an = {'name': naam, 'channels': [], 'samplers': []}
        for i, node in enumerate(joints):
            paden = [('rotation', LQ[:, i], 'VEC4')]
            if names[i] == heup: paden.append(('translation', LT[:, i], 'VEC3'))
            for pad, data, typ in paden:
                an['samplers'].append({'input': ti, 'output': add(data, typ), 'interpolation': 'LINEAR'})
                an['channels'].append({'sampler': len(an['samplers']) - 1, 'target': {'node': node, 'path': pad}})
        nj['animations'].append(an)
    while len(nb) % 4: nb.append(0)
    nj['buffers'] = [{'byteLength': len(nb)}]
    js = json.dumps(nj, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    with open(uit, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(nb)))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(nb), 0x004E4942)); f.write(nb)
    return uit


def laad_npz(path=HIER / 'clips.npz'):
    z = np.load(path)
    namen = [str(x) for x in z['namen']]
    return {n: (z[n + '_t'], z[n + '_q']) for n in namen}


if __name__ == '__main__':
    clips = laad_npz()
    print('geschreven:', bouw(clips))
    if len(sys.argv) > 1:   # extra: volledige soldaat met clips voor de viewer
        print('viewer:', bouw(clips, uit=Path(sys.argv[1]), met_mesh=True))
