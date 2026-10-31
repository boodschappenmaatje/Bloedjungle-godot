# Airfield HQ 2.3 compact layout audit

## Area source and cap

`scripts/data.gd` defines `Data.COMPOUND = 28.0`. `scripts/base_props.gd`, in `BaseProps._wall()`, builds the perimeter walls and posts from that value and `Data.WALL_T = 0.4`.

- Side-wall post outer extent: `28.0 + (0.4 + 0.25) / 2 = 28.325 m`.
- End post outer extent: the last post centre is `28.2 m`; its half-width along the wall is `0.55 / 2`, giving `28.475 m`.
- Ground rectangle: `56.65 × 56.95 m`.
- Ground area: `3,226.2175 m²`.
- Maximum allowed placement rectangle: `2 × 3,226.2175 = 6,452.435 m²`.

This uses the constructed wall/post extent from project source rather than assuming a 56 m square. It is a conservative rectangular ground-area measurement; it does not count only the occupied pixels of the walls.

## Approved 2.2 core dimensions

The approved `Bloedjungle_Airfield_HQ_2_2_LOD0.glb` was imported in Blender 4.5.15 and its mesh bounds were measured. Horizontal dimensions, after mapping the Blender forward axis to Godot ground Z:

| Core piece | Authored ground bounds | Authored size |
| --- | --- | ---: |
| `Hangar HQ 22` | X −32.50…32.50, Z −21.46…21.00 m | 65.00 × 42.46 m |
| `Control Tower 22` | X 61.90…79.40, Z −27.40…−12.60 m | 17.50 × 14.80 m |

The approved hangar, doors, service props, tower, tower door, and wind sock are reused. No mesh, texture, material, UV, collision, animation, scale, or source transform was edited. The complete 2.2 showcase runway/environment is hidden only in the newly placed compact instance. The original 2.2 scene and source remain untouched.

The placed approved core receives one rigid translation of `(-24.125, 0, -0.3)` to frame it in the build footprint; it is not scaled. Combined placed hangar/tower bounds are about `111.90 × 48.40 m`, within the selected preview footprint.

## Candidate ground layout (metres from the placed building origin)

- Footprint preview: `113.25 × 55.40 m` = `6,274.05 m²`.
- Limit: `6,452.435 m²`; remaining headroom: `178.385 m²`.
- Runway: 30 × 38 m; X 20…50, centre Z 8.5. Two 15 m concrete slabs use shared MultiMeshes at three distance bands; their separate collision boxes overlap across the visible 6 cm expansion joint. Taxiway/apron render geometry also has near/mid/far meshes, with a flat far representation.
- Taxiway: 18.4 m wide, segmented concrete, from apron centre `(18, −20)` north to Z −4 then around a sampled 12.5 m-radius 90° arc to the runway at `(30.5, 8.5)`. P-47 nominal wingspan used by the existing marker contract is 12.44 m, leaving 2.98 m nominal wing margin on each side of the paved taxi corridor.
- Apron: separate 18 × 14 m stand centred at `(18, −20)` for the one validated initial parking slot.
- PSP: a separate apron-corner patch of eight interlocking plates, each nominally 3.048 × 0.381 m. It is placed on the already-counted apron and adds no placement area, grass, berm, terrain, runway paint, or gameplay collision. The Blender source is under `source_assets/airfield_hq_v23/psp/`; the GLB and Blender render preview are under `assets/airfield_hq_v23/psp/`.
- Hangar-to-runway X gap: `20 − 8.375 = 11.625 m`.
- Taxi paving's western edge on the straight section: `18 − 18.4/2 = 8.8 m`, versus the hangar's eastern edge at 8.375 m; the paving itself has 0.425 m ground gap. This is a tight geometry clearance and still requires in-engine collision inspection with the actual P-47 model.
- Runway north edge: Z 27.5 m. Approved tower's southern edge in the placed coordinate system is Z −12.9 m; the projected ground gap is 2.4 m where their X ranges overlap.
- Marked takeoff position X 32 m to runway end X 50 m: 18 m available. At the explicitly arcade-only assumption `10 m/s` and `5 m/s²`, `v²/(2a) = 10 m`, leaving 8 m. This is not a P-47 real-world performance claim.

No new runway paint, ground berms, grass, mud, tire marks, oil, decorative cracks, or debris were added. The approved tower design was kept unchanged under the revised instruction.

## PSP source and LODs

The U.S. Army Center of Military History's *The U.S. Army GHQ Maneuvers of 1941* documents Marston mat as 10 ft × 15 in, pierced by 87 holes, with a reported weight of 66.2 lb. The asset uses the 3.048 × 0.381 m nominal dimensions and an 87-hole LOD0. LOD1 retains 24 open holes and LOD2 is a silhouette mesh. Folded edge rails and simple interlocking end lugs are modeled. The `0.14 in` sheet thickness is an explicitly visual/game-asset approximation and is not asserted as a sourced historical specification.

The GLB is imported by Godot and instantiated as eight plates in a single MultiMesh per distance band. The concrete apron supplies the underlying collision surface. See the [CMH publication record](https://history.army.mil/Publications/Publications-Catalog/US-Army-GHQ-Maneuvers-of-1941/) and [rendered PSP library preview](../../assets/airfield_hq_v23/psp/PSP_plate_library_preview.png).

## Free placement guards

The build placement logic transforms all four full-footprint corners by candidate yaw and checks the existing world bounds, minimum separation from the combat spawn circle, river samples, and physics layers used by walls, bunkers, nature, and water. It caps placed airfields at one per base. Build-menu preview and camera framing use the same footprint constants; rotation re-runs the validity check. The suggested initial camera target is only a starting view; placement remains player-selected.

## Limitations

Godot 4.7.2 headless tests now pass for placement bounds, spawn/river/world rejection, a physical wall obstacle, one rotated clear site, route marker alignment, and the placed 2.2 core/pavement nodes. These do not verify P-47 wingtip or landing-gear clearance against the actual aircraft: the original P-47 model is missing. The 30 m strip is a compact game demonstration layout and must not be described as historically representative runway performance. No native-device or Quick Look verification is claimed.
