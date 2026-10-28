# BLOEDJUNGLE — HIGH QUALITY SHOWCASE + VQ2 3D ASSET STANDARD (projectbreed)

**Status:** High Quality Showcase is de standaard voor nieuwe en verbeterde Bloedjungle-assets voor zowel ChatGPT Codex als Claude Code. De bestaande VQ2-richtlijnen en referentieassets blijven de minimale visuele ondergrens; ze worden niet verwijderd.
**Enige bron van waarheid:** dit document. `AGENTS.md` en `CLAUDE.md` verwijzen hiernaar; kopieer de volledige regels niet naar twee verschillende plaatsen.
**Vastgelegde referentie:** bestaande Blender Visual Quality 2.0-productie (kazerne, wachttoren, legerjeep) en [de resultaten](vq2/README.md). Het eerdere [productiecontract](BLENDER_VISUAL_QUALITY_2.md) bevat specifieke gegevens over die drie modellen, geen algemene opdracht om steeds dezelfde drie te bouwen.

## 0. Permanente samenwerking: korte opdrachten, eerst overleg waar nodig

Deze afspraken gelden voor **Codex én Claude Code** bij alle toekomstige 3D-assetwerkzaamheden, ook als de gebruiker alleen een korte opdracht geeft.

### Nieuwe modellen: ontwerp vóór productie
1. Bij een nieuwe asset (bijv. "maak een straaljager") bespreek je **eerst met de gebruiker** het type en uiterlijk, de rol in de game, interacties/gameplayfuncties, beweegbare onderdelen, afzonderlijke Blender-/glTF-animaties, Godot-gestuurde bewegingen, geluid/VFX, schade/vernietiging en mobile prestatiebudgetten. Bied concrete, beknopte keuzes aan en stel vragen stapsgewijs, niet allemaal tegelijk.
2. Sla de afspraken op in een versieerbare **Asset Design Specification** bij de asset, met exacte clipnamen, pivots, clipsduur/loopgedrag, triggers, implementatieverantwoordelijkheid Blender versus Godot en acceptatiecriteria.
3. **Begin niet met de definitieve modelproductie voordat de gebruiker het ontwerp expliciet heeft goedgekeurd.** Als er al een goedgekeurde specificatie is, hergebruik die en vraag alleen naar nieuwe ambiguïteiten.

### Bestaande modellen vervangen of aanpassen: kort verzoek volstaat
1. Wanneer de gebruiker vraagt een oud model te vervangen door de HQ-versie, zoek zelf de relevante Godot-scènes, assetpaden, scripts en eerdere afspraken. Vraag niet opnieuw naar al bekende details; voer het verzoek uit binnen de expliciete scope.
2. Behoud **alle bestaande gameplaycontracten**, waaronder collisions, ingangen/deuren, klim-/dak-/slooplogica, physics, animaties, rigs, pivots, aanvalspunten, triggers, AI en interacties. Controleer met gerichte regressietests, niet alleen een succesvolle GLB-import.
3. Een assetvervanging is niet automatisch een verzoek om gameplayfuncties opnieuw te ontwerpen. Maak een **Draft PR**, lever een vergelijking en meld echte tests en beperkingen.

