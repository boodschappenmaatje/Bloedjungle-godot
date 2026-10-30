# M1911A1 Ultimate Realism — implementation status

Implemented in this branch: original CC0 firing recording retained and derived into a mono gameplay sample; M1911 routes through that sample with narrow pitch variation; M1911 rate is 0.26 s and base damage remains 26; base magazine capacity is seven and the legacy magazine upgrade cannot increase physical capacity; M1911 trigger is edge-triggered so holding the fire input does not continuously fire. Other weapon sound routes remain unchanged.

Not complete: explicit magazine-plus-chamber state and save migration (current legacy ammo integer remains); assisted semi-auto, reload timing split/event markers, separately animated magazine/hammer/trigger, mechanistic audio sources, functional test zone, visual/A-B evidence and native iPhone measurements. Supplied FBX is preserved but not exported into the game pending rig/material comparison. Historical appearance has not received independent review.

Mechanical sound verification: NOT VERIFIED; no licensed mechanical source was supplied. Physical iPhone FPS / 1%-low / p99: NOT RUN.

## Continued verification and implementation delta
- Godot 4.6.3 editor import completed successfully (ObjectDB leak warning at shutdown).
- `tests/meshy_player_integration_test.tscn`: PASS. Existing prone reload IK limitation is reported by test output (`BLOCKED_STANDING_GARAND_ANCHORS_DO_NOT_MATCH_PRONE_POSE`); overall test passes.
- Added an initial runtime chamber/magazine representation in Player. Legacy loaded integer translates to chamber + remaining magazine (maximum 8); after a shot the next magazine round is chambered, and reload completes as 7+1 when retaining chamber or 6+1 when empty. This is not yet a durable independent save schema or a tested complete reload transaction.
- Additional regressions run after chamber-state integration: `tests/wapen_clips_test.gd --fixed-fps 60` PASS; `tests/combat_visuals_test.gd --fixed-fps 60` PASS; `tests/loadout_test.gd` PASS; `tests/auto_raken_test.gd --fixed-fps 60` PASS, 672/672 hit cases (all six weapons). Godot emitted ObjectDB/resource-leak warnings at exit; these tests did not fail on them.

## Latest implementation and source inspection
- M1911 state stores `mag_rounds` and `chambered` in existing `Game.owned.m1911`, mirroring legacy `ammo`. Older records migrate loaded total (clamped 0–8) once; weapon switching restores physical fields. The project has no serialized run-save for `Game.owned`, so app/session persistence is not claimed.
- HUD displays `magazine+chamber | 7`; reload affordance checks physical magazine state.
- Blender 4.3.2 inspection: supplied FBX contains one 580,054-vertex mesh named `Mesh_0`, no armature, and no separate slide/hammer/trigger/magazine objects. Current GLB has `M1911` (14,972 vertices) and separately animated `M1911_Slede` (10,189 vertices), plus an 8-vertex helper. GLB is the practical optimized/animated foundation. FBX safe part-splitting and player-rig mapping requires dedicated modeling and visual review; no guessed geometry was added.

## Reload transaction work
- Reload now has explicit elapsed phases for `mag_out` (28%), `mag_in` (68%), and empty-slede `slide_release` (92%). A magazine is committed at mag-in; interruption before that event does not create rounds. Empty reload chambers one from the new seven-round magazine at completion (6+1); tactical reload preserves an existing chamber round and yields 7+1.
- HUD reload affordance uses magazine count rather than total loaded rounds.
- Temporary mechanical event hooks currently map to existing procedural click/reload sounds only; they are scaffolding, not licensed authentic recordings. Existing shared reload animation still lacks keyed event tracks, so timing is phase-based and approximate.
- Validation after these changes: Godot editor import completed; Meshy integration test PASS. Full regressions from prior commit remain recorded above; reload interruption/state matrix tests have NOT yet been authored.

## Remaining execution checklist (resume here)
- [x] M1911-specific shot sample path and provenance.
- [x] Strict semi-auto trigger edge and legacy ammo migration to physical runtime fields.
- [x] Seven-round capacity cap and 7+1 HUD representation.
- [x] Reload phase/event scaffolding with no magazine fill before mag-in; empty reload chambers one round.
- [x] Standalone test-zone scene/script with live fire/reload/empty-lock controls, stance cycling, semi-auto hold assist toggle, real/procedural audio A/B, volume control, instantaneous FPS and rolling avg/1%-low/p99 frametime display.
- [x] Source geometry inspection; keep current optimized GLB because the FBX is one dense, unrigged mesh.
- [ ] Automated M1911 ammo-state/reload interruption/save-load matrix; current project has no general persistent run-save.
- [ ] Actual sound event-to-animation key tracks and independently licensed mechanism recordings.
- [ ] Separate mechanically accurate hammer, trigger and removable magazine meshes; source FBX has no part boundaries.
- [ ] Prone reload IK correction (the test exposes large errors for the existing Prone_Reload pose).
- [ ] Target range/test enemies and repeatable A/B visual captures in the test zone.
- [ ] Native iPhone 18 Pro Max touch/performance/audio measurements; no device is attached to this environment.

The new test zone is a Godot runnable scene at `scenes/m1911_test_zone.tscn`; it is not wired into the production menu. It launches the actual main scene and adds an opt-in test overlay. Godot headless scene-start check passed; an interactive visual/hardware run was not possible here.
