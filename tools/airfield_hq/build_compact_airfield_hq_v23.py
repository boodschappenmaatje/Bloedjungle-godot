"""Build the compact Airfield HQ review source and runtime LODs.

Run with Blender 4.5.15 from the repository root:
  blender -b assets/airfield_hq_v22/high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend --python tools/airfield_hq/build_compact_airfield_hq_v23.py -- --lod 0
Repeat with --lod 1 and --lod 2. The protected 2.2 input is read-only; output
goes to versioned HQ 2.3 review/export paths.
"""
import bpy
import os
import sys
import json

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE = os.path.join(ROOT, "assets/airfield_hq_v22/high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend")
SOURCE_COPY = os.path.join(ROOT, "source_assets/airfield_hq_v23/hangar/Bloedjungle_Airfield_HQ_23_Compact_Review.blend")
OUT = os.path.join(ROOT, "assets/airfield_hq_v23/hangar")
LOD_NAMES = {"01_Hangar_HQ_22", "02_Hangar_Sliding_Doors", "07_Hangar_Service_Props_22"}

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
level = int(args[args.index("--lod") + 1]) if "--lod" in args else 0
if level not in (0, 1, 2):
    raise ValueError("LOD must be 0, 1, or 2")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(SOURCE_COPY), exist_ok=True)

def set_key(curve, frame, value):
    for key in curve.keyframe_points:
        if abs(key.co.x - frame) < 0.001:
            key.co.y = value
    curve.update()


def fix_gltf_albedo_links():
    """Use one explicit approved diffuse map for each glTF base-color input.

    Several HQ22 Blender materials mix AO into their albedo with a Blender-only
    node chain. glTF accepts one base-color sampler; the exporter warned that
    it would use only the first image. This derivative connects that same
    approved diffuse image directly and leaves the ORM and normal chains intact.
    """
    changed = []
    used_materials = set()
    for collection_name in LOD_NAMES:
        for obj in bpy.data.collections[collection_name].objects:
            if obj.type == "MESH":
                used_materials.update(mat for mat in obj.data.materials if mat)
    for material in used_materials:
        if not material.use_nodes or not material.node_tree:
            continue
        principled = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        base_input = principled.inputs.get("Base Color")
        if base_input is None or not base_input.is_linked:
            continue
        diffuse = next((node for node in material.node_tree.nodes
                        if node.type == "TEX_IMAGE" and node.image
                        and "diff" in os.path.basename(node.image.filepath).lower()), None)
        if diffuse is None or (len(base_input.links) == 1 and base_input.links[0].from_node == diffuse):
            continue
        for link in list(base_input.links):
            material.node_tree.links.remove(link)
        material.node_tree.links.new(diffuse.outputs["Color"], base_input)
        changed.append(material.name)
    return sorted(changed)


fixed_albedo_materials = fix_gltf_albedo_links()

# Apply independent transforms to authored hangar geometry and service dressing.
# The original source remains untouched. Blender axes are X/Y ground, Z up.
for collection_name in LOD_NAMES:
    collection = bpy.data.collections.get(collection_name)
    if collection is None:
        raise RuntimeError(f"Missing source collection: {collection_name}")
    for obj in collection.objects:
        if obj.parent is not None:
            continue
        if collection_name == "07_Hangar_Service_Props_22":
            factors = (0.38, 0.40, 0.45)
        else:
            factors = (0.50, 0.50, 0.45)
        obj.location.x *= factors[0]
        obj.location.y *= factors[1]
        obj.location.z *= factors[2]
        obj.scale.x *= factors[0]
        obj.scale.y *= factors[1]
        obj.scale.z *= factors[2]

        # The 2.2 hangar collection includes two 65 m door guides that extend
        # well beyond its 44 m shell. They are serviceable steel guides, not
        # visual silhouette detail; retain their source mesh/material and full
        # cross section while trimming only their linear span to the compact
        # 22 m portal, so the compact asset's measured envelope is truthful.
        if obj.name in {"Door overhead I-beam track", "Inset lower steel guide"}:
            obj.dimensions.x = 22.0
        if obj.name.startswith("Sliding portal guide post"):
            side = -1.0 if obj.location.x < 0.0 else 1.0
            obj.location.x = side * (11.0 if abs(obj.location.x) > 13.0 else 7.5)
        if obj.name.startswith("Portal trolley roller"):
            obj.location.x *= 0.67

        if obj.type == "MESH" and obj.name.startswith("Hangar sliding door"):
            side = -1.0 if "LEFT" in obj.name else 1.0
            action_name = "Open_Left_Door" if side < 0 else "Open_Right_Door"
            obj.location.x = side * 3.75
            obj.location.y = -9.775
            obj.location.z = 2.9925
            obj.scale.x = 0.36 # 20.47 m source leaf -> 7.37 m leaf
            action = bpy.data.actions.get(action_name)
            if action is not None:
                for curve in action.fcurves:
                    if curve.data_path != "location":
                        continue
                    if curve.array_index == 0:
                        set_key(curve, 1.0, side * 3.75)
                        set_key(curve, 90.0, side * 11.25)
                        set_key(curve, 120.0, side * 11.25)
                    elif curve.array_index == 1:
                        for key in curve.keyframe_points:
                            key.co.y *= 0.50
                    elif curve.array_index == 2:
                        for key in curve.keyframe_points:
                            key.co.y *= 0.45
                    curve.update()

        if obj.type == "LIGHT" and "warm" in obj.name.lower() and "workshop" in obj.name.lower():
            # Keep the five actual fixtures as controllable, local practicals;
            # the 38 kW / 4096 m imports were the source of blown-out scenes.
            obj.data.energy = 2.0
            if hasattr(obj.data, "cutoff_distance"):
                obj.data.cutoff_distance = 6.0
            if hasattr(obj.data, "use_custom_distance"):
                obj.data.use_custom_distance = True
            obj.data.use_shadow = False