### Productie- en kwaliteitsstandaard
- Gebruik waar lokaal bereikbaar de bestaande **Bloedjungle 3D Production Pipeline 1.0 — High Quality Showcase** op de fysieke iMac onder `~/Documents/Bloedjungle 3D — Performance/pipeline-v1/`. Lees de actuele lokale README, config en scripts vóór gebruik; de repository vervangt deze runtime niet.
- Maak een **hoogwaardig bewerkbaar bronmodel** en een afzonderlijk **Godot-geoptimaliseerd gameasset**; behoud bronkwaliteit. Gebruik echte Blender-bronbestanden, GLB, bruikbare gebakken PBR-maps en previews vanuit de werkelijke gameplaycamera. Animaties zijn echte zichtbare clips, of expliciet als Godot-code beschreven.
- Voor Showcase-bronnen is **2K een richtwaarde**, 4K alleen wanneer brondetail en zichtbaarheid dit rechtvaardigen. Voor iPhone-exports gelden meetgestuurde resolutie, atlassen, LOD en trianglebudgetten (vaak 512–2K). Hoge renderresolutie of 128+ Cycles-CPU-samples bewijst op zichzelf geen assetkwaliteit.
- Op de bestaande iMac zijn **Solid Viewport en Cycles CPU** de betrouwbare route. EEVEE/Material Preview zijn niet bevestigd stabiel; ga er niet stilzwijgend van uit dat zij werken. Indien lokale Blender-toegang ontbreekt, zeg dat expliciet en claim geen lokale productie.
- Houd de bestaande **VQ2-referenties** als minimale kwaliteitseis; eerdere stijlafspraken, kleuren, top-down leesbaarheid en gameplaybehoud blijven van kracht.

### Testen, samenwerken en publicatie
- Gebruik passende Godot-import-, scene-, gameplay- en animatieregressietests. Na een al gevalideerde pipeline **geen eindeloze performancetests**: doe een gerichte check per nieuw model en uitgebreid testen bij duidelijke regressie of zware systeemwijzigingen.
- Vermeld `PASS / WARNING / NOT RUN`, en claim nooit fysieke iPhone-FPS zonder echte apparaatmeting. Een afzonderlijke Asset Test Zone bewijst niet automatisch gameplay-FPS.
- Werk op een aparte branch met **Draft PR** voor game-/assetwijzigingen. **Niet naar `main` mergen of naar de gedeelde `updates`-release publiceren zonder afzonderlijke expliciete toestemming van de gebruiker.** De gedeelde OTA-feed bereikt mogelijk andere installaties.
- Schrijf korte uitvoerbare antwoorden aan de gebruiker: die moet kunnen zeggen "Vervang de oude bunker door onze HQ-bunker" zonder lange prompts.

## 1. Stijl: wat is de maatstaf?

- **Realistische, licht verweerde militaire junglewereld**, geïnspireerd op Command & Conquer: Generals, met de goed leesbare top-down actie van Dead Nation. Geen speelgoedachtige kubusvormen, vlakke kleuren, plastic look of overdreven filmische overbelichting.
- Maak herkenbare proporties en een sterk silhouet **vanuit de echte spelcamera**. Besteed extra aandacht aan daken, voertuigbovenzijden, torenplatforms, silhouetlijnen en contrasten die in gameplay zichtbaar zijn.
- Geloofwaardige constructie: plaatdiktes, dragende balken, verstevigingen, bouten/scharnieren op belangrijke plekken, passende deuren/ramen, mechanische verbindingen. Bevels en correcte normals/weighted normals waar passend.
- **Beheerst verweerd:** vuil rond grondcontact en naden, regenstrepen op gevels, afgesleten verf op blootgestelde randen, modder rond banden/rupsen. Geen willekeurige uniforme ruis en geen extreme roest zonder context.
- Samenhangend palet: olijf-/legergroen, gedempt zand/beige, bruine aarde, verweerd hout, beton, donker staal, rubber, canvas. Controleer onder **Godot-gamebelichting**, niet alleen onder Blender-studioverlichting.
- Gebruik de drie VQ2-assets in `assets/{kazerne,wachttoren,legerjeep}.glb` als **ondergrens voor afwerking en materiaalrealisme**, niet als verplicht aantal polygonen of identieke kleur voor elk object.

## 2. PBR en texturen — verplicht waar fysiek zinvol

