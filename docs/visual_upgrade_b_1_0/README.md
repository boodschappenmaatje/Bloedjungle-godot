# Visual Upgrade B 1.0 — Terrain + Foliage Depth Pass

**Werk in uitvoering, geen visuele of mobiele eindacceptatie.** Eén featurebranch `feature/visual-upgrade-b-1-0`, vanaf `b808fe1`. Niet mergen; geen OTA.

## Visuele opdracht

Het door de gebruiker gecorrigeerde [goedgekeurde beeld B](reference/approved-b.jpg) is de doelstandaard. Het eerder meegestuurde beeld C is niet de doelreferentie. [Oorspronkelijke gebruikersscreenshot](reference/user-before.jpg) is uitsluitend door de gebruiker aangeleverd bewijs; de FPS daarvan is geen eigen meting. De gebruiker heeft verduidelijkt dat renderresolutie de zichtbare upgrade niet moet beperken. Bestaande grafische instellingen worden behouden.

## Inventaris vóór productie

- `assets/jungle.glb`, `bron/jungle/maak_jungle.py`: 3 palmvormen, 2 jungleboomvormen, bijbehorende verre vormen, 3 rotsen en 2 stronken. Bestaande boom-/rotsposities, colliders, vallen, rammen en bouwclearing blijven behouden.
- `assets/grass/manifest.json`, `bron/gras/gras.blend`: short/medium/tall × 4 varianten × 3 geometrische LOD's, gedeelde 2K PBR-atlas. Bestaande celbatches, kwaliteitsschaal, LOD-selectie en buigen blijven in gebruik.
- `Foliage.bush/fern`: bestaande gebogen bladmeshes, gedeelde leaf/fern-texturen, wind en zichtlijnfade. Geen duplicaat van deze modellen geproduceerd.
- Reeds aanwezige terreinsets: gras, junglegrond, droge aarde, grind, modder, mos en rivierzand, elk albedo/normal/roughness. De oude grondshader gebruikte geen gras-/bosgrondnormal en koppelde `mud_tex` aan grind.
- Bestaande zon, sky, eenvoudige mist, optionele vaste/echte boomschaduw en PerfGovernor. Geen nieuwe lichtbron, volumetrische mist of schermruimte-effect toegevoegd.

## Implementatie

- `ground.gdshader` mengt gras, bosgrond, aarde, modder, mos en bestaande grindsteen met echte normal/roughnessrespons op wereldvaste schaal. De bestaande `gravel_rock`-PBR-set is toegevoegd aan het ingesleten pad en de onderbroken schouders; organische overgangen en natte sporen blijven zichtbaar. Geen parallax, terreinverplaatsing of collisionwijziging. De drie bestaande discard-contracten (rivier/loopgraven/helipad) blijven behouden.
- `pack_terrain_surfaces.py` pakt bestaande normal RGB en roughness A verliesloos in één bronafbeelding per materiaal, nu ook voor `gravel_rock`. Geen download, vergroting of nieuwe fotobron. Het manifest bevat bron- en outputhashes; de oorspronkelijke licenties staan in `docs/ASSET_SOURCES.md`. Import bewaart alpha, gebruikt VRAM-compressie en mipmaps; geen normalmap-optimalisatie die de roughnessalpha weggooit. Het zes-kaartenpakket is 8.39 MB met mipmaps in de lokale Godot-import; gravel voegt 1.40 MB toe. De shader houdt 15 texture lookups per grondpixel aan; er zijn twee extra samplerbindingen voor het grind-PBR-paar.
- `JungleUnderstory` hergebruikt bestaande varen-, struik-, rots- en stamgeometrie voor onregelmatige kolonies bij natuurankers, padschouders, oevers en buitenfunderingen. Drie goedkope frondsilhouetten en kleine rozetten zijn uit de bestaande bladmaterialen opgebouwd; plat gedraaide grasbladen vormen strooisel. Geen nieuwe fotobron of geïmporteerde GLB.
- Detail is in 24 m cellen gebatcht, maximaal 360 instances per batch, globale soortlimieten, 48/58 m afstandsculling en geen schaduwdraws. Alle extra details volgen bestaande jungle-/dichtheids-/kwaliteitstrappen en de bouwclearance-index. Een afzonderlijke RNG houdt de bestaande natuurcolliders op hun originele posities.
- `GrassField` besteedt short grass eerst aan padschouders en vult daarna de speelvloer buiten een vrije strook van 2,25 m langs het pad. Het begrensde short-grassbudget is 8.200 instances (voorheen 6.200); high rendert 60% via dezelfde cellen, LOD's en afstandsculling. De ondergroei verschuift het bestaande detailbudget van grove hoge varenwaaiers naar bredere lage rozetten en struiken. Er worden geen nieuwe modellen of extra materiaaldrawcalls toegevoegd.
- Wortelcontact in bestaande foliage-/grasshaders; een warmere, lagere dagzon met minder omgevingsinvulling geeft langere schaduwen en meer materiaalcontrast. Tijd, weer en kwaliteitskeuzes blijven werken. Geen dure volumetrische mist of C-lichtbundels.

