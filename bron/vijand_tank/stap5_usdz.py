"""Tank stap 5: USDZ-preview voor iPhone Bestanden/Quick Look van de vijandelijke tank (met de clip Rijden-loop). Leest <uit>/vijand_tank.blend, schrijft <uit>/Vijand_Tank.usdz.
Bevat PBR-materialen (albedo, ORM, normal) en de clip Rijden-loop (de wielen draaien); Draaien-loop en Vuren staan in de GLB en de viewer. Of de animatie in Quick Look
afspeelt is niet gecontroleerd (alleen macOS/iPhone).
Gebruik: python3 stap5_usdz.py <uit-map>"""
import sys
import bpy
from pathlib import Path

UIT = Path(sys.argv[-1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(UIT / "vijand_tank.blend"))
sc = bpy.context.scene
for o in sc.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "Rijden-loop"
sc.frame_start, sc.frame_end = 0, 30
for o in sc.objects:
    o.select_set(False)
doel = UIT / "Vijand_Tank.usdz"
bpy.ops.wm.usd_export(filepath=str(doel), export_materials=True, export_animation=True, generate_preview_surface=True)
print("geschreven:", doel, doel.stat().st_size // 1024, "kB")
