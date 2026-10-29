# BLOEDJUNGLE — HIGH QUALITY SHOWCASE + VQ2 3D ASSET STANDARD (projectbreed)

**Status:** High Quality Showcase is de standaard voor nieuwe en verbeterde Bloedjungle-assets voor zowel ChatGPT Codex als Claude Code. De bestaande VQ2-richtlijnen en referentieassets blijven de minimale visuele ondergrens; ze worden niet verwijderd.
**Enige bron van waarheid:** dit document. `AGENTS.md` en `CLAUDE.md` verwijzen hiernaar; kopieer de volledige regels niet naar twee verschillende plaatsen.
**Vastgelegde referentie:** bestaande Blender Visual Quality 2.0-productie (kazerne, wachttoren, legerjeep) en [de resultaten](vq2/README.md). Het eerdere [productiecontract](BLENDER_VISUAL_QUALITY_2.md) bevat specifieke gegevens over die drie modellen, geen algemene opdracht om steeds dezelfde drie te bouwen.

## 0. Permanente samenwerking: korte opdrachten, eerst overleg waar nodig

Deze afspraken gelden voor **Codex én Claude Code** bij alle toekomstige 3D-assetwerkzaamheden, ook als de gebruiker alleen een korte opdracht geeft.

### Snelle 3-stappenworkflow: maken → bekijken → mergen

Als de gebruiker korte opdrachten geeft zoals **"voertuig maken"**, **"voertuig bekijken"** en **"voertuig naar main en OTA"**, volg deze efficiënte workflow bij **Codex én Claude Code**, zonder nieuwe projecten of dubbele rondes:

1. **MAKEN:** gebruik de bestaande repo, bron- en assetbibliotheken en laatst goedgekeurde specificatie. Voor een nog niet goedgekeurd nieuw ontwerp: stel uitsluitend noodzakelijke korte ontwerpvragen en vraag één expliciete ontwerpgoedkeuring (zie hierna). Produceer vervolgens het volledige echte Blender-HQ-bronmodel, geoptimaliseerde GLB, afgesproken werkende animaties en gerichte tests. **Voeg de GLB direct toe aan de bestaande interactieve 3D-viewer** zodat een tweede bouwsessie niet nodig is. Maak een featurebranch en Draft PR; rapporteer alleen status, eventuele blokkers en viewerlink indien beschikbaar.
2. **BEKIJKEN:** de gebruiker wil het model op iPhone kunnen draaien, zoomen en echte clips afspelen. Hergebruik de al gebouwde viewer op dezelfde branch en geef een **werkend geverifieerd** previewadres of leg precies uit hoe de bestaande viewer bereikbaar is; claim geen werkende openbare URL zonder verificatie. Verwerk concrete feedback op dezelfde branch, zonder alles opnieuw te bouwen. De gebruiker keurt de zichtbare kwaliteit expliciet goed.
3. **MERGEN:** uitsluitend na expliciete instructie **"merge naar main"** én modelgoedkeuring: controleer dat de juiste complete GLB/animaties/Godot-integratie in de PR zitten, dat kritieke tests/CI slagen en dat bestaande gameplay intact is; merge vervolgens naar `main`. **Een push naar `main` kan de gedeelde OTA-update automatisch publiceren**: benoem dit vooraf en voer de merge alleen uit als de gebruiker tevens expliciet OTA-publicatie heeft goedgekeurd, bijvoorbeeld met de korte opdracht **"voertuig naar main en OTA"**. Verifieer de OTA-workflow en het gepubliceerde manifest voordat je zegt dat de update op iPhone klaarstaat.

**Snelheidsregels:** één branch/PR en één assetversie door de volledige cyclus; geen herhaalde brede analyses, exports, headless tests of iPhone-FPS-rondes zonder concrete aanleiding. Geef alleen essentiële goedkeuringsmomenten en blokkerende fouten terug. Bij mislukkende regressies leg uit of ze ook al op `main` bestaan; zet nooit blind veiligheids- of gameplaycontroles uit. **Fase 1 en 2 mogen niet stilzwijgend `main` of de gedeelde OTA-feed wijzigen.**

### Materiaalkeuze in overleg: Poly Haven via Blender MCP

**Bij nieuwe of visueel verbeterde assets:** bespreek tijdens de ontwerpfase ook de zichtbare **materialen en textuurstijl**, vóór het downloaden van nieuwe texturepakketten. Doe dit voor Codex én Claude Code, ook als de opdracht alleen "maak een voertuig" luidt.

