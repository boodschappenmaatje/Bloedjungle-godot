# M2HB wachttoren — technische gamekopie

Visuele bron: Dennis' goedgekeurde Meshy-export in [Google Drive](https://drive.google.com/file/d/1gl5CrJgdwT8JSqOcK_vR22GlBdmffV4v/view). SHA-256 van originele ZIP: `d023680c07b59a7505cc1a46c062b2b1de0477781c3324c6beac10eed495a94e`. De bron is niet in Git opgenomen (>100 MB). Deze export is een uniforme, technisch gedecimeerde kopie van de originele mesh en gebruikt de originele diffuse textuur; er is geen nieuw torenontwerp gemaakt.

`build.py` verwacht de uit de originele ZIP uitgepakte OBJ/MTL/PNG in `/tmp/m2src` en schrijft `assets/vijand_m2_toren.glb`. Blender 4.3.2: 2.486.536 → 60.000 driehoeken; uniforme schaal met Meshy-Y als hoogteas, 6 m hoog. Volledige visuele boundingbox na schaal is circa 4,51 × 3,42 × 6,00 m, inclusief uitstekende details. De constructievoet is nog niet afzonderlijk gemeten. De originele 4096² albedo blijft zichtbaar. Er zijn geen echte MG-pivots in de originele mesh; de Godot-ankers draaien, maar de originele MG-geometrie draait nog niet mee. De 60k mesh is nog niet tegen de ruwe bron in dezelfde camera beoordeeld.

Godot: `scripts/vijand_m2_toren.gd` instantiëert één gedeelde GLB op vier posities. `vijand_verdediger.gd` gebruikt het bestaande Assault-model en zijn bewegingen. Ruïne is de verschoven, herkenbare originele mesh met blijvende collider. Alle vier torens delen dezelfde geïmporteerde resource.

## Open kwaliteitsgates

- Gescheiden M2-mesh en werkelijke yaw/pitch/recoil van het originele wapen; zichtbare munitieband, hulzen en dedicated MG-audio ontbreken.
- Gemeten voetafdruk, bron-vergelijkingsrender, iPhone-LOD en native FPS ontbreken.
- USDZ-export niet beschikbaar in de hier geïnstalleerde Blender 4.3.2 (`bpy.ops.wm.usd_export` ontbreekt).
- De lange `tests/aanval_basis_test.gd` heeft vier mislukte assertions door veranderde live gevechtsverliezen; afstemming van de offscreen-omschakeling is nog nodig.

Geen externe audio toegevoegd: er is dus geen onbewezen gamelicentie of attributie.
