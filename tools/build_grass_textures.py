#!/usr/bin/env python3
"""Author original grass PBR at 2048²: eight full-resolution blade varieties.

Analytic veins and seeded cellular pigments are evaluated at destination pixels.
No photographic claim, source enlargement, provider or image download.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/grass_2k'


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    size = 2048
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = 1.0-y/(size-1)  # root at UV.v=0 (bottom of image)
    lane = np.floor(x/256).astype(int)
    u = (x % 256)/255
    rng = np.random.default_rng(27102026)
    grain = rng.normal(0, .004, (size, size)).astype(np.float32)
    # Distinct pigmentation and dry margins; never a painted solid-color ribbon.
    fibers = np.sin(u*88 + .22*np.sin(t*14+lane))*0.016
    fibers += np.sin(u*217 + t*1.6 + lane)*.008
    cells = np.sin(t*115 + u*7)*np.sin(u*51+t*4)*.006
    midrib = np.exp(-((u-.5)/.035)**2)
    edges = np.exp(-np.minimum(u, 1-u)/.045)
    root = np.exp(-t*9)
    tip = np.clip((t-.62)/.38, 0, 1)
    dry_lane = ((lane==6)*.65 + (lane==7)*.2).astype(np.float32)
    base = np.stack((.29+.11*tip-.10*root, .43+.08*tip-.18*root, .095+.055*tip-.035*root), -1)
    pigment = (fibers + cells + grain + midrib*.025)[..., None]
    color = base + pigment + (.012*np.sin(lane*2.3))[..., None]
    drying = np.clip(dry_lane*.75 + edges*(.08+.18*tip), 0, .85)[..., None]
    straw = np.stack((.50+.08*tip, .43+.08*tip, .19+.05*tip), -1)
    color = color*(1-drying) + straw*drying
    Image.fromarray(np.uint8(np.clip(color, 0, 1)*255)).save(OUT/'albedo.jpg', quality=97, subsampling=0)
    relief = fibers*.6 + cells*.18 + midrib*.02
    gy, gx = np.gradient(relief)
    normal = np.stack((-gx*16, gy*8, np.ones_like(gx)), -1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    Image.fromarray(np.uint8(np.clip(normal*.5+.5,0,1)*255)).save(OUT/'normal.png', optimize=True)
    ao = .84 + .16*(1-root)
    rough = np.clip(.70+.09*root+.07*dry_lane + fibers*.6 + grain, .58,.92)
    Image.fromarray(np.uint8(np.stack((ao, rough, np.zeros_like(rough)),-1)*255)).save(OUT/'orm.png', optimize=True)
    report = {'resolution':[size,size], 'native_authored_resolution':[size,size],
        'method':'Original analytic procedural blade pigmentation, veins, epidermal cells and PBR maps; evaluated at full 2048², not upscaled photographs.',
        'seed':27102026,'atlas_lanes':8,'license':'CC0-1.0', 'author':'Bloedjungle project procedural production',
        'channels':{'albedo.jpg':'sRGB albedo','normal.png':'OpenGL tangent normal, linear data','orm.png':'R ambient occlusion / G roughness / B metallic=0, linear data'},
        'sources':['tools/build_grass_textures.py'],
        'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.suffix in ('.png','.jpg')}}
    (OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
    print('GRASS TEXTURES: native authored 2048x2048, 8 blade lanes, albedo/normal/ORM')


if __name__=='__main__':
    build()
