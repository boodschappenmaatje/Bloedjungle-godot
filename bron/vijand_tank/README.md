# Vijandelijke tank (Dennis' Meshy-model, stap V2)

Bron: Dennis' eigen tank (Meshy, een Tiger I in olijfgroen met gele tekens, 5.262.768 driehoeken, Google Drive, niet in de repo). Dezelfde keten als de jeep (`bron/vijand_jeep/`) en de MCV (`bron/mcv_meshy/`), met `bpy` (Blender als Python-module) en numpy. Rapport: `docs/vq2/vijand-tank-rapport.md`.

```sh
python3 meet_baan.py <bron.glb> [controleplaatje.png]          # eenmalig: de buitenrand van de rupsbaan meten, schrijft baan.json (staat al in de repo)
python3 stap1_delen.py <bron.glb> <cache>                      # op ware grootte zetten (8,0 m met kanon), voorkant +Y, voxel-remesh (2,5 cm), vlakken indelen
python3 stap2_laag.py <cache>                                  # romp en koepel dichtmaken en decimeren, kanon en 22 wielen opnieuw gedraaid, twee rupsen als band, UV's
python3 stap3_bakken.py <cache> 2048 4096                      # albedo, tangent-normal en ORM bakken (Cycles CPU): atlas 2K, rups 4096 x 512
python3 stap4_export.py <cache> <uit> 2048                     # hierarchie, draaipunten, clips; schrijft vijand_tank.blend en vijand_tank.glb
python3 stap5_usdz.py <uit>                                    # Vijand_Tank.usdz (PBR + clip Rijden-loop) voor Quick Look
```

- `tank_delen.py` bevat alle getallen (schaal 4,2 uit bronmaat; 22 wielassen en straal; koepelkrans, kanonas, rupsbaan) en `indelen()`, de plaatsing van elk vlak in een deel. Het wordt door de stappen 1 t/m 4 gedeeld.
- Het bronmodel heeft losse schilfers en dubbele schillen; daarom wordt eerst een gesloten voxel-schil gemaakt en daar worden de delen uit gesneden (zoals bij de jeep).
- Spelassen: x = breedte, voorkant = +Y in Blender (-Z in Godot), 1 eenheid = 1 m, grond op z = 0, oorsprong in het midden van de romp. Maat 3,58 x 3,14 x 8,01 m.
- Knopen (contract met `scripts/vijand_tank.gd`): `VijandTank > Body > [RompMesh, RupsL, RupsR, WielL_w1..w9, WielL_aandrijf, WielL_spanwiel, WielR_..., Toren > [TorenMesh, Kanon > [KanonMesh, Monding]]]`. De rupsen zijn één band met `u` = booglengte: Godot schuift de textuur (`uv1_offset.x`), net als bij de Tiger van de speler.
- Clips (30 beelden/s): `Rijden-loop` (22 wielen, een omwenteling per lus), `Draaien-loop` (links en rechts tegengesteld), `Vuren` (kanon schiet terug en veert, 0,4 s). Godot haalt het achtervoegsel `-loop` van de naam en zet de clip op lus. In het spel stuurt de code koepel, kanon, wielen en rupsen zelf; de clips zijn voor de viewer en de USDZ.
- De `.blend`, de brontexturen en de `.usdz`-preview staan in de projectbibliotheek: `/mnt/project-files/modellen/vijand-tank/`.
