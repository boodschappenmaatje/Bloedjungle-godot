# M-47 Impact Hero Still 5.2 — review

## What changed from 5.1

- Enlarged and brightened the ice-blue impact kernel, with a translucent ion corona and mottled plasma ribbons in place of the flat cyan patches.
- Rebuilt the shock front as one broken, irregular hex arc with a few short plasma flares, reducing the parallel neon-wire look.
- Replaced the visible procedural cell seams with a continuous 2K PBR concrete face around a jagged breach. Added 302 irregular concrete fragments and smaller branching cracks at the aperture.
- Increased the smoke and dust volumes and spread them into a curling wake and a ground-level plume.
- Added more copies of the project's existing PBR ferns and grass, brightened the canopy and wall bounce, and added subtle humid atmospheric scattering.
- Adjusted the impact framing so the strike is larger while the approved M-47 remains visible.

## Direct comparison

`renders/impact_5_1_5_2_vs_target.png` places the supplied target impact panel, the 5.1 render, and the 5.2 render side by side at the same wide impact crop. `renders/M47_Impact_Hero_Cycles_5_2.png` is the new full-resolution still.

The direct comparison shows the brighter core, wider smoke wake, less segmented wall face, and denser green framing clearly against 5.1. It remains short of the target's finish: the core still reads as a smooth, overexposed sphere; energy filaments and cracks remain visibly graphic; the smoke has broad soft billows instead of the target's turbulent detail; and the ground and jungle understory are less richly dressed. The new continuous wall face also reads flatter and more slab-like than the target's irregular masonry. The M-47 and commando remain more visible than in target panel 4, whose crop is tighter. The approved M-47 model was preserved unchanged.

## Render and asset checks

Cycles CPU, 1920×1080, 80 samples, adaptive threshold 0.006, OpenImageDenoise, AgX Medium High Contrast, frame 122. The batch log is `logs/cycles_impact_5_2.log`; metrics and source hashes are in `render_metrics_5_2.json`. The source GLB remains `docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb` with SHA-256 `4031e935c5ef19a96a10257334a3cc99db92410a01389ef708259d887cf89872`.

Only this still and its Blender scene were produced. No video, Godot conversion, gameplay change, merge, or OTA publication was made.
