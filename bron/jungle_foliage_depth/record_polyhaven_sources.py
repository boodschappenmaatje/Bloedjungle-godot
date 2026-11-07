#!/usr/bin/env python3
"""Verify downloaded Poly Haven source bytes and write a relocatable receipt."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = Path(__file__).resolve().parent / "polyhaven_source"
RAW_MANIFEST = SOURCE_ROOT / "download_manifest.json"


def digest(path: Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def record_file(asset_dir: Path, asset_id: str, name: str, entry: dict, category: str) -> dict:
    candidates = list(asset_dir.rglob(Path(name).name))
    if len(candidates) != 1:
        raise RuntimeError(f"Expected exactly one local {name} in {asset_dir}, found {len(candidates)}")
    path = candidates[0]
    md5 = digest(path, "md5")
    if md5 != entry["md5"]:
        raise RuntimeError(f"Poly Haven MD5 mismatch for {asset_id}/{path.name}: {md5}")
    return {
        "path": str(path.relative_to(ROOT)),
        "url": entry["url"],
        "bytes": path.stat().st_size,
        "polyhaven_md5": md5,
        "sha256": digest(path, "sha256"),
        "category": category,
    }


def main() -> None:
    raw = json.loads(RAW_MANIFEST.read_text())
    if all("files" in source for source in raw["assets"].values()):
        for asset_id, source in raw["assets"].items():
            for entry in source["files"]:
                path = ROOT / entry["path"]
                if not path.is_file() or path.stat().st_size != entry["bytes"]:
                    raise RuntimeError(f"Vendored source file missing/size mismatch: {entry['path']}")
                if digest(path, "md5") != entry["polyhaven_md5"] or digest(path, "sha256") != entry["sha256"]:
                    raise RuntimeError(f"Vendored source checksum mismatch: {entry['path']}")
        print("All Poly Haven CC0 source bytes match the pinned MD5 and SHA-256 receipt.")
        return
    assets: dict[str, dict] = {}
    for asset_id, source in raw["assets"].items():
        asset_dir = SOURCE_ROOT / asset_id
        files = []
        for name, entry in source["source_blend_and_maps"].items():
            files.append(record_file(asset_dir, asset_id, name, entry, "source_model_and_maps"))
        for name, entry in source.get("runtime_maps", {}).items():
            files.append(record_file(asset_dir, asset_id, name, entry, "polyhaven_gltf_runtime_map"))
        assets[asset_id] = {
            "page": source["page"],
            "name": source["name"],
            "description": source["description"],
            "authors": source["authors"],
            "source_polycount": source["source_polycount"],
            "source_dimensions_mm": source["dimensions_mm"],
            "download_resolution": source["download_resolution"],
            "files": files,
        }
    receipt = {
        "provider": raw["provider"],
        "api": raw["api"],
        "license": raw["license"],
        "license_url": raw["license_url"],
        "license_note": "Poly Haven assets are published under CC0 1.0 Universal; verified against the official license page and selected source asset pages.",
        "resolution": raw["resolution"],
        "verified_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "integrity_note": "Each official API MD5 matches the local source bytes; SHA-256 pins the vendored file for future checks.",
        "assets": assets,
    }
    RAW_MANIFEST.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({asset_id: {"files": len(source["files"]), "bytes": sum(entry["bytes"] for entry in source["files"])}
                      for asset_id, source in assets.items()}, indent=2))


if __name__ == "__main__":
    main()
