# Kazerne HQ 2.0 — Asset Design Specification

Status: **ontwerp A goedgekeurd op 2026-11-02**. Productie op `feature/kazerne-hq-2-0-wwii`; **niet mergen, geen OTA** zonder afzonderlijke toestemming.

## Bronnen en rangorde
1. `docs/GENERALS_PLAN.md`: Generals-achtige RTS met speelbare soldaat, bestaande economie/techboom en kazerneproductie.
2. `docs/ASSET_QUALITY_STANDARD.md`: High Quality Showcase, uitvoerbare Blender-bron, 2K PBR, viewer/iPhone-preview, tests, één Draft PR.
3. `bron/hoofdkwartier/ASSET_DESIGN_SPEC.md` en `assets/hoofdkwartier.glb`: referentie voor materiaalafwerking, detail, niveauvarianten, overgangen en mobiele LOD.
4. `bron/kazerne/maak_kazerne.py` en `scripts/buildings.gd`: origineel formaat en gameplaycontract.

## Goedkeurde stijl
**A — authentieke Amerikaanse WOII-veldbarak** (1943–1945), herkenbaar als kazerne, niet als tweede commandocentrum.
Olijfgroen verweerd geverfd hout, donkere gegalvaniseerde golfplaten, houten draagwerk, metalen verstevigingen, betonnen voet, zandzakken en kaki canvas. Realistische constructie, subtiel vuil/afbladdering, geen speelgoedlook en geen kopie van C&C-assets. Lichtbalans bij dag en nacht aansluitend op hoofdkwartier. Extra detail op dak en bovenste gevelranden, zichtbaar met de bestaande top-down camera.

## Exacte gameplaycontracten — behouden
- **Bouwvoet/collision:** `Vector3(4.4, 2.2, 3.2)` uit `scripts/buildings.gd` blijft gelijk; maximaal één kazerne, 600 HP, bestaande bouwprijs en 12 s bouwtijd.
- **Pivot:** grondcentrum (0,0,0), met deur aan lokaal **+Z in Godot** (Blender -Y), geen verplaatsing van het bestaande gebouw.
- **Rekruutspawn:** `door_of()`, 2,5 m vóór de pivot; moet vrij blijven. De bouwwijzer/voordeur moeten overeenkomen.
- **Bestaande Generals-logica:** wachtrij maximaal vijf, annuleren met restitutie, verzamelvlag/volgen, `REQUIRES`, training, `room()`, `Game.allies`, schade/verkopen/repareren en bestaande radio onveranderd functioneel.
- **Niveaus:** bestaande lv1 (2 soldaten, 10s), lv2 (4, 7s), lv3 (6, 5s), inclusief bestaande kosten en HP/damage; HK-niveau 2 geeft 25% training-/bouwtijdwinst. De visuals volgen `b.lv`; geen extra gameplay-upgrades.
- **Bouw/vernietiging:** steigers en zichtbare bouwprogressie blijven; schade/instorten, botsing en wrakfunctie behouden. Geen begaanbaar interieur in deze scope omdat huidige collision één gesloten volume is.

## Bouwmodel
- Basismodel 4,4 × 3,2 m, wandhoogte 2,2 m, zichtbare schuine dakvorm tot circa 3,1 m; klein maximaal 0,35 m dakoverstek buiten de footprint met eenvoudige collider ongewijzigd.
- Deurpartij centraal aan +Z: duidelijk herkenbare deur, correcte scharnierzijde, kooilamp, bovenluifel/naamplaat `KAZERNE`, kleine toegangsplaat zonder blokkering van spawn.
- Geloofwaardig golfplatendak: ribben, overlappen, schroeven, goot, regenpijp, ventilatiekappen, vlekken/roest op naden.
- Gevels: olijfgroene planken en stalen hoekprofielen, ramen met houten luiken en donker achtervlak, scharnieren, ventilatieroosters en kabel/elektrakastje.
- Basisniveau: lichte zandzakken aan de voorste zijkanten, houten kratten, opgerold dekzeil, subtiele grondvuilrand; geen onnodig grote buitenplaats.
- Niveau 2: extra dak-/muurversteviging, trainingsbord en aanvullende lamp/communicatiekast; alleen zichtbaar na upgrade.
- Niveau 3: aanvullende zandzakwal, antenne, extra pantserluiken en herkenbare rangmarkering; alleen zichtbaar na upgrade.
- Tijdens training: een subtiele lamp of deuranimatie bij het daadwerkelijk verschijnen van een rekruut. Bij bouwen/vernietiging: bestaande effecten prioriteren.

## Techniek en budget
- **Echte gameasset:** minimaal **40.000 triangles**, richtwaarde 40–50k, geen onzichtbare opvulgeometrie. Zowel triangulatie van de daadwerkelijk geëxporteerde GLB als zichtbare levelsets controleren.
- **2K PBR:** niet slechts upscaled 256px; unieke echt gegenereerde 2048 × 2048 albedo/base color + tangent normal (OpenGL) + ORM (occlusion, roughness, metallic), bij voorkeur twee gedeelde UV-atlassen (romp en details). Houd texturen helder genoeg in Godot.
- **LOD1:** doel maximaal 12k triangles, gedeeld silhouet, 1K mobiele kaarten, omschakeling rond 45 m na camera-/speltest; tenzij bestaande Godot-import automatisch en aantoonbaar de juiste LOD regelt.
- Maximaal circa 6–8 draw surfaces/materialen voor het volledige model, minimaliseer overdraw en transparantie, goedkope statische colliders. Vermijd 40k als onnodige renderkosten bij grote aantallen; maximaal één kazerne.
- Bron `.blend` en reproduceerbare Blender-/textuurgenerator; GLB's, maps, render-overzichten met mesh-triangles/materialen/texturebytes en licentie-informatie.
- Materialen zelf procedureel gemaakt en/of hergebruik geautoriseerde lokale Poly Haven CC0-materialen; geen nieuwe betaalde credits/diensten. Alle externe materialen eerst licentie/bron vastleggen.
- Preview: afzonderlijke iPhone `.usdz` indien export én Quick Look-materialen verifieerbaar; anders expliciet `NOT TESTED` en werkende GLB/3D-viewer als fallback. Korte vergelijking VQ2 vs HQ2.0 vanuit **dezelfde gamecamera**, met daglicht en nacht.
- Tests: GLB import, juiste footprint/oriëntatie, deur en spawn, zichtbare lv1/2/3, techboom, bouw/rij/rally, schade en herstel, aantal echte triangles, 2K kaarten, LOD, bestaand gameplaycontract. iPhone native FPS **NOT TESTED** totdat fysieke OTA-test op expliciet verzoek.

## Oplevering/acceptatie
1. Eerst uitvoerbare echte geometrie en bron `.blend` + `.glb` + LOD/maps; geen alleen conceptplaat.
2. Vergelijkingsbeelden/werkende preview, testlog met PASS/WARNING/NOT RUN en ongewenste regressies opgelost.
3. Alles op **één aparte featurebranch met Draft PR**, expliciete visuele goedkeuring afwachten.
4. **Geen merge naar `main`, geen OTA-publicatie**, geen wijziging aan `GENERALS_PLAN.md` tenzij een gameplaybesluit echt wijzigt.
