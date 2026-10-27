# Wapens (Blender-bron)

`assets/wapens.glb` wordt gemaakt door `maak_wapens.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_wapens.py uit/     # wapens.glb + wapens.blend
    python3 render.py uit/wapens.blend uit/   # plaatjes per wapen (3/4-aanzicht)

Knopen: `M1911`, `Thompson`, `Garand`, `Trench`, `MG42`, `Bazooka`, plus `Huls` en `Raket`. Oorsprong = de greep van de rechterhand,
loop langs Blender +Y (Godot -Z). Per materiaal een mesh (`<wapen>_Staal`, `_Hout`, ...), zodat een wapen maar 3 tot 6 tekenopdrachten kost.
In het spel: `SoldierModel.set_gun(naam)` hangt het wapen aan `DEF-handR` en draait het naar voren; vijanden: knife = geen wapen,
rifle = Garand, heavy = MG 42, rocket = Bazooka; bondgenoten: Thompson; speler: het gekozen wapen. `Fx.casing` gebruikt `Huls_Messing`.

## Bewegende delen en clips (v127)
Delen die bij een schot bewegen zijn eigen knopen onder het wapen: `M1911_Slede`, `Thompson_Repeerknop`, `Garand_Sluiting`, `Trench_Pomp`, `MG42_Repeergreep`
(de Bazooka heeft geen bewegende delen). `maak_wapens.py` zet er echte NLA-clips op en exporteert ze als GLB-animaties (60 beelden/s):
`M1911_schot`, `M1911_leeg` (slede blijft open), `Thompson_schot`, `Garand_schot`, `Trench_schot`, `MG42_schot`; de beweging gaat langs de loop (slede 3,4 cm, knop 2,2 cm,
sluiting 4,5 cm, pomp 7 cm, greep 3 cm). In het spel maakt `SoldierModel._gun_player` er een `AnimationPlayer` van op het wapen (clips zonder wapenvoorvoegsel: `schot`, `leeg`);
`shoot_recoil(kind, empty)` speelt `schot` of, bij een leeg magazijn, `leeg`; `gun_reset()` zet de delen terug na het herladen. Speler, bondgenoten en vijanden gebruiken dezelfde clips.
`assets/wapens.glb.import` staat op `animation/fps=60`, anders gaan de korte clips (MG 42: 0,07 s) bij de import verloren.
Tests: `tests/wapen_clips_test.gd` (afstand en terugkeer per wapen), `tests/combat_visuals_test.gd` (pomp), viewertest `tools/blender-vq2-viewer/test-wapens.mjs`;
demo `tests/wapen_clips_foto.gd` (beeld: `docs/vq2/renders/wapens-bewegende-delen.png`, rijen M1911, M1911 leeg, Thompson, Garand, Trench, MG42; kolommen boven rust/piek, rechts rust/piek).
Viewer: Model "Wapens" in `tools/blender-vq2-viewer`. Geen fysieke iPhone/Xogot-meting gedaan.
