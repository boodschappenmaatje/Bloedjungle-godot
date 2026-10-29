# Godot GLB import evidence

- Engine: Godot 4.7.2.stable.official.ed1daf0bf (official app installed on the iMac).
- Scope: 36 GLBs missing import metadata in the isolated checkout (33 main project assets and 3 FX/barrel assets).
- Method: focused project with only those GLBs linked from the isolated checkout; Godot Editor import, `--headless --editor --import --quit`.
- Result: editor process exited 0; 36/36 `.glb.import` files and 36/36 probe `.scn` cache outputs were generated. No `.godot` cache was copied into the repo.
- Duration: 54.25 seconds; peak RSS reported by `/usr/bin/time -lp`: 1,135,878,144 bytes; no swap. Sampled peak RSS: 1,012,928 KiB; peak CPU: 100.1%. See `godot_time.txt` and `resource_samples.csv`.
- Importer diagnostic: Godot logged 12 identical zero-basis-to-quaternion errors during `brandkraan.glb` import. Its GLB contains zero-scale nodes `Druppel00` and `Druppel23`. Godot still completed and wrote the imported scene. The source GLB is preserved unchanged.
- `asset_inventory.csv` records the SHA-256 and before/after status for each source. `godot-import.log` is the readable progress/error log; `godot-import.raw.log` preserves terminal output.
