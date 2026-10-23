# Wapens (Blender-bron)

`assets/wapens.glb` wordt gemaakt door `maak_wapens.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_wapens.py uit/     # wapens.glb + wapens.blend
    python3 render.py uit/wapens.blend uit/   # plaatjes per wapen (3/4-aanzicht)

Knopen: `M1911`, `Thompson`, `Garand`, `Trench`, `MG42`, `Bazooka`, plus `Huls` en `Raket`. Oorsprong = de greep van de rechterhand,
loop langs Blender +Y (Godot -Z). Per materiaal een mesh (`<wapen>_Staal`, `_Hout`, ...), zodat een wapen maar 3 tot 6 tekenopdrachten kost.
In het spel: `SoldierModel.set_gun(naam)` hangt het wapen aan `DEF-handR` en draait het naar voren; vijanden: knife = geen wapen,
rifle = Garand, heavy = MG 42, rocket = Bazooka; bondgenoten: Thompson; speler: het gekozen wapen. `Fx.casing` gebruikt `Huls_Messing`.
