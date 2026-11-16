# BLOEDJUNGLE — VFX Reference Lab 1.0 (isolated preview)

Standalone Godot 4 project. **This is an executable procedural reference prototype, not finished AAA art**. It uses generated mesh primitives and no third-party visual assets. It is NOT imported by the main game, does not change its defaults, and cannot publish OTA.

## Open
Open **this folder**, not the production root, as a project in Godot 4.7.x and press F6/F5 to run `scenes/lab.tscn`. Controls: **1** wood, **2** concrete, **3** metal, **Space** fire, **A** toggle automatic fire. The camera and three targets are created at runtime.

## Demonstrates
- Two-layer muzzle flash (warm outer halo and white-hot inner flash).
- Two-layer narrow amber tracer; no ballistic or damage logic.
- Different debris colors and counts for wood / concrete / metal.
- Persistent, bounded impact markers (oldest removed first).
- Bounded transient visuals to avoid unlimited effect growth.

This preview **does not implement** actual raycast detection, smoke flipbooks, decals, physical fragments, sound, animation synchronization or weapon model integration. Metal sparks are placeholders, and material detection is selected manually. A browser-rendered preview and iPhone FPS have NOT been captured.

## Source review (2026-11-16)
- [haowg/GODOT-VFX-LIBRARY](https://github.com/haowg/GODOT-VFX-LIBRARY): MIT; oriented toward 2D particle/shader studies, not a drop-in 3D gunfire stack. License inspected: https://github.com/haowg/GODOT-VFX-LIBRARY/blob/main/LICENSE
- [seloc0des/godot-explosion-vfx-lite](https://github.com/seloc0des/godot-explosion-vfx-lite): MIT, useful for a future explosion lab but **out of scope** of gunfire reference lab. License inspected: https://github.com/seloc0des/godot-explosion-vfx-lite/blob/main/LICENSE
- [gdquest-demos/godot-4-VFX-assets](https://github.com/gdquest-demos/godot-4-VFX-assets): MIT for scripts/scenes/shaders; CC-BY-NC-SA 4.0 for art assets. **Do not copy its noncommercial art** into the commercial Bloedjungle asset pipeline. https://github.com/gdquest-demos/godot-4-VFX-assets/blob/main/LICENSE
- Procedural VFX Kit (itch.io) is an external asset package: ownership/asset-by-asset licensing not audited in this commit. Do not vendor it until verified.

**No external code or textures were copied** into this prototype; these links are research only.

## Existing canonical Bloedjungle systems to reuse in a later phase
- `scripts/bullet.gd`: existing tracer and projectile.
- `scripts/fx.gd`: existing pooled muzzle flashes, impact material response, decals.
- `assets/vfx/m1911/`: existing optional Colt flipbook.
- `tests/colt_vfx_test.gd`: existing material/limit regression.
- `docs/superpowers/specs/2026-11-10-colt-shot-vfx-design.md`: approved realistic/arcade look.

## Before any main-game integration
Review the in-editor prototype first. Compare under identical camera/lighting conditions against existing Colt, Thompson, and Browning M2 VFX. Keep a single source of truth for damage and collision, hook effects to existing shot/impact events, preserve flash/tracer/impact pooling limits and old-mark eviction, and use an explicit opt-in A/B switch. Run Godot 4.7.2 import and tests, capture real before/after game-camera images and inspect drawcalls/overdraw. Test 60 FPS in the **native** iPhone app only after separate OTA approval.

## Validation status
- GitHub source structure inspected; independent main project created.
- **NOT RUN**: Godot executable unavailable in authoring environment, so scene parser/runtime, renderer, shader, FPS, screenshots and iPhone validation are unverified.
- **NOT DONE**: merger, OTA upload, modifications to `scripts/fx.gd`, `scripts/bullet.gd` or any gameplay settings.