- Echte **base color/albedo**, **OpenGL normal** en **roughness** (bij voorkeur correct ingepakte glTF metallic/roughness/ORM); AO alleen waar nuttig, metallic alleen voor metaal.
- Kies UV's, texeldichtheid en projectie zorgvuldig. Voorkom uitgerekte vlakken en storend herhalingspatroon. Houd PBR-bronmetadata en licenties bij.
- **High Quality Showcase-bronmodellen:** standaard een richtwaarde van 2K, 4K alleen voor aantoonbaar nuttige hero-details. **Godot-gameversie:** texturebudget per asset en gameplayafstand bepalen, vaak 512px–2K, met atlassen/deling waar verstandig. De bestaande VQ2-1K-regel blijft een zuinige optie voor kleinere assets. Geen 256→2K opschalen en dat als echte kwaliteitswinst tellen.
- Hergebruik goede bestaande CC0/PBR-materiaalsets, onder meer uit `assets/textures/vq2/`, als die passend zijn. Geen externe betaalde leveranciers zonder toestemming.
- Textuurkwaliteit is belangrijker dan losse materiaalnamen. Gebruik gedeelde materiaalbibliotheken/atlassen wanneer dit drawcalls en geheugengebruik helpt.

## 3. Modellen, Godot en prestaties

- Maak in **Blender** met herhaalbaar, waar mogelijk headless Python-script; lever **echte** `.blend`, `.glb` en gebruikte kaarten aan. Geen afbeelding of conceptprompt als vervanging voor een model.
- Export in meters (1 unit = 1 meter), juiste rotatie/origin en praktische pivots. Godot 4 importeert de GLB inclusief PBR en, indien aanwezig, animatietracks.
- Bewaar bestaande gamecontracten: node-/botnamen, schietpunten, colliders, ingangen, teamkleuren, footprints, deur/roof-visible/slooplogica, rig/animaties en bestaande scripts. Voor modellen met zulke contracten **eerst code inspecteren**, dan pas geometry aanpassen.
- Streef naar minder overbodige geometrie, draw surfaces, transparante lagen en aparte materialen. Gebruik normalmaps en goede silhouetten vóór extra microgeometrie.
- **Indicatieve startbudgetten, geen blind harde maxima:** kleine prop 300–1.500 triangles; middelgrote prop 1.500–5.000; kleine/middelgrote gebouwen ongeveer 4.000–20.000; grote gebouwen naar functie en gedeelde fragmenten; voertuigen ongeveer 5.000–50.000 afhankelijk van rol/zichtbaarheid. Motiveer afwijkingen met beeldkwaliteit en metingen.
- Bestaande VQ2-referenties: kazerne 13.912; wachttoren 16.312; statische legerjeep 46.436 triangles. Deze waarden zijn **geen standaardlimieten** voor toekomstige objecten.
- LOD's toevoegen bij herhaald gebruik, grotere renderafstand of zware meshes; simpele colliders behouden. Geen wijziging van globale Godot-camera/renderer/projectinstellingen zonder noodzaak en expliciete motivatie.
- Rapporteer realistische prestaties van de gebruikte testomgeving. **Geen iPhone-FPS claimen** zonder echte fysieke meting in Xogot.

## 4. Animaties en hiërarchie

- Controleer vóór wijzigingen of er echte GLB-clips, rigs, geanimeerde pivots of door GDScript bestuurde bewegende onderdelen bestaan.
- **Elke bestaande animatie of werkende gamebeweging blijft behouden**. Exporteer werkelijke GLB-tracks voor Blender-animaties en verifieer niet alleen clipnamen maar ook zichtbare transform-verandering.
- Voor nieuwe bewegende assets (zoals voertuigen, deuren, rotors, kranen, kanonnen): definieer logische pivots/hiërarchie en de relevante clips, met correcte herhaling en rustposes.
- Houd onderscheid tussen **statische** `legerjeep.glb` en de **speelbare** `jeep.glb`; de laatstgenoemde heeft gameplayafhankelijke tracks en nodecontracten.
- Als een model geen animaties bevat, zeg dit eerlijk. Toon geen fictieve Play-knop die een statisch model afspeelt.

## 5. Verplichte oplevering: échte 3D-viewer + in-game test

