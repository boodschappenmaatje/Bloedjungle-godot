"""Jeep stap 5: USDZ-preview voor iPhone Bestanden/Quick Look van de vijandelijke jeep (met de clip Rijden). Leest <uit>/vijand_jeep.blend, schrijft <uit>/Vijand_Jeep.usdz.
Bevat PBR-materialen (albedo, ORM, normal) en de clip Rijden (de wielen draaien); Sturen en Vuren staan in de GLB en de viewer. Of de animatie in Quick Look
afspeelt is niet gecontroleerd (alleen macOS/iPhone).
Gebruik: python3 stap5_usdz.py <uit-map>"""
import sys
import bpy
from pathlib import Path

UIT = Path(sys.argv[-1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(UIT / "vijand_jeep.blend"))
sc = bpy.context.scene
for o in sc.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "Rijden"
sc.frame_start, sc.frame_end = 0, 24
for o in sc.objects:
    o.select_set(False)
doel = UIT / "Vijand_Jeep.usdz"
bpy.ops.wm.usd_export(filepath=str(doel), export_materials=True, export_animation=True, generate_preview_surface=True)
print("geschreven:", doel, doel.stat().st_size // 1024, "kB")
