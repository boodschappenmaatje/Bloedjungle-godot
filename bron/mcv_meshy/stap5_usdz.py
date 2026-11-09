"""MCV stap 5: USDZ-preview voor iPhone Bestanden/Quick Look van de bouwwagen (met de clip Uitklappen). Leest <uit>/mcv_meshy.blend, schrijft <uit>/Bouwwagen_MCV.usdz.
Bevat PBR-materialen (albedo, ORM, normal) en de clip Uitklappen. Of de animatie in Quick Look afspeelt is niet gecontroleerd (alleen macOS/iPhone).
Gebruik: python3 stap5_usdz.py <uit-map>"""
import sys
import bpy
from pathlib import Path

UIT = Path(sys.argv[-1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(UIT / "mcv_meshy.blend"))
sc = bpy.context.scene
for o in sc.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "Uitklappen"
sc.frame_start, sc.frame_end = 0, 180
for o in sc.objects:
    o.select_set(False)
doel = UIT / "Bouwwagen_MCV.usdz"
bpy.ops.wm.usd_export(filepath=str(doel), export_materials=True, export_animation=True, generate_preview_surface=True)
print("geschreven:", doel, doel.stat().st_size // 1024, "kB")
