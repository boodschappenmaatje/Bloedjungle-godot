# Colt M1911A1 — Cinematic Power VFX 1.0 (Draft)

## Baseline findings (repository inspection; not runtime verified)
- Existing `scripts/fx.gd` already handles pooled muzzle flashes (18 max), muzzle smoke (16 max), casing meshes (36 max), transient light pulses (2 max), and material-dependent impacts.
- `scripts/data.gd` already defines the M1911 visual parameters and sound routing. Existing gameplay visual setting: flash life 0.08 s.
- `scripts/sfx.gd` already loads `assets/audio/m1911/m1911_report.wav` with synthetic pistol fallback; do **not** duplicate or replace it without listening A/B.
- `docs/m1911a1/ASSET_PROVENANCE.md` documents the existing CC0 shot source. Other mechanical sounds are not verified.
- Existing `tests/combat_visuals_test.gd` asserts pooled-effect caps.
- The repository contains older M1911 realism work: keep its ammo, timing, and weapon animation behavior untouched.

## Phase 1 — isolated foundation (this PR)
- The optional `assets/vfx/m1911/m1911_flipbook.gdshader` is a reusable 4x4 atlas shader.
- No shader is currently attached to live weapon meshes, so default rendering and gameplay remain unchanged.
- No placeholder sprite is silently treated as final visual art.

## Phase 2 — visual asset production (not yet complete)
- Produce three approved 16-frame (4x4) muzzle-flash variations plus an independent 16-frame smoke atlas (RGBA, premultiplied-alpha convention explicitly checked).
- Avoid repeating the existing burst and glow: replace the M1911-specific visuals at one call site under a dedicated opt-in test switch.
- Align flash plane to firing direction and top-down camera; retain weapon/hand visibility.
- Start at 50–80 ms flash, 300–480 ms smoke, with no persistent point light. Reuse existing casing pool.
- Use existing material-dependent impact entry point, not a second competing impact pipeline.
- Do not assume GPU particles are cheaper than current CPU effects until profiled on iPhone.

## Phase 3 — audio and recoil (not yet complete)
- Keep the existing documented CC0 report. Evaluate optional independently licensed mechanical slide/action sound, without double-playing the existing shot.
- Preserve M1911 damage, ammunition, fire cadence, recoil logic, reload timing, save format, controls and all graphics defaults.
- Use event synchronization with a single shot event rather than an independent firing timer.

## Performance targets (hypotheses until measured)
- Goal: 60 FPS on target iPhone, plus no meaningful 1% low regression.
- Additional GPU frame time target <= 0.30 ms in the same capture; aim <= 8 additional drawcalls.
- Start with <= 2 additive flash quads per shot; <= 8 smoke particles per shot; <= 6 impact spark particles; <= 12 visible player casings in the optional quality path.
- Existing global caps must remain intact; protect against alpha overdraw at top-down zoom.

## Verification requirements before review
1. Run Godot 4.7.2 import and shader compile on the actual Mobile renderer, with a captured shader validation result.
2. Capture A/B frames from identical camera angles: outdoor daylight, dark jungle, close quarters and 80-enemy combat.
3. Verify single fire sound, existing hit detection, ammo/reload, recoil, the existing `combat_visuals_test.gd` and core regressions.
4. Compare frame time, GPU time where available, 1%-low, drawcalls, overdraw and memory on an actual iPhone 18 Pro Max.
5. Verify asset origin and commercial redistribution rights for any newly sourced audio or atlas.

## Release restriction
Draft PR only. Do not merge; do not trigger OTA distribution or change the normal default graphics settings.

## Current status
- [x] Existing implementation inventoried from GitHub sources
- [x] Feature branch and isolated shader groundwork
- [ ] Real flipbook atlases generated and reviewed
- [ ] Weapon integration and opt-in A/B control
- [ ] Godot editor/import and automated test results
- [ ] iOS on-device benchmarks and visual acceptance
