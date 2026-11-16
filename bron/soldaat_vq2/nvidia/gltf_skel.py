"""Lees het soldatenskelet en de clips uit een GLB (zonder Blender)."""
import json, struct
import numpy as np
from scipy.spatial.transform import Rotation as R

class Glb:
    def __init__(self, path):
        d = open(path, 'rb').read()
        n = struct.unpack('<I', d[12:16])[0]
        self.j = json.loads(d[20:20 + n])
        off = 20 + n
        bl = struct.unpack('<I', d[off:off + 4])[0]
        self.bin = d[off + 8: off + 8 + bl]
        self.parent = {}
        for i, nd in enumerate(self.j['nodes']):
            for c in nd.get('children', []):
                self.parent[c] = i
    def acc(self, i):
        a = self.j['accessors'][i]; bv = self.j['bufferViews'][a['bufferView']]
        comp = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a['componentType']]
        k = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(self.bin, comp, a['count'] * k, o).reshape(a['count'], k).astype(np.float64)
    def local_rest(self, i):
        nd = self.j['nodes'][i]
        return (np.array(nd.get('translation', [0, 0, 0]), float),
                R.from_quat(nd.get('rotation', [0, 0, 0, 1])),
                np.array(nd.get('scale', [1, 1, 1]), float))
    def world_of(self, i, local=None):
        """Wereld-matrix (4x4) van knoop i in rust (local: dict idx->(t,R) overrides)."""
        chain = []; k = i
        while k is not None:
            chain.append(k); k = self.parent.get(k)
        M = np.eye(4)
        for k in reversed(chain):
            t, r, s = self.local_rest(k)
            if local and k in local: t, r = local[k]
            L = np.eye(4); L[:3, :3] = r.as_matrix() * s; L[:3, 3] = t
            M = M @ L
        return M
    def clip(self, name):
        """dict node -> {'t':(times, vals), 'r':...} van animatie."""
        a = next(a for a in self.j['animations'] if a['name'] == name)
        out = {}
        for ch in a['channels']:
            s = a['samplers'][ch['sampler']]; tgt = ch['target']
            if tgt['path'] not in ('translation', 'rotation'): continue
            out.setdefault(tgt['node'], {})[tgt['path'][0]] = (self.acc(s['input'])[:, 0], self.acc(s['output']))
        return out
