"""Stap 6: USDZ-previews voor iPhone Bestanden/Quick Look van de Meshy-vrachtwagen (rig met clip Laden) en het wrak.
Leest uit/voorraadtruck_meshy.blend en uit/voorraadtruck_meshy_wrak.blend, schrijft uit/Voorraadtruck.usdz en uit/Voorraadtruck_wrak.usdz.
De USDZ bevat PBR-materialen (albedo, ORM-ruwheid/metallic, normal) en de clip Laden (de clip Lossen niet: één animatie per bestand). Of de
animatie in Quick Look afspeelt is niet gecontroleerd (alleen macOS/iPhone).
Gebruik: python3 stap6_usdz.py <uit-map>"""
import sys
import bpy
from pathlib import Path

UIT = Path(sys.argv[1]).resolve()


def exporteer(blend, doel, clip):
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    sc = bpy.context.scene
    if clip:
        for o in sc.objects:
            if o.animation_data:
                for tr in o.animation_data.nla_tracks:
                    tr.mute = tr.name != clip
        sc.frame_start, sc.frame_end = 0, 180
    for o in sc.objects:
        o.select_set(False)
    bpy.ops.wm.usd_export(filepath=str(doel), export_materials=True, export_animation=bool(clip), generate_preview_surface=True)
    print("geschreven:", doel, doel.stat().st_size // 1024, "kB")


exporteer(UIT / "voorraadtruck_meshy.blend", UIT / "Voorraadtruck.usdz", "Laden")
exporteer(UIT / "voorraadtruck_meshy_wrak.blend", UIT / "Voorraadtruck_wrak.usdz", None)
