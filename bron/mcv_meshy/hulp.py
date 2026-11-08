"""Gedeelde Blender-hulpjes voor de MCV-stappen (module en poot): delen uit de voxel-schil halen, dichtmaken, decimeren, UV's."""
import numpy as np
import bpy, bmesh


def alleen(view, *objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = objs[0]


def maak_object(scene, naam, verts, faces):
    me = bpy.data.meshes.new(naam)
    me.from_pydata(np.asarray(verts, np.float32).tolist(), [], [list(map(int, f)) for f in faces])
    me.update()
    ob = bpy.data.objects.new(naam, me)
    scene.collection.objects.link(ob)
    return ob


def deel_uit_schil(scene, naam, game, tri, mask):
    t = tri[mask]
    used = np.unique(t.ravel())
    remap = np.full(len(game), -1, np.int64)
    remap[used] = np.arange(len(used))
    return maak_object(scene, naam, game[used], remap[t])


def dichtmaken(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    rand = [e for e in bm.edges if e.is_boundary]
    n0 = len(rand)
    if rand:
        res = bmesh.ops.holes_fill(bm, edges=rand, sides=100000)
        bmesh.ops.triangulate(bm, faces=res["faces"])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rest = sum(1 for e in bm.edges if e.is_boundary)
    bm.to_mesh(ob.data); bm.free()
    print("  %s: %d randranden dichtgemaakt, %d over" % (ob.name, n0, rest), flush=True)


def decimeer(view, ob, doel):
    n = len(ob.data.polygons)
    if n <= doel:
        return
    alleen(view, ob)
    m = ob.modifiers.new("Decimate", "DECIMATE")
    m.ratio = doel / n
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)


def uv_atlas(view, atlas):
    for o in atlas:
        while len(o.data.uv_layers):
            o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name="UVMap")
    alleen(view, *atlas)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.003, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in atlas:
        for pl in o.data.polygons:
            pl.use_smooth = True
