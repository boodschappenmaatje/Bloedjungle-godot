"""Read GLB structures and measured translation tracks without changing assets."""
from pathlib import Path
import hashlib
import json
import math
import struct

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCES = {
    "approved_m47": ROOT / "docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb",
    "cinematic_wall": HERE / "cinematic_concrete_breach.glb",
}


def read(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 4)[0] == 2
    json_size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_size])
    binary_offset = 20 + json_size
    bin_size = struct.unpack_from("<I", data, binary_offset)[0]
    binary = data[binary_offset + 8:binary_offset + 8 + bin_size]
    return gltf, binary, data


def vector(gltf, binary, accessor_index, sample):
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0) + sample * view.get("byteStride", 12)
    assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
    return struct.unpack_from("<fff", binary, offset)


report = {}
for key, path in SOURCES.items():
    gltf, binary, data = read(path)
    mesh_triangles = {}
    for mesh in gltf.get("meshes", []):
        count = 0
        for primitive in mesh["primitives"]:
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            count += gltf["accessors"][accessor]["count"] // 3
        mesh_triangles[mesh["name"]] = count
    animations = {a["name"]: len(a["channels"]) for a in gltf.get("animations", [])}
    materials = {}
    for material in gltf.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        materials[material.get("name", "unnamed")] = {
            "albedo": "baseColorTexture" in pbr,
            "roughness_metallic": "metallicRoughnessTexture" in pbr,
            "normal": "normalTexture" in material,
        }
    item = {
        "path": str(path.relative_to(ROOT)),
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
        "mesh_triangles": mesh_triangles,
        "total_triangles": sum(mesh_triangles.values()),
        "animation_channels": animations,
        "materials": materials,
    }
    if key == "cinematic_wall":
        breach = next(a for a in gltf["animations"] if a["name"] == "Breach")
        translation_distances = []
        for channel in breach["channels"]:
            if channel["target"]["path"] != "translation":
                continue
            index = breach["samplers"][channel["sampler"]]["output"]
            accessor = gltf["accessors"][index]
            translation_distances.append(math.dist(vector(gltf, binary, index, 0), vector(gltf, binary, index, accessor["count"] - 1)))
        item["breach_translation_channels"] = len(translation_distances)
        item["breach_channels_moving_over_0_1m"] = sum(distance > 0.1 for distance in translation_distances)
        item["breach_min_movement_m"] = round(min(translation_distances), 3)
        item["breach_max_movement_m"] = round(max(translation_distances), 3)
    report[key] = item

(HERE / "asset_inspection.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: {"total_triangles": data["total_triangles"], "animation_channels": data["animation_channels"]} for key, data in report.items()}, indent=2))
