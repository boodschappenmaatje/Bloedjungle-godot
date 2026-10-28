# Bloedjungle High Quality Showcase bunker

This game asset is the baked game variant produced by the local **Bloedjungle 3D Production Pipeline 1.0 — High Quality Showcase**. The editable authoring file and optimized `.blend` are stored alongside the runtime GLB. The GLB embeds its baked PBR images, so the Godot import does not depend on loose textures.

## Files and source record

- `high_quality/Bloedjungle_Bunker_HQ_Source.blend` — editable 173-mesh source, 37,752 evaluated triangles, High Quality Showcase profile.
- `game_optimized/Bloedjungle_Bunker_Game_Optimized.blend` — separate baked game variant.
- `../tests/bunker/bloedjungle_bunker_hq.glb` — runtime glTF 2.0 asset, 37,928 triangles, 8 materials/surfaces, 4 embedded 2048px PBR images. It keeps the existing Asset Test Zone path so the previously validated Godot import settings remain reusable.
- `textures/` — the pipeline's 2048px base color, normal, roughness, metallic, AO, packed ORM, emission and height source maps; SHA-256 hashes are in `production.json`.
- `pipeline_glb_validation.json` — original pipeline validation receipt.
- `production.json` — source/output hashes and pipeline metadata.

The source `.blend` SHA-256 is `dedb552de6f280a8f1944dfac10d701a2c55f7d7e3ba6dc6d1f0e6afc1889820`. The game `.blend` SHA-256 is `04f71f6b9d267a9fe2e9faa3ce2a38852d4aaa24ec69175a02f701394700ab5f`. The runtime GLB SHA-256 is recorded in `production.json` and recalculated by validation.

To re-export the existing baked model, from the repository root run:

```sh
blender --background --factory-startup \
  assets/bunker/game_optimized/Bloedjungle_Bunker_Game_Optimized.blend \
  --python tools/bunker_hq/export_game_glb.py
  python3 tools/bunker_hq/validate_glb.py assets/tests/bunker/bloedjungle_bunker_hq.glb
```

The scene builder keeps gameplay's original bunker collision and damage script. It scales the visual source footprint to the existing 4.6 × 4.6 m gameplay footprint; the high-quality source is unchanged.
