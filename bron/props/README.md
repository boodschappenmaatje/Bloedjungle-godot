# Props: zandzakken en kisten (Blender-bron, VQ2)

`assets/props.glb` komt uit `maak_props.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_props.py uit/     # props.glb + props.blend

| knoop | driehoeken | inhoud |
| --- | --- | --- |
| `Zandzak1` / `Zandzak2` / `Zandzak3` | 168 elk | kussenvormige zak (62 x 38 x 22 cm), superellips met ruis, platte onderkant; Zandzak2 met een dichtgebonden hoek; eigen tint op het VQ2-jutegeweven |
| `Kist_Hout` | 336 | houten lattenkist 100 x 100 x 91 cm: hoekpalen, vier latten per zijde met spleten, bodem, deksel van vijf planken met twee dwarslatten |
| `Kist_Munitie` | 572 | munitiekist 62 x 30 x 30 cm: olijfgroen staal met deksel, sloten, handvatten en ribben (twee materialen: olive en steel) |

Samen 1412 driehoeken. Materialen zijn de bestaande VQ2-sets (`canvas`, `timber`, `olive`, `steel`; 1K albedo/normal/ORM, geen nieuwe textuurbestanden);
`scripts/vq2_import.gd` (in `assets/props.glb.import`) deelt ze met de andere VQ2-modellen. Zandzakken: pivot in het midden, lengte langs X; kisten: onderkant op de grond.

In het spel: `Kit.prop_mesh(naam)` laadt de meshes, `Kit.prop(...)` zet er een neer. `Kit.sandbags` (rijen langs de muur en de bunker) zet de drie zakken met MultiMesh neer,
`Defenses._bag_wall` (de zandzakmuur die je koopt) gebruikt ze ook, en `BaseProps._crates` is nu een voorraadhoek in de noordwesthoek van de basis
(7 houten kisten, 4 munitiekisten, 3 vaten) met botsing (laag muur), zodat je er niet doorheen loopt.
Tests: `tests/props_test.gd`, viewertest `tools/blender-vq2-viewer/test-props.mjs`, beelden `tests/props_foto.gd` (zelfde camera voor/na, `docs/vq2/renders/props-voor-na-*.png`).
Geen iPhone/Xogot-meting gedaan.
