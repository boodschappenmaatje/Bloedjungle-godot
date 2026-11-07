# M-47 Cinematic VFX 4.0 — testrapport

## Resultaat

De showcase is een aparte Godot-testscene op featurebranch `feat/m47-cinematic-vfx-4-0`, gebaseerd op PR #239 head `c29d7f5` en de goedgekeurde M-47-assets uit PR #238. De onbewerkte Godot-opname bevat 270 frames op 30 fps, 1280×720, met een gemeten duur van 9,0 seconden.

- [Onbewerkte Godot-video](screenshots/m47_cinematic_vfx_4_0.mp4)
- [Kleur-/bloomversie](screenshots/m47_cinematic_vfx_4_0_graded.mp4) — alleen nabewerking van de vastgelegde beelden; de onbewerkte video blijft de engine-uitvoer.
- [Voor/na en doelcriteria](screenshots/comparison_v21_v40_target_notes.png)
- Zes uitsneden van dezelfde top-down camera: kern, mondingsflits, projectiel, inslag, puin en blijvende doorgang. De originele vergelijking gebruikt dezelfde camera en FOV als VFX 2.1: positie `(-0.4, 5.6, 7.2)`, FOV `47°`.

De meegeleverde doelreferentie is een collage met meerdere camerakaders en is niet als lokaal bestand beschikbaar. Daarom toont de vergelijkingsplaat de VFX 2.1- en 4.0-captures naast de expliciete doelcriteria; er is geen referentiebeeld nagemaakt.

## Blender en geometrie

Blender 4.3.2 draaide in batchmodus. Het nieuwe wandmodel heeft intacte en onregelmatig doorgebroken betonvarianten met dezelfde bestaande beton-albedo-, normal- en ORM-texturen. De doorbraakvariant heeft een aparte haarlijnscheurnetwerk. De 42 betonfragmenten exporteren als één GLB-animatieclip `Breach`, met 42 vertaalsporen. Alle 42 fragmenten bewegen meer dan 0,1 m; de gemeten eindverplaatsingen lopen van 0,425 m tot 2,683 m.

| Asset/onderdeel | Driehoeken |
| --- | ---: |
| Goedgekeurde M-47 LOD0 | 50.000 |
| Goedgekeurde M-47 LOD1 | 25.000 |
| Goedgekeurde M-47 LOD2 | 9.999 |
| Nieuwe wand, scheuren en 42 puinfragmenten samen | 8.984 |

De totalen van de goedgekeurde GLB zijn 85.615 driehoeken over alle LOD's en losse onderdelen. De Godot-preview toont alleen LOD0; LOD1 en LOD2 worden niet tegelijk gerenderd. De originele M-47-GLB is niet door Blender geopend of gewijzigd. SHA-256: `4031e935c5ef19a96a10257334a3cc99db92410a01389ef708259d887cf89872`.

Blender Cycles genereerde 16 RGBA-volumeopnamen voor rook en 16 voor stof, samengevoegd tot flipbooks. De geïmporteerde wand behoudt albedo, normal en roughness/metallic-texturen. De Godot-scène voegt de draaiende kern, mechanische terugslag, helder projectiel, elektrische filamenten, een zichtbare spiraal, mondingsflits, drie zeshoekige golflagen, puin, stof en een blijvende opening samen.

De opgeslagen `.blend` is opnieuw geopend in Blender 4.3.2 ter controle: renderengine `CYCLES`, één Cycles-volumeobject, het materiaal `Animated_Procedural_Volume` en 42 Breach-acties/sporen zijn aanwezig. De volledige batchuitvoer staat in [blender_full.log](logs/blender_full.log).

De goedgekeurde M-47 GLB bevat de vijf clips `Idle`, `Equip`, `Aim`, `Fire` en `Reload`, elk met 9 animatiekanalen. De GLB-animatiedata bevat bewegende kanalen voor alle vijf. De Godot-importcontrole vond alle clips, de PBR-texturen en LOD0–LOD2.

## Godot-controle

Uitgevoerd met officiële `Godot 4.7.2.stable.official.ed1daf0bf`, Compatibility-renderer, Xvfb en Mesa llvmpipe. De geïsoleerde scene valideerde de echte M-47 GLB-import, vijf animaties, PBR, afzonderlijke LOD-weergave, Blender-wandimport, `Breach`-clip, flipbooks en testcollision. `M47_CINEMATIC_TEST PASS` staat in [godot_showcase.log](logs/godot_showcase.log); de detailchecks staan in [results.txt](results.txt).

De vier gevraagde regressies zijn met dezelfde Godot 4.7.2 uitgevoerd; alle processen eindigden met exitcode 0:

- [surface_filtering_test](logs/surface_filtering_test.log) — PASS, 0 failures
- [combat_bazooka_aim_test](logs/combat_bazooka_aim_test.log) — PASS
- [wapen_clips_test](logs/wapen_clips_test.log) — `WAPENCLIPS TEST OK`
- [base_wall_hq2_test](logs/base_wall_hq2_test.log) — PASS, 0 failures

De importlog staat in [import.log](logs/import.log). Een eerdere importpoging doorzocht per ongeluk de Blender-bronmap; de map is daarna uitgesloten en de schone Godot 4.7.2-import eindigde zonder importfouten. Er zijn geen wijzigingen aan root-scenes, gameplay, bazooka, besturing of grafische instellingen achtergebleven.

## Visuele vergelijking en resterende verschillen

De vergelijking toont vooruitgang ten opzichte van PR #239: een PBR-betonwand met scheuren en blijvende opening, animatie van 42 grotere puinstukken, jungle-assets, een zichtbare elektrische projectielspiraal en een gelaagde hexagonale inslag.

De showcase haalt de aangeleverde fotorealistische referentie nog niet. De bestaande jungle-GLB en soldaat zijn gestileerde assets; de wand is een compacte procedurele geometrievariant. De rook en stof zijn voorgerenderde volume-flipbooks, geen live volumetrische vloeistofsimulatie. De projectielmantel en schokgolf zijn helder en leesbaar, maar missen de materiaalcomplexiteit, vonkendetail, rookslierten en grote overtuigende betonbrokken uit de referentie. De top-down camera vergelijkt de gameplay-compositie; het doelbeeld zelf bevat andere camerastandpunten.

Godot draaide hier op softwarematige llvmpipe. Er is geen FPS- of iPhone-prestatieclaim en geen iOS-export uitgevoerd. Er is niets gemerged of naar OTA gepubliceerd.
