# Bloedjungle VFX Studio 1.0 — isolated M2 preview

## Scope

This is the **first isolated review checkpoint**, not a production VFX integration. It deliberately does not change `scenes/main.tscn`, `project.godot`, `scripts/fx.gd`, `scripts/bullet.gd`, gameplay parameters, input maps, saves, or graphics defaults.

- Scene: `res://vfx/preview/vfx_test_arena.tscn`
- Controller: `res://vfx/preview/vfx_test_controller.gd`
- Controls: single shot, short burst, continuous fire, stop; 1/5/12 virtual gun emitters; target surface; preview-local low/high/ultra
- Readouts: engine FPS, percentile-based approximate 1%-low FPS (after 120 samples), drawcalls, object count, static memory, preview tracer count, and existing `Fx.combat_counts()` pool statistics.
- Gun stand geometry is **test proxy geometry** only, not a new WWII model. The `mg42` effect preset currently supplies a canonical rapid-fire baseline for M2 evaluation. An approved M2-specific emission profile and approved model attachment remain outstanding.
- The scene uses only existing `Fx.muzzle`, `Fx.casing` and `Fx.impact` routines, plus pooled temporary tracer visuals. It **never** creates gameplay bullets or calls `Bullet.fire()`.

## Repository inventory (initial, main branch)

- `scripts/fx.gd`: shared visual FX and existing object pools, including up to 18 muzzle flashes, 16 muzzle-smoke sprites, 36 casings, and 2 muzzle lights.
- `scripts/bullet.gd`: existing projectile/hit logic, including jeep M2 tracer visuals; not modified.
- `scripts/vijand_m2_toren.gd`: approved enemy-tower M2 model and muzzle anchor; not modified.
- `scripts/perf_monitor.gd`: frame monitoring; not modified.
- `scripts/game_settings.gd`: persistent preferences; not modified.
- `project.godot`: 4.7 feature requirement, Mobile renderer, iOS Mobile renderer; not modified.
- `.github/workflows/ios.yml`, `ota.yml`: existing pipelines; not modified.
- Existing M47 / graphical upgrade PRs are not altered.

## Running the preview

With Godot **4.7.2**, open the existing project, select the VFX preview scene, and use **Run Current Scene (F6)**. This does not start the regular game. Verify after import that no missing dependencies or GDScript errors occur.

On iPhone, the next step is an *explicitly authorized* preview workflow (not a production OTA publication). A local desktop or cloud editor capture cannot establish native iPhone FPS.

## Repeatable acceptance scenarios

1. Baseline: stop; settle and measure 30+ seconds.
2. One MG: continuous; measure 30+ seconds.
3. Five MGs: continuous; measure 30+ seconds.
4. Twelve MGs: continuous; measure 30+ seconds.
5. Switch each of dirt, concrete, metal, wood and vehicle impacts.
6. Stop; allow >2 s for transient effects to finish; verify live counts decrease and pools stay bounded.
7. Repeat for low, high and ultra preview-local profiles.
8. Record identical camera and viewport configurations, device, thermals, build mode and renderer across comparisons.
9. Check screenshots from top-down camera and compare with a separate M2 reference, prior to any production linkage.

Measure mean FPS, 1%-low, mean/p95 frametime, drawcalls, VRAM / memory where exposed, and visible effect quality. The extra 1 ms frame budget is a **hypothesis**, not measured data. The preview's 1%-low is estimated as inverse p99 frame delta from its rolling window; annotate this limitation.

**Interpretation warning:** This preview isolates the effect subsystem but the scene is deliberately much simpler than full Bloedjungle combat. 60 FPS in this arena does not prove 60 FPS with 80 enemies, dense jungle and towers.

## Game Development Studio status

This session's working container does **not** expose the `game-dev` executable, the local Godot executable, or a mounted checkout of the game. Therefore CLI doctor/capabilities, Godot import, native screenshots, GPU captures, Blender normalization, iOS export and performance measurements are **NOT EXECUTED**. Do not report passing tests or measured FPS until a suitable runner has produced evidence. No paid provider has been invoked, and no external assets have been acquired.

The project's local .game-dev adapter has not been installed or used. If using Game Development Studio later, inspect adapter definitions, preflight and request the action-specific permissions before execution.

## Next stage, only after review

- Replace the `mg42` baseline with a preview-only tuned M2 profile using the existing shared FX pools, preserving canonical gameplay presets.
- Author original/licensed flame and smoke flipbooks if visual quality requires it. Record provenance, licenses and hashes.
- Build reusable attachment sockets and material-based effect variants; then design tank cannon, vehicle dust and M47 modules.
- Compare production assets and currently open PRs before ever merging the system.
- Keep `main`, live scenes and player settings untouched until explicit approval.

## Status

Implementation code submitted to draft branch. **Godot parsing, native screenshots, iOS export, OTA preview, visual acceptance and performance testing remain UNVERIFIED.**
