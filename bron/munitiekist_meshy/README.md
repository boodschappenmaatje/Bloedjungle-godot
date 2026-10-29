# Munitiekist (Meshy-test, VQ2-opschoning)

Eerste proef met [Meshy](https://www.meshy.ai) text-to-3D als bron voor Bloedjungle-props. **Testasset:** nog niet in het spel geplaatst; de bestaande procedurele `Kist_Munitie` in `assets/props.glb` blijft ongewijzigd. Of de Meshy-kist die vervangt, beslist Dennis na het bekijken.

## Bron

| | |
| --- | --- |
| Dienst | Meshy API v2 text-to-3D, `art_style: realistic`, remesh naar driehoeken (doel 8.000) |
| Prompt | military ammunition crate, olive drab painted wooden box with metal corner brackets, two rope carry handles, steel latches, stenciled yellow markings, slightly weathered and worn edges, realistic, game asset |
| Textuurprompt | olive drab painted wooden ammunition crate, worn paint on edges, dark steel brackets and latches, faded yellow stencil text, light dirt |
| Taken | preview `01a188f6-c712-7689-b8ef-386874666f63` (20 credits), refine met PBR `01a188f7-9698-70a4-8398-33fb54b703c6` (10 credits), 29-10-2026 |
| Resultaat | `meshy_bron.glb`: 6.941 driehoeken, 1 materiaal, 2K albedo / normal / metallic-ruwheid (jpg), versnipperde UV-atlas. `meshy_thumb.png` = Meshy's eigen voorbeeld. |
| Licentie | Meshy betaald abonnement: de uitvoer is van de abonnee (Dennis), privé en commercieel bruikbaar. |

## Opschoning (`maak_munitiekist.py`)

    python3 maak_munitiekist.py uit/          # Blender 5.2 via pip install bpy, ~1 minuut
    cp uit/munitiekist_meshy.glb ../../assets/

1. Op echte maat: 70 × 57 × 43 cm, lengte langs X, pivot midden onder (onderkant op y = 0), transformaties toegepast.
2. Meshy schreef onleesbare AI-letters ("AWAIN") op de zijkanten. Die zijn uit de albedo gepoetst (gele pixels opgevuld met de omliggende verf) en in de normal map vlak gemaakt.
3. Lage versie: decimeren naar 2.500 driehoeken met nieuwe UV's (Smart UV Project). Direct decimeren op Meshy's UV-atlas liet de textuur zichtbaar schuiven; 1.500 driehoeken gaf kreukels aan de dekselrand, daarom 2.500 (net boven de richtwaarde voor een kleine prop, gemotiveerd door beeldkwaliteit).
4. Albedo, tangent-normal, ruwheid en metallic van hoog naar laag gebakken (Cycles CPU, 2K) en ingepakt als glTF-ORM. Meshy zette veel geverfd hout op half-metallic; alleen het donkere grijze beslag blijft metaal, verf/hout wordt mat (ruwheid ≥ 0,62).
5. Materiaal `Munitiekist_Meshy`, enkelzijdig. Game-glb met 1K-texturen; `uit/munitiekist_meshy.blend` bevat hoog (verborgen) en laag met de 2K-bake.

## Resultaat

| | Oud `Kist_Munitie` | Meshy-kist |
| --- | ---: | ---: |
| Driehoeken | 572 | 2.499 |
| Materialen / surfaces | 2 / 2 | 1 / 1 |
| Texturen | VQ2-sets olive + steel, 1K | eigen 1K albedo / normal / ORM |
| Maat | 62 × 30 × 30 cm | 70 × 57 × 43 cm |

Bekende Meshy-gebreken die na opschoning zichtbaar blijven: een donkere spleet over het deksel (zit in Meshy's geometrie), een paar kreukels in de onderste rand. Op gamecamera-afstand (28 m) is de kist ongeveer 15 pixels breed.

Beelden: `docs/vq2/renders/munitiekist-blender-oud-meshyvol-meshygame.png` (Cycles: oud, Meshy vol, Meshy game), `docs/vq2/renders/munitiekist-viewer-*.png`.

## Tests

| Test | Status |
| --- | --- |
| Godot 4.7.2 import + `tests/munitiekist_meshy_test.gd` (maat, pivot, 1 surface, 1K-PBR, enkelzijdig) | PASS |
| Viewer `tools/blender-vq2-viewer/test-munitiekist.mjs` (oud/nieuw/naast elkaar, gamecamera, draaien, geen clips) | PASS (Chromium, software-WebGL) |
| USDZ `previews/usdz/munitiekist_meshy/v1/` (pakket: usdc + 3 texturen) | PASS; Apple `usdchecker` NOT RUN (geen Mac) |
| In het spel geplaatst / gameplayregressie | NOT RUN (testasset, niet geplaatst) |
| iPhone / Xogot / Safari / Quick Look | NOT RUN |

Geen animaties: een gesloten kist heeft geen clips.
