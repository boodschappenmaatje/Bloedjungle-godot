# AAA Meshy Commando Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an original, visibly upgraded player-only jungle commando whose movement and weapon handling hold up in the native iPhone game for all six playable weapons.

**Architecture:** Preserve the current 28-bone Meshy/Mixamo rig and `SoldierModel` interface. Repair the locomotion state transition first, then curate and retarget existing Meshy motion before buying new API actions. Build a separate player-only Blender source and optimized GLB on that rig; Godot keeps control of movement, weapon selection and IK.

**Tech Stack:** Godot 4.7.2/GDScript, Blender 4.5+ Python, glTF/GLB, PBR, USDZ, existing Three.js VQ2 viewer, Meshy CLI 0.8.5 for free catalog/balance and only approved paid jobs.

**Spec:** `docs/superpowers/specs/2026-11-11-aaa-meshy-commando-design.md`

**Implementation status (11 November 2026):** The Blender source, new GLB, six-weapon profiles, focused tests, browser comparison and USDZ are built. Sprint foot drift, native iPhone validation and real gamecamera capture remain open; see `docs/meshy_commando_motion_review.md`. No new paid Meshy task has been submitted.

## Global Constraints

- Original design; visible face, compact helmet/headset, Tiger Stripe uniform, matte olive vest, radio, plausible loadout.
- Player only: do not change ally/enemy models, gameplay speed/damage/stamina/colliders or input.
- Keep the 28-bone rig, existing `SoldierModel` interface, six weapons and 13+62 existing animations usable.
- Native iPhone is the performance acceptance environment; report **NIET GETEST** without a real device measurement.
- New paid Meshy tasks require an exact action list and credit estimate before submission. Submit each task only once.
- Work on this feature branch and a Draft PR; no merge or OTA publication without separate user authorization.

## Review Focus

1. Stop while a sprint frame has one leg forward: `tests/meshy_commando_transition_test.gd` checks both legs return to idle during sustained fire.
2. Release fire and immediately move again: the same test checks the base clip resumes and never remains on a one-shot fire clip.
3. Switch weapons while moving or reloading: `tests/meshy_commando_weapons_test.gd` checks all six grips and valid animation state after the switch.
4. Fast reverse/strafe into fire: `tests/meshy_commando_transition_test.gd` checks no reversed clip or leftover root translation persists.
5. Missing new GLB in an older OTA app: `tests/speler_zichtbaar_test.gd` checks existing fallback still creates a visible player.

---

### Task 1: Full-body idle and transition regression

**Files:** Modify `scripts/soldier_model.gd` (`_add_meshy_idle`, `_play_meshy_clip` only as evidence requires); create `tests/meshy_commando_transition_test.gd`.

**Interfaces:** `SoldierModel.play(clip: String, blend := 0.18, speed := 1.0)` remains unchanged. The test creates the real Meshy player from `scenes/player.tscn` and drives `Game.move`/`Game.fire` through physics frames.

- [ ] Write a failing transition test: run, sprint, stop and hold fire; assert idle clip is selected, both leg bones approach the standing pose, the body stays at the controller's position, and fire release/move resumes a locomotion clip.
- [ ] Run with Godot 4.7.2 to establish the failure; record 4.6.3 incompatibility separately if the local binary cannot import the project.
- [ ] Make idle contain a complete rig pose, with a neutral leg/hip rest and subtle upper-body motion, and make the run→idle blend resolve all affected tracks.
- [ ] Re-run the focused test plus `tests/meshy_player_integration_test.tscn` and `tests/meshy_player_stance_test.tscn`; commit.

### Task 2: Curate movement and blend quality

**Files:** Modify `scripts/soldier_model.gd` and, only if needed, `scripts/player.gd`; add a versioned motion selection/retarget script under `bron/meshy_speler_animaties/`; extend `tests/meshy_commando_transition_test.gd`; create `docs/meshy_commando_motion_review.md`.

**Interfaces:** Preserve `play` and clip names (`stil`, `lopen`, `rennen`, `sprinten`, `achteruit`). Any new animation resource remains player-only under `resources/animations/`.

