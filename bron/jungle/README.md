# Jungle: palmen en rotsen (Blender-bron)

`assets/jungle.glb` wordt gemaakt door `maak_jungle.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_jungle.py uit/     # jungle.glb + jungle.blend

Knopen (elk op de oorsprong, voet op y = 0, een mesh per knoop):

| knoop | driehoeken | inhoud |
| --- | --- | --- |
| `Palm1` / `Palm2` / `Palm3` | 624 / 712 / 692 | geringde, wijd uitlopende en lichtjes leunende stam (5,4 / 6,3 / 4,6 m), kroon van 12-15 gebogen bladeren, 6 jonge hartbladeren, 2 verdorde hangbladeren |
| `Palm1_far` / `_far` | 134 / 146 / 158 | verre variant (vanaf 62 m): 5 zijden, 5 ringen, weinig bladeren |
| `Boom1` / `Boom2` | 1002 / 1002 | jungleboom (11 / 13,5 m): rechte stam met 4-5 plankwortels, brede kroon, twee zijtakken met eigen bladerbos, 7 lianen |
| `Boom1_far` / `Boom2_far` | 228 / 228 | verre variant |
| `Rots1` / `Rots2` / `Rots3` | 270 / 256 / 270 | icosfeer met ruis-vervorming, platte onderkant, hoeken vlakker gemaakt; steen en mos in de vertexkleuren |
| `Stomp1` / `Stomp2` | 110 / 230 | stronk van een omgevallen palm (0,9 m) of jungleboom (1,5 m, met vijf lage plankwortels): splinterrand met lange splinters, licht hout op de breuk (vertexkleur), schors via `Boom_Stam` |

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

## Jungleboom en botsing (v130)
Bomen hebben drie oppervlakken (stam, blad, lianen; materiaal op naam: `Boom_Stam` schors, `Boom_Blad` = bladmateriaal "leaf", `Boom_Liaan` vlak met windgewicht).
Een op de vijf plekken van de palmen (`Foliage.PALM_POOL`) krijgt een jungleboom, op 0,75 geschaald; dichtheid per gebied volgt dus de palmen (dicht = veel, open plek = bijna geen).
Stammen en rotsen blokkeren sinds v129 mensen, voertuigen, kogels en granaten (laag `natuur` = 128, `Foliage._collide`); bomen hebben straal 0,6 m, palmen 0,3 m.
Meting (lavapipe): basis 62k driehoeken / 66 draw, stadsrand 79k / 161; voor jungleboom (v129) 61k / 64 en 79k / 161. Geen iPhone-meting.

## Omvallende bomen (v135)
Een grote ontploffing vlakbij velt palmen en jungle­bomen (`Game.note_blast` -> `Foliage.fell_near`): straal vanaf `Foliage.FELL_MIN_R` (3 m: tankgranaat, raket, granaat, vat, brandend voertuig),
de boom moet binnen 0,55 x de straal liggen, hoogstens `FELL_MAX` (6) per knal. De staande boom verdwijnt uit zijn MultiMesh (ook de verre variant en de nepschaduw) en uit de hellijst;
`Stomp1`/`Stomp2` blijft staan met een lage botszuil. `scripts/boom_val.gd` laat de boom van de knal af kantelen (versnellend, klap met stof, bladeren en een dreun, korte terugveer) en
laat hem als lage stam liggen: een balk op de natuurlaag (dekking, kogels en voertuigen stuiten erop). Alleen de val is code; de modellen zijn echte Blender-meshes.
Tests: `tests/boom_val_test.gd`, opnames `tests/boom_val_foto.gd` (spelcamera, vaste volgorde van beelden), viewer: Stronk palm / Stronk jungleboom, `tools/blender-vq2-viewer/test-jungle.mjs`.
Geen iPhone/Xogot-meting gedaan.

Voertuigen (v136/v137): `Foliage.ram(body, snelheid, min_palm, min_boom)` na `move_and_slide`, met gewichtsklassen. Tank velt een palm vanaf 1,5 m/s en een jungleboom vanaf 2,5; bus 4 / 8;
jeep 6 / nooit; auto 7 / nooit. Een te zware jungleboom houdt het voertuig tegen: het kaatst terug (kwart van de snelheid) en auto en bus raken beschadigd. Een geramde boom valt in de rijrichting;
stronk en stam krijgen dan geen botsing (platgereden, geen haken). De legertruck botst niet met bomen (maskers) en valt hier buiten. Test: `tests/boom_val_ram_test.gd`.
Alle voertuigen blokkeren op bomen (v139): eerst botsen, dan valt de boom (in de rijrichting), en daarna blokkeren stronk en liggende stam het voertuig ook (botsing op de natuurlaag, dus niemand rijdt of loopt erdoorheen).
Ook de legertruck botst nu met bomen (masker 178) en valt via `Foliage.ram` mee (palmen vanaf 5 m/s). Draaiende tank: de natuurkunde houdt draaien niet tegen, dus `Foliage.hull_tree(tank, romp)` controleert na elke beweging of een boom in het rompvlak staat;
zo ja dan draait de tank terug (botst), en velt de boom. Test: `tests/boom_val_tank_test.gd` (echte tank).
