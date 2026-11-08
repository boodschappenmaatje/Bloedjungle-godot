# Fern 02 field trial

This is a review-only fern grouping for the bounded bospad comparison. It is assembled from two existing photographed meshes, `fern_02_a` and `fern_02_c`, from the already approved Poly Haven `fern_02` source. The individual fern assets already provide the target leaf detail, so the trial changes silhouette and crown layering without inventing a procedural leaf shape or adding another texture set.

Poly Haven source: [`fern_02`](https://polyhaven.com/a/fern_02), CC0 1.0 Universal. Source Blender file and 2K color, alpha, OpenGL normal, and roughness maps remain under `polyhaven_source/fern_02/`. The runtime GLB reuses the existing fern 1K color/alpha, normal, and roughness maps through Godot's shared `depth_arch_fern` material. It uses alpha cutout (`cut = 0.42`), opaque depth writes, and no blended transparency.

| Property | Trial |
| --- | --- |
| Blender source | [`fern_trial.blend`](fern_trial.blend) |
| Reproducible generator | [`make_fern_trial.py`](make_fern_trial.py) |
| Godot runtime model | [`jungle_fern_trial.glb`](../../assets/jungle_fern_trial.glb) |
| LOD0 dimensions | 1.533 × 1.513 × 0.680 m |
| LOD0 / LOD1 / LOD2 | 3,032 / 1,637 / 545 triangles |
| LOD thresholds | 20 m / 48 m |
| Runtime material surfaces | 1 per LOD |
| Collisions | None |
| Runtime texture additions | None; reuses three 1024² fern maps |
| Live scatter | Not enabled; the existing `spawn()` never requests `fern_trial` |

The comparison capture temporarily disables only the existing `arch_fern` variant-0 MultiMesh batch in one 24 m bospad cell, then places the original single fern and this two-crown trial side by side in that patch. The save is produced by `scenes/main.tscn` and its existing `Camera` node, with the approved `approved-b.jpg` included as a labeled reference panel. Only that capture harness changes the camera distance for individual-frond inspection; FOV remains 45° and the downward angle remains 53°. This is a one-off visual proof, not a production camera or gameplay change.

The interactive model viewer also exposes the three trial LODs alongside the existing fern variants. There is no animation. A USDZ preview is not included in this trial: the local Blender is 4.3.2, while the project's Apple Quick Look export/validation tool requires Blender 4.5+.
