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

- `ground.gdshader` mengt gras, bosgrond, aarde, modder en mos met echte normal/roughnessrespons op wereldvaste schaal. Organische padschouders, longitudinale slijtage en onderbroken vochtplekken vervangen het uniforme grindbeeld. Geen parallax, terreinverplaatsing of collisionwijziging. De drie bestaande discard-contracten (rivier/loopgraven/helipad) blijven behouden.
- `pack_terrain_surfaces.py` pakt bestaande normal RGB en roughness A verliesloos in één bronafbeelding per materiaal. Geen download, vergroting of nieuwe fotobron. Het manifest bevat bron- en outputhashes; de oorspronkelijke licenties staan in `docs/ASSET_SOURCES.md`. Import bewaart alpha, gebruikt VRAM-compressie en mipmaps; geen normalmap-optimalisatie die de roughnessalpha weggooit.
- `JungleUnderstory` hergebruikt bestaande varen-, struik-, rots- en stamgeometrie voor onregelmatige kolonies bij natuurankers, padschouders, oevers en buitenfunderingen. Plat gedraaide bestaande driekaart-geometrie met het bladmateriaal vormt strooisel; verkleinde rotsen zijn visuele steentjes. Geen nieuwe GLB/Blender-modelversie: bestaande bronbestanden en viewers blijven leidend.
- Detail is in 24 m cellen gebatcht, maximaal 360 instances per batch, globale soortlimieten, 48/58 m afstandsculling en geen schaduwdraws. Alle extra details volgen bestaande jungle-/dichtheids-/kwaliteitstrappen en de bouwclearance-index. Een afzonderlijke RNG houdt de bestaande natuurcolliders op hun originele posities.
- `GrassField` besteedt een deel van het bestaande short-grassbudget eerst aan padschouders. Geen hogere tuftlimiet, nieuwe grasmesh of transparante graslaag.
- Wortelcontact in bestaande foliage-/grasshaders; iets neutraler daglicht en minder uniforme gele nabijmist via bestaande zon/sky. Tijd, weer en kwaliteitskeuzes blijven werken. Geen C-lichtbundels.

## Bewijsprotocol

`tests/visual_b_capture.gd` laadt de echte `scenes/main.tscn`, gebruikt de ongewijzigde `Camera`-node met bestaande camerascript en vaste wereldposities, seed `20261106`, High/day/clear, fake tree shadows, wind uit. HUD en sticks zijn zichtbaar. Resolutieschaal 60% wordt alleen voor de gecontroleerde vergelijking ingesteld; geen productinstelling gewijzigd. PerfGovernor staat uitsluitend in het testproces stil zodat hij de A/B-schaal niet verandert.

De oorspronkelijke screenshot bevat geen savepositie, exacte camera-/kwaliteitsinstellingen of wereldcoördinaten. Daarom wordt **geen identieke reconstructie van die screenshot geclaimd**. De echte nieuwe voor/na-paren gebruiken wel dezelfde locaties, cameratransforms, tijd, seed en instellingen. De referentie is apart gelabeld en nooit als geïmplementeerde render gepresenteerd.

De testomgeving is Linux met **Godot 4.7.2 Mobile/Vulkan, Mesa llvmpipe (software)**, een 1280×720 virtueel scherm en twee gedeelde CPU-cores. Absolute FPS zijn geen iPhone- of Windows-hardwaremeting. De gevechtsproef gebruikt 80 echte vijanden met bestaande AI en wapens; de bestaande wereldverdedigers blijven aanwezig. Shaderopwarming en gesorteerde individuele frametijden worden apart van structurele draw-/primitivecounts beoordeeld.

## Nog zichtbaar onder referentie B

B is **nog niet gehaald**: de bestaande palm-/varenatlassen hebben procedureel 512px brondetail, de ondergrond blijft geometrisch vlak en de vaste schaduwen zijn benaderingen. B heeft fijnere fotorealistische bladstructuur, dichtere gelaagde vegetatie, zichtbaar opgehoogde wortel-/oeverranden en rijker lokaal contactlicht. Deze PR verandert geen bestaande natuurcolliders of levelhoogte om die indruk te forceren. De vochtplekken zijn materiaalvariatie, geen geometrische plassen met gereflecteerde boomkruinen. Geen claim van volledige visuele voltooiing.

## Acceptatie

Echte native iPhone-/Windows-metingen, thermiek, 60 seconden bewegingsshimmer en representatieve lange grote gevechten blijven nodig. Geen fysieke iPhone-test, iOS Quick Look of iMac-productiepipeline uitgevoerd. Geen overeenkomst met referentie B claimen op basis van uitsluitend technisch groene tests.

## Reviewcorrecties

Een afzonderlijke GPT-6 Astra-review controleerde de code zonder tests te claimen. Hersteld: vaste AABB's per detailcel (clearance verplaatst oude slots onder de wereld), correcte lokale assen voor takjes, gemeenschappelijke tangentbasis voor gedraaide modder-normalmaps, deterministisch gemengde habitatkandidaten vóór dichtheidslimieten, bijgewerkte bestaande surface-capture en gecontroleerde bestandswrites. De gerichte integratietest faalde vóór de bounds-/schaduwcorrectie en slaagde erna met 0 failures.

De bestaande vaste palmschaduw gebruikt nu dezelfde palm-alfa om de egale ovaal te onderbreken. Dit is uitdrukkelijk een **benaderde vaste schaduw**, geen nieuwe geometrisch correcte realtime-schaduw. De bestaande schaduwmodus blijft ongewijzigd; echte boomschaduw blijft een bestaande gebruikerskeuze.
