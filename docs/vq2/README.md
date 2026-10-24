# Blender Visual Quality 2 — resultaten en testinstructies

De drie bestaande modellen zijn daadwerkelijk opnieuw opgebouwd en geëxporteerd met Blender 4.3.2. De definitieve GLB's worden rechtstreeks door de bestaande game geladen. PR #54 blijft Draft tot de gebruiker de beelden op een fysieke iPhone/Xogot heeft beoordeeld.

## Open de interactieve viewer

[Bloedjungle VQ2 3D-viewer](https://bloedjungle-vq2-modellen.whole-jam-7898.chatgpt.site/tools/blender-vq2-viewer/)

De preview wordt privé voor de eigenaar gehost; meld zo nodig aan met hetzelfde ChatGPT-account. De bron staat op `feature/blender-visual-quality-v2-three-models`. Een lokale server kan ook, zie [viewer-instructies](../../tools/blender-vq2-viewer/README.md).

De hostingdienst bevestigt een geslaagde publicatie en leverde een [echt browserbeeld van de geladen kazerne](renders/hosted-viewer-kazerne.jpg). De volledige live-URL-check vanuit deze uitvoeromgeving is geblokkeerd: de netwerkproxy weigert de CONNECT met HTTP 403 vóór de site bereikt wordt. Alle interactieve functies zijn wel lokaal in Chromium gecontroleerd. [Publicatiebewijs en exacte beperking](results/live-site-test.json). Dit is een externe webviewer; er wordt geen native inline 3D-weergave binnen ChatGPT geclaimd.

- Eén vinger/muis draait 360°, twee vingers zoomen en verplaatsen.
- Kies V1, VQ2 of beide naast elkaar. V1 gebruikt vaste originele bytes uit main `967e9c2`, niet de later veranderende main.
- Camera en belichting zijn gedeeld. Het gamepreset gebruikt 58° elevatie, 28 meter afstand en 45° FOV.
- PBR-, albedo-, normal-, ruwheid- en wireframe-weergaven gebruiken de echte GLB-materialen.
- Statische modellen melden expliciet **Geen animaties in dit model**.
- De speelbare jeep biedt zeven echte clips, play/pause, opnieuw, snelheid en een scrubber. Wielen, sturen, vering, MG-terugslag en geschut draaien werkelijk via de GLB-tracks.
- De runtimebibliotheek staat lokaal gebundeld; de viewer heeft geen externe CDN nodig.

## Wat is veranderd

**Kazerne:** golfplaat met echte doorsnede/dikte, gebogen nok, plaatnaden en bevestigingen, fotografische vezelstructuur onder verweerde olijfverf, zichtbare houten verbindingen, kozijnen/vensterbank, ventilatielamellen, deurbeslag, naamplaat en fundering. De oude gevelbalken lopen niet meer door de deur. Oriëntatie, bouwkosten, bestaande plaatsing en de collider van 4,4 × 2,2 × 3,2 meter blijven behouden.

**Wachttoren:** versterkte houtverbindingen en knieschoren, stalen voetschoenen/boutplaten, dikker dek, echte dakgolven en afwatering, ladderbevestigingen en treden, fotografisch hout, canvas en staal. Het werkelijke dekoppervlak is 5,3 meter hoog; de bestaande +X-klimroute en `Toren_dak`/`Toren_dakrib` blijven intact, inclusief alle dakonderdelen die verdwijnen bij het klimmen.

**Statische legerjeep:** minder overbodige ronde segmenten en kleine bevels, betere PBR-verf/staal/stoelen, motorkapscharnier en sluitingen, carrosserieribben, gerichte modder aan wielranden, jerrycan-kruis en riemen. De bestaande StaticBody3D-collider is ongewijzigd.

**Speelbare jeep:** de bestaande geometrie, materiaaldefinities, 34 nodes en zeven clipnamen zijn behouden. Inspectie vond dat de oude GLB helemaal geen stuurkanaal bevatte, ondanks de beschreven `Bocht`-clip. De bestaande Blender-generator exporteert nu een zichtbaar, cyclisch stuurspoor. Godot behoudt de constante cliptracks bij import. De rij-, schiet-, schade- en besturingscode zijn ongewijzigd. [Compatibiliteitscontrole](results/asset-report.json) vergelijkt de echte oude/nieuwe GLB's, inclusief gelijke geometrische posities op 0,01 mm nauwkeurigheid.

## Geometrie- en materiaalbudget

| Asset | Driehoeken V1 → VQ2 | Meshes V1 → VQ2 | Materialen V1 → VQ2 | Surfaces V1 → VQ2 |
| --- | ---: | ---: | ---: | ---: |
| Kazerne | 2.428 → 13.912 | 13 → 14 | 13 → 9 | 13 → 14 |
| Wachttoren | 3.240 → 16.312 | 10 → 10 | 10 → 6 | 10 → 10 |
| Statische legerjeep | 75.628 → 46.436 | 1 → 1 | 15 → 13 | 15 → 13 |

De statische jeep bevat 38,6% minder driehoeken. De gebouwen zijn zwaarder door echte dakgeometrie, zachte randen en verbindingen. Productiebudgetten voor deze versie: maximaal 16k / 18k / 50k driehoeken, respectievelijk. Vier torens plus één kazerne en één statische jeep betekenen ongeveer 125,6k basisdriehoeken tegenover 91k in V1; de extra gebouwen kosten dus geometrie. Godot genereert bij import automatisch LOD's. Er zijn geen extra realtime lichten toegevoegd aan de game.

Een oppervlak is hier een mogelijke materiaaldraw per zichtbare mesh; schaduw- en rendererpasses kunnen extra draws veroorzaken. Vier torens plus één van de andere twee modellen hebben samen 67 surfaces tegenover 68 in V1. Dit zijn aantallen uit GLB-inspectie, geen gemeten frame-drawcalls.

Alle zeven PBR-families hebben echte 1024×1024 bronkaarten: albedo, OpenGL normal en gepakte roughness/metallic. [Provenance en bronhashes](../../assets/textures/vq2/provenance.json) verwijzen naar de bestaande CC0-fotobronnen. Er zijn geen lage resolutie afbeeldingen vergroot of betaalde providers gebruikt.

De browser-GLB's bevatten hun maps. De scoped Godot-importer koppelt uitsluitend `VQ2_*` aan gedeelde bestanden om tekstuurkopieën per GLB te voorkomen. De 21 gedeelde importbeelden gebruiken **14,0 MiB gecomprimeerde desktop-imagepayload inclusief mipmaps** in deze omgeving; zie [texture-budget.json](results/texture-budget.json). Ongecomprimeerd RGBA8 met mipmaps zou dit 112 MiB zijn. Dit bewijst geen werkelijk resident GPU-geheugen of iPhone-FPS; mobile ETC2/Metal kan verschillen. Globale renderinstellingen zijn behouden.

## Reproduceren

Benodigd: lokale Blender 4.3.2+, Python 3 met Pillow/Numpy en Godot 4.6.3 (geteste versies).

```sh
python3 tools/build_vq2.py
python3 tools/vq2_report.py
blender --background --threads 4 --python tools/render_vq2.py
godot4 --headless --path . --editor --quit
GODOT=godot4 tools/run_tests.sh
godot4 --headless --path . -s tools/vq2_texture_budget.gd
godot4 --path . scenes/vq2_showcase.tscn
```

De eerste command bouwt de bestaande generators, slaat de bewerkbare `.blend` met gepackte textures op en synchroniseert de runtime-GLB's. Baselines worden uit de vaste gitcommit gelezen en nooit over de verbeterde assets heen teruggezet. De `.blend`-bronbestanden staan in `bron/kazerne/uit/`, `bron/wachttoren/uit/`, `bron/legerjeep/` en `bron/jeep/`. Voor één model kan `--only kazerne|wachttoren|legerjeep|jeep` gebruikt worden.

De game-ontwikkel-CLI `game-dev` is niet geïnstalleerd in deze omgeving. De productie is rechtstreeks met de door de gebruiker gevraagde lokale Blender- en Godot-programma's uitgevoerd; geen tool-wrapper- of providerreceipts geclaimd.

## Godot-showcase en iPhone/Xogot

1. Fetch in Working Copy en check **feature/blender-visual-quality-v2-three-models** uit. Pull alleen deze branch; `main` hoeft niet aangepast te worden.
2. Open dit project in Xogot, laat de import aflopen en open `scenes/vq2_showcase.tscn`.
3. Start **deze scène**. Kies model en V1/VQ2; gebruik Schuin of Gamecamera voor de vergelijking.
4. **Klim toren** gebruikt de echte speler en ladderlogica; controleer op het dek de verdwenen dakdelen en bij afdalen het terugkerende dak.
5. **Rij zelf** gebruikt de bestaande speelbare jeep. Linker stick bestuurt; rechter stick richt/schiet. De bestaande IN/UIT-knop laat je uitstappen. De clipkeuze is een apart kijkmoment; Clip afspelen/Pauze demonstreert de werkelijke tracks.
6. Controleer textuurscherpte, licht/donkere materialen, transparant glas, shadows, bereikbaarheid van de knoppen en de normale gameplay via `scenes/main.tscn`.

Op een fysieke iPhone zijn Safari/WebGL/Metal, Xogot-import, touchcomfort, geheugen en langere speelsessies nog handmatig te beoordelen. Er is geen gemeten mobiele FPS of menselijke visuele goedkeuring geclaimd.

## Verificatie en echte renders

- Godot-import en de nieuwe integratietest slagen; de bestaande regressiesuite bevat 42 geslaagde tests inclusief VQ2. [Resultaten](results/verification.json).
- De VQ2-test controleert echte PBR-import en gedeelde textures, V1/V2 laden, gebouwplaatsing/colliders, daadwerkelijke platformgeometrie op 5,3 m, klimmen/afdalen/dakzichtbaarheid, wiel-/stuur-/MG-tracks en instappen/rijden/uitstappen.
- De browsercheck controleert drie vergelijkingen, vijf materiaalmodi, orbit, de 58°/28m-camera, zichtbare beweging in de bedoelde nodes van alle zeven clips, play/pause/scrub, 390×844 en 844×390 layouts en pinch zoom. Dit is Chromium-software-WebGL/touchemulatie, geen fysieke Safari-test. [Rapport](results/viewer-test.json).
- De Cycles CPU-studiorenders gebruiken gelijke camera, schaal en licht per V1/VQ2-paar. V1 is daar de oorspronkelijke kale GLB; in de Godot-opnames krijgt V1 zijn oorspronkelijke runtime `Kit.skin`-materialen.
- De Godot-opnames gebruiken de bestaande junglewereld, camera-node en gamecamera-instellingen (45° FOV, 58°, 28 m). Ze zijn gerenderd met Mesa llvmpipe/OpenGL Compatibility; het normale Forward+/iOS Mobile-projectprofiel is niet veranderd.
- Bestaande gear-owner- en ObjectDB/resourcewaarschuwingen bij afsluiten blijven zichtbaar; ze veroorzaken geen testfailure. Een fysieke Xogot-test blijft vereist.

| Model | Blender V1 | Blender VQ2 | Godot V1 | Godot VQ2 |
| --- | --- | --- | --- | --- |
| Kazerne | [beeld](renders/kazerne-studio-v1.png) | [beeld](renders/kazerne-studio-v2.png) | [beeld](renders/kazerne-godot-game-v1.png) | [beeld](renders/kazerne-godot-game-v2.png) |
| Wachttoren | [beeld](renders/wachttoren-studio-v1.png) | [beeld](renders/wachttoren-studio-v2.png) | [beeld](renders/wachttoren-godot-game-v1.png) | [beeld](renders/wachttoren-godot-game-v2.png) |
| Legerjeep | [beeld](renders/legerjeep-studio-v1.png) | [beeld](renders/legerjeep-studio-v2.png) | [beeld](renders/legerjeep-godot-game-v1.png) | [beeld](renders/legerjeep-godot-game-v2.png) |

De browservergelijkingen en jeepanimatiebeelden staan daarnaast in `renders/`. Alle beelden komen van Blender, Godot of de echte WebGL-viewer; er zijn geen AI-mock-ups gebruikt.
