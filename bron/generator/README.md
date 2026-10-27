# Dieselgenerator (Blender-bron, VQ2)

`assets/generator.glb` komt uit `maak_generator.py` (Blender 5.2, ook zonder scherm via `pip install bpy`). Het geluid komt uit `maak_generator_geluid.py` (numpy, geen externe bron):

    python3 maak_generator.py uit/                       # generator.glb + generator.blend (texturen gepakt)
    python3 render.py uit/generator.blend uit/            # Cycles-studiobeelden g_voor, g_achter, g_boven, g_wrak
    python3 maak_generator_geluid.py ../../assets/geluid/generator.wav   # 2 s naadloze lus, mono 22050 Hz

Z = omhoog (Godot Y), 1 eenheid = 1 meter. Twee wortelknopen:

| knoop | driehoeken | inhoud |
| --- | --- | --- |
| `Generator` | 9.306 | oorsprong = midden van de betonplaat (3,0 x 1,8 m). Stalen slede met I-liggers en rubber trillingsdempers, olijfgroene geluiddempende kap 2,2 x 1,0 m (twee deurpanelen per zijde met lamellen, grepen, scharnieren, bouten), dak met ribben, brandstofvuldop met ketting, uitlaatdemper met pijp en regenkap, bedieningskast (meters, noodstop, contactdozen, schakelaars), verdeeldoos met rubber kabel, luchtinlaat-kooi met ventilator. Voorkant (deuren, kast) = +Y in Blender (-Z in Godot) |
| `Wrak` | 1.816 | zelfde plaat, 4 m opzij in de glb: ingezakte zwartgeblakerde kap, losgeraakte deur, losse uitlaat, verbogen kast, scheve ventilatorkooi zonder bladen, brokstukken, brandvlek |

Samen 11.122 driehoeken (boven de indicatieve 1.500-5.000 voor een prop; de kap met lamellen, bouten en bedieningskast is bewust rijk omdat de generator een belangrijk doelwit is en dicht bij de camera staat; geen LOD gemaakt), 11 materialen, 9 afbeeldingen: de VQ2-families `olive`, `steel`, `concrete` (1K, gedeeld via `scripts/vq2_import.gd`) en een gebrande variant van elk (`VQ2_*_gebrand`; de tint zet `vq2_import.gd` in Godot weer als albedo-kleur, omdat hij in Blender in een node zit). Plus vlakke materialen voor rubber, meterglas, geel en rood.

**Animatie:** clip `Draaien` op knoop `Ventilator`: 360 graden om de X-as in 24 beelden (30 fps), lineair, lus. Het wrak heeft geen clips. Trilling van de motor, rook, vuur, explosie en geluid zijn Godot-effecten.

**In het spel** (`scripts/generator.gd`): staat in de westhoek van de basis op (-26,2; 0; -10), voorkant naar het midden. Botsblok (`GeneratorBody`, laag muur) 2,9 x 1,5 x 1,3 m: je loopt er niet doorheen en er kan niets op gebouwd worden. 350 hp; schade van jouw kogels en die van vijanden (0,6x), melee (0,5x) en explosies (1x via `Generator.blast`, aangeroepen vanuit vaten, raketten en granaten); kogels van je soldaten beschadigen hem niet. Onder 60%: rook en banner, onder 30%: vuur en lager motorgeluid, op 0: explosie (straal 7 m, schade aan vijanden, jou, gebouwen), brandend wrak zonder botsing en **stroomuitval**: `Game.power = false`. Dan zijn de zwaailampen bij de poorten uit en branden de straatlantaarns in de stad niet. Repareren: kaart "Generator repareren" in de wapenkamer (400 punten kapot, een derde bij schade). Het motorgeluid is een lus (`AudioStreamPlayer3D`, bereik 45 m).

Tests: `tests/generator_test.gd` (alles hierboven in de logica), viewertest `tools/blender-vq2-viewer/test-generator.mjs`, opnames `tests/generator_foto.gd`.
Geen iPhone/Xogot-meting gedaan.
