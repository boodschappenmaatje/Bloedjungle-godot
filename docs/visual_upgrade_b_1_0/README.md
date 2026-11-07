# Bloedjungle — Visual Upgrade B 1.0

**Branch:** `feature/visual-upgrade-b-1-0`

**Draft PR:** [#237](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237)

**Laatste codecommit:** `6e7701a26332a6c3f9b4767d5ebd6934a45ae52a`

De recente pass haalt de zware warme kleurzweem weg, maakt bladkleuren neutraler, verzacht de palmhulp-schaduw en houdt brede bladeren uit de start-zichtlijn. De echte bospadpreview toont nu een zichtbare speler en natuurlijker groen. De grote open graszone en de eenvoudiger silhouetten/materialen liggen nog duidelijk onder de premium, fotorealistische richting van afbeelding C. Visuele acceptatie blijft daarom open. De gebruiker test de iOS-build zelf op een iPhone; toestelprestaties zijn niet gemeten. Deze PR blijft Draft, is niet gemerged en heeft niets gepubliceerd.

## Richting en grenzen

De gebruiker heeft afbeelding C — “Lighting & Atmosphere Pass” — als huidige kwaliteitsrichting gekozen; de aangeleverde C-afbeelding staat in de chat, maar is nog niet als bestand in de repository opgeslagen. `reference/approved-b.jpg` en [de bestaande driebeeldvergelijking](captures/compare/three-way.jpg) zijn historische B-documentatie en mogen niet worden voorgesteld als C. De [oorspronkelijke gebruikersscreenshot](reference/user-before.jpg) bevat geen opslagpositie of vaste camera-instellingen, dus die oude vergelijking claimt geen identieke reconstructie.

De doelrichting is een rijk, natuurlijk junglegevechtsgebied met leesbare spelers en schietlijnen; details hoeven niet letterlijk met C overeen te komen. De huidige echte render houdt nog een groot, open grasvlak en mist een deel van C's fijne plant-, grond- en lichtdiepte. De PNG hieronder is een echte Godot-render, geen conceptbeeld. Er zijn geen AI-conceptbeelden als implementatiebewijs gebruikt.

## Wat de upgrade aanpast

- Hergebruikt `assets/jungle.glb`, de bestaande grasvarianten en hun drie geometrische LOD's, foliage- en fernmeshes, en de bestaande PBR-texturen voor gras, bosgrond, aarde, modder, mos, grind en rivierzand.
- De terreinshader mengt de bestaande albedo-, normal- en roughness-informatie op wereldvaste schaal. Het ingesleten pad gebruikt de bestaande gravel-rock PBR-set; randen zijn organischer en sporen blijven herkenbaar. Er is geen displacement, parallax of collisionwijziging.
- `GrassField` en `JungleUnderstory` hergebruiken de bestaande CC0/PBR-soorten, LOD's, MultiMesh-batches, kwaliteitschalen en afstandsculling. Deze pass verhoogt het aantal planten niet; hij varieert de groepcontouren, verkleint brede bladeren licht en houdt zulke bladeren uit de start-zichtlijn.
- De dagbelichting gebruikt nu een neutralere zonkleur, meer bruikbaar omgevingslicht, lagere contrast-/mistzwaarte en een subtiele neutrale vignette. De radiale palmbladprojectie op de grond is vervangen door de zachte mobiele hulp-schaduw; de bestaande instellingen en renderer blijven gelijk.
- De bestaande bouw-clearance, routes, schietlijnen, bomen, collisions, camera, HUD, besturing, AI, wapens en voertuigen blijven behouden. Renderdetail krijgt geen nieuwe collisions.

## Echte Godot-beelden

De nieuwe snelle capture is [GitHub Actions-run 42425169412](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42425169412), geslaagd op commit `6e7701a`. Hij start de echte `scenes/main.tscn` en bestaande hoofdgamecamera op vaste bospadpositie, Godot 4.7.2 Mobile/Vulkan, High/day/clear en output 1280×720 met 100% capture scale. Het is bewust één preview, geen volledige benchmarkreeks.

De echte Godot-preview staat in [captures/iterations/6e7701a/bospad.png](captures/iterations/6e7701a/bospad.png); metadata staat naast de PNG. De vorige echte bospadbeelden blijven onder `captures/after/` als eerdere pass, maar tonen andere capture scale. De nieuwe screenshot toont geen radiale palmster meer en de speler blijft vrij. Hij toont ook dat de open graszone nog te groot en te eenvoudig is tegenover C.

De PNG is een echte Mobile/Vulkan-gamecapture via **llvmpipe-software-rendering** op Linux. De ingebrande `1 FPS` hoort bij die softwarebackend en zegt niets over een iPhone. Renderresolutie is niet de visuele kwaliteitslat. Er is op deze commit geen iPhone-, Metal- of Windows-runtime-test gedaan.

**Beoordeling van deze pass:** de kleur is aantoonbaar minder amber en bladgroen blijft zichtbaar; de speler staat niet meer onder een radiale kunstschaduw. De preview is een gerichte winst voor idee 2 en 3, maar nog geen visuele acceptatie: de grote grasopening, beperkte kleine blad-/bodemdetails en eenvoudige scènecompositie blijven verder van C dan gewenst.

## Softwaremetingen

De laatste volledige ruwe resultaten in `results/after-metrics.json` horen bij de oudere codecommit `69d3f43`, niet bij `6e7701a`. Deze snelle preview heeft geen GPU-/frametimebenchmark uitgevoerd. De eerdere Godot 4.7.2 Mobile/Vulkan-llvmpipe waarden hieronder zijn alleen software-renderdiagnostiek; ze zijn geen telefoonbenchmark.

| Scène | Gemiddelde ms | P99 ms | 1%-low FPS | Draw calls | Primitives |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bospad | 2.053 | 3.399 | 0,294 | 514 | 2.922.663 |
| Rivier | 1.220 | 1.274 | 0,785 | 365 | 2.026.194 |
| Kamp | 5.096 | 5.220 | 0,192 | 393 | 1.778.068 |
| Combat, 80 vijanden | 3.747 | 13.547 | 0,074 | 1.371 | 3.761.680 |

De oude voor-meting gebruikte eveneens Godot Mobile/Vulkan, maar **llvmpipe LLVM 19.1.7** in plaats van LLVM 20.1.2. Daarom zijn de oude en nieuwe frametijden en 1%-lows niet rechtstreeks vergelijkbaar. De softwaretijden hierboven zijn seconden per frame door de gedeelde CI-renderer en mogen niet als iPhone-FPS worden gelezen. De ruwe voor/na-structurele tellers staan in [comparison.json](results/comparison.json); ze laten de extra scènegeometrie zien, geen telefoonprestatie.

De 1%-low uit die oudere test is één langzaamste sample en geen hardwareacceptatie. Op iPhone zijn frametimes, 1%-lows, shimmer, langdurige gevechten en thermiek **niet gemeten**.

## Validatie en iPhone-test

- GitHub op `6e7701a`: Godot 4.7.2 projectimport en visuele integratietest PASS, bospadcapture PASS, vijandbasisregressie PASS, GLB-importmetadata PASS en OTA-patchpreview PASS. OTA-publicatie is niet uitgevoerd.
- Lokaal met Godot 4.6.3: `visual_b_test.tscn` PASS (0 failures; batches, LOD's, collisions, zichtlijn-pocket en neutrale bladgrade gecontroleerd). Er zijn gebruikelijke headless SSAO/resource-cleanupmeldingen; geen script-/shaderfout.
- iOS unsigned export: [run 42425169497](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42425169497) is gestart voor `6e7701a`, maar was bij deze documentupdate nog **in progress**. Er is nog geen nieuwe test-IPA opgehaald.
- Een oudere unsigned iOS-export bestaat voor commit `69d3f43` (run 42315505684, artifact-id `13551276722`); die is niet deze codeversie. Wacht op run `42425169497` voor de test-IPA die bij `6e7701a` hoort.
- De export bewijst geen ondertekening, installatie, Metal-rendering of iPhone-uitvoering. Er is geen fysieke iPhone-test of Windows-runtime-test uitgevoerd. De [iPhone-testlijst](IPHONE_TEST_PLAN.md) bevat vaste stappen voor stilstaand beeld, shimmer/pop-in, een groot gevecht, terreinranden, frametimes, 1%-lows en thermiek. Laat die velden op **niet gemeten** staan tot je de tests uitvoert.

Visuele acceptatie blijft open door het resterende vlakke speelveld en de afstand tot C. Mobiele acceptatie blijft open totdat de gebruiker de nieuwe build op een echte iPhone heeft getest. De C-referentieafbeelding moet nog als repositorybestand worden toegevoegd voor een blijvende side-by-side vergelijking.
