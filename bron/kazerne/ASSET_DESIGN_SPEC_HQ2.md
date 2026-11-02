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

## Gameplaycontracten — behouden, behalve expliciet groter formaat
- **Bouwvoet/collision:** het nieuwe goedgekeurde Meshy-model is **6,4 m breed × 4,8 m diep × 3,5 m hoog**. Bij daadwerkelijke gameplay-integratie wordt de oude `Vector3(4.4, 2.2, 3.2)` in `scripts/buildings.gd` gecoördineerd aangepast naar `Vector3(6.4, 3.5, 4.8)`, inclusief collision/plaatsingscontrole. De bestaande kostprijs, maximaal één kazerne, 600 HP en 12 s bouwtijd blijven intact. Wijzig gameplay niet voordat een visueel correcte game-GLB klaarstaat.
- **Pivot:** grondcentrum (0,0,0), met deur aan lokaal **+Z in Godot** (Blender -Y), geen verplaatsing van het bestaande gebouw.
- **Rekruutspawn:** huidige `door_of()` zit 2,5 m vanaf de pivot. Met de nieuwe 4,8 m diepte moet de nieuwe afstand t.o.v. deur en colliders opnieuw worden bepaald (richtwaarde circa 3,2–3,3 m aan +Z); controleer dit fysiek, niet blind de oude 2,5 m behouden.
- **Bestaande Generals-logica:** wachtrij maximaal vijf, annuleren met restitutie, verzamelvlag/volgen, `REQUIRES`, training, `room()`, `Game.allies`, schade/verkopen/repareren en bestaande radio onveranderd functioneel.
- **Niveaus:** bestaande lv1 (2 soldaten, 10s), lv2 (4, 7s), lv3 (6, 5s), inclusief bestaande kosten en HP/damage; HK-niveau 2 geeft 25% training-/bouwtijdwinst. De visuals volgen `b.lv`; geen extra gameplay-upgrades.
- **Bouw/vernietiging:** steigers en zichtbare bouwprogressie blijven; schade/instorten, botsing en wrakfunctie behouden. Geen begaanbaar interieur in deze scope omdat huidige collision één gesloten volume is.

## Bouwmodel
- Goedgekeurd grotere Meshy-basis: 6,4 × 4,8 m en totale hoogte 3,5 m, inclusief dak en dakdetails. Plaats- en botsingsmaten wijzigen alleen samen met de finale asset. Controleer overstek en vrij doorpad voor de deur.
- Deurpartij centraal aan +Z: duidelijk herkenbare deur, correcte scharnierzijde, kooilamp, bovenluifel/naamplaat `KAZERNE`, kleine toegangsplaat zonder blokkering van spawn.
- Geloofwaardig golfplatendak: ribben, overlappen, schroeven, goot, regenpijp, ventilatiekappen, vlekken/roest op naden.
- Gevels: olijfgroene planken en stalen hoekprofielen, ramen met houten luiken en donker achtervlak, scharnieren, ventilatieroosters en kabel/elektrakastje.
- Basisniveau: lichte zandzakken aan de voorste zijkanten, houten kratten, opgerold dekzeil, subtiele grondvuilrand; geen onnodig grote buitenplaats.
- Niveau 2: extra dak-/muurversteviging, trainingsbord en aanvullende lamp/communicatiekast; alleen zichtbaar na upgrade.
- Niveau 3: aanvullende zandzakwal, antenne, extra pantserluiken en herkenbare rangmarkering; alleen zichtbaar na upgrade.
- Tijdens training: een subtiele lamp of deuranimatie bij het daadwerkelijk verschijnen van een rekruut. Bij bouwen/vernietiging: bestaande effecten prioriteren.

## Techniek en budget
- **Echte gameasset:** minimaal **40.000 triangles** als overeengekomen detaildoel; streef 60–80k voor LOD0 alleen als de originele dichte geometrie en PBR-silhouet behouden blijven. Afgewezen: snelle 80K-voxelreductie met gaten in dak/gevel (visueel geconstateerd 2 november 2026). Controleer de daadwerkelijk geëxporteerde GLB; geen onzichtbare opvulgeometrie.
- **2K PBR:** niet slechts upscaled 256px; unieke echt gegenereerde 2048 × 2048 albedo/base color + tangent normal (OpenGL) + ORM (occlusion, roughness, metallic), bij voorkeur twee gedeelde UV-atlassen (romp en details). Houd texturen helder genoeg in Godot.
- **LOD1:** doel maximaal 12k triangles *alleen indien visueel acceptabel*; hogere tussen-LOD (20–30k) is toegestaan als dat gaten/silhouetverlies voorkomt. Mobiele kaarten 1K op afstand waar zinvol, afstandskeuze pas na camera-/speltest; anders Godot-auto-LOD alleen bij aantoonbaar juist importresultaat.
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

## Werkelijke Meshy-bron en kwaliteitsgate (2 november 2026)
- Upload bevat een ZIP met `Meshy_AI_Create_a_photorealist_1102134757_texture.fbx` en vier echte 2048² maps (albedo, normal, roughness, metallic). Een inspectie mat **2.285.660 triangles** en een UV-atlas.
- Een hoog-resolutie GLB met correcte afmetingen en +Z-entree is lokaal geëxporteerd (66,4 MB), maar is geen mobiele gameplayasset.
- Eerste geautomatiseerde 80K-test liet zichtbare gaten/artefacten in het dak en gevels zien: **REJECTED**. Correcte retopologie/decimate plus high-to-low normal bake in Blender noodzakelijk vóór gameplayvervanging.
- Deze branch bevat uitsluitend voorbereiding en specificatie totdat de kwalitatief goedgekeurde `.glb` echt beschikbaar is en door Godot-tests is gegaan. **Geen merge/OTA.**
