# Assault HQ 2.0 — rigging, weapon and gameplay validation

Status: feature branch is being prepared for the user to review and merge. No merge or OTA publication has been performed.

## Source and rig

- Original appearance: `source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb`.
- Source SHA-256: `4a730abf9e1bdfe38496e09d51a269ec99ffad07b6fdfbb82e558c511ee92803` (127,543,360 bytes). The source is kept locally and is not tracked in Git.
- Rig source: `assets/meshy_jungle_commando.glb`, the existing 28-bone Mixamo skeleton. The player model was read only as the technical source; no player mesh parts or appearance are in the Assault GLB.
- The new body keeps its own Meshy geometry, camouflage and PBR material. Blender's spatial nearest-four weight transfer created up to four normalized influences per vertex. The detached Meshy rifle was removed from the weighted body and exported as a rigid prop with hand, muzzle, sight, magazine and casing anchors.
- The rigged high-poly export contains 1,777,586 body vertices / 3,296,450 body triangles and is retained only under the local source-assets directory. It is not part of the runtime patch.

## Meshy rifle and combat integration

The Meshy rifle is the only visible rifle. `WeaponModelAdapter.configure_existing_meshy()` reparents it as a rigid prop; the M1 Garand model is not drawn alongside it. The existing Garand combat route supplies the enemy projectile type, rifle damage/balance, sounds, tracers and casing behavior. The projectile spawns at the Meshy muzzle anchor.

The Assault starts with the existing Garand magazine capacity of eight and uses its 1.9-second reload timing. On an empty magazine the current enemy AI starts the reload action, moves the left hand to the Meshy magazine, then refills. The ordinary enemy hit and death paths remain in use. The first wave includes an Assault.

## Runtime asset

`assets/enemies/assault/assault_meshy_hq2_runtime.glb` is 3,601,088 bytes (3.43 MiB), SHA-256 `b51a006bc3b4d44f95cfb0c6b7ce9afc97a3aa5865973120dc5062339cd0cb69`. It contains one shared PBR material, 2K base-color and normal maps, and a 1K ORM map.

| Level | Body triangles | Rifle triangles | Total triangles |
| --- | ---: | ---: | ---: |
| LOD0, near | 11,999 | 1,800 | 13,799 |
| LOD1, mid | 3,500 | 700 | 4,200 |
| LOD2, far | 1,400 | 300 | 1,700 |

Godot selects LOD0 to 18 m, LOD1 from 18 to 36 m, and LOD2 beyond 36 m. Blender Decimate retained the original UVs and texture detail; this pass did not include hand retopology or a new normal-map bake.

## Animations

The two existing libraries provide 13 additional clips and 62 retargeted Meshy API clips (75 unique source clips). The Assault exposes all 75 through the clip-inspection hook. Godot checked that every track references a bone in its 28-bone skeleton (0 bad paths).

Full-loop hand-IK checks passed for `Combat_Stance`, `Cautious_Crouch_Walk_Forward`, `Run_and_Shoot`, `Walk_Backward_with_Gun`, `Walk_Left_with_Gun`, `Rifle_Charge_inplace`, `Cautious_Crouch_Walk_Left`, `Cautious_Crouch_Walk_Right_inplace`, and `Crouch_Walk_Left_with_Gun`. The Assault AI currently uses:

- Standing and stationary firing: `Combat_Stance`.
- Walking toward its target: `Cautious_Crouch_Walk_Forward`.
- Running: `Run_and_Shoot`.
- Reload: existing generated hand-to-magazine action, paired with the Garand reload timer.
- Hit and death: existing retargeted hit/death clips; the gameplay test exercised `dood2` to completion.

`Rifle_Aim_Turn_Right`, `Combat_Idle_Turn_Left`, `Walk_Forward_While_Shooting`, and `Walk_Backward_While_Shooting` are present and inspectable, but their authored left-hand positions do not fit the detached Meshy rifle throughout the clip. They are not selected for Assault gameplay. The stationary combat stance is the tested aim-ready pose. The existing AI does not request backward or side-step animation from its `_animate()` path; `Walk_Backward_with_Gun` and `Walk_Left_with_Gun` remain available for inspection.

## Tests run locally

Local engine available here: Godot 4.6.3 headless and Blender 4.3.2. The requested Godot 4.7.2 runtime was not installed locally; the branch's remote iOS CI will validate with the repository workflow's Godot/Xcode setup. Local tests do not establish on-device iPhone performance.

- Blender rig/export and runtime LOD build completed. Final GLB imported in Godot and passed the rig/skin/LOD/material validator.
- `tools/enemy_assault/test_animation_clips.gd`: 75 clips inspectable, 0 invalid bone tracks; full-cycle IK tests for gameplay-compatible clips passed. Maximum tested hand error on selected locomotion clips was under 1.2 cm.
- `tests/assault_weapon_test.tscn`: checked all six LOD meshes, a single separate Meshy rifle, forward-facing muzzle, right/left hand IK, actual projectile damage to the player, recoil, eight-round ammo, reload hand motion/refill, Assault hit damage and complete death animation.
- `tests/assault_type_test.gd`: checked Assault identity, first-wave inclusion, standard rifle balance and Garand magazine capacity.
- `tests/meshy_player_integration_test.tscn`: rerun after isolating Assault changes; the existing Meshy player, AnimationTree, IK and M1911 slide test passed. The test still reports the known prone-reload grip limitation on the standing Garand anchors.
- `tests/smoke_test.gd`: simulated the first wave for 150 game seconds without a script crash; an Assault spawned and advanced from the distant edge into combat. The harness stopped at its frame limit while the game was still in `play`, so it did not complete a full game-over flow.
- Blender captures were regenerated from the final runtime GLB and are two camera views of the Meshy rifle in the IK-held ready pose. They are not an iPhone or Godot gameplay screenshot.

No native iPhone FPS, minimum FPS, 1%-low, P99, draw-call or memory measurements are available. Those require testing the merged update on the iPhone 18 Pro Max. Remote CI on the final pushed commit is still required before the PR is marked ready to merge.

## Capture files

- `captures/capture_meshy_weapon_grip_front.png`
- `captures/capture_meshy_weapon_grip_side.png`

## Reproduction

With the original GLB available locally:

```sh
blender -b --python tools/enemy_assault/rig_enemy_assault.py -- source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb source_assets/enemy_assault/rig_test/enemy_assault_meshy_weapon_rigged_test.glb
blender -b --python tools/enemy_assault/build_assault_mobile_lods.py -- source_assets/enemy_assault/rig_test/enemy_assault_meshy_weapon_rigged_test.glb assets/enemies/assault/assault_meshy_hq2_runtime.glb
blender -b --python tools/enemy_assault/capture_meshy_weapon_blender.py -- assets/enemies/assault/assault_meshy_hq2_runtime.glb docs/enemy_assault_hq2/captures
godot --headless --path . -s tools/enemy_assault/validate_rig.gd
godot --headless --path . -s tools/enemy_assault/test_animation_clips.gd
godot --headless --path . res://tests/assault_weapon_test.tscn
```
