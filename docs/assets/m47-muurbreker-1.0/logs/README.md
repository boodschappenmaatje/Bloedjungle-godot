# Godot 4.7.2 evidence logs

The `godot_4.7.2_*` files are output captured from local Godot 4.7.2 runs after a full root-project import. The M-47 asset log records 32 passing checks. The three requested regressions use the workflow's fixed 60 fps timestep; `wapen_clips_test.gd` requires it for a deterministic animation-distance assertion.

Files prefixed `main_` are regression outputs captured from a detached worktree at `b808fe1`, using the same imported GLB cache as the featurebranch run. They compare the unchanged test and gameplay code; the official main workflow is the independent CI baseline. [`github_actions_42395675534.log`](github_actions_42395675534.log) summarizes the successful macOS build and the uploaded artifacts. The raw `godot-diagnostics-*` logs and unsigned IPA are attached to the [GitHub Actions run](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42395675534). The local Linux environment cannot run Xcode.
