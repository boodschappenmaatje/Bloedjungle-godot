# M2HB wachttoren — technische gamekopie

Visuele bron: Dennis' goedgekeurde Meshy-export in [Google Drive](https://drive.google.com/file/d/1gl5CrJgdwT8JSqOcK_vR22GlBdmffV4v/view). SHA-256 van originele ZIP: `d023680c07b59a7505cc1a46c062b2b1de0477781c3324c6beac10eed495a94e`. De bron is niet in Git opgenomen (>100 MB). Deze export is een uniforme, technisch gedecimeerde kopie van de originele mesh en gebruikt de originele diffuse textuur; er is geen nieuw torenontwerp gemaakt.

`build.py` verwacht de uit de originele ZIP uitgepakte OBJ/MTL/PNG in `/tmp/m2src` en schrijft `assets/vijand_m2_toren.glb`. Blender 4.3.2: 2.486.536 → 60.000 driehoeken; uniforme schaal met Meshy-Y als hoogteas, 6 m hoog. Volledige visuele boundingbox na schaal is circa 4,51 × 3,42 × 6,00 m, inclusief uitstekende details. De constructievoet is nog niet afzonderlijk gemeten. De originele 4096² albedo blijft zichtbaar. Er zijn geen echte MG-pivots in de originele mesh; de Godot-ankers draaien, maar de originele MG-geometrie draait nog niet mee. De 60k mesh is nog niet tegen de ruwe bron in dezelfde camera beoordeeld.

Godot: `scripts/vijand_m2_toren.gd` instantiëert één gedeelde GLB op vier posities. `vijand_verdediger.gd` gebruikt het bestaande Assault-model en zijn bewegingen. Ruïne is de verschoven, herkenbare originele mesh met blijvende collider. Alle vier torens delen dezelfde geïmporteerde resource.

## Open kwaliteitsgates

- Gescheiden M2-mesh en werkelijke yaw/pitch/recoil van het originele wapen; zichtbare munitieband, hulzen en dedicated MG-audio ontbreken.
- Gemeten voetafdruk, bron-vergelijkingsrender, iPhone-LOD en native FPS ontbreken.
- USDZ-export niet beschikbaar in de hier geïnstalleerde Blender 4.3.2 (`bpy.ops.wm.usd_export` ontbreekt).
- `tests/aanval_basis_test.gd` slaagt nadat de routetest de speler tijdens het nabije MG-gevecht in leven houdt; de live/offscreen-omschakeling is daarmee functioneel gecontroleerd, maar langere gevechten en mobiele prestaties blijven open.

Geen externe audio toegevoegd: er is dus geen onbewezen gamelicentie of attributie.

## Experimentele M2-meshscheiding — 5 november (niet voor productie)

Nieuw: `split_weapon_probe.py`. Uitgangspunt is **precies Dennis' goedgekeurde bron**, geen ander uiterlijk. Het script leest een bestaande geoptimaliseerde GLB, laat de bron ongemoeid, en exporteert een **diagnostische** `TowerStatic` + `MG_Yaw` met originele texture/UV. Het schrijft **niet** naar de gameplay-asset.

Lokaal gecontroleerd op een andere 162.806-triangle LOD0-export van dezelfde goedgekeurde Meshy-bron:
- Selectie: 12.694 MG-kandidaat-driehoeken en 150.112 statische driehoeken; de som blijft exact gelijk.
- GLB herladen, UV/materialen behouden, omvattende bounds in rustpositie minder dan 2 mm afwijking.
- Dezelfde statische camerahoek gaf gemiddelde RGB-afwijking ca. 0,48/255 per kanaal tegenover het oorspronkelijke LOD0-renderbeeld (rendervergelijking is **geen** bewijs van identieke weergave op alle kijkhoeken).
- Een aparte 45° yaw-diagnose is gerenderd. **Bekend probleem:** delen van het zwarte schild en de onderste affuit zijn nog niet helemaal afgesplitst; die kunnen bij draaien achterblijven. Daarom is dit uitsluitend een voorbereidende proef, **niet geïntegreerd** in `assets/vijand_m2_toren.glb`.
- **NIET GETEST** op de 60.000-triangle productie-GLB of in Godot; vereiste volgende stappen: selectie in Blender handmatig corrigeren met alle aan elkaar horende MG-delen, echte yaw/pitch/recoil-pivots, aparte richt-/muzzleankers, bronvergelijkingsrenders en regressietests. Pas daarna productie-GLB vervangen.

