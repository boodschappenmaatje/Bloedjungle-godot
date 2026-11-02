# Assault HQ 2.0 — first rigging test

Status: rigged test GLB exported and imported by Godot; this is **not yet animation-approved**.

## Inputs and outputs

- Enemy source: `source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb`
- Source checksum: SHA-256 `4a730abf9e1bdfe38496e09d51a269ec99ffad07b6fdfbb82e558c511ee92803`
- Rig source: `assets/meshy_jungle_commando.glb`
- Output: `source_assets/enemy_assault/rig_test/enemy_assault_rigged_test.glb`
- Output size: 164,784,064 bytes (HQ texture maps retained)
- Output SHA-256: `00a722d5940974c3bbc408ce9dd2e443e7f8b9b5a2ee9bdbd0969989d69fcb8e`

## Build and static checks

- Blender 4.3.2 executed `tools/enemy_assault/rig_enemy_assault.py` successfully.
- Original enemy mesh is retained: 1,861,582 vertices / 3,454,896 triangles.
- One enemy mesh, 28 named Mixamo bones, 28 vertex groups; all mesh vertices have skin weights.
- Vertex weights were copied from the existing skinned player mesh by nearest spatial proxy sample, normalized and quantized in 1/32 increments. The script never exports player geometry.
- Enemy body was foot-aligned to the Mixamo armature (source body centered at Z=0; body offset +0.952 m).
- Godot 4.6.3 headless resource check passed: one Skeleton3D, one MeshInstance3D with Skin, 28 bones. The skeleton node is named `target_character/Skeleton3D`, matching the existing animation track paths.
- Blender warned that Draco compression is unavailable and that multiple shader image nodes reference texture slots. Export succeeded; Draco compression was not required.

## Visual pose review

Captures are Blender Workbench renders: `capture_neutral.png` and `capture_aim_test.png`. They use the actual exported GLB. The aim image uses manually rotated arm bones, not a named production animation clip.

The original static appearance is recognizable, but the synthetic arm pose shows stretched artifacts around the rifle/forearm. The rifle and other equipment are part of the single source mesh and nearest-surface weight transfer does not yet provide acceptable deformation for those pieces. This output is a rigging test, **not validated for walk, aim, or death clips**. Godot test `tools/enemy_assault/test_animation_clips.gd` loaded the existing library and played `Walking`, `Rifle_Aim_Turn_Right`, and `dying_backwards`. Each clip has 26 tracks, all resolved after correcting the exported node name and AnimationPlayer root path; each changed the skeleton pose. Godot emitted no unresolved-track warnings in the passing run. This confirms track compatibility and playback, but does not certify visual deformation over the full clips. The synthetic Blender arm pose still shows stretched artifacts around the rifle/forearm. Do not integrate this GLB into gameplay yet.

## Reproduction

```sh
blender -b --python tools/enemy_assault/rig_enemy_assault.py
godot --headless --path . --script res://tools/enemy_assault/validate_rig.gd
blender -b --python tools/enemy_assault/capture_rig_poses.py
godot --headless --path . --script res://tools/enemy_assault/test_animation_clips.gd
```

## Current gameplay handoff

The rig test remains outside the gameplay scene. It is 164,784,064 bytes and has not been optimized for mobile. The current isolated test confirms clip tracks and bone movement only; weapon/muzzle alignment, enemy firing, hit/death visuals, AI behavior, and wave spawn are not yet integrated or validated.
