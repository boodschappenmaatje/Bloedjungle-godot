#!/usr/bin/env python3
"""Losslessly pack existing RGB normal + roughness alpha. No new source/upscaling."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/textures/terrain/surfaces'
def main():
 DEST.mkdir(exist_ok=True)
 records=[]
 for family in ['grass','jungle_ground','dry_earth','mud','moss']:
  folder=ROOT/'assets/textures/terrain'/family
  normal=Image.open(folder/'normal_gl.jpg').convert('RGB')
  rough=Image.open(folder/'roughness.jpg').convert('L')
  assert normal.size==rough.size
  normal.putalpha(rough)
  out=DEST/(family+'.png');normal.save(out,optimize=True)
  records.append({'family':family,'size':normal.size,'channels':'RGB OpenGL tangent normal, A roughness (linear)',
   'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [folder/'normal_gl.jpg',folder/'roughness.jpg']},
   'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
 (DEST/'manifest.json').write_text(json.dumps({'method':'Lossless channel packing of existing licensed project PBR maps; no resampling','license_reference':'docs/ASSET_SOURCES.md','maps':records},indent=2)+'\n')
if __name__=='__main__':main()
