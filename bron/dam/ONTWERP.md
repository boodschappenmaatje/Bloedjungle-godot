# Asset Design Specification: betonnen dam met sluisdeuren (dambreuk stap 2)

**Goedgekeurd door Dennis:** keuze 6A (betonnen gewichtsdam met sluisdeuren), 7A (alleen de speler met zwaar spul of springlading, drie zwakke plekken), 8A (5 s kraken, daarna de breuk), 13A (dam en dal liggen vast). Op 15 november 2026 aangescherpt: **minstens 40.000 driehoeken en 4K-texturen** (de keuzekaart zei eerst 25k en 2K).

## Uiterlijk en maten (meters, 1 eenheid = 1 m)
- Gewichtsdam van beton, 60 m breed op de kroon, 14 m hoog boven de kloofbodem, kroon 6 m breed. Voorkant (stuwmeerkant) bijna verticaal, achterkant 0,75 m vlak per meter hoogte. Tussen de kloofwanden ingeklemd met landhoofden die in de rots verdwijnen.
- Middenstuk van 36 m met drie stalen sluisdeuren (8 x 6,4 m, met ribben, rollen en bouten) tussen vier betonnen pijlers, drempel op 10 m, hijsmachines op een stalen loopbrug (3 m breed, rooster, leuning) op 18,6 m.
- Op de flanken: parapetten, stalen leuning en kabelgoot, lantaarns, twee betonnen trappen naar de loopbrug, inspectiegang met stalen deur, afvoergaten, wachthuis (links).
- Aan de achterkant een betonnen slijtvloer met barrièreblokken en geleidemuren, met stortsteen langs de randen. Stuwmeerpeil 12 m boven de kloofbodem (2 m onder de kroon).
- Stijl: realistisch, licht verweerd, olijfgroen staal (VQ2-palet), vuil, waterlijn, mos en roestvlekken in de vertexkleur.

## Gamefuncties
- Stap 2: dam staat er alleen. Stap 3 (breuk en vloed) gebruikt de clips en stukken hieronder; stap 4 de gevolgen.
- Zwakke plekken (stap 3): de drie poorten (`Poort_1..3`). Na twee kapotte poorten start `Kraken`; dan volgt `Breken`.

## Knopen en clips (30 beeld/s, NLA, rustpose = dam intact)
| Knoop | Wat |
| --- | --- |
| `Fundering`, `Flank_L/R`, `Slijtvloer`, `Trap_L/R`, `Leuning`, `Lantaarns`, `Wachthuis`, `Stenen` | vast |
| `Blok_i_j` (i = 1..8 kolom, j = 1..3 laag) | 24 betonblokken van het middenstuk, vallen weg in Breken |
| `Pijler_1..4`, `Poort_1..3`, `Hijs_1..3`, `Loopbrug` | bewegen in Breken |
| `Kraak_1..15` | scheuren (schaal 0,001 in rust, groeien in Kraken) |
| `Lek_1..11` | waterstralen (schaal 0,001 in rust, in Kraken aan, in Breken weg) |

- **Kraken (5 s):** scheuren groeien (0 tot 2,6 s gespreid), lekstralen vanaf 1 s, blokken, pijlers, poorten en loopbrug trillen steeds harder. Godot: sirene, stofwolkjes, scheurgeluid.
- **Breken (6 s):** poorten scheuren eerst los (0 s), dan pijlers en bovenste blokken, dan de rest van binnen naar buiten, daarna de loopbrug met de hijsmachines. Eindpose: puin stroomafwaarts. Godot: schuim, nevel, geluid, vloedwater (stap 3).
- **Godot-gestuurd (niet in Blender):** vloedwater, schuim, nevel, geluid, schade-aantallen, het vervangen van het gebroken middenstuk door puin.

## Materialen en texturen
`DAM_Beton` en `DAM_Staal` krijgen 4K-foto-PBR (albedo, normal, ORM) van Poly Haven, CC0: **concrete_wall_007** (beton) en **green_metal_rust** (staal), jpg 4096 x 4096 (`assets/textures/dam/`). `DAM_Steen` (stortsteen) gebruikt hetzelfde beton donkerder. Verder `DAM_Water`, `DAM_Lamp`, `DAM_Glas`, `DAM_Kraak` zonder textuur. UV's zijn wereldgebonden (3 m per tegel beton, 2 m staal), de vertexkleur (AO, vuil, waterlijn, mos) zit in COLOR_0. De glb heeft alleen kale materialen; Godot (`scripts/dam.gd`) en de viewer hangen de maps eraan.

## Budget en acceptatie
- Minstens 40.000 driehoeken: **54.066** (beton 35.960, staal 10.736, steen 3.680, water 1.584, scheuren 1.818, lamp/glas 288).
- Tekenbudget in het spel: de dam tekent als één samengevoegd net (6 oppervlakken) zonder schaduw; de 71 losse stukken zijn verborgen tot `kraken()`/`breken()`.
- Geheugen: zes 4K-maps; geschat ongeveer 130 MB VRAM met ASTC en mipmaps op de iPhone. **NIET GETEST** op een echt toestel.
- Acceptatie: `tests/dam_test.gd`, viewer-test `tools/blender-vq2-viewer/test-dam.mjs`, opnames `docs/dambreuk/captures/dam_*.jpg`, geen iPhone-meting geclaimd.

## Versie 2: Dennis' Meshy-dam via de importstraat (15 november 2026)
- Bron: Dennis' eigen Meshy-dam (2.403.118 driehoeken) en Meshy-sluisdeur (898.670), Google Drive, niet in de repo. Eerst door `tools/importstraat/straat.py` (dam 14 m hoog, 50.000 driehoeken, 4K gebakken; deur 8 m breed, 8.000 driehoeken, 2K), daarna `DAM_MESHY=<straat-uitvoer> python3 maak_dam.py uit/` met `meshy_dam.py`.
- De Meshy-dam is ~31 x 15 m en heeft geen deuren. Zonder vervorming verbreed naar 60 m: het vlakke muurstuk naast het midden gespiegeld herhaald (naden als dilatatievoegen). In het midden boven 10 m uitgezaagd voor de pijlers, de drie Meshy-sluisdeuren, loopbrug en hijsmachines (procedureel gebleven). Onder de drempel 24 blokken met dichte zaagvlakken (`Blok_i_j`, pivot in hun midden).
- Meshy-kroon is ~1,3 m dik: een kroondek van 6 m op betonconsoles (Flank_L/R) zodat het spel (kroon y -3..3) klopt. Pijlers staan op de muur in plaats van op de oude schuine achterkant. Scheuren en lekstralen liggen op het nieuwe achtervlak; in Breken verdwijnen de scheuren op het middenstuk met de blokken.
- Zelfde knopen en clips (Kraken 5 s, Breken 6 s). 109.341 driehoeken (Meshy-muur 67.550, deuren 24.000). Materialen `DAM_Meshy` en `DAM_Sluis` (gebakken, `assets/textures/dam/meshy_*`), beton en staal blijven 4K Poly Haven.
- Geheugen (schatting ASTC): Meshy-dam 3 x 4K ~67 MB + deur 3 x 2K ~17 MB bovenop de bestaande ~130 MB. iPhone **NIET GETEST**.
- Oude dam: `assets/vq2_baseline/dam.glb` (viewer V1).