- [ ] Capture current walk/run/sprint/strafe, stop and fire from the gamecamera; record clip, foot contact, arm grip and visible defects.
- [ ] Test the existing 62 API clips against those defects; choose the best matching tactical cycles and retarget them on the current rig without horizontal root motion.
- [ ] If a required action is absent, query Meshy's catalog and balance, list the exact missing actions and cost, then request the required paid-task decision before creating anything.
- [ ] Add tests for starting/stopping, reverse/strafe and residual root motion; make the failing behavior visible in the gamecamera.
- [ ] Adjust clip choice, transition timing and foot/contact cleanup one issue at a time; rerun focused tests and compare before/after frames; commit.

### Task 3: Weapon-specific animation for all six weapons

**Files:** Modify `scripts/soldier_model.gd`, `scripts/weapon_model_adapter.gd` and only the affected weapon profiles in `resources/weapon_profiles/`; create `tests/meshy_commando_weapons_test.gd`; extend motion review.

**Interfaces:** Reuse `SoldierModel.set_gun(kind: String)`, `set_shoot_pose(active: bool, weapon: String, rate: float)` and existing weapon profiles. The six tested IDs are `m1911`, `thompson`, `garand`, `trench`, `mg42`, `bazooka`.

- [ ] Create a failing test that exercises each weapon in idle, walk, run, stop→shoot, reload and resume, and checks hands/anchors and current clip without changing damage or ammo.
- [ ] Compare the actual six-weapon gameplay-camera captures; list where existing IK and action tracks fail.
- [ ] Correct mounts and upper-body motion per weapon; use only compatible existing Meshy actions or approved new actions, and preserve per-weapon reload and recoil timing.
- [ ] Run the focused test plus existing weapon and Meshy integration tests; commit.

### Task 4: Player-only high-quality visual asset

**Files:** Create `bron/meshy_commando/README.md`, design/production script, editable `.blend`, PBR sources and export receipt; create an optimized player GLB in `assets/`; modify `scripts/soldier_model.gd` to select it for `soldaat = meshy` with the old GLB as fallback.

**Interfaces:** The new GLB retains the exact Mixamo skeleton/bone hierarchy and root scale. Existing weapon adapters, animation libraries and player node contracts continue to resolve.

- [ ] Establish reference images of the current Meshy player and accepted Tiger Stripe/olive materials from identical close-up and gamecamera views.
- [ ] Build the visible-faced high-cut helmet, single-ear headset, Tiger Stripe clothing, olive vest, rear radio and restrained equipment in Blender on the existing rig; keep joint clearance and PBR maps.
- [ ] Export editable source, optimized GLB and asset receipt; compare actual bone names/rest, skinning, textures, triangle/material budgets, and six-weapon intersections against the original.
- [ ] Add the GLB to Godot behind the existing Meshy selection with fallback; run model import and player/weapon regression tests; commit.

### Task 5: Viewer, iPhone preview and integrated acceptance

**Files:** Modify `tools/blender-vq2-viewer/` selector/manifest/build and relevant viewer test; create USDZ and renders in the project's preview output; update `bron/meshy_commando/README.md`.

**Interfaces:** The viewer exposes the old and new real GLBs with shared camera and clip playback; Godot integration remains the source of truth for IK and controller transitions.

- [ ] Add before/after 360°, gameplay angle and genuine clip playback; run viewer checks.
- [ ] Export USDZ from the new Blender source and validate package/materials, recording the limits of untested iPhone Quick Look.
- [ ] Capture the complete six-weapon sequence with the real gamecamera and check that the recorded stuck-running pose no longer occurs.
- [ ] Run targeted Godot import/regression tests, compare render and memory/performance observations, and mark physical native iPhone checks **NIET GETEST** until Dennis tests the Draft PR/authorized OTA route.
- [ ] Publish the feature branch and open a Draft PR, report exactly what was tested and what awaits iPhone validation; do not merge or publish OTA.
