#!/usr/bin/env python3
"""Kazerne HQ2 GLB format gate; run against the FINAL candidate before Godot integration.
    python3 tests/kazerne_hq2_glb_gate.py /path/to/kazerne_hq2.glb
Passing this gate does NOT prove correct visuals, collision, iPhone FPS, or gameplay.
"""
import json
import struct
import sys
from pathlib import Path


def check(path: Path) -> dict:
    with path.open("rb") as f:
        header = f.read(12)
        assert len(header) == 12, "GLB truncated"
        magic, version, size = struct.unpack("<4sII", header)
        assert magic == b"glTF" and version == 2 and size == path.stat().st_size, "invalid GLB header"
        chunks = []
        while f.tell() < size:
            raw = f.read(8)
            assert len(raw) == 8, "truncated GLB chunk header"
            length, kind = struct.unpack("<I4s", raw)
            payload = f.read(length)
            assert len(payload) == length, "truncated GLB chunk"
            chunks.append((kind, payload))
    assert chunks[0][0] == b"JSON", "missing JSON chunk"
    doc = json.loads(chunks[0][1].decode("utf-8"))
    binary = [chunk for kind, chunk in chunks if kind == b"BIN\x00"]
    assert len(binary) == 1, "expected one BIN chunk"
    buffer = binary[0]

    assert len(doc.get("materials", [])) == 1, "expected one material"
    material = doc["materials"][0]
    pbr = material["pbrMetallicRoughness"]
    assert "baseColorTexture" in pbr and "metallicRoughnessTexture" in pbr and "normalTexture" in material
    accessors = doc["accessors"]
    parts = [p for mesh in doc["meshes"] for p in mesh["primitives"]]
    count = 0
    bounds = []
    for part in parts:
        assert part.get("mode", 4) == 4 and "indices" in part, "mesh must use indexed triangles"
        indices = accessors[part["indices"]]
        assert indices["count"] % 3 == 0
        count += indices["count"] // 3
        position = accessors[part["attributes"]["POSITION"]]
        bounds.append((position["min"], position["max"]))
    assert count >= 40000, f"triangle count below agreed minimum: {count}"
    mins = [min(bb[0][i] for bb in bounds) for i in range(3)]
    maxs = [max(bb[1][i] for bb in bounds) for i in range(3)]
    dimensions = [maxs[i] - mins[i] for i in range(3)]
    assert all(abs(v - expected) < 0.07 for v, expected in zip(dimensions, (6.4, 3.5, 4.8))), dimensions
    assert abs(mins[1]) < 0.02, "pivot not at ground plane"

    images, views, textures = doc["images"], doc["bufferViews"], doc["textures"]
    for name, slot in (("albedo", pbr["baseColorTexture"]),
                       ("normal", material["normalTexture"]),
                       ("metallic-roughness", pbr["metallicRoughnessTexture"])):
        image = images[textures[slot["index"]]["source"]]
        view = views[image["bufferView"]]
        offset = view.get("byteOffset", 0)
        payload = buffer[offset:offset + view["byteLength"]]
        assert payload[:8] == b"\x89PNG\r\n\x1a\n", f"{name}: not an embedded PNG"
        width, height = struct.unpack(">II", payload[16:24])
        assert (width, height) == (2048, 2048), f"{name}: not 2K ({width}x{height})"
    return {"triangles": count, "dimensions_m": dimensions, "2k_pbr": "PASS",
            "godot_and_native_iphone": "NOT_TESTED"}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python tests/kazerne_hq2_glb_gate.py path/to/candidate.glb")
    try:
        print(json.dumps(check(Path(sys.argv[1])), indent=2))
    except Exception as exc:
        sys.exit(f"KAZERNE_HQ2_GLB_GATE_FAIL: {exc}")