- Zoek maximaal **2–4 relevante materiaalopties** in de **bestaande lokale materiaalbibliotheek** en/of [Poly Haven](https://polyhaven.com/textures) (CC0). Toon per kandidaat een **echte voorbeeldafbeelding of gecontroleerde materiaalpagina** plus korte beschrijving: materiaal, kleur, slijtage, schaal in meters, hoe het eruitziet van boven vanuit de gameplaycamera. Geen nepplaatjes of ongeverifieerde assetlinks. Stel vervolgens **één eenvoudige keuzevraag** aan de gebruiker; herhaal de keuze bij duidelijk verschillende onderdelen (dak, muur, wielen) alleen indien zinvol.
- **Eerst goedkeuring, dan downloaden:** na de materiaalkeuze importeer via de **beschikbare en aantoonbaar werkende Poly Haven-integratie in Blender MCP** of de officiële Poly Haven API. Kijk eerst welke MCP-tools in die concrete lokale/remote omgeving beschikbaar zijn; geen niet-bestaande commando's verzinnen. Claudes cloud-Blender kan afwijken van de lokale Codex-MCP op de iMac. Geen betaalde add-ons of services zonder toestemming.
- Haal een **volledige bruikbare PBR-set** op: albedo/base color, OpenGL normal en roughness; metallic waar passend, optioneel AO/displacement. Controleer kleurbeheer, UV/texelmaat en geloofwaardige schaal; bake of pak de maps correct voor glTF/Godot. Respecteer de afgesproken High Quality Showcase-bronkwaliteit en de **afzonderlijke geoptimaliseerde mobiele GLB**; 4K alleen wanneer aantoonbaar nuttig.
- **Voorkom opnieuw downloaden:** cache materialen en bronnen, leg exacte Poly Haven-id/URL, gekozen resolutie en CC0-licentie vast in assetdocumentatie; hergebruik in volgende gebouwen en voertuigen voor een consistente Bloedjungle-stijl. Poly Haven-bronbestanden zijn CC0, maar gebruik de openbare API conform de actuele gebruiksvoorwaarden.
- Als er al een **goedgekeurde materiaalspecificatie** is, hergebruik die zonder nieuwe goedkeuringsvraag. Download niet lukraak tientallen materialen en verander bestaande goedgekeurde texturen niet zonder aanleiding.

### iPhone Bestanden-preview (voorkeursroute)

- Lever bij ieder nieuw/gewijzigd model **naast de echte .blend-bron en Godot-.glb** bij voorkeur een werkend **.usdz-previewbestand** om rechtstreeks vanuit **Bestanden / Apple Quick Look op de iPhone** te bekijken. Blender 4.5 kan USDZ exporteren via USD-export met `.usdz`-extensie; controleer daarna of meshes, schaal, textures en materialen echt zichtbaar zijn in Apple Quick Look.
- Maak het USDZ-bestand via een **door de gebruiker daadwerkelijk bereikbare downloadroute**, bijvoorbeeld een geschikt release-artifact of een al ingestelde iCloud Drive-map. Een bestand dat alleen in een lokale map op de iMac of in een niet-gedeelde cloudcontainer staat is geen iPhone-downloadlink; zeg dat eerlijk. Gebruik geen nieuwe betaalde hosting zonder toestemming.
- **Animaties:** behoud alle werkelijke clips in GLB/Godot. Quick Look is geen volwaardige clipselector; maak indien passend afzonderlijke USDZ-previewclips of gebruik de bestaande webviewer/Godot-demonstratie om complex gedrag te beoordelen. Claim alleen werkende iPhone-animaties als ze op iOS gecontroleerd zijn.
- Maak USDZ **gelijktijdig bij MAKEN** in de 3-stappenworkflow. In BEKIJKEN geeft de agent een link naar het reeds gemaakte bestand, **niet opnieuw modelleren of exporteren** zonder concrete foutmelding. Het blijft mogelijk de bestaande 3D-webviewer als fallback te gebruiken.

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
- Maak voor elk model ook een aparte **`.usdz`-preview voor iPhone Bestanden/Quick Look**. Dit is een beoordelingskopie; de bewerkbare `.blend` blijft de bron en de geoptimaliseerde `.glb` blijft de Godot-export. Neem PBR-materialen en benodigde texturen mee, houd de schaal in meters en exporteer afgesproken animatie wanneer de bron echte, actieve Blender/GLB-animatie bevat. Verzin geen clips en claim geen playback die niet is gecontroleerd.
- Gebruik op de iMac `tools/usdz_preview/export_usdz.py` met Blender 4.5+, gevolgd door `tools/usdz_preview/validate_usdz.py` (Apple `usdchecker --arkit` en `usdzip`-inhoudscontrole). Zet previews bij voorkeur in iCloud Drive `Bloedjungle Previews/<asset>/<versie>/`; gebruik bij ontbrekende iCloud-toegang `previews/usdz/<asset>/<versie>/` in het project en geef een directe downloadlink. Gebruik nooit een bestaande bestandsnaam stilzwijgend opnieuw.
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
6. Maak daarnaast een los `.usdz`-bestand voor iPhone Bestanden/Quick Look, met materialen en waar technisch ondersteund de afgesproken animaties. Valideer de pakketstructuur en materialen; controleer de native Quick Look-preview op macOS indien beschikbaar. Een succesvolle archiefcheck bewijst niet dat animatie op een specifieke iPhone afspeelt; vermeld die toestelcontrole als niet uitgevoerd totdat ze echt is gedaan.

## 6. Kwaliteitscontrole per oplevering

Een asset is **niet af** zonder:
- [ ] Oude versie en nieuwe versie vergeleken in identieke Blender- en Godot-camera's, indien upgrade.
- [ ] Overtuigende VQ2-stijl, constructie, PBR-texturen, correcte UVs en realistische slijtage — verbetering is ook op gameplayafstand leesbaar.
- [ ] Nieuwe `.glb`, bewerkbare Blender-bron, herhaalbaar exportscript en bron-/licentieinformatie opgeslagen.
- [ ] Afzonderlijke `.usdz`-iPhonepreview met materiaaltexturen gemaakt, gecontroleerd en op iCloud Drive gezet indien beschikbaar; animatie is alleen als werkend gemeld na controle.
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
