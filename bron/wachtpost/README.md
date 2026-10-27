# Poortwachtpost: slagboom en wachthuisje (Blender-bron, VQ2)

`assets/wachtpost.glb` komt uit `maak_wachtpost.py` (Blender 5.2, ook zonder scherm via `pip install bpy`). Eerst de verf, dan het model:

    python3 maak_slagboomverf.py uit/      # slagboomverf_{albedo.jpg,normal.jpg,orm.png}, 1024x512, eigen ruis (numpy), geen externe bron
    python3 maak_wachtpost.py uit/         # wachtpost.glb + wachtpost.blend (texturen gepakt)
    python3 render.py uit/wachtpost.blend uit/   # Cycles-studiobeelden

Z = omhoog (Godot Y), 1 eenheid = 1 meter. Twee wortelknopen:

| knoop | driehoeken | inhoud |
| --- | --- | --- |
| `Slagboom` | 2.088 | oorsprong = midden van de poortopening op de grond. Betonvoet en olijfgroene kast (deurpaneel, scharnieren, bouten, as met flens) op X = -3,75, steunvork op X = +3,85, arm `Boom` (7,2 m, rood-wit verf, contragewicht, reflectoren) |
| `Wachthuis` | 4.672 | oorsprong = midden van de vloer op de grond, 2,3 x 2,3 m, 2,5 m hoog: betonplaat, olijfstalen wanden, raam met kozijn en vensterbank, stalen deur in de zijwand, canvasluifel op twee steunarmen, golfplaten dak met ventilatiekast en pijp, lamp boven de deur. Voorkant = +Y in Blender (-Z in Godot). In de glb staat hij 4,5 m opzij van de slagboom, de game zet hem zelf neer |

Samen 6.760 driehoeken, 9 materialen, 21 gedeelde afbeeldingen (VQ2-families `olive`, `steel`, `concrete`, `roof`, `timber`, `canvas` uit `assets/textures/vq2`, 1K, gedeeld via `scripts/vq2_import.gd`, plus eigen `Slagboomverf`).

**Animatie:** clip `Open` (1,5 s) op knoop `Boom`: arm 82 graden omhoog, bezier, terugspelen = sluiten. Blender-Y wordt Godot-Z, dus in Godot draait `Boom.rotation.z` van 0 naar +82 graden. Het wachthuis heeft geen clips (raam, deur en luifel zijn vast).

**In het spel** (`scripts/wachtpost.gd`): bij elke poort staat de slagboom 2,6 m binnen de muur, het huisje 5 m binnen de muur en 6,3 m naast het midden (noord links, zuid rechts, raam naar de weg). De arm volgt `Gates.list[i].open`: omhoog vanaf 35% open, volledig omhoog bij 100% of als de poort kapot is. Botsing: huisje 2,4 x 2,5 x 2,4 m en de kast van de slagboom (laag muur); de arm zelf heeft geen botsing, de stalen poort blokkeert de weg al. Een vierde wacht (Patrouille) staat voor het huisje bij de noordpoort. Op de plek van het huisje kan geen gebouw geplaatst worden (`Buildings.can_place` ziet de botsing).

Tests: `tests/wachtpost_test.gd` (aantal, botsing, arm volgt de poort, geen gebouw erop), `tests/patrouille_test.gd`, viewertest `tools/blender-vq2-viewer/test-wachtpost.mjs`, opnames `tests/wachtpost_foto.gd`.
Opnames in de spelcamera: `docs/vq2/renders/wachtpost-spel-*.png`; Blender: `wachtpost-blender-*.png`.
Geen iPhone/Xogot-meting gedaan.
