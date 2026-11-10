"""Meshy-begroeiing (kokospalm, varen, jungleboom) -> spelversie.
Invoer: de verkleinde meesters (stap1_verklein.py of gltfpack, zie README) in <meesters>/ (palm, varen, boom, heliconia, 2 keien, 2 stammen). Uitvoer: <uit>/meshy_flora.glb met per soort een nabij- en een ver-model.
Per model: voet op de grond (z=0) en midden op de oorsprong, echte maat in meters, windgewicht in de alfa van de
vertexkleur (0 = vast, 1 = losse bladpunt, zoals shaders/foliage.gdshader verwacht), texturen verkleind.
Gebruik: python3 stap2_spel.py <meesters> <uit>"""
import bpy, sys, os, math
from mathutils import Vector

MEESTERS = os.path.abspath(sys.argv[-2])
UIT = os.path.abspath(sys.argv[-1])
os.makedirs(UIT, exist_ok=True)

# soort -> (meester, maat in m, maat-as ("z" = hoogte, "max" = grootste afmeting, "lang" = langste as komt langs Z),
#           [(modelnaam, driehoeken)], windgewicht (van, tot) als deel van de hoogte, albedo-pixels, normaal-pixels)
SOORTEN = {
    "Palm": ("palm_40k.glb", 6.6, "z", [("Meshy_Palm", 5000), ("Meshy_Palm_far", 800)], (0.45, 0.85), 2048, 1024),
    "Varen": ("varen_40k.glb", 1.15, "z", [("Meshy_Varen", 2500)], (0.05, 0.6), 1024, 512),
    # de boom is met gltfpack (-sa) voorverkleind: Blender-collapse loopt vast op haar UV-randen
    "Boom": ("boom_30k.glb", 13.0, "z", [("Meshy_Boom", 30000)], (0.5, 1.0), 2048, 1024),
    "BoomVer": ("boom_2k.glb", 13.0, "z", [("Meshy_Boom_far", 2000)], (0.5, 1.0), 1024, 512),
    "Heli": ("heliconia_11k.glb", 1.0, "z", [("Meshy_Heli", 6000)], (0.1, 0.7), 1024, 512),
    "KeiA": ("kei_mos_a_40k.glb", 0.9, "max", [("Meshy_KeiA", 2500)], (1.0, 1.0), 1024, 512),
    "KeiB": ("kei_mos_b_40k.glb", 0.9, "max", [("Meshy_KeiB", 2500)], (1.0, 1.0), 1024, 512),
    "StamA": ("stam_a_9k.glb", 3.0, "lang", [("Meshy_StamA", 3500)], (1.0, 1.0), 1024, 512),
    "StamB": ("stam_b_16k.glb", 3.0, "lang", [("Meshy_StamB", 3500)], (1.0, 1.0), 1024, 512),
}


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def laad(pad):
    bpy.ops.import_scene.gltf(filepath=pad)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"][-1]


def maak_lod(master, naam, tris, hoogte, wind, px_a, px_n, eerste, as_):
    o = master.copy()
    o.data = master.data.copy()
    o.name = naam
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects:
        x.select_set(False)
    o.select_set(True)
    n = len(o.data.polygons)
    while n > tris * 1.03:
        m = o.modifiers.new("d", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = max(tris / n, 0.25)
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="d")
        voor, n = n, len(o.data.polygons)
        print(naam, "->", n, flush=True)
        if n > voor * 0.995:   # kan niet verder (UV-randen): stoppen, anders loopt het eindeloos
            break
    # langste as langs Z (stammen), dan voet op de grond, midden op de oorsprong, echte maat
    me = o.data
    if as_ == "lang":
        ext = [max(v.co[i] for v in me.vertices) - min(v.co[i] for v in me.vertices) for i in range(3)]
        k = ext.index(max(ext))
        if k != 2:
            for v in me.vertices:
                c = v.co.copy()
                if k == 0:
                    v.co = Vector((c.z, c.y, c.x))
                else:
                    v.co = Vector((c.x, c.z, c.y))
            me.flip_normals()
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    zmin, zmax = min(zs), max(zs)
    if as_ == "lang":
        zc = (zmin + zmax) / 2
        s = hoogte / (zmax - zmin)
        for v in me.vertices:
            v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - zc) * s))
        hoogte = hoogte / 2
    else:
        dim = (zmax - zmin) if as_ == "z" else max(zmax - zmin, max(xs) - min(xs), max(ys) - min(ys))
        s = hoogte / dim
        for v in me.vertices:
            v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - zmin) * s))
        if as_ == "max":
            hoogte = (zmax - zmin) * s
    # windgewicht in de alfa van de vertexkleur
    for ca in list(me.color_attributes):
        me.color_attributes.remove(ca)
    ca = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    for v in me.vertices:
        h = (v.co.z / hoogte) if wind[0] < 1.0 else 0.0
        w = smooth(wind[0], wind[1], h) if wind[1] > wind[0] else 0.0
        ca.data[v.index].color = (1.0, 1.0, 1.0, w)
    me.color_attributes.active_color = ca
    # texturen verkleinen (eenmalig per materiaal)
    if eerste:
        for mat in me.materials:
            for nd in mat.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image is not None:
                    img = nd.image
                    kleur = nd.image.colorspace_settings.name == "sRGB"
                    px = px_a if kleur else px_n
                    if img.size[0] > px:
                        img.scale(px, px)
    print(naam, "tris", len(me.polygons), "hoogte", round(hoogte, 2))
    return o


bpy.ops.wm.read_factory_settings(use_empty=True)
uit = []
for soort, (bestand, h, as_, lods, wind, pa, pn) in SOORTEN.items():
    pad = os.path.join(MEESTERS, bestand)
    if not os.path.exists(pad):
        print("ONTBREEKT", pad)
        continue
    master = laad(pad)
    master.name = "master_" + soort
    for i, (naam, tris) in enumerate(lods):
        uit.append(maak_lod(master, naam, tris, h, wind, pa, pn, i == 0, as_))
    master.hide_set(True)
    bpy.data.objects.remove(master, do_unlink=True)

for o in bpy.context.scene.objects:
    o.select_set(o in uit)
bpy.ops.export_scene.gltf(filepath=os.path.join(UIT, "meshy_flora.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=88, export_vertex_color="ACTIVE", export_yup=True)
print("klaar")
