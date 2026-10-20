#!/usr/bin/env python3
"""Download the approved Bloedjungle asset manifest in resumable batches.

Requires Pillow only for 1K texture conversion. Run from any directory:
    python3 tools/download_assets.py --batch terrain
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
LOCK = ROOT / "assets" / "licenses" / "downloaded_assets.json"
MAX_BYTES = 40 * 1024 * 1024


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def inspect(path, kind, resize_1k=False):
    if kind == "texture":
        from PIL import Image
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            width, height = image.size
        if width < 1024 or height < 1024:
            raise ValueError(f"texture too small: {width}x{height}")
        if resize_1k and (width != 1024 or height != 1024):
            with Image.open(path) as image:
                image.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS).save(
                    path.with_suffix(".converted.jpg"), "JPEG", quality=88, optimize=True
                )
            return path.with_suffix(".converted.jpg"), {"width": 1024, "height": 1024, "source_size": [width, height]}
        return path, {"width": width, "height": height}
    if kind == "model":
        with path.open("rb") as stream:
            header = stream.read(20)
            if len(header) != 20 or header[:4] != b"glTF":
                raise ValueError("not a GLB")
            _, version, total, chunk_length, chunk_type = struct.unpack("<4sIIII", header)
            if version != 2 or total != path.stat().st_size or chunk_type != 0x4E4F534A:
                raise ValueError("invalid GLB header")
            model = json.loads(stream.read(chunk_length))
        if not model.get("meshes"):
            raise ValueError("GLB has no mesh")
        externals = [item["uri"] for key in ("buffers", "images") for item in model.get(key, [])
                     if "uri" in item and not item["uri"].startswith("data:")]
        if externals:
            raise ValueError(f"external GLB dependencies: {externals}")
        return path, {"meshes": len(model["meshes"]), "materials": len(model.get("materials", [])),
                      "embedded_images": len(model.get("images", []))}
    if kind == "hdri":
        if path.open("rb").read(11) not in (b"#?RADIANCE\n", b"#?RGBE\n\n\n\n\n"):
            # HDR headers may use either of these signatures; inspect the prefix explicitly.
            if not path.open("rb").read(12).startswith((b"#?RADIANCE", b"#?RGBE")):
                raise ValueError("not a Radiance HDR image")
        return path, {}
    raise ValueError(f"unknown kind: {kind}")


def download(url, destination):
    request = urllib.request.Request(url, headers={"User-Agent": "Bloedjungle-asset-downloader/1.0"})
    with urllib.request.urlopen(request, timeout=45) as response, destination.open("wb") as output:
        if response.status != 200:
            raise ValueError(f"HTTP {response.status}")
        length = int(response.headers.get("Content-Length", "0"))
        if length > MAX_BYTES:
            raise ValueError("download exceeds 40 MiB limit")
        size = 0
        while block := response.read(1024 * 1024):
            size += len(block)
            if size > MAX_BYTES:
                raise ValueError("download exceeds 40 MiB limit")
            output.write(block)
        if size == 0 or (length and length != size):
            raise ValueError("empty or truncated download")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", choices=["terrain", "buildings", "nature", "military", "vehicles", "all"], default="all")
    args = parser.parse_args()
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["assets"]
    lock = json.loads(LOCK.read_text(encoding="utf-8")) if LOCK.exists() else {}
    known = {sha256(path): str(path.relative_to(ROOT)) for path in (ROOT / "assets").rglob("*")
             if path.is_file() and path.suffix.lower() in (".glb", ".jpg", ".png", ".hdr")}
    failures = []
    for entry in entries:
        if args.batch != "all" and entry["batch"] != args.batch:
            continue
        relative = Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != "assets":
            raise ValueError(f"unsafe destination: {relative}")
        path = ROOT / relative
        if path.exists():
            actual = sha256(path)
            if str(relative) in lock and actual != lock[str(relative)]["sha256"]:
                failures.append(f"{relative}: existing file differs from lock; kept unchanged")
            else:
                print(f"SKIP existing {relative} {actual}")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="asset-", dir=ROOT) as tempdir:
            source = Path(tempdir) / ("source" + path.suffix)
            try:
                download(entry["url"], source)
                source_hash = sha256(source)
                if entry.get("source_sha256") and source_hash != entry["source_sha256"]:
                    raise ValueError("source SHA-256 mismatch")
                prepared, details = inspect(source, entry["kind"], entry.get("resize_1k", False))
                if prepared != source:
                    prepared, checked = inspect(prepared, entry["kind"])
                    details.update(checked)
                digest = sha256(prepared)
                if digest in known:
                    raise ValueError(f"duplicate of {known[digest]}")
                os.replace(prepared, path)
                known[digest] = str(relative)
                lock[str(relative)] = {"sha256": digest, "source_sha256": source_hash,
                                       "bytes": path.stat().st_size, "source_url": entry["url"],
                                       "license": entry["license"], "creator": entry["creator"], **details}
                LOCK.parent.mkdir(parents=True, exist_ok=True)
                LOCK.write_text(json.dumps(lock, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
                print(f"OK {relative} {digest} ({path.stat().st_size} bytes)")
            except Exception as error:
                failures.append(f"{relative}: {error}")
                print(f"FAIL {relative}: {error}")
    if failures:
        print(f"{len(failures)} failed; re-run the same batch to retry safely")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