## Bewijsprotocol

`tests/visual_b_capture.gd` laadt de echte `scenes/main.tscn`, gebruikt de ongewijzigde `Camera`-node met bestaande camerascript en vaste wereldposities, seed `20261106`, High/day/clear, fake tree shadows, wind uit. HUD en sticks zijn zichtbaar. Resolutieschaal 60% wordt alleen voor de gecontroleerde vergelijking ingesteld; geen productinstelling gewijzigd. PerfGovernor staat uitsluitend in het testproces stil zodat hij de A/B-schaal niet verandert.

De oorspronkelijke screenshot bevat geen savepositie, exacte camera-/kwaliteitsinstellingen of wereldcoördinaten. Daarom wordt **geen identieke reconstructie van die screenshot geclaimd**. De echte nieuwe voor/na-paren gebruiken wel dezelfde locaties, kwaliteit en tijd; de vastgezette camera-pose wijkt per paar hoogstens 1 cm af. De referentie is apart gelabeld en nooit als geïmplementeerde render gepresenteerd.

De eerdere lokale meettabel is gemaakt op Linux met **Godot 4.7.2 Mobile/Vulkan, Mesa llvmpipe (software)**, 1280×720 en twee gedeelde CPU-cores. De latere PR-run `42276280736` rapporteerde door ontbrekende Vulkan-surface-extensies echter **OpenGL Compatibility / llvmpipe LLVM 20**; die echte PNG's zijn geen Mobile-renderpad. De captureworkflow installeert nu Mesa lavapipe wanneer beschikbaar en schrijft de werkelijk gebruikte renderer en Vulkan-diagnostiek naar het artifact. Geen van beide softwarepaden is een fysieke iPhone- of Windows-meting. De gevechtsproef gebruikt 80 echte vijanden met bestaande AI en wapens; de bestaande wereldverdedigers blijven aanwezig. Shaderopwarming en gesorteerde frametijden staan los van structurele draw-/primitivecounts.

## Nog zichtbaar onder de kwaliteitslat

Beeld B is de richting, geen checklist van letterlijk na te maken stenen of planten. De echte render van commit `1f2d814` (Godot-run `42276280736`) haalt de bredere maatstaf **nog niet**: grote rustige grasvlakken blijven zichtbaar en het pad ligt vanuit die camera te ver van de speler om de detailverbetering goed te tonen. De gravel-PBR maakt de aarde beter herkenbaar, maar bodem en ondergroei ogen nog niet rijk genoeg. Daarom schuift deze iteratie budget naar lage bladplanten en kort gras en maakt de bestaande steentextuur op het pad fijner. De nieuwe Godot-render moet die wijziging nog bevestigen; visuele acceptatie blijft open.

De atlas van bestaande bladeren beperkt de vormvariatie van kleine tropische bodemplanten; vaste schaduwen zijn benaderingen en de grond blijft geometrisch vlak. Deze wijziging verandert geen bestaande natuurcolliders of levelhoogte. De vochtplekken zijn materiaalvariatie, geen geometrische plassen met gereflecteerde boomkruinen. Fysieke iPhone-profilering en langere shimmer-/gevechtstests zijn nodig voor mobiele acceptatie.

## Acceptatie

Echte native iPhone-/Windows-metingen, thermiek, 60 seconden bewegingsshimmer en representatieve lange grote gevechten blijven nodig. Geen fysieke iPhone-test, iOS Quick Look of iMac-productiepipeline uitgevoerd. Geen overeenkomst met referentie B claimen op basis van uitsluitend technisch groene tests.

## Regressietests en iOS-export

- `visual_b_test.gd`: PASS, 0 failures na toevoeging van gravel; controleert de echte gamelevel, PBR/mips, objectlimieten, clearings, paden/oeverdetails, kwaliteits- en jungleknoppen en ontbreken van nieuwe colliders.
- `visual_b_capture.gd`: de vorige iteratie slaagde met echte camerabeelden en 80 bestaande AI-vijandscènes. De toegevoegde PR-workflow draait deze capture opnieuw voor de graveliteratie, inclusief de render op 100% schaal. De lokale shell heeft geen grafische displayserver; daarom is daar geen nieuwe GPU-capture uitgevoerd.
- Bestaande tests `jungle_test`, `rivier_test`, `schaduw_test`, `kwaliteit_test`, `surface_filtering_test`, `camera_test` en `team_commands`: geslaagd.
- GitHub-checks voor vijandbasis/voertuigen/wapens/touchregressie en de unsigned iOS-IPA-export: geslaagd. Dit bewijst compilatie en gesimuleerde touch-events, geen uitvoering op een iPhone.
- GitHub OTA-patchcontrole en PR-preview: geslaagd; de release-publicatiestap is overgeslagen.
- `grass_3d_test`: faalt alleen op de bestaande verwachting voor palm-/rotsposities. Dezelfde test faalt op de onaangepaste startcommit `b808fe1`, dus deze check legt een bestaande discrepantie vast.
- De brede `run_tests.sh`-verzameling is afgebroken bij `airfield_hq_22_import_test`: die test vereist de wrapper-scène `airfield_hq_22_import_test_scene.tscn`, terwijl de algemene runner hem rechtstreeks met `-s` start en `Game` daardoor ontbreekt. Dit is een runner-/testaanroepfout, geen regressie-uitspraak over de asset.
- Godot 4.7.2 `--export-pack iOS` maakte een resourcepack van circa 1,2 GB. Tijdens het opnieuw importeren meldde Godot twaalf `Basis must be normalized`-fouten bij de ongewijzigde `assets/brandkraan.glb`; de pack-export liep daarna wel door. Dit controleert alleen de resourcepack, niet een IPA-build, Apple Metal-rendering, ondertekening of uitvoering op een iPhone.

