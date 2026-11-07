# M-47 Visual Upgrade 2.1 — isolated Godot test range

This is a test-only Godot 4.7.2 project. It links to the approved M-47 GLB and VQ2 player GLB without copying or modifying either source. The wall, projectile, particles, shock ring, and debris are local test geometry; no gameplay scene or player-control script is changed.

Run from the repository root with the official Godot 4.7.2 binary:

```sh
GODOT_BIN=/path/to/Godot_v4.7.2-stable
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe tests/m47_vfx/run_test.sh
```

The captured run writes `results.json`, still screenshots, and a temporary numbered frame sequence. The no-capture run writes `results_performance.json` so PNG encoding is excluded from performance sampling. The script checks all five existing M-47 clips, core rotation at low and accelerated clip rates, imported PBR maps, single-LOD visibility, test-wall collision before and after destruction, debris collision, effect-count budgets, and engine-reported memory/performance monitors.

The project uses Godot's Compatibility renderer and conservative mobile budgets: at most 64 one-shot particles, eight temporary debris bodies, no dynamic shadowed effect lights, no screen-space post effects, and a low-poly six-sided shockwave. Local headless render/performance figures are diagnostic only; they do not establish native iPhone frame rate or thermal performance. No OTA publish step is part of this test project.
