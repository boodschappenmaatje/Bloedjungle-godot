#!/usr/bin/env python3
"""Create a static Pages artifact from this exact feature checkout, with no CDN."""
from pathlib import Path
import argparse, shutil
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('destination',type=Path);args=parser.parse_args()
dest=args.destination.resolve()
if dest.exists():
    raise SystemExit('Destination must be a new directory: '+str(dest))
viewer=dest/'tools/blender-vq2-viewer';viewer.mkdir(parents=True)
for name in ('index.html','viewer.js','viewer.js.LEGAL.txt','style.css','THREE-LICENSE.txt'):
    shutil.copy2(ROOT/'tools/blender-vq2-viewer'/name,viewer/name)
(dest/'assets/vq2_baseline').mkdir(parents=True)
for name in ('kazerne','wachttoren','legerjeep'):
    for folder in ('assets','assets/vq2_baseline'):
        shutil.copy2(ROOT/folder/(name+'.glb'),dest/folder/(name+'.glb'))
shutil.copy2(ROOT/'assets/jeep.glb',dest/'assets/jeep.glb')
(dest/'docs/vq2/results').mkdir(parents=True)
shutil.copy2(ROOT/'docs/vq2/results/asset-report.json',dest/'docs/vq2/results/asset-report.json')
(dest/'index.html').write_text('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=tools/blender-vq2-viewer/"><a href="tools/blender-vq2-viewer/">Open Bloedjungle 3D viewer</a>')
(dest/'.nojekyll').touch()
print('Static viewer artifact:',dest)