## Reviewcorrecties

Een afzonderlijke GPT-6 Astra-review controleerde de code zonder tests te claimen. Hersteld: vaste AABB's per detailcel (clearance verplaatst oude slots onder de wereld), correcte lokale assen voor takjes, gemeenschappelijke tangentbasis voor gedraaide modder-normalmaps, deterministisch gemengde habitatkandidaten vóór dichtheidslimieten, bijgewerkte bestaande surface-capture en gecontroleerde bestandswrites. De gerichte integratietest faalde vóór de bounds-/schaduwcorrectie en slaagde erna met 0 failures.

De bestaande vaste palmschaduw gebruikt nu dezelfde palm-alfa om de egale ovaal te onderbreken. Dit is uitdrukkelijk een **benaderde vaste schaduw**, geen nieuwe geometrisch correcte realtime-schaduw. De bestaande schaduwmodus blijft ongewijzigd; echte boomschaduw blijft een bestaande gebruikerskeuze.

## Echte renders en softwaremetingen

[Gebruikersbeeld / doel B / vorige echte Godot-render](captures/compare/three-way.jpg)

De bovenstaande vergelijking en tabel zijn van de vorige iteratie, vóór de gravel-PBR-binding; de tabel meet dus niet de huidige detailverdeling. De echte GL Compatibility-render en 100%-bospadcapture van commit `1f2d814` staan in het PR-artifact. De nieuwe branchwijziging wordt na de lavapipe/Mobile capture opnieuw beoordeeld en alleen dan worden de voor/na-afbeelding en tabel vernieuwd.

| Plek | Echt voor/na, zelfde camera | Gem. ms voor → na | P99 ms voor → na | 1% low FPS voor → na | Draws voor → na | Primitives voor → na |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| bospad | [Vergelijking](captures/compare/bospad.jpg) | 818.6 → 1613.5 | 1186.6 → 2144.6 | 0.84 → 0.47 | 331 → 504 | 836804 → 1797869 |
| rivier | [Vergelijking](captures/compare/rivier.jpg) | 406.6 → 960.9 | 544.9 → 1231.0 | 1.84 → 0.81 | 280 → 364 | 255653 → 1092208 |
| kamp | [Vergelijking](captures/compare/kamp.jpg) | 2465.1 → 2717.1 | 3075.1 → 3375.8 | 0.33 → 0.30 | 310 → 390 | 670925 → 1293442 |
| combat_80 | [Vergelijking](captures/compare/combat.jpg) | 2504.7 → 2735.2 | 25552.8 → 4372.2 | 0.04 → 0.23 | 1277 → 1369 | 1904919 → 2930846 |

**WARNING:** deze softwaremetingen bewijzen extra renderkosten, geen behoud van native iPhone-FPS. De lange frametijden, korte vensters (60 frames per stille plek, 100 in gevecht) en shader-/hoststalls maken de 1% lows ongeschikt als toestelacceptatie. Alle individuele gesorteerde frametijden, 1% lows en capturemetadata staan onverkort in [before-metrics.json](results/before-metrics.json), [after-metrics.json](results/after-metrics.json) en [comparison.json](results/comparison.json). De eerste baselineplek overlapt deels de importopwarming; gebruik die tijd niet als geïsoleerde GPU-regressiemeting. Camera-/pusher-CPU staat tijdens meten stil; dit is een vaste-camera-renderdiagnose, geen volledige gameplaybenchmark.

De oude gevechtsteller vroeg een niet-bestaande nodegroep op en registreerde daardoor 0. De test spawnede daadwerkelijk 80 vijanden (ook zichtbaar in de HUD/renders); de huidige capturecode leest de echte `Game.enemies`-lijst. Het oude ongeldige tellerveld is in de ruwe nulmeting behouden en expliciet gelabeld.

De 12-frame langzame camera-translatie is lokaal gerenderd voor/na. Er is geen gekalibreerde temporele shimmer-score en geen 60-secondencontrole op native hardware uitgevoerd. Shimmer en 1% lows blijven open acceptatiepunten.
