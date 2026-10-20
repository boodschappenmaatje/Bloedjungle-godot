#!/usr/bin/env python3
"""Download the approved Bloedjungle asset manifest in resumable batches.

Requires Pillow for image checks and resizing. Missing Poly Haven KTX2 files also
require the open Basis Universal `basisu` CLI on PATH (or BASISU_BIN pointing to
its executable). Run from any directory:
    python3 tools/download_assets.py --batch terrain
"""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
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
        with path.open("rb") as stream:
            if not stream.read(12).startswith((b"#?RADIANCE", b"#?RGBE")):
                raise ValueError("not a Radiance HDR image")
        return path, {}
    raise ValueError(f"unknown kind: {kind}")


def download(url, destination):
    cache = ROOT / ".asset-download-cache"
    cache.mkdir(exist_ok=True)
    stem = hashlib.sha256(url.encode("utf-8")).hexdigest()
    partial, complete = cache / (stem + ".part"), cache / (stem + ".source")
    if complete.exists():
        shutil.copyfile(complete, destination)
        return
    offset = partial.stat().st_size if partial.exists() else 0
    headers = {"User-Agent": "Bloedjungle-asset-downloader/1.0"}
    if offset:
        headers["Range"] = f"bytes={offset}-"
    request = urllib.request.Request(url, headers=headers)
    try:
        response = urllib.request.urlopen(request, timeout=45)
    except Exception:
        # Keep the partial file so the next run can use an HTTP Range request.
        raise
    with response:
        if response.status not in (200, 206):
            raise ValueError(f"HTTP {response.status}")
        if offset and response.status == 206:
            content_range = response.headers.get("Content-Range", "")
            if not content_range.startswith(f"bytes {offset}-"):
                raise ValueError("server returned an invalid Content-Range; partial retained")
            mode = "ab"
        else:
            offset = 0
            mode = "wb"
        length = int(response.headers.get("Content-Length", "0"))
        if length + offset > MAX_BYTES:
            raise ValueError("download exceeds 40 MiB limit")
        total = offset
        with partial.open(mode) as output:
            while block := response.read(1024 * 1024):
                total += len(block)
                if total > MAX_BYTES:
                    raise ValueError("download exceeds 40 MiB limit")
                output.write(block)
        if total == 0 or (length and total != offset + length):
            raise ValueError("empty or truncated download; partial retained")
    os.replace(partial, complete)
    shutil.copyfile(complete, destination)


