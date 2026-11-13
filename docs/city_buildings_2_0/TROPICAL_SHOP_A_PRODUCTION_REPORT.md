# Tropical Shop A — productie- en testrapport

**Branch:** `feature/city-buildings-2-0-tropical-shop`
**Draft PR:** #306
**Status:** geïntegreerd in de stadseditor en klaar voor CI/iPhone-installatietest; niet gemerged, geen OTA-publicatie.

## Wat is opgeleverd

- De goedgekeurde Meshy-GLB is ongewijzigd bewaard in `bron/tropical_shop_a/source/`. De tiled roof-geometrie en het originele materiaal zijn hergebruikt; de overige gesloten bronmesh is vervangen door een echte holle, modulaire constructie met openingen.
- Bewerkbare Blender-bron en generator: `bron/tropical_shop_a/Tropical_Shop_A.blend` en `build_tropical_shop_a.py`. De Godot-export is `assets/tropical_shop_a.glb`.
- De winkel is 10,3 × 8,6 m met twee vloeren, 18 houten traptreden, balkon, zeven beweegbare deurpivots, winkelmeubilair en bovenwoning. Het dak en de interieurmodules zijn afzonderlijk benoemd voor zichtbaarheid en cutaway.
- De stadseditor biedt **Tropisch winkelpand A · 2 lagen** aan in de categorie Gebouw, met footprint, kosten, plaatsingspreview en echt gerenderd paleticoon. Het gebouw wordt niet toegevoegd aan `StadData.ITEMS` of de standaardstad.
- `scenes/tropical_shop_a_test.tscn` is een geïsoleerde speelbare testscene. De default spelerbesturing, camera en actieve stad zijn niet gewijzigd.
- De bestaande interactieve viewer bevat het GLB als `tropical_shop_a`; renders zijn opgeslagen onder `bron/tropical_shop_a/previews/`. De USDZ-preview staat in `bron/tropical_shop_a/previews/usdz/`.

## Geometrie en mobiele grenzen

Godot/GLB-importaudit: **71.223 driehoeken, 44 meshes, 52 nodes en 11 materialen**. De oorspronkelijke gecombineerde Meshy-mesh is gerapporteerd op 48.646 driehoeken. De runtimeexport houdt modules gescheiden voor dak-, verdieping- en cutaway-zichtbaarheid.

LOD0/LOD1/LOD2 zijn niet afzonderlijk gebakken of op een iPhone gemeten. Ook GPU-frame time, draw calls tijdens gameplay, geheugengebruik en 60 FPS op iPhone 18 Pro Max zijn **NIET GETEST**. Het model overschrijdt het voorlopige richtgetal van circa 50.000 polygonen; echte iPhone-profilering is nodig voordat prestaties kunnen worden goedgekeurd. De editorpreview gebruikt de bestaande vereenvoudigde footprint en er zijn aparte gameplaycolliders voor muren, vloeren, meubels, trap en balkon.

De huidige scene gebruikt de project-bestaande bewegings-/aanvalsinvoer. Er is geen nieuwe navmesh toegevoegd; AI-routeplanning door dit interieur is daarom **NIET GETEST**.

## Verificatie

- **PASS** — Blender 4.5.4 batchrender van de zeven gebouwrenders uit de opgeslagen `.blend`; soldaat is de echte `soldaat_vq2.glb`.
- **PASS** — GLB-audit en Godot 4.7.2 headless import/scene-start.
- **PASS** — geïsoleerde zelftest van GLB, stadseditorregistratie en plaatsing, zeven deuren, collision, meubelcolliders, traplopen, balkon, interieur-ray, dak/cutaway en camerawissel.
- **PASS** — bestaande `stad_editor_2_test.gd`: 2.963 controles, 0 fouten; alle editor-kaarten hebben een geladen preview-icoon. De eerste run vond een ontbrekend icoon voor dit type; het modelicoon is toegevoegd en de rerun slaagde.
- **PASS** — geïsoleerde Godot-test: GLB, stadseditorplaatsing, deuren, collision, meubels, trap, balkon, raycast en cameramodi.
- **PASS** — interactieve 3D-viewer build; 360° draaien en zoom.
- **PASS** — USDZ ZIP-integriteit/exportpakket. Apple `usdchecker --arkit`, Quick Look op een fysieke iPhone en iPhone-installatie/playtest zijn hier niet uitgevoerd.
- **PENDING** — iOS unsigned export en de volledige CI/regressies; de workflow start na push van de Draft PR-update.

De unsigned IPA uit de bestaande CI-workflow vereist lokaal ondertekenen/sideloaden (workflow-opmerking noemt AltStore). Er wordt geen OTA-release gemaakt. De daadwerkelijke native iPhone-test en FPS-meting blijven open tot de app op het apparaat is geïnstalleerd.

## Preview- en testpaden

- `bron/tropical_shop_a/previews/01_street_exterior.png`
- `bron/tropical_shop_a/previews/02_rear_exterior.png`
- `bron/tropical_shop_a/previews/03_build_camera_roof.png`
- `bron/tropical_shop_a/previews/04_ground_floor_open.png`
- `bron/tropical_shop_a/previews/05_upper_floor_without_roof.png`
- `bron/tropical_shop_a/previews/06_third_person_soldier_inside.png`
- `bron/tropical_shop_a/previews/07_balcony_and_stair.png`
- `scenes/tropical_shop_a_test.tscn`
- `tools/blender-vq2-viewer/index.html` — open via een lokale webserver en kies “Tropisch WOII-winkelpand A”.
