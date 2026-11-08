# M-47 Photoreal Impact Hero Still 5.1

This directory contains one Blender Cycles still of the approved M-47 striking a concrete wall. It does not add an animation, video, Godot conversion, or gameplay integration.

## Deliverables

- `blender/M47_Impact_Hero_5_1.blend` — the shot scene.
- `blender/build_impact_still.py` — batch scene construction and one-frame render.
- `blender/make_comparison.py` — crops impact panel 4 from the supplied storyboard and lays it beside the final render.
- `renders/M47_Impact_Hero_Cycles.png` — the single full-resolution render for review.
- `renders/impact_vs_target.png` — direct target-panel comparison.
- `REPORT.md` and `render_metrics.json` — visual review and render/source metadata.
- `logs/cycles_impact_final.log` — Blender batch log.
- `logs/blender_saved_scene_validation.log` — reopen check for the saved scene, M-47 mesh counts, actions, and packed images.

## Reproduction

Use the official Blender 4.3.2 build with OpenImageDenoise support, from the repository root:

```sh
blender -b -t 4 --python tests/m47_photoreal_vfx5_1/blender/build_impact_still.py
python3 tests/m47_photoreal_vfx5_1/blender/make_comparison.py
```

The build script reuses the existing Photoreal Cinematic 5.0 scene-building code and project-owned PBR materials. It reads `docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb` without editing its mesh or materials. `assets/` is a relative link to the already-approved CC0 foliage assets in the 5.0 branch.

## Render settings

Cycles CPU, 1920×1080, 96 samples, OpenImageDenoise, AgX Medium High Contrast. The saved scene is frame 122, the existing cinematic's impact moment.
