#!/usr/bin/env python3
"""Validate the player-only Jungle Commando GLB contract without third-party packages."""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path


REQUIRED_PARTS = {"Lijf_JungleCommando", "Vest", "Koppel", "Laarzen", "Mag_Pouches", "Radio_Field", "IFAK_Pouch"}
REQUIRED_ANIMATIONS = {"stil", "lopen", "rennen", "achteruit", "schieten", "geraakt", "dood1", "dood2", "steken", "herladen"}
PBR_MATERIALS = {"JungleCommando_Camo", "Commando Nylon · Olive Drab", "Commando Webbing · Dark Olive", "Commando Hardware · Parkerized Steel", "Commando Hair · Short Dark Brown", "Commando Combat Boots"}


def load_glb(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("File is too small to be a GLB")
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("Invalid GLB header, version, or file length")
    json_length, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON":
        raise ValueError("First GLB chunk is not JSON")
    return json.loads(data[20 : 20 + json_length])


def validate(path: Path) -> dict:
    doc = load_glb(path)
    nodes = {str(node.get("name")): node for node in doc.get("nodes", [])}
    missing_parts = sorted(REQUIRED_PARTS - nodes.keys())
    if missing_parts:
        raise ValueError(f"Missing player parts: {missing_parts}")
    skins = doc.get("skins", [])
    if len(skins) != 1 or len(skins[0].get("joints", [])) != 53:
        raise ValueError("Expected the original 53-joint DEF skin")
    animation_names = {str(clip.get("name")) for clip in doc.get("animations", [])}
    if not REQUIRED_ANIMATIONS <= animation_names:
        raise ValueError(f"Missing embedded source animations: {sorted(REQUIRED_ANIMATIONS-animation_names)}")

    accessors = doc.get("accessors", [])
    meshes = doc.get("meshes", [])
    default_triangles = 0
    for name in REQUIRED_PARTS:
        node = nodes[name]
        if node.get("skin") != 0 or "mesh" not in node:
            raise ValueError(f"{name} is not skinned to the DEF rig")
        for primitive in meshes[node["mesh"]].get("primitives", []):
            attrs = primitive.get("attributes", {})
            if not {"POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"} <= attrs.keys():
                raise ValueError(f"{name} is missing positions, normals, UVs, or skin weights")
            if "indices" in primitive:
                default_triangles += accessors[primitive["indices"]]["count"] // 3

    materials = {str(m.get("name")): m for m in doc.get("materials", [])}
    if not PBR_MATERIALS <= materials.keys():
        raise ValueError(f"Missing PBR materials: {sorted(PBR_MATERIALS-materials.keys())}")
    for name in PBR_MATERIALS:
        material = materials[name]
        if "normalTexture" not in material:
            raise ValueError(f"{name} lacks tangent-space normal map")
        pbr = material.get("pbrMetallicRoughness", {})
        if "baseColorTexture" not in pbr or "metallicRoughnessTexture" not in pbr:
            raise ValueError(f"{name} lacks base-color or metallic/roughness PBR map")
    images = doc.get("images", [])
    if not images or any("bufferView" not in image for image in images):
        raise ValueError("One or more textures are not embedded in the GLB")
    if default_triangles > 16000:
        raise ValueError(f"Default player variant exceeds the 16k triangle budget: {default_triangles}")

    try:
        display_path = str(path.relative_to(Path.cwd()))
    except ValueError:
        display_path = path.name
    return {
        "status": "PASS",
        "glb": display_path,
        "bytes": path.stat().st_size,
        "player_default_triangles": default_triangles,
        "skin_joints": len(skins[0]["joints"]),
        "embedded_source_animations": sorted(animation_names),
        "materials": sorted(PBR_MATERIALS),
        "embedded_images": len(images),
        "required_meshes_with_uv_normals_and_skinning": sorted(REQUIRED_PARTS),
        "note": "The seven Godot-merged clips remain loaded from their existing resources and are checked by the Godot soldier regression test.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = validate(args.glb.expanduser().resolve(strict=True))
    encoded = json.dumps(result, indent=2)
    print(encoded)
    if args.report:
        report = args.report.expanduser().resolve()
        if report.exists():
            raise FileExistsError(report)
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(encoded + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise
