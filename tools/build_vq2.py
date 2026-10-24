#!/usr/bin/env python3
"""Reproduce VQ2 assets with local CPU Blender, preserving baseline bytes from main."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from vq2_textures import build as textures

ROOT=Path(__file__).resolve().parents[1]
BASELINE="967e9c23baffa0f5e5d62eedce3af30b8634d7c0"


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--blender",default="blender")
    parser.add_argument("--only",choices=["kazerne","wachttoren","legerjeep","jeep"])
    args=parser.parse_args()
    before=ROOT/"assets/vq2_baseline"
    before.mkdir(exist_ok=True)
    for name in ("kazerne","wachttoren","legerjeep","jeep"):
        data=subprocess.check_output(["git","show",f"{BASELINE}:assets/{name}.glb"],cwd=ROOT)
        dest=before/f"{name}.glb"
        if dest.exists() and dest.read_bytes()!=data:
            raise RuntimeError(f"Refusing different baseline: {dest}")
        dest.write_bytes(data)
    textures()
    sources={"kazerne":"bron/kazerne/maak_kazerne.py", "wachttoren":"bron/wachttoren/maak_wachttoren.py", "legerjeep":"bron/legerjeep/maak_jeep.py"}
    for name,source in sources.items():
        if args.only and args.only!=name:
            continue
        subprocess.run([args.blender,"--background","--threads","4","--python",str(ROOT/source)],cwd=ROOT,check=True)
        if name!="legerjeep":
            shutil.copy2(ROOT/Path(source).parent/"uit"/f"{name}.glb",ROOT/"assets"/f"{name}.glb")
    if args.only in (None,"jeep"):
        with tempfile.TemporaryDirectory(prefix="bloedjungle-vq2-jeep-") as tmp:
            subprocess.run([args.blender,"--background","--threads","4","--python",str(ROOT/"bron/jeep/maak_jeep.py"),"--",tmp],cwd=ROOT,check=True)
            shutil.copy2(Path(tmp)/"jeep.glb",ROOT/"assets/jeep.glb")
            shutil.copy2(Path(tmp)/"jeep.blend",ROOT/"bron/jeep/jeep.blend")
    print("Built VQ2 assets; baseline pinned to",BASELINE)


if __name__=="__main__":
    main()
