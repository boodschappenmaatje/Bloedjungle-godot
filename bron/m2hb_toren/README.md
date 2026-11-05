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
