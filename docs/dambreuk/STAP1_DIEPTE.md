# Dambreuk-plan stap 1a: diepte rond de kaart (v239)

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

## Opnames (zelfde camera's, licht en seed; links main zonder deze PR, rechts deze PR; de labels op de beelden zeggen nog v237/v238)
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

---

# Stap 1b: reliëf in het speelveld en diepe rivier (v239)

**Status:** zelfde Draft PR. Niet mergen en geen OTA zonder Dennis' aparte go. Native iPhone: **NIET GETEST**.

## Wat stap 1b toevoegt
| Onderdeel | Wat |
| --- | --- |
| `Bergland.relief(x, z)` | Heuvelrug langs de rivier (tot 2,2 m, behalve bij brug, voorde en achterdeur) en flanken aan de oost- en westkant (tot 4 m). Steilste helling 0,18. Loopt zonder sprong over in `Bergland.height()` aan de plaatrand. |
| Vlakke terrassen | Kamp, stad, vijandbasis, rivierstrook (3,5 m) en oversteekplaatsen blijven exact op 0 (test met 600 punten). |
| Grond | Mesh op 4 m raster met normalen en tangenten, botsing met `HeightMapShape3D`. |
| Bewegende dingen | Soldaten, bondgenoten, vijanden, jeep, tank, vijandjeep en -tank, MCV, auto, bus, vrachtwagen, voorraadtruck, parachutisten, vliegtuig, Apache, effecten, decals en begroeiing volgen `Data.ground_y()`. |
| Bouwen | Gebouwen, MCV en verdedigingen staan op grondhoogte. Te steil (meer dan 0,6 m verschil onder de bouwvlak) geeft "Te steil om te bouwen". Vinger naar grond via `Data.ground_ray()` (build_mode, napalm, bevelstand). |
| Rivier | Bedding 1,9 m diep, waterpeil -0,45 m, voorde ondieper. Watershader is helder bij de oever (bodem zichtbaar) en donkerder in het midden. |

## Tests
- `tests/bergland_test.gd` slaagt (heuvelrug 2,2 m, flank 4,0 m, steilste helling 0,18; terrassen exact 0; vliegtuigen op 12 m blijven vrij; kloof en bekken; mesh <= 45k driehoeken).
- `tests/vijand_basis_test.gd` aangepast voor `HeightMapShape3D`.
- Volledige ronde (170 tests): 26 falende tests falen ook op main met dezelfde melding; de overige twee waren niet door 1b veroorzaakt (magazijn_dak is wisselvallig, vijand_basis is aangepast).

## Opnames (links main zonder deze PR, rechts deze PR)
`tools/diepte_foto.gd`, Godot 4.7.2, lavapipe, 1280 x 720, zelfde camera's en seed: `docs/dambreuk/captures/1b_k_*.jpg` (9 stuks, onder andere heuvelrug zuidoever, flank oost, diepe rivier dichtbij, rivier op ooghoogte).

## Bekende beperkingen
- Voertuigen volgen de hoogte maar kantelen niet mee met de helling.
- Soldaten bij de voorde lopen op y = 0 boven de diepere bedding (nog geen wadiepte).
- Kogels worden niet door heuvels tegengehouden.
- Rotsmeshes langs steile wanden ontbreken nog (alleen in de shader).
- Native iPhone (fps, aanraking, spel op hellingen): **NIET GETEST**.
