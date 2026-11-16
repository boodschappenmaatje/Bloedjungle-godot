# BLOEDJUNGLE — VFX Reference Lab 1.0

An isolated, visual-only scene inside the existing Godot project. It displays the real M1911A1 GLB from `assets/meshy_m1911.glb` in a camera matching the gameplay camera's 40° lens and 60° downward angle, with classic and enhanced effects shown side by side against wood, concrete, and metal targets.

## Open the preview

Open the repository root in Godot 4.7.2, then run `prototypes/vfx_reference_lab/scenes/lab.tscn` with **F6**. From a terminal:

```sh
godot --path . --scene res://prototypes/vfx_reference_lab/scenes/lab.tscn
```

Controls work with keyboard and the touch-sized on-screen buttons:

- `Space`: fire at the selected target in both lanes
- `1`, `2`, `3`: wood, concrete, metal
- `B`: cycle both lanes, classic only, enhanced only
- `H`, `M`: High and Mobile preview presets
- `A`: toggle automatic fire

For an automated Mobile preset capture, pass `-- --vfx-mobile` after Godot's regular options. This flag changes the lab's in-memory preset only.

The High/Mobile presets exist only while this scene is running. They change the in-memory quality tier, lab glow, and lab key-light shadows. The scene restores the starting in-memory settings when it exits and never calls the settings save function.

## Reused game systems

- The Colt mesh and its animated slide come from the existing `assets/meshy_m1911.glb`.
- Classic flashes, impacts, sparks, decals, and their caps come from `scripts/fx.gd`.
- Enhanced muzzle flashes, material responses, and tracer mesh come from `scripts/wapenfx.gd` and `scripts/bullet.gd`.
- The comparison lanes use the same underlying base-impact path. The enhanced lane adds the current WapenFx material response, as the gameplay shot path does.
- Tracers are visual-only mesh instances with a fixed two-entry pool. This lab does not instantiate `Bullet`, perform collision queries, change health/damage, play audio, or alter controls.
- The VFX sources/assets are existing Bloedjungle project files. No external assets or code were copied.

## Validation

Run the visual smoke test from the repository root:

```sh
godot --headless --path . --scene res://prototypes/vfx_reference_lab/tests/lab_smoke_test.tscn
```

The test checks scene load, camera, all three materials, bounded transient/decal pools, and that gameplay state and settings are restored. It does not establish GPU frame rate or certify a physical iPhone. Record screenshots/video from a rendered preview before treating visual quality or device performance as approved.

Executed evidence and missing platform checks are recorded in [evidence/RESULTS.md](evidence/RESULTS.md). The [High screenshot](evidence/vfx-reference-high.png), [High video](evidence/vfx-reference-high.mp4), [Mobile screenshot](evidence/vfx-reference-mobile.png), and [Mobile video](evidence/vfx-reference-mobile.mp4) show the 3D A/B preview from the gameplay camera. Captures use Mesa llvmpipe software OpenGL and do not establish hardware or iPhone performance.

## Scope

Only this lab scene and its test/documentation belong to the preview. No gameplay, controls, damage, audio, game settings, renderer defaults, merge, or OTA publication are changed.
