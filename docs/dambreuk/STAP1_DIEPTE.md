# Dambreuk-plan stap 1a: diepte rond de kaart (v238)

**Keuzes van Dennis (14 november 2026):** 1A 2A 3B 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A. Keuzekaart: `/mnt/project-files/generals/dam/dam-keuzes.html`.
**Status:** Draft PR. Niet mergen en geen OTA zonder Dennis' aparte go. Native iPhone: **NIET GETEST**.

## Wat er was
- De wereld was één vlakke grondplaat (440 x 520 m) op hoogte 0. Daarbuiten zag je de rand van de plaat en een donkergroene band (de onderkant van de lucht).
- De rivier is een geul van 0,85 m; de bedding stopt bij x = ±210 en de grondplaat bij ±220 (daar zat een gat in de grond).

## Wat stap 1a toevoegt
| Onderdeel | Bestand | Wat |
| --- | --- | --- |
| Hoogtefunctie | `scripts/bergland.gd` `Bergland.height()`, `Data.ground_y()` | 0 op de hele grondplaat; daarbuiten heuvels (zuid, oost, west), hoge bergen (noord), rivierdal, kloof en stuwmeerbekken. Vaste vorm (keuze 13A), de rivier kronkelt zoals nu per spel. |
| Bergland-mesh | `scripts/bergland.gd` `build_mesh()` | Raster van 10 m tot 760 m van het midden, cellen op de plaat overgeslagen: **40.416 driehoeken, 1 tekenopdracht, 1 materiaal**, geen schaduw (belichting via normalen en holte in de vertexkleur), geen botsing (niemand komt buiten `Data.clamp_world`). |
| Shader | `shaders/bergland.gdshader` | Bladerdak met boomkruinen (2 ruislookups), rotswanden waar het steil is (triplanair, 2 lookups), donkere dalen, zachte overgang naar de plaatrand. Bestaande texturen (`jungle_ground`, `gravel_rock`), **geen nieuwe texturen**. |
| Rivier verder | `Bergland._river_out()` | Water loopt van x = ±206 door het dal tot 760 m (vult ook het oude gat tussen 210 en 220). |
| Kloof voor de dam | `Bergland.GORGE_X / DAM_Z / BASIN / LAKE_Y` | Kloof recht boven de vijandbasis (x ≈ -36), dam komt op z = -336 (36 m buiten de plaat) met de bodem op +2 m, wanden > 18 m; bekken rond (-48, -470) voor het stuwmeer (peil +14). |
| Verre bergen in de lucht | `shaders/lucht_bergen.gdshader`, `scripts/atmosphere.gd` | Vervangt de `ProceduralSkyMaterial` door een sky-shader met dezelfde kleuren en zon plus twee rijen bergsilhouetten. Die zijn ook in third person (zichtafstand 60 m) te zien. Onder de horizon is de lucht nu heiig in plaats van een donkergroene band; de belichting (cubemap) gebruikt nog de oude grondkleur. |

Bestaande gameplay is ongewijzigd: alles op de plaat blijft op hoogte 0 (`tests/bergland_test.gd` controleert 400 willekeurige punten). Vliegtuigen (12 m) blijven in de eerste 50 m buiten de kaart boven de heuvels.

## Niet in deze stap (stap 1b)
- Rivierdal en heuvels **in** het speelveld (dan moet alles wat beweegt `Data.ground_y` volgen; ongeveer 35 scripts zetten nu `y = 0`).
- Waterdiepte in de watershader (helder bij de oever, bodem zichtbaar): pas zinvol als de rivier echt dieper is.
- Rotsmeshes langs steile wanden (nu alleen in de shader).

## Opnames (zelfde camera's, licht en seed; links v237, rechts v238)
`tools/diepte_foto.gd`, Godot 4.7.2, Vulkan op lavapipe (cloud), 1280 x 720, zonder HUD. Bestanden: `docs/dambreuk/captures/`.
1. Overzicht rivier en stad (tactisch, zichtafstand 220 m)
2. Noordkant met de kloof achter de vijandbasis (zichtafstand 400 m)
3. Ooghoogte zoals third person (zichtafstand 60 m)
4. Oostrand waar de rivier de heuvels in loopt (220 m)
5. Hoog vanuit het zuiden zoals bij vliegen (600 m)

## Prestaties
- Bergland: +40k driehoeken in één tekenopdracht, zonder schaduwpas; de vertex-belasting is klein naast de jungle. Geschat +0,2-0,4 ms GPU.
- Lucht: een paar sinussen per luchtpixel, geen texturen; de cubemap-pas slaat de bergen over. Geschat < 0,1 ms.
- Laadtijd: het raster (21k hoogtes + normalen) wordt bij het bouwen van de wereld gemaakt; in de cloud ongeveer 0,1-0,2 s.
- Native iPhone-fps: **NIET GETEST**. Lavapipe-tijden zeggen niets over de iPhone.
