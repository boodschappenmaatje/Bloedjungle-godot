# Assault HQ 2.0 — first rigging test

Status: rigged test GLB exported and imported by Godot; this is **not yet animation-approved**.

## Inputs and outputs

- Enemy source: `source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb`
- Source checksum: SHA-256 `4a730abf9e1bdfe38496e09d51a269ec99ffad07b6fdfbb82e558c511ee92803`
- Rig source: `assets/meshy_jungle_commando.glb`
- Output: `source_assets/enemy_assault/rig_test/enemy_assault_rigged_test.glb`
- Output size: 164,784,068 bytes (HQ texture maps retained)
- Output SHA-256: `d575d12656a993b1462d8a763fe5e0c5999c6944525b21df879129dad6f8ab37`

## Build and static checks

- Blender 4.3.2 executed `tools/enemy_assault/rig_enemy_assault.py` successfully.
- Original enemy mesh is retained: 1,861,582 vertices / 3,454,896 triangles.
- One enemy mesh, 28 named Mixamo bones, 28 vertex groups; all mesh vertices have skin weights.
- The source mesh has 2,926 disconnected surface islands. 2,694 small islands use one dominant source influence; larger islands use nearest spatial proxy weights, normalized and quantized in 1/32 increments (726,610 vertices). The islands are joined before export. The script never exports player geometry.
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

The rig test remains outside the gameplay scene. It is 164,784,068 bytes and has not been optimized for mobile. The current isolated test confirms clip tracks and bone movement only; weapon/muzzle alignment, enemy firing, hit/death visuals, AI behavior, and wave spawn are not yet integrated or validated.

## Existing Garand hookup test

A second test export removes 79 disconnected front-rifle islands (84,000 vertices) from the Meshy body so the existing Garand can be attached by the game's `WeaponModelAdapter`; the original high-quality source GLB remains untouched. Test body: `enemy_assault_body_rigged_garand_test.glb`, 158,514,924 bytes, SHA-256 `68a8df217eb6881a5c784db7a7843d75109d09c6dd753650cc850071955be4c4`.

The canonical `assault` type now selects this test body when it exists. It uses the shared Meshy animation libraries, Garand adapter, both `SkeletonIK3D` hand chains, existing enemy AI and existing bullet firing path. `tests/assault_weapon_test.tscn` passed: both hand targets were within 6 mm and 3 mm respectively at `modification_processed`, and firing spawned one bullet through the existing path. `tests/ai_test.gd` also passed with assertions for the 28-bone Assault rig, Garand adapter, both IK chains and walk/aim/death clips.

This is still a local test asset, not a release asset. The 158.5 MB GLB is unoptimized, the mesh has not had an in-engine human visual review with the attached Garand, and native iPhone performance is untested. It is intentionally not committed; mobile retopology/texture optimization and final visual review remain required before release.

## Follow-up: arm IK and Assault AI verification

- Re-ran `tests/assault_weapon_test.tscn` on Godot 4.6.3: passed. `SkeletonIK3D.modification_processed` measured 5.4 mm from the right-hand target and 2.5 mm from the left-hand Garand grip; calling the existing `_shoot()` path created one live bullet.
- Re-ran `tests/ai_test.gd`. Its original hand assertion read the Skeleton pose from `SceneTree._process`, before the IK modifier had updated that frame, so it reported stale hand positions. The test now samples from each IK `modification_processed` callback. AI regression passed for cover, retreat/help, flank and staggered gates; during the run, the right and left hand errors measured 1.7 mm and 8.2 mm.
- Re-ran `tests/assault_type_test.gd`: first-wave Assault, class identity, Garand configuration and rifle-equivalent balance passed.
- Re-ran `tools/enemy_assault/validate_rig.gd`: one skinned mesh, one Skeleton3D, 28 bones.
- Re-ran the clip playback check on `enemy_assault_body_rigged_garand_test.glb`: `Walking`, `Rifle_Aim_Turn_Right`, and `dying_backwards` each resolved 26 tracks and changed the skeleton pose.
- Blender 4.3.2 produced `capture_garand_arm_test.png` from the Garand test GLB after applying a synthetic arm pose. This is a grey Workbench rig/weight inspection capture, not a Godot gameplay screenshot or approval of the complete animation deformation.

Remaining gate for this stage: inspect the actual body and attached Garand in an in-engine camera view and review arm/shoulder deformation through the clips. The existing weapon/IK and firing paths are functionally attached, but this unoptimized 158.5 MB candidate is still a local rig test and is not suitable for an OTA release.
