# Bloedjungle — Visual Upgrade B 1.0

**Branch:** `feature/visual-upgrade-b-1-0`

**Draft PR:** [#237](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237)

**Laatste codecommit:** `69d3f434802a2f8ef6b7fc918badca3dea2a24c3`

De upgrade voegt zichtbaar meer lage junglevegetatie en grasstructuur toe, met PBR-terrein en een gedetailleerder pad. De echte Godot-render is beter dan de oude scène, maar haalt de volle sfeer en microdetaildichtheid van beeld B nog niet. Visuele acceptatie blijft open. De gebruiker test de unsigned iOS-build zelf op een iPhone; er zijn geen toestelprestaties gemeten. Deze PR blijft Draft, is niet gemerged en heeft niets gepubliceerd.

## Richting en grenzen

Het door de gebruiker goedgekeurde beeld B is een kwaliteitsrichting, geen letterlijke scènebouwopdracht. De [oorspronkelijke gebruikersscreenshot](reference/user-before.jpg) bevat geen opslagpositie of vaste camera-instellingen; de vergelijking claimt daarom geen identieke reconstructie. De [driebeeldvergelijking](captures/compare/three-way.jpg) labelt de gebruikersscreenshot, referentie en echte game-render apart.

De game gebruikt bestaande gestileerde, relatief lichte boom- en bladmodellen. De resterende afstand tot B zit vooral in de vlakke speelruimte, het beperkte aantal kleine bladvormen, het nog vrij eenvoudige water en het ontbreken van geometrisch terreinreliëf. De referentie heeft fijnere, fotografische blad- en bodemdetaillering en meer reflecterend water. Die kenmerken zijn met de huidige modellen, terreinplaat en materialen niet volledig te evenaren zonder een aparte asset-/terreinproductieronde. Er zijn geen AI-conceptbeelden als implementatiebewijs gebruikt.

## Wat de upgrade aanpast

- Hergebruikt `assets/jungle.glb`, de bestaande grasvarianten en hun drie geometrische LOD's, foliage- en fernmeshes, en de bestaande PBR-texturen voor gras, bosgrond, aarde, modder, mos, grind en rivierzand.
- De terreinshader mengt de bestaande albedo-, normal- en roughness-informatie op wereldvaste schaal. Het ingesleten pad gebruikt de bestaande gravel-rock PBR-set; randen zijn organischer en sporen blijven herkenbaar. Er is geen displacement, parallax of collisionwijziging.
- `GrassField` en `JungleUnderstory` vullen de speelvloer met short grass, rozetten, bladeren, stenen, twijgen en varens. De laatste pass verhoogt het begrensde short-grassbudget naar 14.500, zet groundcover op maximaal 11.000 en verplaatst een deel van hoog/klein detail naar lage planten. De planten blijven in bestaande MultiMesh-batches, kwaliteitschalen en afstandsculling.
- Bestaande leaf-materialen krijgen wat meer lichtrespons. De eerdere passes voegden wortelcontact, warmere zonrespons en een subtiele mistlaag toe. Er zijn geen volumetrische lichtbundels of dure schermruimte-effecten toegevoegd.
- De bestaande bouw-clearance, routes, schietlijnen, bomen, collisions, camera, HUD, besturing, AI, wapens en voertuigen blijven behouden. Renderdetail krijgt geen nieuwe collisions.

## Echte Godot-beelden

Capture: [GitHub Actions-run 42315505667](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42315505667), geslaagd op de codecommit hierboven. De workflow start de echte `scenes/main.tscn`, ongewijzigde hoofdgamecamera, vaste wereldposities en seed, Godot 4.7.2 Mobile/Vulkan, High/day/clear en dezelfde pose-/kwaliteitsprocedure als de baseline. De vier scènes worden op 60% interne schaal vastgelegd; er staat ook een aparte bospadopname op 100%. Die 100%-opname bevestigt dat de open graszone niet door de lagere interne schaal wordt veroorzaakt.

De huidige echte beelden zijn [bospad](captures/after/bospad.png), [bospad op 100%](captures/after/bospad-100.png), [rivier](captures/after/rivier.png), [kamp](captures/after/kamp.png) en [combat met 80 vijanden](captures/after/combat.png). De [voor/na-vergelijkingen](captures/compare/) gebruiken echte gamecaptures; de camera pose in ieder paar blijft binnen 1 cm.

De laatste pass vergroot lage rozetten en short grass; de render toont meer herkenbare bladgroepen langs de speelruimte, oevers en bosrand. Het midden van het bospad blijft open voor leesbaarheid en de weg blijft vrij. Mijn visuele beoordeling: duidelijke verbetering ten opzichte van de oude render, maar nog geen volledige match met de rijke, premium dichtheid van B. Het grote egale grasvlak, de gestileerde bladmodellen en het vlakke water blijven de belangrijkste zichtbare verschillen.

De PNG's zijn echte Mobile/Vulkan-gamecaptures via **llvmpipe software-rendering** op Linux. De ingebrande `1 FPS` in die beelden is de trage softwarebackend; die waarde zegt niets over een iPhone. Renderresolutie is niet de visuele kwaliteitslat en de productinstellingen zijn niet gewijzigd.

## Softwaremetingen

Huidige ruwe resultaten van `results/after-metrics.json`: Godot 4.7.2 Mobile/Vulkan, llvmpipe LLVM 20.1.2, 1280×720 output, High, 60% interne schaal en korte vaste-camerasamples. Combat gebruikt 80 echte vijanden. Draw calls en primitives zijn Godot-rendererdiagnostiek; de softwaretijden zijn geen hardwarebenchmark.

| Scène | Gemiddelde ms | P99 ms | 1%-low FPS | Draw calls | Primitives |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bospad | 2.053 | 3.399 | 0,294 | 514 | 2.922.663 |
| Rivier | 1.220 | 1.274 | 0,785 | 365 | 2.026.194 |
| Kamp | 5.096 | 5.220 | 0,192 | 393 | 1.778.068 |
| Combat, 80 vijanden | 3.747 | 13.547 | 0,074 | 1.371 | 3.761.680 |

De oude voor-meting gebruikte eveneens Godot Mobile/Vulkan, maar **llvmpipe LLVM 19.1.7** in plaats van LLVM 20.1.2. Daarom zijn de oude en nieuwe frametijden en 1%-lows niet rechtstreeks vergelijkbaar. De softwaretijden hierboven zijn seconden per frame door de gedeelde CI-renderer en mogen niet als iPhone-FPS worden gelezen. De ruwe voor/na-structurele tellers staan in [comparison.json](results/comparison.json); ze laten de extra scènegeometrie zien, geen telefoonprestatie.

De laatste densiteitspass (`862cf0b` → `69d3f43`) is ook apart met dezelfde llvmpipe-setup vastgelegd: draw calls veranderen per scène tussen 0 en +1%; primitives stijgen 3,5–10,4%. De 1%-low in deze test is één langzaamste sample uit 60 frames (of één uit 100 in combat), dus niet betrouwbaar als hardwareacceptatie. Op iPhone zijn frametimes, 1%-lows, shimmer, langdurige gevechten en thermiek **niet gemeten**.

## Validatie en iPhone-test

- GitHub voor `69d3f43`: echte Godot-capture PASS, unsigned iOS-export PASS, vijandbasisregressie PASS en OTA-patchpreview PASS. De OTA-publicatiestap is overgeslagen voor deze PR-run.
- Lokaal met Godot 4.6.3: `visual_b_test.gd` PASS (14.500 short grass; groundcover 11.000; clearances/collisions blijven intact), `surface_filtering_test.gd` PASS, `rivier_test.gd` exit 0, `camera_test.gd` PASS en `schaduw_test.gd` PASS. De gepinde Godot 4.7.2-integratietest slaagde ook in de captureworkflow.
- iOS-export: [run 42315505684](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42315505684), geslaagd. Unsigned artifact **`bloedjungle-ios-unsigned-a3e5dd8cca52fa33c29a2d381b638d4c02ed5e53`**, artifact-id **`13551276722`**, **1.151.750.795 bytes** (circa 1,15 GB). Download op de runpagina, onderteken met je eigen Apple-account en installeer met je gebruikelijke iOS-installatiemethode.
- De export bewijst geen ondertekening, installatie, Metal-rendering of iPhone-uitvoering. Er is geen fysieke iPhone-test of Windows-runtime-test uitgevoerd. De [iPhone-testlijst](IPHONE_TEST_PLAN.md) bevat vaste stappen voor stilstaand beeld, shimmer/pop-in, een groot gevecht, terreinranden, frametimes, 1%-lows en thermiek. Laat die velden op **niet gemeten** staan tot je de tests uitvoert.

Visuele acceptatie blijft open door het resterende vlakke speelveld en de stilistische assetgrens. Mobiele acceptatie blijft open totdat de gebruiker deze build op de iPhone heeft gespeeld en de resultaten heeft teruggekoppeld.
