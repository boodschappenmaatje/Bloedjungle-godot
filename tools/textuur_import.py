#!/usr/bin/env python3
"""Zet de import van alle 3D-textures goed: VRAM-compressie (ASTC op iPhone) en mipmaps.

Zonder dit staan foto-textures (grond, gebouwen, bus) als onbewerkte RGB/RGBA zonder mipmaps in het videogeheugen:
tot 8x zo groot en veel trager om te lezen, juist bij een camera die van boven kijkt (alles is verkleind).
De .import-bestanden staan in .gitignore; wat hier aangepast wordt, moet met `git add -f` mee (zoals bij assets/textures/vq2).
Draaien (na een eerste `godot --headless --import`): python3 tools/textuur_import.py && godot --headless --import
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# 2D, UI en effect-beeldreeksen (vuur) en bladeren met alpha laten we zoals ze zijn
SKIP = ("assets/textures/vq2/", "assets/ui/", "assets/stad_icons/", "assets/fx/", "assets/textures/foliage/", "assets/vq2_baseline/")
NORMAL = re.compile(r"(normal|_n\.(png|jpg))", re.I)


def set_param(text: str, key: str, value: str) -> str:
    if re.search(r"^%s=" % re.escape(key), text, re.M):
        return re.sub(r"^%s=.*$" % re.escape(key), "%s=%s" % (key, value), text, flags=re.M)
    return text.replace("[params]\n", "[params]\n\n%s=%s\n" % (key, value), 1)


def etc2_only(text: str) -> str:
    """Alleen het iPhone-formaat (ETC2/ASTC) vastleggen, zoals Xogot het zelf doet; Windows maakt zijn eigen formaat bij het openen."""
    text = re.sub(r'^path\.s3tc=.*\n', "", text, flags=re.M)
    text = text.replace('["s3tc_bptc", "etc2_astc"]', '["etc2_astc"]')
    return re.sub(r'dest_files=\[(.*?)\]', lambda m: "dest_files=[%s]" % ", ".join(p for p in m.group(1).split(", ") if ".s3tc." not in p), text)


def main() -> int:
    changed = 0
    for f in sorted(glob.glob(os.path.join(ROOT, "assets", "**", "*.import"), recursive=True)):
        rel = os.path.relpath(f, ROOT).replace(os.sep, "/")
        text = open(f).read()
        if 'importer="texture"' not in text or rel.startswith(SKIP):
            continue
        new = etc2_only(set_param(text, "compress/mode", "2"))
        new = set_param(new, "mipmaps/generate", "true")
        new = set_param(new, "compress/normal_map", "1" if NORMAL.search(os.path.basename(rel)) else "0")
        if new != text:
            open(f, "w").write(new)
            changed += 1
    print("aangepast:", changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