Voorbeeld (alle output in `/tmp`): `python3 bron/m2hb_toren/split_weapon_probe.py --source assets/vijand_m2_toren.glb --output /tmp/m2-split-PREVIEW.glb --debug-mask /tmp/m2-mask-PREVIEW.glb --yaw-preview /tmp/m2-yaw45-PREVIEW.glb`.

**Geen merge/OTA**, geen nieuwe bron- of productiemodellen aan deze wijziging toegevoegd.

## Bewegende M2HB: tweede technische proef (5 november 2026)

**Op de featurebranch toegevoegd:**

- `build_articulated_m2.py` maakt uit de **bestaande goedgekeurde game-GLB** een **aparte kandidaat-GLB**; de productiebestanden en bron worden niet overschreven.
- De kandidaat bevat `TowerStatic`, `MG_Yaw/MG_ShieldMount`, `MG_Yaw/MG_Pitch/MG_Recoil/MG_BarrelReceiver` en een `Muzzle`-anker. Het volledige schild en de affuit worden zoveel mogelijk aan de yaw-pivot gekoppeld, de loop en receiver aan de pitch/recoil-pivot.
- `scripts/vijand_m2_toren.gd` zoekt de **echte geïmporteerde** yaw/pitch/recoil-geometrie op. Wanneer die ontbreekt, wordt het oude fallback-ankersysteem gebruikt en blijft het bestaande speelbare GLB werkzaam. De GLB in `assets/` is nog **niet** vervangen.
- De geïsoleerde workflow `.github/workflows/m2hb-articulation-preview.yml` bouwt een **review-artifact** op de branch en vervangt de bron/gameasset **niet**. De workflowstatus is vanuit ChatGPT niet bevestigd; het artifact is nog geen bewezen Godot-import.

**Lokale proefresultaten op een 162.806-triangle LOD0 van precies dezelfde Meshy-bron (dus niet de huidige productie-60k):**

- `TowerStatic`: 149.156 triangles; yaw/schild/affuit: 7.315; pitch/loop/receiver: 6.335. **Som: 162.806, geen verloren of dubbele driehoeken.**
- Opnieuw geïmporteerde GLB: exacte hiërarchie en **afwijking in rust-boundingbox minder dan 2 mm** (numeriek werkelijk <0,001 mm). Originele kleurentextuur en UV's worden hergebruikt.
- Vergelijking dezelfde rendercamera: gemiddelde RGB-afwijking ca. **0,70/255 (frontaal)** en **0,44/255 (bovenaanzicht)**. Dit is een nuttige kwaliteitscheck maar **geen volledige bronmodel-pariteit op ieder gezichtspunt**.
- Een yaw-voorbeeld van 45° en een pitch-voorbeeld van 10° zijn gegenereerd. Resterende bevestiging: de onderdelen draaien binnen de werkelijke Godot-camera zonder een zichtbaar vastzittend plaatdeel.
- Lokaal zijn Python/VTK-controles gedaan; **Godot CI/native iPhone voor deze nieuwe animatieverbinding nog NOT RUN**. De eerdere drie groene Godot-tests gelden voor de bestaande niet-gearticuleerde 60k-gameversie, niet als bewijs van de nieuwe kandidaat.

**Volgende harde poort vóór productie:** laat de GitHub-artifactbouw op de echte 60k slagen, render **origineel vs. kandidaat** vanuit dezelfde 4 richtingen, verifieer schild/onderbouw/voetafdruk, test `has_articulated_m2() == true` in Godot, test yaw/pitch/recoil en kogelstart vanaf de werkelijke `Muzzle` en voer de bestaande toren-/basis-regressies opnieuw uit. **Geen automatische merge of OTA.**

