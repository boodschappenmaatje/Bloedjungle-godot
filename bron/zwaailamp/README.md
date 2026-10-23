# Zwaailamp (poortlamp)

`maak_zwaailamp.py` bouwt in Blender (bpy) de zwaailamp: voet, kap (materiaal "Lampkap"), lampje ("Lampje") en een
draaiende reflector (node "Draaier", clip "draaien", loop). `render.py` maakt previews.
In het spel (scripts/gates.gd `_beacon`): rood = dicht, oranje draaiend + SpotLight = poort beweegt, groen = open.
Export: assets/zwaailamp.glb