# Close the 3.5 m shoulders beside the new 15 m sliding-door opening. They are
# added only to this derivative, use the source hangar's approved olive-steel
# material, and have matching scene collision proxies.
hangar = bpy.data.collections["01_Hangar_HQ_22"]
jamb_material = bpy.data.materials.get("USAAF olive drab painted steel")
if jamb_material is None:
    raise RuntimeError("Approved olive steel material is missing")
for side, label in [(-1.0, "Left"), (1.0, "Right")]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side * 9.25, -9.775, 3.0))
    jamb = bpy.context.object
    jamb.name = f"Compact Hangar Door Jamb {label}"
    jamb.dimensions = (3.5, 0.35, 6.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    jamb.data.materials.append(jamb_material)
    for owner in list(jamb.users_collection):
        owner.objects.unlink(jamb)
    hangar.objects.link(jamb)

if level == 0:
    bpy.context.scene.frame_set(1)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_COPY)

# Keep one authored mesh node per major shell/interior component. The door
# collection stays split because the two moving leaves have distinct actions.
def join_static(collection_name, target_name):
    collection = bpy.data.collections[collection_name]
    objects = [o for o in collection.objects if o.type == "MESH" and not o.name.startswith("COL_")
               and not o.data.shape_keys and not (o.animation_data and o.animation_data.action)]
    if len(objects) < 2:
        if objects:
            objects[0].name = target_name
        return
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.convert(target="MESH")
    objects = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = target_name

join_static("01_Hangar_HQ_22", "Hangar HQ 22")
join_static("07_Hangar_Service_Props_22", "Hangar Service Props 22")

if level in (1, 2):
    # Distance tiers retain the same transforms/materials with real mesh reduction.
    ratio = 0.48 if level == 1 else 0.24
    for collection_name in LOD_NAMES:
        collection = bpy.data.collections[collection_name]
        for obj in collection.objects:
            if obj.type != "MESH" or obj.name.startswith("COL_") or obj.data.shape_keys:
                continue
            if obj.animation_data and obj.animation_data.action:
                continue
            if len(obj.data.polygons) < 80:
                continue
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            modifier = obj.modifiers.new(f"Compact LOD{level} reduction", "DECIMATE")
            modifier.ratio = ratio
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            obj.select_set(False)

selected = []
for collection_name in LOD_NAMES:
    for obj in bpy.data.collections[collection_name].objects:
        if obj.type in {"MESH", "LIGHT"} and not obj.name.startswith("COL_"):
            selected.append(obj)
if not selected:
    raise RuntimeError("No compact airfield objects selected")
for obj in selected:
    if obj.type != "MESH" or (obj.data.shape_keys and len(obj.data.shape_keys.key_blocks) > 1):
        continue
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("Compact glTF triangle preparation", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action="DESELECT")
for obj in selected:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(o for o in selected if o.type == "MESH")

name = f"Airfield_HQ_23_Compact_LOD{level}"
path = os.path.join(OUT, name + ".glb")
options = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
               export_texcoords=True, export_normals=True, export_tangents=True,
               export_materials="EXPORT", export_image_format="AUTO",
               export_animations=(level == 0), export_nla_strips=False,
               export_force_sampling=True, export_frame_range=True,
               export_cameras=False, export_lights=(level == 0),
               export_skins=False, export_morph=True)
known = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
result = bpy.ops.export_scene.gltf(**{key: value for key, value in options.items() if key in known})
if "FINISHED" not in result:
    raise RuntimeError(f"glTF export failed: {result}")

meshes = [obj for obj in selected if obj.type == "MESH"]
triangles = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in meshes)
report = {"asset": "Bloedjungle Airfield HQ 2.3 Compact", "source": "protected HQ 2.2 source; transformed review copy",
          "blender": bpy.app.version_string, "lod": level, "units": "metres",
          "mesh_objects": len(meshes), "triangles": triangles,
          "light_nodes": sum(1 for obj in selected if obj.type == "LIGHT") if level == 0 else 0,
          "door_clear_width_m": 15.0, "door_clear_height_m": 5.89,
          "door_leaf_width_m": 7.37, "door_wing_margin_each_side_m": 1.28,
          "clear_interior_m": [15.0, 13.0, 6.0],
          "gltf_albedo_material_fixes": fixed_albedo_materials,
          "animations": ["Open_Left_Door", "Open_Right_Door"] if level == 0 else [],
          "glb": os.path.relpath(path, ROOT), "bytes": os.path.getsize(path)}
with open(os.path.join(OUT, name + "_metrics.json"), "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
print("AIRFIELD_HQ_23_COMPACT", json.dumps(report))