## Productie-integratie gearticuleerde 60k-GLB — 5 november, vervolg

De 60k-game-GLB is nu opnieuw opgebouwd met `build_articulated_m2.py` en als `assets/vijand_m2_toren.glb` geïnstalleerd. De bestaande `build.py` zet voortaan de OBJ-importrotatie op nul nadat Meshy-Y naar Blender-Z is omgezet. De vorige productie-GLB had daardoor een extra 90° node-rotatie; een Godot-meshcontrole bevestigde dat de oude visuele toren liggend binnenkwam. De nieuwe game-GLB heeft een rechtopstaande Godot-import. De echte Godot-pivots, het schild en de receiver zijn afzonderlijke delen. Geen nieuwe mesh of textuur werd ontworpen.

Geverifieerd: exact 60.000 triangles (56.021 statisch, 2.113 yaw/schild, 1.866 pitch/loop), UV's en originele 4096² albedo. De oude en nieuwe geëxtraheerde PNG's hebben exact dezelfde RGB-pixels. De Godot-proef vindt de zeven vereiste nodes, UV's en materiaal op alle drie meshes, verplaatst monding/schild/loop met yaw, pitch en recoil en bevestigt monding `(-2.25, 5.75, 0.83)` meter in de niet-geroteerde modelruimte. In Blender zijn origineel OBJ, nieuwe rustpose, selectie en 45° yaw vanuit dezelfde camera gerenderd; zie `docs/vq2/renders/m2hb_20261105_*.png`. De gemiddelde pixelafwijking tussen originele OBJ en nieuwe rustpose in de render is 3,08/255 per kleurkanaal (inclusief sampling/decimatie). Dit is geen formele iPhone-beeldvergelijking.

De werkelijke visuele onderbouw heeft circa 3,87 × 3,34 m footprint. De collider is daarop aangepast. De GLB en collider staan binnen de muur doordat de **inhoud** van de vier torenroots 0,75 m in x en 0,50 m in z naar de binnenplaats is gezet; de historische hoekroots blijven op hun plek. Er is geen niet-proportionele schaal gebruikt.

De bestaande `vijand_m2_toren.gd` gebruikt de geïmporteerde pivots. `tests/vijand_m2_articulatie_test.gd` en `tests/vijand_m2_toren_test.gd` vormen de gerichte regressies. De eerdere experimentele secties hierboven beschrijven de geschiedenis vóór deze productie-integratie. Native iPhone-FPS en daadwerkelijke OTA-installatie blijven apart te testen.

Ook `m2hb_20261105_pitch10.png` en `m2hb_20261105_recoil12.png` tonen met dezelfde camera een echte +10° elevatie en 12 cm terugslag van de oorspronkelijke receiver/loop. De Godot-articulatietest gebruikt dezelfde elevatieas en terugslagvector als de gameplaycode en controleert dat de monding zichtbaar meebeweegt.

De macOS iOS-importcheck op PR #227 vond een tijdelijke scriptinstantie bij het achteraf wisselen van het script op `enemy.tscn`. De verdediger gebruikt daarom nu `scenes/vijand_verdediger.tscn` met het afgeleide Assault-script als vaste scene-resource. Het model, de rolverdeling en gameplaywaarden zijn dezelfde; de iOS-check wordt op de volgende commit opnieuw gedraaid.

Vervolg op de macOS-importcheck: Godot kan tijdens `--editor --import` runtime-soldatenscripts als placeholders instantiëren wanneer de basis wordt opgebouwd. `VijandBasis.build` maakt de twaalf verdedigers nu uitsluitend buiten editor-hint aan. De native/runtime-scene blijft ongewijzigd: de twaalf eenheden worden daar wel gespawned. Een schone lokale editorimport en de runtime-tests zijn na deze guard opnieuw uitgevoerd.
