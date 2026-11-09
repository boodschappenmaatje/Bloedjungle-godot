# Vijandelijke jeep uit Dennis' Meshy-model (9 november 2026, stap V1)

Model van Dennis (Drive, "Iedereen met de link", `Dit is de jeep`): één GLB met de hele jeep, niet in de repo. Afspraak met Dennis: **bestuurder en schutter erbij** (uit de eigen jeep, in vijandkleuren), alle getallen in het spel zijn voorstellen om te testen.

## Resultaat
- `assets/vijand_jeep.glb` (4,8 MB, 3 JPEG-texturen van 2K: albedo, normal, ORM) met `vijand_jeep_jeep_*.jpg`. **45.050 driehoeken**, 10 meshes, 5 materialen, 3 clips. 4,2 m lang, 1,9 m breed, oorsprong midden tussen de assen op de grond, voorkant = -Z (Godot).
- Delen: romp 29.994, MG 8.000, vier wielen van 1.296, bestuurder en schutter samen ongeveer 1.900 (blokkerige stand-ins van de eigen jeep; een mooier model kan later via de Meshy-soldaat).
- Knopen (contract met `scripts/vijand_jeep.gd`): `VijandJeep > Body > [RompMesh, StuurLV > WielLV, StuurRV > WielRV, WielLA, WielRA, Bestuurder > [BestuurderBenen, BestuurderBovenMesh], Geschut > [MG > Monding, Schutter > [SchutterBenen, Bovenlijf > BovenlijfMesh]]]`.
- Echte GLB-clips (24 beelden/s, lussen): **Rijden** (wielen draaien, 1,0 s), **Sturen** (voorwielen links-rechts, 2,0 s), **Vuren** (MG-terugslag, 4 beelden). In het spel stuurt Godot wielen, sturen en MG zelf; de clips zijn voor de viewer.
- Bron en reproduceerbare keten (Blender 5.2 via `bpy`): `bron/vijand_jeep/` (stap1 voxel-remesh, stap2 delen + dichtmaken + decimeren, stap3 bakken 2K, stap4 samenbouwen met clips, stap5 USDZ).
- Viewer: `tools/blender-vq2-viewer`, asset `vijand_jeep` (`test-vijand-jeep.mjs`: alle clips bewegen hun onderdelen, 360°, gamecamera; `docs/vq2/results/vijand-jeep-viewer-test.json`). Chromium software-WebGL, geen Safari.
- Bewerkbare `.blend`, `.usdz`-preview (`Vijand_Jeep.usdz`, 5,3 MB, PBR + clip Rijden) en de brontexturen staan in de projectbibliotheek (`/mnt/project-files/modellen/vijand-jeep/`). Quick Look is niet gecontroleerd.

## Spel (`scripts/vijand_jeep.gd`, `VijandJeep`)
- **Schema (keuze 1B):** groep 3 t/m 5 een jeep, groep 6 t/m 8 een tank (tot de tank er is rijdt er een jeep), vanaf groep 9 tank en jeep; nooit meer dan drie voertuigen tegelijk (`Data.groep_voertuigen`, `Data.VOERTUIG_MAX`); het voertuig rukt uit vóór de soldaten (`main.gd`).
- **Weg (keuze 4A):** uit de poort, door de jungle naar de oostkant van de stad, de Hoofdstraat langs de zuidkant, door de strook ten westen van de geparkeerde auto, over de brug en naar je kamp (`AanvalRoutes.voertuig_pad`). Bicycle-model met pure pursuit, drie voelsprieten voor muren en geparkeerde auto's, vastzitten leidt tot achteruit en een ander punt, bomen rijdt hij plat. Staat de brug omhoog, dan wacht hij aan de noordkant.
- **Doel (keuze 5A):** zuid van de rivier de dichtstbijzijnde soldaat of jou binnen 55 m met het MG (30 m bereik, 5 schade, salvo's van 6); bij het kamp houdt hij 22 m afstand en beschiet het hoofdkwartier (weinig schade).
- **Pantser (keuze 6A):** 220 levenspunten (+5% per groep). Kogels 30%, scherpschutter 50%, raket, granaat en explosie 150%, napalm 55 per seconde x 1,5; rook onder 50%, vuur onder 25%; wrak blijft 30 s liggen, zwartgeblakerd. Telt als kill (+150 punten). `Data.ARMOR_MULT` heeft de sleutels `jeep` en `tank`; "explosie" en "brand" bestaan alleen voor voertuigen, voor soldaten verandert niets.
- **Zichtbaarheid (keuze 8A):** rode stip op de motorkap, levensbalk, rode ruit op de radar, melding "VIJANDELIJKE JEEP ONDERWEG", motorgeluid. De Engelse radiozin ("Enemy vehicle approaching") wacht op Dennis' opname: `voertuig_onderweg_1.wav`; zonder bestand blijft de melding stil.

## Tests
- `tests/vijand_jeep_test.gd` (in `.github/workflows/vijand-basis.yml`, Godot 4.7.2 headless): **68 controles, 0 fouten**, twee keer lokaal gedraaid (ruim een minuut elk; 6700 beeldjes). Het dekt: model (knopen, clips, 45.050 driehoeken, materialen), schema per groep, schade per soort wapen (kogel 30%, scherpschutter 50%, raket 150%, knal 150%, napalm), kill en punten, wrak ruimt op, wachtrij en maximum van drie, schieten op de speler en op een soldaat, de hele rit van de poort over de Hoofdstraat en de brug naar het kamp (3900 beeldjes), en wachten voor een opgehaalde brug.
- Lokaal Godot 4.6.3 headless is voor deze scène onbetrouwbaar (na enkele honderden beeldjes hapert of crasht het proces met glibc-mutexfouten, ook zonder jeep-geluid, bomen platrijden of clip-aanpassing, en niet op 4.7.2); daarom is de CI-versie 4.7.2 de maatstaf.
- Bestaand en niet gewijzigd: `vijand_basis_test`, `aanval_basis_test`, `jeep_m2_schutter_test`, `auto_wapens_test`.
- Foto's in de gamecamera (software-Vulkan, `tests/vijand_jeep_foto.gd`): `docs/vq2/renders/vijand_jeep_*.png`.

## Bekend en niet gemeten
- **NIET GETEST:** native iPhone (FPS, touch, camera), Xogot, Quick Look. Een jeep kost 45k driehoeken; met drie tegelijk plus de soldaten is dat nog niet gemeten.
- De bestuurder en de schutter zijn blokkerige stand-ins.
- De weg is één vaste route: een boom of auto die er na het opruimen bij komt, kan hem tegenhouden (hij zet dan achteruit en probeert het volgende routepunt).
- Granaten, napalm en ontploffingen raken hem via `Game.hit_class` en een ontploffingsvenster van een kwart seconde; de bazooka van de speler telt als explosie als hij vlakbij ontploft.
- De tank volgt in stap V2 (eigen Meshy-model van Dennis nodig); eigen voertuigen met levenspunten in V3.
