"""Stap 5: LOD1 (statisch, ~3.200 driehoeken, eigen 1K-textuur van de bron gebakken) en wrak (statische kraanpose, verkoold) van de Meshy-vrachtwagen.
Leest cache/gebakken.blend (LOD1) en uit/voorraadtruck_meshy.blend (wrak); schrijft uit/voorraadtruck_meshy_lod1.glb en uit/voorraadtruck_meshy_wrak.glb
(+ de .blend's). Gebruik: python3 stap5_lod_wrak.py <cache-map> <uit-map> [lod|wrak]"""
import sys, time, math
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen as D

CACHE, UIT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
WAT = sys.argv[3] if len(sys.argv) > 3 else "beide"
LOD_TRIS = 3200
LOD_TEX = 1024
t0 = time.time()
view = None


def alleen(*objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = active or objs[0]



def externaliseer(map_, namen=None):
    """de gebakken beelden als JPEG naast de .blend (anders zit er 15 MB aan PNG in elke .blend); zonder weergavetransformatie"""
    map_ = Path(map_); map_.mkdir(parents=True, exist_ok=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)   # verwijderde objecten laten hun materialen en beelden achter
    for im in list(bpy.data.images):
        if im.users == 0 or im.name.startswith("Image_") or im.type != "IMAGE":    # restanten van de bron-import en ongebruikte beelden
            bpy.data.images.remove(im)
            continue
        if im.size[0] < 8 or (namen and im.name not in namen):
            continue
        pad = map_ / (im.name + (".png" if im.name.startswith("Kist") else ".jpg"))
        im.filepath_raw = str(pad)
        im.file_format = "PNG" if pad.suffix == ".png" else "JPEG"
        im.save()
        if im.packed_file:
            im.unpack(method="REMOVE")
        im.filepath = str(pad)
        im.source = "FILE"
        im.reload()


def exporteer(pad):
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.ops.export_scene.gltf(filepath=str(pad), export_format="GLB", use_selection=False, export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False, export_image_format="JPEG",
                              export_jpeg_quality=86, export_animations=False)


def nieuw_beeld(naam, b, h, kleur):
    im = bpy.data.images.new(naam, b, h, alpha=False, float_buffer=False)
    im.colorspace_settings.name = "sRGB" if kleur else "Non-Color"
    return im


def verbind(mat, alb, nrm, orm):
    nt = mat.node_tree; pr = nt.nodes["Principled BSDF"]; lk = nt.links
    na = nt.nodes.new("ShaderNodeTexImage"); na.image = alb
    lk.new(na.outputs["Color"], pr.inputs["Base Color"])
    no = nt.nodes.new("ShaderNodeTexImage"); no.image = orm
    sep = nt.nodes.new("ShaderNodeSeparateColor"); lk.new(no.outputs["Color"], sep.inputs["Color"])
    lk.new(sep.outputs["Green"], pr.inputs["Roughness"]); lk.new(sep.outputs["Blue"], pr.inputs["Metallic"])
    nn = nt.nodes.new("ShaderNodeTexImage"); nn.image = nrm
    nm = nt.nodes.new("ShaderNodeNormalMap"); lk.new(nn.outputs["Color"], nm.inputs["Color"]); lk.new(nm.outputs["Normal"], pr.inputs["Normal"])
    for im in (alb, nrm, orm):
        im.pack()


# ------------------------------------------------------------------ LOD1
def lod1():
    global view
    bpy.ops.wm.open_mainfile(filepath=str(CACHE / "gebakken.blend"))
    scene = bpy.context.scene; view = bpy.context.view_layer
    scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = 4
    hoog = bpy.data.objects["Truck_HQ"]; hoog.hide_render = False; hoog.hide_viewport = False
    mat_hoog = hoog.data.materials[0]
    bsdf = next(n for n in mat_hoog.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    delen = [o for o in bpy.data.objects if o.type == "MESH" and o is not hoog]
    for o in delen:
        o.hide_render = True; o.hide_viewport = True
    # LOD1 uit de gesloten voxel-schil van stap 1 (2 cm), grover opnieuw gevoxeld (8 cm) en dan decimeren: dat houdt vorm en wielen beter dan
    # de losse delen samenvoegen en decimeren
    d = np.load(CACHE / "voxel.npz")
    game = D.naar_spel(d["co"] / D.SCHAAL).astype(np.float32)
    tri = d["tri"].astype(np.int32)
    me = bpy.data.meshes.new("Voorraadtruck_LOD1")
    me.vertices.add(len(game)); me.vertices.foreach_set("co", game.ravel())
    me.loops.add(len(tri) * 3); me.loops.foreach_set("vertex_index", tri.ravel())
    me.polygons.add(len(tri)); me.polygons.foreach_set("loop_start", np.arange(len(tri), dtype=np.int32) * 3)
    me.polygons.foreach_set("loop_total", np.full(len(tri), 3, np.int32))
    me.update(); me.validate()
    laag = bpy.data.objects.new("Voorraadtruck_LOD1", me); scene.collection.objects.link(laag)
    alleen(laag)
    laag.data.remesh_voxel_size = 0.08; laag.data.remesh_voxel_adaptivity = 0.0
    bpy.ops.object.voxel_remesh()
    bm = bmesh.new(); bm.from_mesh(laag.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(laag.data); bm.free()
    n0 = len(laag.data.polygons)
    print("LOD1 voxelschil %d driehoeken, %.0f s" % (n0, time.time() - t0), flush=True)
    alleen(laag)
    m = laag.modifiers.new("Decimate", "DECIMATE"); m.ratio = LOD_TRIS / n0; m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
    laag.data.validate()
    laag.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pl in laag.data.polygons:
        pl.use_smooth = True
    print("LOD1: %d -> %d driehoeken, %.0f s" % (n0, len(laag.data.polygons), time.time() - t0), flush=True)
    mat = bpy.data.materials.new("VR_Meshy_truck_lod1"); mat.use_nodes = True; mat.use_backface_culling = False
    laag.data.materials.append(mat)
    nt = mat.node_tree

    def bak(im, soort, **kw):
        node = nt.nodes.new("ShaderNodeTexImage"); node.image = im; nt.nodes.active = node
        alleen(hoog, laag, active=laag)
        bpy.ops.object.bake(type=soort, use_selected_to_active=True, cage_extrusion=0.14, max_ray_distance=0.30, margin=8, **kw)
        return node
    alb = nieuw_beeld("Truck_lod1_albedo", LOD_TEX, LOD_TEX, True); n1 = bak(alb, "DIFFUSE", pass_filter={"COLOR"})
    nrm = nieuw_beeld("Truck_lod1_normal", LOD_TEX, LOD_TEX, False); n2 = bak(nrm, "NORMAL", normal_space="TANGENT")

    def kanaal(sok):
        src = bsdf.inputs[sok]
        van = src.links[0].from_socket if src.links else None
        em = mat_hoog.node_tree.nodes.new("ShaderNodeEmission")
        uit_ = next(n for n in mat_hoog.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
        oud = uit_.inputs["Surface"].links[0].from_socket
        if van:
            mat_hoog.node_tree.links.new(van, em.inputs["Color"])
        else:
            v = src.default_value; em.inputs["Color"].default_value = (v, v, v, 1)
        mat_hoog.node_tree.links.new(em.outputs[0], uit_.inputs["Surface"])
        im = nieuw_beeld("tmp_" + sok, LOD_TEX, LOD_TEX, False)
        nd = bak(im, "EMIT")
        mat_hoog.node_tree.links.new(oud, uit_.inputs["Surface"]); mat_hoog.node_tree.nodes.remove(em); nt.nodes.remove(nd)
        arr = np.array(im.pixels[:], np.float32).reshape(-1, 4)[:, 0]
        bpy.data.images.remove(im)
        return arr
    ruw = kanaal("Roughness"); met = kanaal("Metallic")
    a = np.array(alb.pixels[:], np.float32).reshape(-1, 4)[:, :3]
    staal = (a.max(1) - a.min(1) < 0.07) & (a.max(1) < 0.25)
    met = np.where(staal, np.clip(met, 0.45, 0.8), 0.0)
    ruw = np.where(staal, np.clip(ruw, 0.4, 0.75), np.clip(ruw, 0.6, 0.95))
    orm = np.ones((LOD_TEX * LOD_TEX, 4), np.float32); orm[:, 1] = ruw; orm[:, 2] = met
    o_im = nieuw_beeld("Truck_lod1_orm", LOD_TEX, LOD_TEX, False); o_im.pixels.foreach_set(orm.ravel())
    nt.nodes.remove(n1); nt.nodes.remove(n2)
    verbind(mat, alb, nrm, o_im)
    for o in list(bpy.data.objects):
        if o is not laag:
            bpy.data.objects.remove(o)
    bpy.context.preferences.filepaths.save_version = 0
    externaliseer(UIT / "textures_lod1")
    bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "voorraadtruck_meshy_lod1.blend"), compress=True)
    exporteer(UIT / "voorraadtruck_meshy_lod1.glb")
    print("LOD1 klaar, %.0f s" % (time.time() - t0), flush=True)


# ------------------------------------------------------------------ wrak
def wrak():
    global view
    from PIL import Image
    bpy.ops.wm.open_mainfile(filepath=str(UIT / "voorraadtruck_meshy.blend"))
    scene = bpy.context.scene; view = bpy.context.view_layer
    ob = bpy.data.objects
    for o in ob:
        if o.animation_data:
            for tr in o.animation_data.nla_tracks:
                tr.mute = tr.name != "Laden"
    scene.frame_set(0)
    # kraan ingestort: giek half neergezakt, klauwen open op de grond, geen kist
    kolom, giek, uit, kp, grab, ketting, kist, tele = (ob[n] for n in ("Kolom", "Giek", "GiekUit", "Kettingpunt", "Grijper", "Ketting", "Kist_vast", "Telescoop"))
    for o in (kolom, giek, uit, kp, grab, ketting, kist, tele):
        o.animation_data_clear()
    kolom.rotation_euler = (0, 0, 0.9)
    giek.rotation_euler = (-0.10, 0, 0)
    ext = 1.0
    hoek = math.atan(0.27)
    uit.location = Vector(uit.location) + Vector((0, math.cos(hoek), math.sin(hoek))) * ext
    tele.scale = (1, 0.9 + ext, 1)
    kp.rotation_euler = (0.10, 0, 0)
    L = 2.2
    ketting.scale = (1, 1, L)
    grab.location = Vector(grab.location) + Vector((0, 0, -L))
    kist.scale = (0.001,) * 3
    for o in ob:
        if o.name.startswith("Klauw_"):
            o.animation_data_clear()
            o.rotation_quaternion = (1, 0, 0, 0)
    view.update()
    dg = bpy.context.evaluated_depsgraph_get()
    delen = []
    for o in ob:
        if o.type == "MESH" and o.name not in ("Kist_vast_mesh",) and not o.name.startswith("Truck_HQ"):
            e = o.evaluated_get(dg)
            me = bpy.data.meshes.new_from_object(e)
            me.transform(o.matrix_world)
            k = bpy.data.objects.new(o.name + "_w", me)
            scene.collection.objects.link(k)
            delen.append(k)
    for o in list(ob):
        if not o.name.endswith("_w"):
            bpy.data.objects.remove(o, do_unlink=True)
    alleen(*delen)
    bpy.ops.object.join()
    w = view.objects.active
    w.name = w.data.name = "Voorraadtruck_wrak"
    # inzakken en een beetje scheef, onderkant op de grond houden
    w.data.transform(Matrix.Rotation(0.05, 4, "Y") @ Matrix.Rotation(-0.02, 4, "X"))
    w.data.transform(Matrix.Translation((0, 0, -0.10)))
    for pl in w.data.polygons:
        pl.use_smooth = True
    n = len(w.data.polygons)
    # materialen: de atlas (VR_Meshy_truck) wordt een verkoolde kopie, VR_Staal blijft
    mats = {m.name: m for m in bpy.data.materials}
    atl = mats["VR_Meshy_truck"]
    nt = atl.node_tree
    tex = [x for x in nt.nodes if x.type == "TEX_IMAGE"]
    alb_node = next(x for x in tex if x.image and x.image.name.endswith("_albedo"))
    orm_node = next(x for x in tex if x.image and x.image.name.endswith("_orm"))
    alb = alb_node.image
    b, h = alb.size
    a = np.array(alb.pixels[:], np.float32).reshape(h, b, 4)
    rng = np.random.default_rng(11)

    def laag_freq(grootte, sterkte):
        z = rng.random((grootte, grootte)).astype(np.float32)
        im = Image.fromarray((z * 255).astype(np.uint8)).resize((b, h), Image.BICUBIC)
        return np.asarray(im, np.float32) / 255.0 * sterkte
    soot = np.clip(laag_freq(24, 1.0) * 0.9 + laag_freq(96, 1.0) * 0.5, 0, 1)
    roest = np.clip(laag_freq(40, 1.0) * 1.4 - 0.55, 0, 1)
    lum = a[:, :, :3].mean(axis=2, keepdims=True)
    donker = (a[:, :, :3] * 0.42 + lum * 0.12) * (0.35 + 0.65 * (1 - soot[:, :, None])) + 0.012
    rood = np.array([0.30, 0.13, 0.05], np.float32)
    uitkomst = donker * (1 - 0.55 * roest[:, :, None]) + rood * 0.22 * roest[:, :, None] * (0.4 + lum)
    out = a.copy(); out[:, :, :3] = np.clip(uitkomst, 0, 1)
    nieuw = nieuw_beeld("Wrak_albedo", b, h, True); nieuw.pixels.foreach_set(out.ravel()); nieuw.pack()
    alb_node.image = nieuw
    # ruwheid hoog, geen metaal behalve het blote staal
    o_im = orm_node.image
    o = np.array(o_im.pixels[:], np.float32).reshape(h, b, 4)
    o[:, :, 1] = np.clip(o[:, :, 1] * 0.2 + 0.8, 0.75, 0.98); o[:, :, 2] = o[:, :, 2] * 0.25
    o2 = nieuw_beeld("Wrak_orm", b, h, False); o2.pixels.foreach_set(o.ravel()); o2.pack()
    orm_node.image = o2
    for im in list(bpy.data.images):
        if im.name in ("Truck_albedo",) or im.name == "Kist_albedo":
            pass
    atl.name = "VR_Meshy_wrak"
    for im in bpy.data.images:
        if im.name.startswith("Truck_") and im.size[0] > 2048:
            im.scale(2048, 2048)
    bpy.context.preferences.filepaths.save_version = 0
    externaliseer(UIT / "textures_wrak")
    bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "voorraadtruck_meshy_wrak.blend"), compress=True)
    exporteer(UIT / "voorraadtruck_meshy_wrak.glb")
    print("wrak klaar: %d driehoeken, %.0f s" % (n, time.time() - t0), flush=True)


if WAT in ("lod", "beide"):
    lod1()
if WAT in ("wrak", "beide"):
    wrak()
