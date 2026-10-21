# Houten ophaalbrug
Gemaakt met Blender (bpy headless): `python3 maak_brug.py uit/` geeft `uit/brug.blend` en `uit/brug.glb`; `render.py uit/brug.blend uit/ <beeld> <suffix>` maakt de voorbeeldplaatjes (beeld 108 = omlaag, 0 = omhoog).
12,4 m lang (langs Z), dek 5 m breed (tank en jeep kunnen erover). De klep (9,6 m) draait om een scharnier aan de zuidoever omhoog (1,4 rad) aan twee touwen van een poortframe. Naast de brug staat een kastje met hendel en lampjes.
Knopen: Klep, Hendel, TouwL, TouwR, LampRood, LampGroen, KastjePunt. Animaties: Omhoog (4,2 s) en Omlaag (3,6 s). Materialen: Hout1/2/3, Balk, Paal, Metaal, Touw, LampRood, LampGroen; het spel hangt er foto-texturen aan (`Kit.skin(model, "brug")`). In het spel: scripts/bridge.gd.
