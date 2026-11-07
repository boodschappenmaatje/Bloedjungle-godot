# M-47 Muurbreker VFX 2.0 — test report

**Status:** 36 isolated Godot checks PASS; four root regressions PASS; official Godot 4.7.2 used. The scene and all new geometry are test-only. No bazooka, gameplay script, player control, shared scene, or root rendering setting changed.

## Isolated test range

`M47VfxTest.tscn` loads the approved `M47_Muurbreker_1.0_animated.glb` and existing VQ2 player as relative read-only symlinks. The test project uses the Compatibility renderer; `run_test.sh` rejects any Godot version other than 4.7.2 and saves the separate screenshot and no-capture performance passes.

The M-47 GLB is not edited. LOD0 remains 50,000 triangles, its original albedo, normal, roughness, and metallic textures import, and the test keeps one LOD visible at a time. `Idle`, `Equip`, `Aim`, `Fire`, and `Reload` each advance. The existing `Idle` core-bone animation is played at 0.4× and 3.6×; the sampled bone rotation confirms the faster rate produces faster motion.

## Effect and collision checks

- The energy payload has a scrolling plasma shader, two rotating containment rings, and three orbiting filaments. It travels from the actual M-47 muzzle line to the wall.
- Its low-poly smoke trail winds 6.25 turns along 75 longitudinal segments.
- The impact expands a six-sided ring and emits two one-shot dust/smoke systems. Three emitters use **64 particles total**.
- The test wall begins with a continuous static collider. On impact the wall shape is disabled, the wall layer is cleared, the test label and wall visuals disappear, and a ray passes through the opening. Eight low-poly debris bodies retain their own collision shapes.
- The projectile, spiral, shockwave, particle billboards and debris use **2,924 triangles** combined. The effects add no shadow-casting dynamic lights or full-screen post-effects.

## Results

| Check | Result |
| --- | --- |
| Godot 4.7.2 isolated VFX scene | 36 PASS, 0 failures |
| GLB clips and mechanical-core acceleration | PASS |
| PBR maps and single-LOD visibility | PASS |
| Pre-impact wall ray, disabled wall collision, clear post-impact ray | PASS |
| Eight debris collision shapes | PASS |
| Root project import | Second import pass exits 0 with no `ERROR`, `SCRIPT ERROR`, or parse errors |
| `surface_filtering_test.gd` | PASS (0 failures) |
| `combat_bazooka_aim_test.gd` | PASS |
| `wapen_clips_test.gd` | PASS |
| `base_wall_hq2_test.gd` | PASS (0 failures) |

The first root cache-prime pass reimported the project's scenes and printed temporary missing-UID messages while rebuilding the import cache. The second full import pass was clean. The first pass also logged the repository's existing non-normalized `brandkraan.glb` basis warnings; the M-47 VFX test does not touch that asset. The bazooka and weapon-clip scripts print the same shutdown resource/PagedAllocator messages as the recorded `main` baseline; their test PASS markers and exit codes remain successful.

## Memory and performance observation

The final separate no-capture pass ran at 1280×720 on **Xvfb + Mesa llvmpipe software rendering**. It reported a 2–9 FPS range, peak engine process time of 253.039 ms, 133 scene draw calls, and 238,342 rendered primitives. Process static memory was 66,029,018 bytes at sequence start, 84,596,287 bytes after the sequence, and 104,749,789 bytes at peak. These are whole-process/software-renderer values; they do not isolate GPU memory or predict native iPhone performance. No iPhone hardware or native frame-time measurement was available, so native iPhone performance remains **NOT RUN**.

For mobile efficiency the effects cap one-shot emission at 64 particles, use only eight temporary debris colliders, keep the shockwave low-poly, and add no dynamic shadowed lights or full-screen post-processing. The PBR M-47 model and its LODs remain the approved source asset.

## Captures and logs

- [Ready scene](screenshots/m47_vfx_01_ready.png)
- [Energy projectile mid-flight](screenshots/m47_vfx_02_projectile_midflight.png)
- [Impact and wall collision reset](screenshots/m47_vfx_02_impact.png)
- [Reload and debris](screenshots/m47_vfx_03_reload_rubble.png)
- [5.23-second video preview](screenshots/m47_vfx_preview.mp4)
- [VFX checks and capture metrics](results.json)
- [No-capture performance metrics](results_performance.json)
- Godot logs: [`logs/`](logs/)

## CI previews

Both manual preview workflows completed successfully for branch commit `6d75022` with the official Godot 4.7.2 toolchain:

- [Unsigned iOS workflow](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42403049506) — cache import, project validation, the workflow's root regression suite, Godot iOS export, Xcode build, IPA existence check, ZIP integrity check, and `Payload/*.app/Info.plist` check all passed. Artifact `bloedjungle-ios-unsigned-6d75022527d5c026c800d6a9fe102816a376588f` uploaded at 1,144,245,464 bytes. It is unsigned; no device install was performed.
- [Non-publishing OTA preview workflow](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42403050612) — base and patch exports, OTA safety simulations, and preview upload passed. The generated light update is 5.5 MB, the preview manifest carries the existing 57-piece heavy chain (5,657.9 MB total), and the bridge is 0.01 MB. Artifact `ota-preview-6d75022527d5c026c800d6a9fe102816a376588f` uploaded at 92,964,590 bytes. The `Publish to the "updates" release` step was **skipped** (`publish=false`); nothing was published.

The GitHub Actions runs and artifacts are available from the linked run pages. CI logs show Godot shutdown `resources still in use at exit` diagnostics for headless tests; the workflow permits that exact shutdown-only message, and the job completed successfully. No unsigned IPA was installed on a physical iPhone, and no OTA package was published.
