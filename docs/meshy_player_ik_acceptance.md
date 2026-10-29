# Meshy player two-hand IK acceptance

Branch: `feature/player-high-poly-proof-1`
Godot: 4.7.2
Rig: Meshy/Mixamo, 28 bones

## Root cause

The previous `0.444 m` right-hand and `0.738 m` left-hand readings were sampled from the hand pose outside `SkeletonModifier3D.modification_processed`. Those values represented the pose before Godot applied the `SkeletonIK3D` result. Godot's final modifier pose must be sampled in `modification_processed`; the earlier integration test used a stale pose reading and incorrectly reported an IK failure.

No change to the Meshy or DEF rig was needed. The existing modifiers are children of the Meshy's `Skeleton3D`, use the `mixamorig_*Shoulder` through `mixamorig_*Hand` chains, are active at influence `1.0`, and run in idle process mode (`1`). Their `modification_processed` signals fire. The prior grip targets and adapter did not create a feedback loop: the right grip target is an actor-space marker, while the left grip is a marker on the weapon model.

## Measured results

The Godot integration test freezes animation, stops IK, moves each target `15 cm` from the measured hand position, restarts the modifiers, and samples the final bone poses in their signals.

| Phase | Right hand error | Left hand error |
| --- | ---: | ---: |
| Configured Garand hold | 0.48 mm | 7.29 mm |
| 15 cm reachable-target probe | 0.46 mm | 0.76 mm |
| Idle | 0.49 mm | 7.34 mm |
| Walking | 13.48 mm | 2.03 mm |
| Running | 1.42 mm | 0.30 mm |
| RunFast | 0.72 mm | 1.25 mm |
| Aiming direction change | Pass, both under 30 mm | Pass, both under 30 mm |
| Garand shot/recoil | 3.72 mm | 6.67 mm |
| Reload interaction target | — | 3.73 mm |

Both hands moved approximately `150 mm` in the reachable-target probe. The support hand traveled `84.4 mm` toward the magazine during reload. All tested stable grip phases satisfy the `30 mm` acceptance limit.

## Combat and regression checks

- The existing player combat path hit the test target: health changed from `100` to `16`; ammo changed from `5` to `4`; the existing reload path refilled the Garand magazine.
- `tests/soldaat_vq2_test.gd` completed with `SOLDAAT VQ2 TEST OK`; the old 53-bone DEF player remains the default and NPC model selection is unchanged.
- Godot 4.7.2 exited with code `0` for `tests/meshy_player_integration_test.tscn` and printed `MESHY_PLAYER_INTEGRATION_RESULT=PASS`.

## Visual proof

`artifacts/meshy_player/previews/Meshy_Player_Garand_Gameplay_Camera.mp4` contains 144 frames at 24 fps, 1600×900, captured with the real `scripts/camera_rig.gd` on an isolated Meshy player and Garand. It shows idle, Walking, Running, RunFast, firing and reload-target motion. The camera preview used Godot's OpenGL Compatibility renderer because Vulkan compute pipeline initialization failed on this iMac's AMD Radeon R9 M395. Compatibility mode does not provide the game's screen-space AA or depth-of-field effects.

This proves the hand constraints and visual grip on the Mac. Xogot/iPhone behavior and performance remain untested.
