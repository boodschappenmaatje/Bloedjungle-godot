"""poort.glb met een stuk muur en palen erbij, alleen voor het 3D-voorbeeld (niet voor de game)."""
import sys, os, bpy
blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
def blk(name, loc, size, col):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*[c ** 2.2 for c in col], 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    o.data.materials.append(m)
    bpy.ops.object.transform_apply(scale=True)
blk("muurL", (-2.4 - 4, 0, 0.775), (8, 0.4, 1.55), (0.55, 0.55, 0.52))
blk("muurR", (2.4 + 4, 0, 0.775), (8, 0.4, 1.55), (0.55, 0.55, 0.52))
for sx in (-1, 1):
    blk("paal", (sx * 2.7, 0, 1.05), (0.7, 0.7, 2.1), (0.38, 0.38, 0.36))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_yup=True, export_animation_mode="SCENE", export_force_sampling=True)
