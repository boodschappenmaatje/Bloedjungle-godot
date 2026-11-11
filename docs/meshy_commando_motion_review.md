# Meshy commando: motion review (11 November 2026)

## Source and decisions

The user's iPhone screen recording shows stationary fire retaining a running leg pose after a sprint. `SoldierModel._add_meshy_idle()` previously keyed only Spine2, Neck and Head. It now keys the entire skeleton, so the stopped player returns both legs to neutral during sustained fire. `tests/meshy_commando_transition_test.gd` reproduces the run → stop → fire → move sequence and passes on Godot 4.7.2.

The 13 app clips and 62 previously purchased Meshy API clips were reviewed. `Walking`, `Running`, and `RunFast` remain the base forward cycles. The API `Walk_Forward_While_Shooting` has an upright, floating step; `Walk_Left_with_Gun` has a deep, hopping crouch; `Combat_Stance` leaves the feet staggered about 0.6 m apart. Those are unsuitable as neutral locomotion or idle. The game continues to strip horizontal root translation; Godot owns movement. The new `MeshyLegPose` modifier turns the hips toward strafe travel while counter-rotating the torso to preserve aim. It returns to zero at idle, sprint, reload and roll.

Foot contact remains a visible limitation. In a local controller test, median absolute planted-foot drift was approximately **0.89 m/s walking**, **1.29 m/s running**, and **2.03 m/s sprinting**. Speeding up the sprint clip to 1.25× or 1.45× made absolute drift worse, so no tempo change was retained. The measurements are from headless Godot bone positions, not a native iPhone visual or FPS check. A dedicated authored sprint or foot locking pass is still needed before calling the locomotion AAA quality.

## Six weapons

`tests/meshy_commando_weapons_test.gd` switches M1911, Thompson, Garand, Trench, MG42 and Bazooka through idle, run, stationary fire, walk, reload and run. Both hands remain within 4 cm of their grips. Four long guns now use explicit profiles. In particular, the Thompson muzzle had been **0.485 m** ahead of the barrel; the Trench muzzle was **0.17 m** ahead. New markers align to the actual imported mesh bounds. The existing recoil and reload timing remain controlled by Godot.

## Meshy Prime sprint experiment

The user approved one Prime sprint experiment. Meshy generated one 3-second clip and retargeted it to the existing Meshy rig task `01a18b88-1709-77cf-bce7-e580117991cb`:

- Text to Motion task `01a1cc5c-d64e-7085-b3a2-8c53ec3de8c9`: **SUCCEEDED**, 10 credits.
- Animation retarget task `01a1cc5d-62fb-711a-8382-27f6740ce364`: **SUCCEEDED**, 3 credits.
- Total charged: **13 credits**. Balance afterwards: **12 credits**.
- Source FBX: `bron/meshy_commando/prime_sprint_raw/motion.fbx`.
- Meshy retarget GLB: `bron/meshy_commando/prime_sprint_retargeted/animation_glb.glb` (24-bone API rig).
- Game-rig Animation resource: `resources/animations/meshy_commando_prime_sprint.res` (retargeted to 28 bones by `bron/meshy_commando/retarget_prime_sprint.gd`).
- [Browser comparison image](../previews/meshy_commando/prime_sprint_candidate.png) plays the actual Meshy clip next to the original player.

The clip plays and changes the hips on the game rig, but the actual preview shows an excessively folded-forward upper body and lowered head. It is **not** assigned to `sprinten`; the game continues to use `RunFast`. The review-only viewer candidate uses Meshy's 24-bone output and does not represent a game-ready clip. No second generation or retarget was submitted.

The free animation catalog also returned action **509, “Lean Forward Sprint”** (`WalkAndRun/Running`). Its preview looks more upright than this Prime result. Applying a catalog action to the same rig costs **3 credits** according to the [Meshy price list](https://docs.meshy.ai/api/pricing.md), checked 11 November 2026. That additional paid retarget has not been submitted.

## Verification limits

Headless Godot 4.7.2: transition and six-weapon tests pass. Browser viewer: actual GLB and its Walking, Running, RunFast clips load in Chromium software WebGL. Native iPhone gameplay, frame time, touch and Quick Look: **NIET GETEST**. The broad legacy viewer test currently times out at its initial `kazerne` readiness check; the focused commando viewer test passes.
