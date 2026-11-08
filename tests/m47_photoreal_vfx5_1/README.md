# M-47 Photoreal Impact Hero Still 5.1 / 5.2

This directory contains the original 5.1 impact still and its 5.2 refinement. The latter is one Blender Cycles still of the approved M-47 striking a concrete wall. No animation, video, Godot conversion, or gameplay integration is included.

## Deliverables

- `blender/M47_Impact_Hero_5_1.blend` — the shot scene.
- `blender/build_impact_still.py` — batch scene construction and one-frame render.
- `blender/make_comparison.py` — crops impact panel 4 from the supplied storyboard and lays it beside the final render.
- `renders/M47_Impact_Hero_Cycles.png` — the original 5.1 full-resolution render.
- `renders/impact_vs_target.png` — direct target-panel comparison.
- `renders/M47_Impact_Hero_Cycles_5_2.png` — revised impact still, 1920×1080.
- `renders/impact_5_1_5_2_vs_target.png` — target, 5.1, and 5.2 at the same impact crop.
- `blender/M47_Impact_Hero_5_2.blend` — refined Blender scene, based on the 5.1 scene.
- `blender/refine_impact_still_5_2.py` — batch refinement and Cycles render.
- `blender/validate_scene_5_2.py` and `logs/blender_scene_validation_5_2.log` — saved-scene reopen and asset checks.
- `REPORT_5_2.md`, `render_metrics_5_2.json`, and `logs/cycles_impact_5_2.log` — 5.2 review and render evidence.
- `REPORT.md` and `render_metrics.json` — visual review and render/source metadata.
- `logs/cycles_impact_final.log` — Blender batch log.
- `logs/blender_saved_scene_validation.log` — reopen check for the saved scene, M-47 mesh counts, actions, and packed images.

## Reproduction

Use the official Blender 4.3.2 build with OpenImageDenoise support, from the repository root:

```sh
blender -b -t 4 --python tests/m47_photoreal_vfx5_1/blender/build_impact_still.py
python3 tests/m47_photoreal_vfx5_1/blender/make_comparison.py
blender -b -t 3 --python tests/m47_photoreal_vfx5_1/blender/refine_impact_still_5_2.py
python3 tests/m47_photoreal_vfx5_1/blender/make_comparison_5_2.py
```

The 5.1 build script reuses the existing Photoreal Cinematic 5.0 scene-building code and project-owned PBR materials. The 5.2 refinement loads that saved `.blend` and adds a weathered concrete facade, fine fracture debris, turbulent volume smoke, layered plasma, and more project foliage. Both workflows read `docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb` without editing its mesh or materials. `assets/` is a relative link to the already-approved CC0 foliage assets in the 5.0 branch.

## Render settings

The 5.1 reference uses Cycles CPU at 1920×1080 and 96 samples. The 5.2 refinement uses Cycles CPU at 1920×1080 and 80 samples with OpenImageDenoise and AgX Medium High Contrast. Both scenes use frame 122, the existing cinematic's impact moment.