Voor **ieder nieuw/verbeterd model**:
1. Voeg het **daadwerkelijke GLB-bestand** toe aan de bestaande interactieve viewer bij `tools/blender-vq2-viewer/`. Breid selector/manifest/build uit voor het nieuwe model in plaats van telkens losse viewers te maken. Zie [viewer-instructies](../tools/blender-vq2-viewer/README.md).
2. Maak touchbediening voor iPhone: 360° draaien, pinch-zoom, reset, schuin en gamecamera-preset. Bij een vervanging/upgrade: **V1 naast V2** met identieke framing, camera, belichting en materiaalmodi.
3. Toon echte `glTF`-animatieclips met selector, Play/Pause, restart, en scrubber/snelheid waar passend. Test zichtbaar bewegende wielen, rotors, schuifdeuren of andere doelonderdelen. Voor puur door Godot gestuurde beweging: bied daarnaast een **echte Godot-testscene**, en label wat de webviewer zelf niet kan spelen.
4. Publiceer indien mogelijk een werkende, op iPhone te openen viewerlink. **Een webviewer is niet hetzelfde als native inline 3D in ChatGPT**; maak geen onjuiste beloftes dat de modellen in dit chatvenster interactief verschijnen.
5. Test de modellen in bestaande Godot-scènes of een geïntegreerde showcase met **de werkelijke gameplaycamera**; behoud gameplaybesturing. Voor/na-renders mogen niet de enige controle zijn.

## 6. Kwaliteitscontrole per oplevering

Een asset is **niet af** zonder:
- [ ] Oude versie en nieuwe versie vergeleken in identieke Blender- en Godot-camera's, indien upgrade.
- [ ] Overtuigende VQ2-stijl, constructie, PBR-texturen, correcte UVs en realistische slijtage — verbetering is ook op gameplayafstand leesbaar.
- [ ] Nieuwe `.glb`, bewerkbare Blender-bron, herhaalbaar exportscript en bron-/licentieinformatie opgeslagen.
- [ ] Objectnaam, pivots, metermaat, collisions, gameplay-nodecontracten en eventueel destructie-/bouwgedrag behouden en getest.
- [ ] Werkelijke driehoeken, materialen, surfaces, texturebronresoluties en geheugen-/prestatie-observaties gerapporteerd.
- [ ] 3D-viewer uitgebreid met echte asset, iPhone-vriendelijke besturing en animatie-afspeelfuncties wanneer clips bestaan.
- [ ] Godot-import en relevante regressietests uitgevoerd; niet-uitgevoerde fysieke iPhone-check expliciet vermeld.
- [ ] Geen ongewenste wijziging aan unrelated assets, VFX of renderer.

## 7. Agentworkflow — Codex én Claude Code

1. Lees voor iedere 3D-assettaak dit document plus relevante `bron/<asset>/README.md`, generator en `docs/vq2/README.md`. Inspecteer actuele `main` en open PRs.
2. Maak de gewenste kwaliteit concreet voordat je scripts draait; hergebruik bestaande Blender-code, beelden, materialen en viewers.
3. **Bouw echt met Blender** (lokaal/headless of gratis GitHub Actions), exporteer GLB, inspecteer de daadwerkelijke output. Wanneer Blender niet uitvoerbaar is: rapporteer blocker, claim geen voltooid model.
4. Test daarna Godot-import, gameplayregressies, animaties en mobiele viewer. Documenteer PASS/FAIL/NOT RUN.
5. Werk op een **aparte featurebranch en Draft PR** bij inhoudelijke model-/gamewijzigingen; **geen automatische merge naar `main`**. Alleen de gebruiker keurt modelkwaliteit definitief goed na visuele beoordeling.
6. Maak geen tweede concurrerende kwaliteitsstandaard. Wijzig bij een gewenste stijlupgrade **eerst dit document** en werk Codex/Claude instructieverwijzingen zo nodig bij.

**Korte naam voor prompts:** `BLOEDJUNGLE HIGH QUALITY SHOWCASE`. Bij korte verzoeken geldt automatisch deze workflow én de VQ2-basis als minimum. Voor nieuwe modellen eerst het ontwerp overleggen; voor bestaande modellen het gevraagde aanpassen met behoud van alle gameplaycontracten.
