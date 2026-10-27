# Jungle: palmen en rotsen (Blender-bron)

`assets/jungle.glb` wordt gemaakt door `maak_jungle.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_jungle.py uit/     # jungle.glb + jungle.blend

Knopen (elk op de oorsprong, voet op y = 0, een mesh per knoop):

| knoop | driehoeken | inhoud |
| --- | --- | --- |
| `Palm1` / `Palm2` / `Palm3` | 624 / 712 / 692 | geringde, wijd uitlopende en lichtjes leunende stam (5,4 / 6,3 / 4,6 m), kroon van 12-15 gebogen bladeren, 6 jonge hartbladeren, 2 verdorde hangbladeren |
| `Palm1_far` / `_far` | 134 / 146 / 158 | verre variant (vanaf 62 m): 5 zijden, 5 ringen, weinig bladeren |
| `Rots1` / `Rots2` / `Rots3` | 270 / 256 / 270 | icosfeer met ruis-vervorming, platte onderkant, hoeken vlakker gemaakt; steen en mos in de vertexkleuren |

Palmen hebben twee oppervlakken: 0 = stam (UV: u rond, v langs de stam, voor de schorstextuur), 1 = kroon (UV zoals `Foliage._frond`: u langs het blad, v over de breedte).
De vertex-alfa is het windgewicht voor `shaders/foliage.gdshader` (stam 0-0,04, blad 0 aan de basis tot 1 aan de punt).

In het spel: `Foliage.jungle_mesh(naam)` laadt de meshes; stam = `Foliage.material("bark")` (foto-schors `nature/tree_bark`, herhalend), kroon = `material("palm")`,
rotsen = `Kit.rock()` (triplanar steen) met vertexkleur. `Foliage.plant` verdeelt de palmen en rotsen over de drie vormen; strooiing, dichtheid per gebied,
zichtafstanden, nepschaduwen en de lijst `trees` voor de heli blijven gelijk.
Tests: `tests/jungle_test.gd`, viewertest `tools/blender-vq2-viewer/test-jungle.mjs`, beelden `tests/jungle_foto.gd` (zelfde camera voor/na).
Geen iPhone/Xogot-meting gedaan.

## Meting (lavapipe, Mobile-renderer, fps_meting.gd, Ultra; geen iPhone)
| plek | voor (tri / draw) | na (tri / draw) |
| --- | --- | --- |
| basis | 73k / 58 | 61k / 64 |
| stadsrand | 73k / 160 | 79k / 161 |
Voor/na-beelden met identieke camera: `docs/vq2/renders/jungle-voor-na-{0,1,2}.png` (links voor, rechts na).
