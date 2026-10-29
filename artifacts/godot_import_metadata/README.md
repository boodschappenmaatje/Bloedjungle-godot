# Godot GLB import evidence

- Engine: Godot 4.7.2.stable.official.ed1daf0bf (official app installed on the iMac).
- Scope: 36 GLBs missing import metadata in the isolated checkout (33 main-project assets and 3 FX/barrel assets). All 36 GLBs passed the container/chunk/JSON/buffer validation and stayed byte-identical.
- Targeted method: a minimal Godot project containing only those source files, imported with the official Godot editor using `--headless --editor --import --quit`.
- Targeted result: editor process exited 0; 36/36 `.glb.import` files and 36/36 probe `.scn` cache outputs were generated. No `.godot` cache was copied into the repository.
- Targeted duration: 54.25 seconds; peak RSS reported by `/usr/bin/time -lp`: 1,135,878,144 bytes; no swap. Sampled peak RSS: 1,012,928 KiB; peak CPU: 100.1%. See `godot_time.txt` and `resource_samples.csv`.
- Main-project clean checkout: full editor import exited 0 in 38.62 seconds and produced imported scenes for all 56 GLBs under `assets/`. Peak RSS was 1,398,214,656 bytes; no swap. See `clean_checkout_editor_import.log`, `clean_checkout_time.txt`, and `clean_checkout_resource_samples.csv`.
- Regression checks in that checkout: `tests/soldaat_vq2_test.gd` printed `SOLDAAT VQ2 TEST OK`; the main scene ran headless for 3 frames and exited 0. The test and smoke logs are included.
- First-import diagnostics: 12 zero-basis-to-quaternion errors came from zero-scale nodes `Druppel00` and `Druppel23` in `brandkraan.glb`. Godot also logged missing extracted-texture paths during the first filesystem pass for the embedded PBR images in `soldaat_jungle_commando.glb` and `straaljager.glb`; the same editor import generated those files later in that run. The post-import test and main-scene smoke run succeeded. These source GLBs were not changed.
- `asset_inventory.csv` records the SHA-256 and before/after metadata/cache status per source. `godot-import.log` is the readable targeted progress/error log; `godot-import.raw.log` preserves the original terminal output.
