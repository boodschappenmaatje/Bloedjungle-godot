# M-47 Photoreal Cinematic 5.0

Blender-only Cycles cinematic, built around the approved animated M-47 GLB. The imported GLB source is retained unchanged; the additional energy core, projectile, pressure front, dust and debris are separate scene objects.

## Files

- `blender/M47_Photoreal_Cinematic_5_0.blend` — saved scene, linked CC0 foliage libraries, packed PBR maps, camera animation and VDB domains.
- `blender/build_cinematic.py` — builds the scene and renders the five captures or the full video.
- `blender/finalize_scene.py` — idempotent camera, VFX material and density pass for the baked scene.
- `blender/validate_scene.py` — scene data inspection; writes `build_metrics.json`.
- `blender/cache/` — baked Mantaflow OpenVDB data and noise for projectile smoke and concrete dust.
- `assets/polyhaven/` — linked CC0 tree and fern source libraries plus their texture maps.
- `reference/` — exact target image supplied for this task and its five panel crops.
- `renders/` — five 960×540 Cycles captures, overview, and target comparison board.
- `M47_Photoreal_Cinematic_5_00001-0192.mp4` — 8-second, 24 fps Cycles video (rendering at 8 samples per frame).
- `REPORT.md` — visual comparison, settings, measurements and limitations.

## Rebuild

Run from the repository root with Blender 4.3.2:

```sh
blender -b -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --build
blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --bake
blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/finalize_scene.py
blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --stills
blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --video
```

The `.blend` uses relative links to `assets/polyhaven/` and `blender/cache/`; keep both folders beside the scene. The source build reads the approved M-47 GLB and existing project materials from the repository.
