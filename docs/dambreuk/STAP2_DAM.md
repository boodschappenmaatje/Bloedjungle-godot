# Dambreuk-plan stap 2: dam en stuwmeer (v240)

**Keuzes van Dennis:** 6A (betonnen dam met sluisdeuren), 7A, 8A, 13A. Op 15 november 2026 aangescherpt: **minstens 40.000 driehoeken en 4K-texturen**.
**Status:** zelfde Draft PR als stap 1 (#316). Niet mergen en geen OTA zonder Dennis' aparte go. Native iPhone: **NIET GETEST**.
Ontwerpspecificatie: `bron/dam/ONTWERP.md`.

## Wat er nu is
| Onderdeel | Bestand | Wat |
| --- | --- | --- |
| Dammodel | `bron/dam/maak_dam.py` (Blender, headless), `assets/dam.glb`, `bron/dam/uit/dam.blend` is het resultaat | 60 x 14 m, drie stalen sluisdeuren, loopbrug met hijsmachines, trappen, wachthuis, slijtvloer, stortsteen. **54.066 driehoeken**, 71 stukken, 7 materialen. Echte clips **Kraken** (5 s) en **Breken** (6 s). |
| Texturen | `assets/textures/dam/` | 4096 x 4096: beton (Poly Haven `concrete_wall_007`) en staal (`green_metal_rust`), CC0. Albedo, normal en ORM per materiaal. Vuil, AO, waterlijn en mos zitten in de vertexkleur. |
| Dam in het spel | `scripts/dam.gd` (`Dam`) | Staat op de kloofbodem bij `Bergland.DAM_Z`. Tekent één samengevoegd net (6 oppervlakken, geen schaduw); de losse stukken zijn verborgen tot `kraken()` of `breken()` (stap 3). |
| Stuwmeer | `scripts/stuwmeer.gd`, `shaders/stuwmeer.gdshader` | Peil `Bergland.LAKE_Y` = 14 m. De vorm volgt het terrein (vloedvulling vanuit het bekken), 180 x 220 m, alleen voor de dam. Diepte in de vertexkleur: donker en diep in het midden, helder en met schuimrand bij de oever. |
| Viewer | `tools/blender-vq2-viewer` (keuze "Betonnen dam"), `test-dam.mjs` | Echte glb, 4K-maps, clips Kraken en Breken met schuifbalk. |
| iPhone-preview | `previews/usdz/dam/v1/Bloedjungle_Dam_iPhone.usdz` | 6 MB, texturen op 2048 px (preview), animatie meegenomen. Apple-controle (`usdchecker`) **NOT RUN**: hier geen macOS. |

## Tests
- `tests/dam_test.gd`: plek, minstens 40.000 driehoeken, 4K-maps, 24 blokken, 4 pijlers, 3 poorten, 3 hijsmachines, scheuren en lekken, duur van de clips, samengevoegd net, Kraken groeit de scheuren, Breken laat blokken wegvallen, meer op peil en voor de dam. **PASS**.
- `tests/bergland_test.gd` en `tests/vijand_basis_test.gd` blijven slagen. Viewer: `node test-dam.mjs` **PASS** (Chromium, software-WebGL).

## Opnames (Godot 4.7.2, lavapipe, 1280 x 720, zelfde seed)
`docs/dambreuk/captures/dam_*.jpg` (van voren, tactisch, ooghoogte, stuwmeer van boven, vanaf het meer, overzicht, dichtbij) en `dam-viewer-rust/kraken/gebroken.png`.

## Prestaties (schatting, NIET GETEST op iPhone)
- Geometrie: +54k driehoeken in 6 tekenopdrachten, zonder schaduw; meer: ongeveer 2.000 driehoeken, 1 tekenopdracht. Dam en meer liggen ver van het speelveld (36 m buiten de kaart) en zijn alleen in beeld als je naar het noorden kijkt.
- **Geheugen is de zorg:** zes 4K-maps zijn ongeveer 130 MB VRAM (ASTC met mipmaps). Als de iPhone-test dat te veel vindt, zetten we de import voor `assets/textures/dam/*` op 2K; dat is een kleine aanpassing.
- Laadtijd: model en samenvoegen waren in de cloud niet merkbaar (geen meting op iPhone).

## Bekend en nog te doen
- De dam breekt nog niet: dat is stap 3 (breuk en vloed). De clips zijn er al.
- Geen botsing en geen schade op de dam: pas nodig als je hem kunt beschieten (stap 3).
- Het meer heeft nog geen golven of oevergeluid; dit is een rustig meer. Wat het water na de breuk doet is stap 3.
