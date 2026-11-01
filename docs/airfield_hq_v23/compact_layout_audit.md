# Airfield HQ 2.3 compact layout audit

Candidate implementation on `feature/airfield-compact-layout`, based on the
current `origin/main`. This audit supersedes the former 65 × 42.46 m hangar and
17.5 × 14.8 m tower layout. No merge, release, or OTA action is included.

## Component dimensions (metres)

| Component | Geometry / zone | Position / notes |
|---|---:|---|
| Runway | **75 × 18** | Five 15 m slabs; X `-37.5…37.5`, shared centerline Z `-17.5`, yaw `90°` |
| Hangar shell | measured bounds about **22.5 × 21.055** | Includes foundation and shortened door guides; slightly above the nominal 22 × 20.65 m target |
| Hangar construction zone | **28 × 24** | Center `(0, 2.5)`; not a single scene-scale transform |
| Clear interior envelope | **15 × 13 × 6** | Clear central volume reserved inside the hangar |
| Hangar doorway | **15 × 5.89** | Two animated leaves about 7.37 m wide; collision boxes track them |
| Control-tower core zone | **8 × 8** | Center `(-17, 19.5)`; exterior stair-access region is tracked separately |
| Tower stair-access zone | **4 × 8** | Center `(-22, 19.5)`; kept outside the 8 × 8 core zone |
| Apron | **18 × 14** | Center `(0, 19.5)`; meets the hangar apron-side wall |
| Taxiway | **18 m wide** | Apron edge `(9, 19.5)`, short straight, 12 m radius 90° turn, then a straight connection to runway edge `(28, -8.5)` |

The route stops at the runway edge. Its final concrete module overlaps the runway
by its normal half-length to avoid a collision/surface gap; the taxi turn does
not continue along the runway. The five runway modules have one shared axis and
uniform 15 m center spacing. Their 0.04 m collision overlap is confined to the
slab seams.

## Clearance and construction area

The plane reference remains 12.44 m wingspan and 4.45 m height. A 15 m opening
leaves **1.28 m per wingtip** and the 5.89 m modeled leaf opening leaves **1.44
m overhead**. The 18 m taxi paving leaves 2.78 m per wingtip on paper. These are
dimension checks; no aircraft is present and no taxi/flight test is claimed.

The existing player scale remains 1.2. For reference, the garage is about 6.4 m
wide and the barracks runtime mesh is about 5.8 m across. The derived hangar
shell is roughly 3.5 garage widths across; the reserved clear interior can fit
the existing player without reducing the overall player scale. The scene
contract checks geometry and collision proxies, but a player walk-through,
stair climb, door passage, and vehicle traversal have not been tested.

The conservative surface sum includes the hangar zone, tower core and stair
zone, runway, apron, taxi centerline length and an 8 m taxi end-coverage margin:

`28×24 + 8×8 + 4×8 + 75×18 + 18×14 + (7 + 12×π/2 + 16 + 8)×18 = 3,267.29 m²`

The base ground reference is 56.65 × 56.95 m = 3,226.2175 m², with a 2× cap
of 6,452.435 m². Placement still tests individual regions against world bounds,
the combat-spawn radius, river clearance, the base gate route and collision
layers. The framing bound is 75 × 53 m; it is not one colliding slab.

## Protected source and derived asset

`assets/airfield_hq_v22/high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend`,
the 2.2 LODs, runtime GLBs, source showcase scene/script, animations and texture
assets are inputs only. A new editable review copy is generated at
`source_assets/airfield_hq_v23/hangar/Bloedjungle_Airfield_HQ_23_Compact_Review.blend`.
The matching 2.3 GLB LODs live under `assets/airfield_hq_v23/hangar/`. A
repeatable Blender 4.5.15 script transforms the hangar and service collections
independently, narrows and retimes the two sliding doors, and bounds the five
workshop lights (2 W, 6 m cutoff, shadows disabled) instead of their old
38,045.99-energy / 4,096 m import values. The placed scene keeps those lamps off
in normal daylight; a reversible runtime toggle supports paired visual review.

The separate tower scene is scaled on its horizontal axes for the 8 × 8 m core;
stair colliders are repositioned with that asset and receive a 1 m tread width.
The compact HQ2.3 tower asset currently has no authored `Open_Tower_Door` or
`Wind_Sock_Gust` animation clips. The approved HQ2.2 source still contains and
passes checks for those clips, but the new compact tower does not preserve those
behaviors; this is an acceptance gap. Review stair access in Godot before
treating climb access as accepted.

## Flight-length limitation

The purchaseable P-47 remains disabled and the original plane model is absent.
The 75 m runway is retained as requested. It is **not established as sufficient
for a real P-47 takeoff or landing**; real aircraft movement, takeoff distance,
taxi steering, and flight remain open acceptance items pending a real aircraft
asset and separately approved tests. No runway extension or flight claim is
made here.

## Validation status

See `REPORT.md` for the current branch state, test outcomes, captures and
remaining acceptance gaps. Blender CPU Cycles images exist for the hangar and
tower comparisons, while paving is compact-only. Current Godot screenshots,
native iPhone acceptance and performance were not captured and are not inferred
from the Blender renders.
