#!/usr/bin/env python3
"""Validate a USDZ package with Apple's macOS USD tools; optionally update a receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--usdz", required=True)
    parser.add_argument("--report", help="Write combined validation JSON; will not replace an existing report")
    parser.add_argument("--export-receipt", help="Optional JSON receipt from export_usdz.py to extend")
    return parser.parse_args(raw)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    args = parse_args()
    usdz = Path(args.usdz).expanduser().resolve(strict=True)
    if usdz.suffix.lower() != ".usdz":
        raise ValueError("Input must be a .usdz file")
    report_path = Path(args.report).expanduser().resolve() if args.report else None
    receipt_path = Path(args.export_receipt).expanduser().resolve() if args.export_receipt else None
    if report_path and report_path.exists():
        raise FileExistsError(f"Refusing to overwrite validation report: {report_path}")
    if report_path and receipt_path == report_path:
        raise ValueError("Validation report and export receipt must use different paths")

    with zipfile.ZipFile(usdz) as archive:
        entries = [entry for entry in archive.namelist() if not entry.endswith("/")]
        usd_layers = [name for name in entries if Path(name).suffix.lower() in {".usd", ".usda", ".usdc"}]
        texture_files = [name for name in entries if Path(name).suffix.lower() in {".png", ".jpg", ".jpeg", ".exr", ".avif", ".tif", ".tiff"}]
        if not usd_layers:
            raise RuntimeError("Archive contains no USD layer")

    checker = subprocess.run(["xcrun", "usdchecker", "--arkit", str(usdz)], text=True, capture_output=True)
    lister = subprocess.run(["xcrun", "usdzip", str(usdz), "--list", "-"], text=True, capture_output=True)
    if checker.returncode:
        sys.stderr.write(checker.stdout + checker.stderr)
        raise RuntimeError("Apple usdchecker rejected the package")
    if lister.returncode:
        sys.stderr.write(lister.stdout + lister.stderr)
        raise RuntimeError("Apple usdzip could not list the package")

    result = {
        "status": "PASS",
        "usdz": str(usdz),
        "bytes": usdz.stat().st_size,
        "sha256": sha256(usdz),
        "apple_usdchecker_arkit": "PASS",
        "usdzip_contents": entries,
        "usd_layers": usd_layers,
        "texture_files": texture_files,
        "usdzip_list": [line for line in lister.stdout.splitlines() if line.strip()],
        "device_quicklook_playback": "NOT_TESTED",
    }
    if receipt_path:
        export_receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if Path(export_receipt.get("output", "")).resolve() != usdz:
            raise ValueError("Export receipt belongs to a different USDZ output")
        if export_receipt.get("output_sha256") != result["sha256"]:
            raise ValueError("Export receipt hash does not match the USDZ file")
        export_receipt["apple_arkit_validation"] = "PASS"
        export_receipt["validation_sha256"] = result["sha256"]
        export_receipt["validation_bytes"] = result["bytes"]
        export_receipt["validated_usd_layers"] = usd_layers
        export_receipt["validated_textures"] = texture_files
        result["export_receipt_updated"] = str(receipt_path)
        receipt_path.write_text(json.dumps(export_receipt, indent=2) + "\n", encoding="utf-8")
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
