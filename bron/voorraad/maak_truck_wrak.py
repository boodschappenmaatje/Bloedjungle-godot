"""Wrak van de voorraadtruck (Generals-plan stap 4b): uitgebrand, scheef op platte banden, de kraan slap neergezakt, verkoolde kisten ernaast.

    python bron/voorraad/maak_truck_wrak.py hq|game   # uit/Voorraadtruck_wrak_HQ.blend  |  assets/voorraadtruck_wrak.glb

Hergebruikt de onderdelen van de heile truck (maak_truck.py), met verbrande materialen. Geen animatie; Godot zet dit model in de plaats van
`Voorraadtruck` zodra de truck sneuvelt (zelfde oorsprong en voorkant +z).
"""
import math
import random

import maak_truck as MT
from vc import *  # noqa: F401,F403


# verkoold: bijna zwart, geen afbladderende verf en nauwelijks stof; alleen roest op de randen
B.KINDS["burnt"] = dict(chip=(0.05, 0.045, 0.04), chip_metal=0.0, dirt=0.35, mud=0.1, streak=0.45, edge=0.08, rust=0.25, moss=0.0, dust=0.06,
                        metal_scale=0.0, bump=0.5)


def main():
    sc = fresh_scene()
    M = materials()
    char = B.weathered("VR_Verkoold", "burnt", color=(0.028, 0.026, 0.023), rough=0.93, seed=21)
    char2 = B.weathered("VR_Verkoold_licht", "burnt", color=(0.06, 0.054, 0.046), rough=0.9, seed=22)
    rust = B.weathered("VR_Roest", "burnt", color=(0.17, 0.085, 0.04), rough=0.85, metal=0.4, seed=23)
    for k in ("olijf", "geel", "gevaar", "wit", "hout"):
        M[k] = char
    M["olijf2"] = char2
    M["staal"] = rust
    M["glas"] = char
    for k in ("amber", "rood", "wit_lamp"):
        M[k] = char
    root = bpy.data.objects.new("Voorraadtruck_wrak", None)
    sc.collection.objects.link(root)
    objs = MT.build(root, M)
    for o in objs:                           # geen stencilletters en embleem meer: verbrand
        if o.name == "Stencil":
            bpy.data.objects.remove(o, do_unlink=True)
    wheels, wobjs = MT.build_wheels(root, M)
    parts, cobjs = MT.build_crane(M, root)
    for w in wheels:                         # platte, verkoolde banden: lager en breder
        w.scale = (1.0, 1.0, 0.78)
        w.location.z -= 0.1
    parts["kolom"].rotation_mode = "XYZ"
    parts["kolom"].rotation_euler = (0, 0, 2.45)             # de kraan is opzij weggezakt
    parts["giek"].rotation_euler = (-0.38, 0, 0)
    parts["mid"].location = P(0, 0, -0.9)
    parts["uit"].location = P(0, 0, -0.9)
    parts["kp"].rotation_euler = (0.38, 0, 0)
    parts["ketting"].scale = (1, 1, 0.9)
    parts["grab"].location = P(0, -0.9, 0)
    for (sx, sz), c in parts["claws"].items():
        c.rotation_euler = (0, -sx * 0.9, 0)
    # de hele truck staat scheef en een klein stukje in de grond
    root.rotation_euler = (0.0, 0.07, 0.0)
    root.location = P(0, -0.12, 0)
    # verkoolde kisten en wrakstukken in de buurt
    gs, gm, gy, gk = G(), G(), G(), bmesh.new()
    rng = random.Random(9)
    for i, c in enumerate(((1.9, 0.36, -2.6), (-2.1, 0.36, -1.2), (2.2, 0.36, 0.9))):
        crate(gs, gm, gy, gk, c, yaw=rng.uniform(-0.8, 0.8), stencil=None, size=MT.CB)
    commit("Wrak_kisten", gs, char2, None, tile=1.0, bevel=D >= 1)
    commit("Wrak_beslag", gm, rust, None, tile=0.5, bevel=False)
    gk.free()
    for o in list(bpy.data.objects):
        if o.name.startswith("Wrak_") and o.parent is None:
            o.parent = root
    print(f"[{LEVEL}] driehoeken (voor snoeien): {tri_count()}")
    if LEVEL != "hq":
        bake_groups([("wrak", bakeable())])
    print(f"[{LEVEL}] driehoeken: {tri_count()}  materialen: {len(bpy.data.materials)}")
    stem = {"hq": "Voorraadtruck_wrak_HQ", "game": "voorraadtruck_wrak", "lod1": "voorraadtruck_wrak"}[LEVEL]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen:", OUT / f"{stem}.blend")
        return
    export_glb(ROOT / "assets" / f"{stem}.glb")
    if LEVEL == "game":
        export_usdz(OUT / "Voorraadtruck_wrak.usdz")


if __name__ == "__main__":
    main()
