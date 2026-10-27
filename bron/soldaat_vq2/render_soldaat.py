"""Cycles-renders van de soldaat-varianten: close-up, schuin en de gamecamera (58 graden, 28 m, 45 graden FOV)."""
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector
from PIL import Image

LOOKS = {
    "eigen": ("Lijf_Uniform", ["Helm", "Vest", "Koppel", "Rugzak", "Laarzen"]),
    "speler_bloot": ("Lijf_Bloot", ["Hoofdband", "Koppel", "Laarzen"]),
    "speler_mouwloos": ("Lijf_Mouwloos", ["Hoofdband", "Koppel", "Laarzen"]),
    "speler_vest": ("Lijf_Uniform", ["Hoofdband", "Vest", "Koppel", "Laarzen"]),
    "vijand_knife": ("Lijf_Vijand", ["Bandana", "Laarzen_V"]),
    "vijand_rifle": ("Lijf_Vijand", ["Boonie", "Borsttuig", "Laarzen_V"]),
    "vijand_rocket": ("Lijf_Vijand", ["Pet", "Raketzak", "Laarzen_V"]),
    "vijand_heavy": ("Lijf_Vijand", ["Staalhelm", "Patroongordels", "Laarzen_V"]),
}
TINT = {"eigen": "5a6a36", "speler_bloot": "4b5a2c", "speler_mouwloos": "4b5a2c", "speler_vest": "4b5a2c",
        "vijand_knife": "4c5056", "vijand_rifle": "8c7b52", "vijand_rocket": "5a4a3a", "vijand_heavy": "3e4a2b"}
BAND = "c0140f"


def _rgb(hx):
    return [((int(hx[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4)] + [1]


def uniform_tint(hx):
    """Zelfde formule als SoldierModel.uniform_tint(): kleurtoon van de uniformkleur, helderheid beperkt."""
    c = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    mx = max(max(c), 1e-3)
    lum = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    k = 0.42 * min(max(mx / 0.35, 0.45), 1.0)
    return [((lum / mx + (v / mx - lum / mx) * 0.85) * k) ** 2.2 for v in c] + [1]


def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("SAMPLES", 32))
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    sc.world = w
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.62, 0.70, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN"))
    sun.data.energy = 4.0
    sun.data.angle = 0.05
    sun.rotation_euler = (math.radians(40), 0, math.radians(-38))
    sc.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=40)
    g = bpy.context.active_object
    g.name = "grond"
    m = bpy.data.materials.new("grond")
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.15, 0.09, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    g.data.materials.append(m)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def show(look):
    body, gear = LOOKS[look]
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name != "grond":
            o.hide_render = not (o.name == body or o.name in gear)
    for m in bpy.data.materials:
        if not (m.name.endswith("_Kleding") or m.name == "Hoofdband"):
            continue
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        mix = nt.nodes.get("tint")
        if mix is None:
            src = bsdf.inputs["Base Color"].links[0].from_node
            mix = nt.nodes.new("ShaderNodeMix")
            mix.name = "tint"
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1
            nt.links.new(src.outputs["Color"], mix.inputs[6])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        # Godot: lineaire textuur x lineaire albedo_color
        mix.inputs[7].default_value = _rgb(BAND) if m.name == "Hoofdband" else uniform_tint(TINT[look])


def pose(rig, action, frame):
    rig.animation_data_create()
    act = bpy.data.actions.get(action)
    rig.animation_data.action = act
    if act is not None and act.slots:
        rig.animation_data.action_slot = act.slots[0]
    bpy.context.scene.frame_set(frame)


def shot(sc, cam, path, pos, target, lens=50, res=(600, 800)):
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.data.lens = lens
    cam.location = pos
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def sheet(paths, out):
    ims = [Image.open(p) for p in paths]
    c = Image.new("RGB", (sum(i.width for i in ims), max(i.height for i in ims)))
    x = 0
    for i in ims:
        c.paste(i, (x, 0))
        x += i.width
    c.save(out)


def run(out, rig, log, looks=None, action="stil", frame=5):
    out = Path(out) / "renders"
    out.mkdir(parents=True, exist_ok=True)
    sc, cam = setup_scene()
    pose(rig, action, frame)
    looks = looks or list(LOOKS)
    near, game, heads = [], [], []
    # gamecamera: 58 graden hoogte, 28 m afstand, 45 graden FOV (36 mm sensor -> lens 43,5)
    el = math.radians(58)
    gpos = (0, -28 * math.cos(el), 28 * math.sin(el) + 0.9)
    for lk in looks:
        show(lk)
        p = out / f"{lk}_schuin.png"
        shot(sc, cam, p, (1.9, -2.9, 1.9), (0, 0, 0.95), 50)
        near.append(p)
        hd = out / f"{lk}_hoofd.png"
        shot(sc, cam, hd, (-0.15, -0.95, 1.62), (0, 0, 1.56), 70, (400, 400))
        heads.append(hd)
        g = out / f"{lk}_game.png"
        shot(sc, cam, g, gpos, (0, 0, 0.9), 43.5, (1200, 1200))
        Image.open(g).crop((520, 470, 680, 670)).resize((240, 300), Image.NEAREST).save(g)
        game.append(g)
        log("render", lk)
    sheet(near, out / "overzicht_schuin.png")
    sheet(game, out / "overzicht_game.png")
    sheet(heads, out / "overzicht_hoofd.png")
