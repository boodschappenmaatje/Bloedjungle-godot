# Vijandelijke tank uit Dennis' Meshy-model (9 november 2026, stap V2)

Model van Dennis (Drive, "Oké dit is de tank"): één GLB met de hele tank (een Tiger I in olijfgroen met gele tekens en schedels), 5.262.768 driehoeken, niet in de repo. Afspraak met Dennis: **één complete tank** (geen losse delen; de delen worden in Blender uit het model gesneden). Alle getallen in het spel zijn voorstellen om te testen.

## Resultaat
- `assets/vijand_tank.glb` (4,6 MB, 6 JPEG-texturen: atlas 2K albedo/normal/ORM voor romp, koepel, kanon en wielen, plus rups 4096 x 512 albedo/normal/ORM). **37.922 driehoeken**, 27 meshes, 2 materialen, 3 clips. 3,58 m breed, 3,14 m hoog, 8,01 m lang (kanon wijst naar -Z), grond op y = 0, oorsprong midden in de romp.
- Delen: romp 16.000, koepel 11.000, kanon 1.056 (opnieuw gedraaid, holle loop), 22 wielen samen 8.624 (negen steunwielen, aandrijfwiel en spanwiel per kant, opnieuw gedraaid), twee rupsen van 632 (één band met `u` = booglengte, 12,65 m).
- Knopen (contract met `scripts/vijand_tank.gd`): `VijandTank > Body > [RompMesh, RupsL, RupsR, WielL_*, WielR_*, Toren > [TorenMesh, Kanon > [KanonMesh, Monding]]]`. Toren draait om Y, Kanon kantelt om X, de wielen draaien om X, de rupsen lopen via `uv1_offset.x` (net als de Tiger van de speler).
- Echte GLB-clips (30 beelden/s): **Rijden-loop** (22 wielen, een omwenteling per lus, romp deint), **Draaien-loop** (links en rechts tegengesteld), **Vuren** (kanon schiet terug en veert, 0,4 s). Godot haalt `-loop` van de naam en zet de clip op lus (`Rijden`, `Draaien`). In het spel stuurt de code koepel, kanon, wielen en rupsen zelf.
- Bron en reproduceerbare keten (Blender 5.2 via `bpy`): `bron/vijand_tank/` (meet_baan, stap1 voxel-remesh en indeling, stap2 delen + dichtmaken + decimeren + opnieuw draaien, stap3 bakken, stap4 samenbouwen met clips, stap5 USDZ).
- Viewer: `tools/blender-vq2-viewer`, asset `vijand_tank` (`test-vijand-tank.mjs`: alle clips bewegen hun onderdelen, de koepelschuif draait `Toren`, de kanonschuif kantelt `Kanon`, de rupsen lopen zodra Rijden speelt, 360° en gamecamera; `docs/vq2/results/vijand-tank-viewer-test.json`). Chromium software-WebGL, geen Safari.
- Bewerkbare `.blend`, `.usdz`-preview (`Vijand_Tank.usdz`, 20 MB, PBR + clip Rijden-loop) en de brontexturen staan in de projectbibliotheek (`/mnt/project-files/modellen/vijand-tank/`). Quick Look is niet gecontroleerd.

