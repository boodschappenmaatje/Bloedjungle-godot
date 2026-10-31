# Airfield HQ 2.1 — technische review

**Status: review candidate; visueel niet akkoord / niet productieklaar.** Deze branch bevat een zelfstandige 2.1-versie naast de bewaarde HQ 2.0-bestanden. De huidige vergelijkingsbeelden tonen technische vooruitgang, maar voldoen nog niet aan het gevraagde fotorealistische acceptatiecriterium.

## Wat is gemaakt

- Bewerkbare Blender 4.5.15-bron: `high_quality/Bloedjungle_Airfield_HQ_2_1_Source.blend`.
- Mobiele GLB-varianten: `runtime/Bloedjungle_Airfield_HQ_2_1_LOD{0,1,2}.glb`.
- 2K Poly Haven CC0 PBR-maps voor geverfd/gegolfd staal, hangarbeton en beton, met 1K terreinmaps op LOD0 en kleinere mip-tier-assets op LOD1/2. De GLB's bevatten de beelddata.
- LOD0 heeft 15 mesh-nodes, 131.930 driehoeken, 48 primitives/material slots, 17 unieke materialen en 6 puntlichten. Clips: linker/rechter hangardeur en knipperende rode markers.
- LOD1: 12 mesh-nodes, 53.112 driehoeken, 46 primitives, 17 materialen; LOD2: 12 mesh-nodes, 23.331 driehoeken, 46 primitives, 17 materialen. Afstand-LODs zijn statisch; de animaties en lichtbronnen blijven in LOD0.
- Onderhoudsbanken, onderdelenrekken en olievaten aan de hangarzijde; echte onderste raamopeningen, dorpels, lateien en roeden in de verkeerstoren.
- Geïsoleerde Godot-showcase met eenvoudige gameplay-collisions en schakeling tussen LOD's. De productie-2.0-scène is ongemoeid gelaten.
- Vier 2.0/2.1-comparisons zijn vanuit dezelfde camera's gerenderd in `../../previews/airfield_hq/v21_review/`.
- iPhone Quick Look USDZ: `../../previews/usdz/airfield_hq/2.1/Bloedjungle_Airfield_HQ_2_1_iPhone.usdz`.

## Validatie

- Godot 4.7.2 importeert de GLB; regressietest `tests/airfield_hq_21_import_test.gd` controleert UV's en materialen, speelt de twee deurclips en markerclip af, controleert de bewegende deurcollision-proxy's en de meshes van LOD1/2. Resultaat: PASS (15 mesh-nodes; 131.930 driehoeken; 6 geïmporteerde hangarlampen; 6 collision shapes).
- Apple `usdchecker --arkit`: PASS. `usdzip --list`: PASS. Afspelen in Quick Look op een fysiek iPhone-apparaat: niet getest.
- Viewerbundle gebouwd via aanwezige lokale esbuild-runtime. `pnpm run build` stopte op de repositorypolicy die install-scripts van `esbuild` blokkeert; `node build.mjs` met de al aanwezige dependency slaagde. Browsercontrole kon niet worden uitgevoerd: de host heeft lokale browserbesturing uitgeschakeld. De bundle is dus gebouwd maar niet live in een browser of op een iPhone afgetekend.
- GLB-payloads: LOD0 45.580.576 bytes; LOD1 12.855.500 bytes; LOD2 4.743.248 bytes. USDZ 50.286.924 bytes. Dit zijn gecomprimeerde bestandsgroottes, geen metingen van GPU- of runtimegeheugen.
- Schatting gedecodeerde RGBA8-texturen bij 9×2048² en 6×1024²: circa 168 MiB zonder mipmaps, circa 224 MiB met volledige mipketens. Dit is een rekenkundige schatting; geen fysieke iPhone-geheugenmeting.
- Drawcallproxy: 48 GLB-primitives op LOD0 (niet gelijk aan een device-capture van daadwerkelijke drawcalls). Frametime/FPS en geheugen op een iPhone 18 Pro Max zijn niet gemeten; 60 FPS is dus onbevestigd.

## Bekende acceptatieblokkades

- De interne vergelijkingsrender laat nog altijd een donkere, grotendeels lege centrale bay zien en er staat geen P-47 in. Er is geen passend, correct gelicentieerd P-47-model in de repository gevonden; er is bewust geen nepvliegtuig of moderne F-16 als vervanging gebruikt.
- De hangarhoofdvorm en een groot deel van de verkeerstoren/terreininrichting erven nog geometrie uit HQ 2.0. De nieuwe raamopeningen en onderhoudsprops verbeteren de compositie, maar zijn geen grondige fotorealistische herbouw volgens de referentiebeelden.
- De runway-/terreinscreenshot toont nog te regelmatige, te glanzende stroken en harde terreinvlakken. De gevraagde geïntegreerde hoogteovergangen, concrete plaatverdeling, verkeerstoreninterieur en volledige operationele basis zijn niet visueel afgemaakt.
- Collisions zijn eenvoudige box-proxy's; ze zijn geïmporteerd en de deurproxy beweegt met de deur, maar er is geen fysieke gameplay-run of botsingspad op apparaat gevalideerd.
- LOD-afstanden 52 m en 122 m zijn conservatieve showcasewaarden gebaseerd op de projectcamera-range; er is geen device-profilerun vanuit echte zichtbaarheid gedaan.

**Conclusie:** 2.1 levert een geïmporteerde, geanimeerde en versiebeheerbare reviewbasis op. Het voldoet niet aan de opgegeven eindacceptatie. Behandel dit als tussenresultaat voor visuele goedkeuring; niet mergen, niet publiceren en niet als fotorealistisch of iPhone-gevalideerd presenteren.
