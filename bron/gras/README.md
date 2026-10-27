# Blender grass — three heights, four variants each

`python3 tools/build_grass_textures.py` creates original procedural 2048×2048 PBR
maps with blade veins, root/tip gradients and controlled dry edges. No source
image is enlarged; these are authored procedural maps, not claimed photographs.

`blender --background --threads 4 --python bron/gras/maak_gras.py` creates the
editable packed `gras.blend` and exports three families × three geometric LODs.
Each GLB contains four individual tuft variants with a root pivot at ground level.
All blades are tapered, folded and curved geometry; no crossed alpha cards.

Short: 10–25 cm. Medium: 35–65 cm. Tall: 90–140 cm (approximate leaf ranges,
without the small deterministic runtime size variation). LODs retain the same
seeded blade shapes and root positions while reducing blades and segments.

Wind is a shared Godot shader using the existing wind menu, not a fake GLB clip.
The web viewer labels this distinction. Tall grass zones are preparation only;
no AI, prone or concealment behavior is added in this asset round.