def embed_dependencies(source, entry, tempdir):
    """Embed manifest-approved external PNGs as glTF data URIs in a standalone GLB."""
    dependencies = entry.get("dependencies")
    if not dependencies:
        return source, {}
    raw = source.read_bytes()
    if raw[:4] != b"glTF":
        raise ValueError("not a GLB")
    json_size = struct.unpack_from("<I", raw, 12)[0]
    model = json.loads(raw[20:20 + json_size])
    hashes = {}
    for image in model.get("images", []):
        uri = image.get("uri")
        if not uri or uri.startswith("data:"):
            continue
        if uri not in dependencies or not uri.endswith(".png"):
            raise ValueError(f"unapproved dependency: {uri}")
        dependency = Path(tempdir) / Path(uri).name
        download(dependencies[uri], dependency)
        from PIL import Image
        with Image.open(dependency) as pixels:
            pixels.verify()
        hashes[uri] = sha256(dependency)
        expected = entry.get("dependency_sha256", {}).get(uri)
        if expected and hashes[uri] != expected:
            raise ValueError(f"dependency SHA-256 mismatch: {uri}")
        image["uri"] = "data:image/png;base64," + base64.b64encode(dependency.read_bytes()).decode("ascii")
    if not hashes:
        raise ValueError("declared dependencies were not found in GLB")
    encoded = json.dumps(model, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((-len(encoded)) % 4)
    remainder = raw[20 + json_size:]
    output = Path(tempdir) / "embedded.glb"
    output.write_bytes(struct.pack("<4sII", b"glTF", 2, 20 + len(encoded) + len(remainder))
                       + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded + remainder)
    return output, hashes


def convert_ktx2(source, tempdir):
    """Decode a CC0 mirror's 512px UASTC KTX2 with basisu, then store a 1K JPEG."""
    if not source.read_bytes()[:12] == b"\xabKTX 20\xbb\r\n\x1a\n":
        raise ValueError("not a KTX2 texture")
    basisu = os.environ.get("BASISU_BIN") or shutil.which("basisu")
    if not basisu:
        raise ValueError("basisu CLI required to decode this KTX2 source; set BASISU_BIN")
    result = subprocess.run([basisu, "-unpack", "-file", str(source), "-no_ktx",
                             "-output_path", str(tempdir)], capture_output=True, text=True, timeout=90)
    if result.returncode:
        raise ValueError(f"basisu failed: {result.stderr[-500:]}")
    matches = list(Path(tempdir).glob("source_unpacked_rgba_RGBA32_level_0_*.png"))
    if len(matches) != 1:
        raise ValueError(f"basisu did not produce one RGBA32 first mip: {len(matches)}")
    from PIL import Image
    with Image.open(matches[0]) as image:
        image.verify()
    with Image.open(matches[0]) as image:
        original_size = image.size
        if not all(480 <= dimension <= 512 for dimension in original_size):
            raise ValueError(f"unexpected KTX2 source resolution: {original_size}")
        output = Path(tempdir) / "prepared.jpg"
        image.convert("RGB").resize((1024, 1024), Image.Resampling.BILINEAR).save(
            output, "JPEG", quality=90, optimize=True
        )
    return output, {"source_size": list(original_size), "width": 1024, "height": 1024,
                    "effective_resolution": "at most 512px source resampled to 1K"}


def convert_blend_model(source, output):
    """Export mesh objects from an approved Blender source as a standalone GLB."""
    blender = os.environ.get("BLENDER_BIN") or shutil.which("blender")
    if not blender:
        raise ValueError("Blender CLI is required to convert this approved .blend model")
    expression = (
        "import bpy; bpy.ops.object.select_all(action='DESELECT'); "
        "[o.select_set(True) for o in bpy.data.objects if o.type == 'MESH']; "
        "bpy.context.view_layer.objects.active = next((o for o in bpy.data.objects if o.type == 'MESH'), None); "
        f"bpy.ops.export_scene.gltf(filepath={json.dumps(str(output))}, export_format='GLB', "
        "use_selection=True, export_yup=True, export_apply=True)"
    )
    result = subprocess.run([blender, "--background", str(source), "--python-expr", expression],
                            capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise ValueError(f"Blender GLB export failed: {result.stdout[-500:]} {result.stderr[-500:]}")


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
            source_suffix = {"ktx2_texture": ".ktx2", "blend_model": ".blend"}.get(entry["kind"], path.suffix)
            source = Path(tempdir) / ("source" + source_suffix)
            try:
                download(entry["url"], source)
                source_hash = sha256(source)
                expected = entry.get("source_sha256") or lock.get(str(relative), {}).get("source_sha256")
                if expected and source_hash != expected:
                    raise ValueError("source SHA-256 mismatch")
                if entry["kind"] == "ktx2_texture":
                    embedded, dependency_hashes = source, {}
                    prepared, details = convert_ktx2(source, tempdir)
                    _, checked = inspect(prepared, "texture")
                    details.update(checked)
                elif entry["kind"] == "blend_model":
                    prepared = Path(tempdir) / "converted.glb"
                    convert_blend_model(source, prepared)
                    embedded, dependency_hashes = prepared, {}
                    prepared, details = inspect(prepared, "model")
                else:
                    embedded, dependency_hashes = embed_dependencies(source, entry, tempdir)
                    prepared, details = inspect(embedded, entry["kind"], entry.get("resize_1k", False))
                if prepared != embedded and entry["kind"] != "ktx2_texture":
                    prepared, checked = inspect(prepared, entry["kind"])
                    details.update(checked)
                digest = sha256(prepared)
                if digest in known:
                    raise ValueError(f"duplicate of {known[digest]}")
                os.replace(prepared, path)
                known[digest] = str(relative)
                lock[str(relative)] = {"sha256": digest, "source_sha256": source_hash,
                                       "bytes": path.stat().st_size, "source_url": entry["url"],
                                       "license": entry["license"], "creator": entry["creator"],
                                       "dependency_sha256": dependency_hashes, **details}
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
