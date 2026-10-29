#!/usr/bin/env python3
"""Fail when a project GLB is missing its checked-in Godot import config."""

from __future__ import annotations

import configparser
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"


def unquote(value: str) -> str:
    return value.strip().strip('"')


def main() -> int:
    errors: list[str] = []
    models = sorted(ASSETS.rglob("*.glb"))
    if not models:
        print("No GLB assets found under assets/", file=sys.stderr)
        return 2

    for model in models:
        sidecar = Path(f"{model}.import")
        relative = model.relative_to(ROOT).as_posix()
        if not sidecar.is_file():
            errors.append(f"{relative}: missing {sidecar.name}")
            continue

        config = configparser.ConfigParser(interpolation=None)
        try:
            loaded = config.read(sidecar, encoding="utf-8")
        except (OSError, configparser.Error) as error:
            errors.append(f"{relative}: unreadable import config ({error})")
            continue
        if not loaded or not config.has_section("remap") or not config.has_section("deps"):
            errors.append(f"{relative}: missing [remap] or [deps] section")
            continue

        source_file = unquote(config.get("deps", "source_file", fallback=""))
        importer = unquote(config.get("remap", "importer", fallback=""))
        resource_type = unquote(config.get("remap", "type", fallback=""))
        remap_path = unquote(config.get("remap", "path", fallback=""))
        dest_files = unquote(config.get("deps", "dest_files", fallback=""))

        if source_file != f"res://{relative}":
            errors.append(f"{relative}: source_file points to {source_file!r}")
        if importer != "scene" or resource_type != "PackedScene":
            errors.append(f"{relative}: expected scene/PackedScene importer")
        if not remap_path.startswith("res://.godot/imported/") or remap_path not in dest_files:
            errors.append(f"{relative}: invalid imported-scene remap/destination")

        import_script = unquote(config.get("params", "import_script/path", fallback=""))
        if import_script:
            if not import_script.startswith("res://") or not (ROOT / import_script[6:]).is_file():
                errors.append(f"{relative}: import script does not exist: {import_script!r}")

    if errors:
        print("GLB import metadata check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"GLB import metadata check passed for {len(models)} assets.")
    print("Godot's generated cache remains local under .godot/ and is not checked in.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
