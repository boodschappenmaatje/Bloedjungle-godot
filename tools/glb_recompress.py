#!/usr/bin/env python3
"""Verklein de ingebedde JPEG-texturen van een .glb (alleen JPEG, PNG met alfa blijft ongemoeid).

Gebruik: python3 tools/glb_recompress.py in.glb uit.glb [kwaliteit_albedo=88] [kwaliteit_overig=86]
Albedo krijgt de hogere kwaliteit; normal en ORM iets lager. Geometrie, animaties en materialen blijven identiek.
"""
import io
import json
import struct
import sys

from PIL import Image


def main():
    src, dst = sys.argv[1], sys.argv[2]
    q_alb = int(sys.argv[3]) if len(sys.argv) > 3 else 88
    q_oth = int(sys.argv[4]) if len(sys.argv) > 4 else 86
    data = open(src, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + jlen])
    boff = 20 + jlen
    blen = struct.unpack("<I", data[boff:boff + 4])[0]
    bin_ = data[boff + 8:boff + 8 + blen]

    # welke afbeeldingen zijn albedo (sRGB, via baseColorTexture)?
    albedo_tex = set()
    for m in j.get("materials", []):
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t:
            albedo_tex.add(j["textures"][t["index"]]["source"])

    views = j["bufferViews"]
    new_bytes = {}
    for i, im in enumerate(j.get("images", [])):
        if im.get("mimeType") != "image/jpeg":
            continue
        v = views[im["bufferView"]]
        raw = bin_[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        pil = Image.open(io.BytesIO(raw)).convert("RGB")
        out = io.BytesIO()
        pil.save(out, "JPEG", quality=q_alb if i in albedo_tex else q_oth, subsampling=0 if i in albedo_tex else 2, optimize=True)
        new_bytes[im["bufferView"]] = out.getvalue()

    chunks = []
    off = 0
    for idx, v in enumerate(views):
        blob = new_bytes.get(idx)
        if blob is None:
            o = v.get("byteOffset", 0)
            blob = bin_[o:o + v["byteLength"]]
        pad = (-off) % 4
        off += pad
        chunks.append(b"\0" * pad)
        v["byteOffset"] = off
        v["byteLength"] = len(blob)
        chunks.append(blob)
        off += len(blob)
    new_bin = b"".join(chunks)
    new_bin += b"\0" * ((-len(new_bin)) % 4)
    j["buffers"][0]["byteLength"] = len(new_bin)
    jb = json.dumps(j, separators=(",", ":")).encode()
    jb += b" " * ((-len(jb)) % 4)
    total = 12 + 8 + len(jb) + 8 + len(new_bin)
    out = struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<I4s", len(jb), b"JSON") + jb
    out += struct.pack("<I4s", len(new_bin), b"BIN\0") + new_bin
    open(dst, "wb").write(out)
    print(f"{src}: {len(data) / 1e6:.1f} MB -> {dst}: {len(out) / 1e6:.1f} MB")


main()