## Spel (`scripts/vijand_tank.gd`, `VijandTank`)
- **Schema (keuze 1B):** groep 3 t/m 5 een jeep, groep 6 t/m 8 een tank, vanaf groep 9 tank en jeep, nooit meer dan drie voertuigen (`Data.groep_voertuigen`, `Data.TANK_KLAAR := true`, `main.gd`). De tank rukt uit vóór de soldaten; melding "VIJANDELIJKE TANK ONDERWEG" (de Engelse radiozin blijft stil, zoals bij de jeep).
- **Weg:** uit de poort, door de jungle, de Hoofdstraat, over de brug naar je kamp (`AanvalRoutes.voertuig_pad(true)`). De tank is 3,4 m breed en 5,8 m lang en past niet door elk gat waar de jeep door kan: hij heeft een eigen route (`TANK_WEG`) die ruim door de bocht zwaait en precies in het midden van de strook tussen het huis en de geparkeerde auto rijdt. Eerste versie bleef daar 20 tot 30 s hangen (botsdoos 7,4 m lang, voelsprieten onder een hoek, waypoints te ruim); nu 74 s voor de hele rit van de poort naar het kamp, in de smalle straat ongeveer 14 s. De botsdoos is 3,4 x 2,8 x 5,8 m (alleen de romp: het kanon steekt er 2 m voor uit), drie evenwijdige voelsprieten langs de rupsen, waypoints op 3 m. Staat de brug omhoog, dan wacht hij aan de noordkant.
- **Beleg (keuze G, 5A):** hij stopt zodra er een doel binnen 38 m is en schiet een granaat per 6 s (70 schade, straal 3,2 m, 0,9 m spreiding, bereik 45 m, 55 m/s) op de dichtstbijzijnde soldaat, jou, een bouwwerk (drie keer zoveel schade), een poort of het hoofdkwartier (56 van 1000 per granaat). Soldaten en jij tellen 30% zwaarder dan een muur. De koepel draait 0,9 rad/s en hij schiet pas als hij recht staat en de romp niet meer flink draait. Tijdens de voorbereiding ("prep") beschiet hij het hoofdkwartier niet.
- **Pantser (keuze 6A):** 900 levenspunten (+5% per groep). Kogels 5%, scherpschutter 10%, raket 200%, explosie 150%, brand 150% (`Data.ARMOR_MULT["tank"]`), napalm 40 per seconde x 1,5; rook onder 50%, vuur onder 25%; wrak blijft 30 s liggen, zwartgeblakerd met een scheve koepel. Telt als kill (+300 punten).
- **Zichtbaarheid (keuze 8A):** rode stip op het koepeldak, levensbalk, rode ruit op de radar, motorgeluid met toonhoogte naar snelheid.

## Tests
- `tests/vijand_tank_test.gd` (in `.github/workflows/vijand-basis.yml`, Godot 4.7.2 headless): **86 controles, 0 fouten**. Het dekt: model (knopen, 22 wielen, clips Vuren, Rijden en Draaien met lus, 37.922 driehoeken, maat), schema per groep, schade per soort wapen, brand, kill en punten, wrak, wachtrij en maximum van drie voertuigen, ontploffing van een granaat (straal, afname, soldaat, speler, zandzak, hoofdkwartier), beleg van soldaat, speler en bouwwerk (stoppen op 38 m, koepel op het doel, granaten raken), de hele rit van de poort over de Hoofdstraat en de brug naar het kamp (4440 beeldjes), HQ-schade zodra het spel loopt, en wachten voor een opgehaalde brug.
- Bestaand en opnieuw gedraaid zonder fouten: `tests/vijand_jeep_test.gd` (jeep houdt zijn eigen route `VOERTUIG_WEG`).
- Lokaal Godot 4.6.3 headless is voor deze scène onbetrouwbaar (zie het jeeprapport); Godot 4.7.2 is de maatstaf.
- Foto's in de gamecamera (software-Vulkan, `tests/vijand_tank_foto.gd`): `docs/vq2/renders/vijand_tank_*.png` (rijdt aan, schiet een granaat, rookt, brandt, wrak, radar met rode ruit).

## Bekend en niet gemeten
- **NIET GETEST:** native iPhone (FPS, touch, camera), Xogot, Quick Look. De tank kost 38k driehoeken; met drie voertuigen en soldaten tegelijk is dat nog niet gemeten.
- Eén vaste route; een boom, auto of paal die er na het opruimen bij komt kan hem tegenhouden (hij zet dan achteruit en probeert het volgende routepunt).
- Een tank botst met zijn romp, niet met zijn kanon: het kanon kan dus door een muur of boom heen steken.
- De USDZ is 20 MB (PNG-texturen); Quick Look en iCloud Drive hebben daar geen last van, maar het is groter dan nodig.
- Eigen voertuigen met levenspunten (V3) volgen later.
