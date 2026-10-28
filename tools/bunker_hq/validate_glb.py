#!/usr/bin/env python3
"""Static glTF 2.0 GLB validator; checks container, chunks, references, UVs, textures and triangles."""
import argparse
import json
import os
import struct
import sys

def validate(path):
    checks = []
    def record(name, ok, detail=""):
        checks.append({"check": name, "status": "PASS" if ok else "FAIL", "detail": detail})
    try:
        data = open(path, "rb").read()
        if len(data) < 20:
            raise ValueError("File shorter than GLB header and JSON chunk")
        magic, version, declared = struct.unpack_from("<4sII", data, 0)
        record("glb_magic", magic == b"glTF", magic.decode("ascii", "replace"))
        record("gltf_version_2", version == 2, str(version))
        record("declared_length", declared == len(data), f"declared={declared} actual={len(data)}")
        offset, doc = 12, None
        while offset + 8 <= len(data):
            size, kind = struct.unpack_from("<I4s", data, offset)
            offset += 8
            if offset + size > len(data):
                raise ValueError(f"Chunk {kind!r} extends beyond file")
            chunk = data[offset:offset + size]
            offset += size
            if kind == b"JSON":
                doc = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        if doc is None:
            raise ValueError("Missing JSON chunk")
        record("json_chunk", True, "Parsed JSON chunk")
        accessors = doc.get("accessors", [])
        primitives = [p for m in doc.get("meshes", []) for p in m.get("primitives", [])]
        triangle_count = sum((accessors[p.get("indices", -1)].get("count", 0) // 3) if p.get("indices", -1) >= 0 else 0 for p in primitives)
        uv_count = sum(1 for p in primitives if "TEXCOORD_0" in p.get("attributes", {}))
        normal_count = sum(1 for p in primitives if "NORMAL" in p.get("attributes", {}))
        image_count = len(doc.get("images", []))
        material_count = len(doc.get("materials", []))
        material_channels={"base_color":0,"metallic_roughness":0,"normal":0,"occlusion":0,"emission":0}
        for material in doc.get("materials",[]):
            pbr=material.get("pbrMetallicRoughness",{})
            material_channels["base_color"]+=bool(pbr.get("baseColorTexture"))
            material_channels["metallic_roughness"]+=bool(pbr.get("metallicRoughnessTexture"))
            material_channels["normal"]+=bool(material.get("normalTexture"))
            material_channels["occlusion"]+=bool(material.get("occlusionTexture"))
            material_channels["emission"]+=bool(material.get("emissiveTexture"))
        record("scene", bool(doc.get("scenes")), f"{len(doc.get('scenes', []))} scenes")
        record("mesh_nodes", bool(doc.get("meshes")), f"{len(doc.get('nodes', []))} nodes; {len(doc.get('meshes', []))} meshes")
        record("uv_mapping", uv_count == len(primitives) and bool(primitives), f"{uv_count}/{len(primitives)} primitives have TEXCOORD_0")
        record("normals", normal_count == len(primitives) and bool(primitives), f"{normal_count}/{len(primitives)} primitives have NORMAL")
        record("materials", bool(material_count), f"{material_count} materials")
        record("embedded_textures", bool(image_count), f"{image_count} images")
        for channel,count in material_channels.items():
            record("pbr_"+channel,count==material_count and material_count>0,
                   f"{count}/{material_count} materials reference this map")
        # Validate every accessor and texture reference used by the JSON document.
        refs_ok = True
        for mesh in doc.get("meshes", []):
            for prim in mesh.get("primitives", []):
                for index in list(prim.get("attributes", {}).values()) + ([prim["indices"]] if "indices" in prim else []):
                    refs_ok &= isinstance(index, int) and 0 <= index < len(accessors)
        for tex in doc.get("textures", []):
            refs_ok &= 0 <= tex.get("source", -1) < image_count
        record("references", refs_ok, "Accessor and texture indices in range")
        report = {"asset": os.path.basename(path), "bytes": len(data), "triangles": triangle_count,
                  "nodes": len(doc.get("nodes", [])), "meshes": len(doc.get("meshes", [])),
                  "materials": material_count, "images": image_count, "material_channels":material_channels,
                  "godot_import_status":"NOT TESTED", "checks": checks,
                  "status": "FAIL" if any(x["status"] == "FAIL" for x in checks) else "PASS"}
    except Exception as exc:
        report = {"asset": os.path.basename(path), "status": "FAIL",
                  "checks": checks + [{"check": "parse", "status": "FAIL", "detail": f"{type(exc).__name__}: {exc}"}]}
    return report

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("--json", dest="json_path")
    args = ap.parse_args()
    report = validate(args.glb)
    rendered = json.dumps(report, indent=2)
    print(rendered)
    if args.json_path:
        with open(args.json_path, "w", encoding="utf-8") as f:
            f.write(rendered + "\n")
    return 1 if report["status"] == "FAIL" else 0

if __name__ == "__main__":
    sys.exit(main())
