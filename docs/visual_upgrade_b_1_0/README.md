# Bloedjungle — Visual Upgrade B 1.0

**Draft PR:** [#237](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237)
**Branch:** `feature/visual-upgrade-b-1-0`
**Codecommit in de nieuwste Godot-capture en iOS-export:** `ff1002deb27e081e53c426672bcf6851b2f445b4`
**Gerichte kwaliteitspass:** `8d1ed47` — terreinshader en bestaande understoryplaatsing.

De gebruiker heeft de C-afbeelding uit de chat als kwaliteitsrichting gekozen. De pass hergebruikt bestaande meshes en PBR-assets; plantenaantallen, grafische instellingen, gameplay, camera, HUD, besturing, collisions en schietlijnen zijn niet aangepast. De aanpassing voegt geen nieuwe modellen of plantmassa toe.

## Huidige pass

De terreinshader breekt de bestaande gras-, aarde-, mos- en grindlagen en de padschouders wat verder op, met subtielere world-space detailmapping. Bestaande jungle-understorygroepen zijn losser verdeeld en brede rozet-/varenmodellen iets verkleind; bestaande MultiMesh-, LOD- en afstandscullingstructuur blijft staan.

De visuele uitkomst is **een beperkte, zichtbare verbetering en nog geen acceptabel eindniveau**. De vier echte screenshots laten zien dat open bosgrond nog egaal blijft, het pad nog als vrij uniforme strook leest, en herhaalde lage rozetten/varens de jungle-rand nog te dicht en stilistisch uniform maken. Bij de rivier is het water vlak en een radiale plant dicht bij de speler trekt de aandacht. De beelden liggen nog duidelijk onder de rijke, premium C-richting. Daarom blijft visuele acceptatie open.

## Echte Godot-captures

Deze onbewerkte PNG's komen uit de bestaande `scenes/main.tscn`-gamecamera. Ze zijn in één actuele capturepass gemaakt na de gerichte shader-/plaatsingswijzigingen. Ze zijn geen conceptafbeeldingen.

| Locatie | Echte Godot-render |
| --- | --- |
| Bospad | [PNG](captures/iterations/ff1002d/bospad.png) |
| Rivier | [PNG](captures/iterations/ff1002d/rivier.png) |
| Kamp | [PNG](captures/iterations/ff1002d/kamp.png) |
| Combat — 80 vijanden | [PNG](captures/iterations/ff1002d/combat.png) |
| Vier scènes naast elkaar | [Overzicht](captures/iterations/ff1002d/overzicht-4-scenes.jpg) |

Captureworkflow: [Godot Actions-run 42460199664](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42460199664), geslaagd op codecommit `ff1002d`; artifact-id `13609722999`. Godot 4.7.2 Mobile/Forward Mobile via Vulkan, 1280×720, 100% capture scale, High/day/clear, MSAA 2, FOV 45° en bestaande cameraregistratie/pitch. Locaties en alle instellingen staan in [CAPTURE.md](captures/iterations/ff1002d/CAPTURE.md).

De adapter is **llvmpipe-software-rendering** op Linux, niet een telefoon of fysieke GPU. De ingebrande `1 FPS` op de captures en de metrics horen uitsluitend bij die softwarebackend. Dit is geen iPhone-, Metal- of GPU-prestatieclaim.

## Software-renderdiagnostiek

De workflow verzamelde 60 frametimingsamples per scène, 100 voor combat, plus gemiddelde draw calls en primitives. Deze waarden zijn van llvmpipe en niet representatief voor iPhone. Ze zijn alleen opgenomen voor reproduceerbaarheid; vergelijk ze niet rechtstreeks met de oude 60%-capture of met hardwaremetingen.

| Scène | Gemiddelde frame ms | P99 ms | Software 1%-low FPS | Draw calls gem. | Primitives gem. |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bospad | 3217,5 | 3768,5 | 0,265 | 527 | 4.087.995 |
| Rivier | 1345,3 | 1392,6 | 0,718 | 424 | 3.614.767 |
| Kamp | 4518,4 | 4852,4 | 0,206 | 463 | 1.673.251 |
| Combat — 80 vijanden | 3477,3 | 8393,6 | 0,119 | 1439 | 4.939.503 |

Ruwe bron: [metrics.json](captures/iterations/ff1002d/metrics.json). De exacte testsoftware en adapter zijn vastgesteld; de lage waarden tonen vooral dat deze Linux-run geen bruikbare hardwarebenchmark is. iPhone-frametimes, 1%-lows, shimmer, gevechtsperformance en thermiek zijn **niet gemeten**.

## Validatie en iPhone-test

- Godot 4.7.2 workflow op `ff1002d`: projectimport, Visual B-terrein-/foliage-integratietest en alle vier captures PASS. Bekende waarschuwing: SSAO wordt niet ondersteund door de ingestelde Mobile-renderer; capture meldt geen script-/shaderfout.
- Unsigned iOS-export: [run 42460949217](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42460949217), PASS op dezelfde codecommit `ff1002d` en gekoppeld aan PR #237.
- Testartifact: `bloedjungle-ios-unsigned-ff1002deb27e081e53c426672bcf6851b2f445b4`, id **`13609419743`**, 1.156.344.069 bytes, downloadbaar t/m 8 december 2026. Download via de tab **Artifacts** in de iOS-run. Het is unsigned: onderteken met je eigen Apple-account vóór installatie.
- De export maakt de build beschikbaar voor de gebruiker, maar bewijst geen installatie, iPhone-uitvoering, Metal-rendering of prestaties. Geen fysieke iPhone- of Windows-runtime-test is uitgevoerd.
- Zie [IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md) voor de teststappen. Houd shimmer, grote gevechten, frametimes/1%-lows en warmte op **niet gemeten** tot ze fysiek zijn getest.

Visuele en mobiele acceptatie blijven open. PR #237 blijft **Draft**, wordt niet gemerged en er is niets via OTA gepubliceerd.
