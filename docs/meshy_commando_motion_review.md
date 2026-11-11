# Meshy commando: motion review (11 November 2026)

## Source and decisions

The user's iPhone screen recording shows stationary fire retaining a running leg pose after a sprint. `SoldierModel._add_meshy_idle()` previously keyed only Spine2, Neck and Head. It now keys the entire skeleton, so the stopped player returns both legs to neutral during sustained fire. `tests/meshy_commando_transition_test.gd` reproduces the run → stop → fire → move sequence and passes on Godot 4.7.2.

The 13 app clips and 62 previously purchased Meshy API clips were reviewed. `Walking`, `Running`, and `RunFast` remain the base forward cycles. The API `Walk_Forward_While_Shooting` has an upright, floating step; `Walk_Left_with_Gun` has a deep, hopping crouch; `Combat_Stance` leaves the feet staggered about 0.6 m apart. Those are unsuitable as neutral locomotion or idle. The game continues to strip horizontal root translation; Godot owns movement. The new `MeshyLegPose` modifier turns the hips toward strafe travel while counter-rotating the torso to preserve aim. It returns to zero at idle, sprint, reload and roll.

Foot contact remains a visible limitation. In a local controller test, median absolute planted-foot drift was approximately **0.89 m/s walking**, **1.29 m/s running**, and **2.03 m/s sprinting**. Speeding up the sprint clip to 1.25× or 1.45× made absolute drift worse, so no tempo change was retained. The measurements are from headless Godot bone positions, not a native iPhone visual or FPS check. A dedicated authored sprint or foot locking pass is still needed before calling the locomotion AAA quality.

## Six weapons

`tests/meshy_commando_weapons_test.gd` switches M1911, Thompson, Garand, Trench, MG42 and Bazooka through idle, run, stationary fire, walk, reload and run. Both hands remain within 4 cm of their grips. Four long guns now use explicit profiles. In particular, the Thompson muzzle had been **0.485 m** ahead of the barrel; the Trench muzzle was **0.17 m** ahead. New markers align to the actual imported mesh bounds. The existing recoil and reload timing remain controlled by Godot.

## Optional Meshy motion purchase

The already owned API library has no convincing planted-foot tactical sprint for this controller. The smallest paid experiment would be **one 3-second prime Text to Motion tactical sprint**, followed by **one Animation retarget** to the existing Meshy rig task `01a18b88-1709-77cf-bce7-e580117991cb`. The [Meshy price list](https://docs.meshy.ai/api/pricing.md), checked 11 November 2026, quotes **10 + 3 = 13 credits**; the available balance was **25 credits**. A second prime walk costs another 13 credits, exceeding that balance by one. A swift motion costs 3 + 3 credits but may be unsuitable for hero animation. No new paid task was submitted. The generated motion would still need retargeting from the API's 24-bone rig to the game's 28-bone rig and visual/foot-contact acceptance; purchase alone is no guarantee of better movement.

## Verification limits

Headless Godot 4.7.2: transition and six-weapon tests pass. Browser viewer: actual GLB and its Walking, Running, RunFast clips load in Chromium software WebGL. Native iPhone gameplay, frame time, touch and Quick Look: **NIET GETEST**. The broad legacy viewer test currently times out at its initial `kazerne` readiness check; the focused commando viewer test passes.
