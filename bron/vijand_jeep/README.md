# Vijandelijke jeep (Dennis' Meshy-model, stap V1)

Bron: Dennis' eigen jeep (Meshy, 4.069.928 driehoeken, Google Drive, niet in de repo). Dezelfde keten als de MCV (`bron/mcv_meshy/`), met `bpy` (Blender als Python-module) en numpy. Rapport: `docs/vq2/vijand-jeep-rapport.md`.

```sh
python3 stap1_schil.py jeep_dennis.glb <cache> jeep 2.2105 0.015   # voxel-remesh (1,5 cm) op ware grootte (4,2 m lang)
python3 stap2_jeep.py <cache>                                        # delen: romp 30k, MG 8k, vier wielen; dichtmaken, decimeren, UV's
python3 stap3_bakken.py jeep_dennis.glb <cache> jeep 2048            # albedo, tangent-normal en ORM bakken (Cycles CPU, 2K)
python3 stap4_bouwen.py <cache> <uit> <assets/jeep.glb> 2048         # hierarchie, bemanning uit de eigen jeep, clips; schrijft vijand_jeep.blend en .glb
python3 stap5_usdz.py <uit>                                          # Vijand_Jeep.usdz (PBR + clip Rijden) voor Quick Look
```

- `delen_jeep.py` bevat de maten (schaal 2,2105, assen, MG-draaipunt, monding) en de maskers waarmee de delen uit de voxelschil worden gesneden.
- Spelassen: x = breedte (rechts = +x), voorkant = +Y in Blender (-Z in Godot), 1 eenheid = 1 m, grond op z = 0, oorsprong midden tussen de assen.
- De bestuurder en de schutter komen uit `assets/jeep.glb` (de jeep van de speler) en worden in vijandkleuren gezet (uniform 8c7b52, helm 5b6038), de bestuurder rechts op de voorbank, de schutter achter het MG.
- Clips (24 beelden/s): Rijden (1,0 s, wielen), Sturen (2,0 s, voorwielen), Vuren (4 beelden, MG-terugslag). In het spel stuurt Godot wielen, sturen en MG zelf (`scripts/vijand_jeep.gd`).
- De `.blend`, de brontexturen en de `.usdz`-preview staan in de projectbibliotheek: `/mnt/project-files/modellen/vijand-jeep/`.
