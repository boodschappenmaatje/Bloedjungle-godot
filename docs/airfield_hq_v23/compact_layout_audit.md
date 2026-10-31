# Airfield HQ 2.3 compact layout audit

## Measured player-base area and cap

`scripts/data.gd` defines `Data.COMPOUND = 28.0`; `scripts/base_props.gd`, in `BaseProps._wall()`, places the outer perimeter posts using that value and `Data.WALL_T = 0.4`.

- Side-wall post outer extent: `28.0 + (0.4 + 0.25) / 2 = 28.325 m`.
- End-post outer extent: last post centre `28.2 m` plus half-width `0.275 m` = `28.475 m`.
- Measured ground rectangle: `56.65 × 56.95 m`.
- Player-base ground area: `3,226.2175 m²`.
- Two-times limit: `6,452.435 m²`.

This measures the authored perimeter ground extent, not the wall’s surface area.

## Approved core and protection

The 2.2 authored hangar ground envelope is 65.00 × 42.46 m; the former tower envelope is 17.50 × 14.80 m. The hangar and interior remain at their original dimensions and source transforms. The complete approved 2.2 showcase scene and source GLBs are retained. The mounted core is translated rigidly by `(-24.125, 0, -0.3)` to align the fixed structure with the module coordinate frame; no overall scaling is applied.

The 2.3 tower is a separate scene/asset at the approved tower position. The former tower shell is hidden only in the newly placed 2.3 instance; the old door and wind-sock animation remain available. `approved_2_2_sha256_before.txt` records the protected-source hashes made before these edits.

## Surface layout (local metres from the placed building origin)

- Hangar envelope: centre `(-24.125, -0.3)`, size `65.0 × 42.46 m`.
- Tower envelope: centre `(47.875, -20.3)`, size `17.5 × 14.8 m`.
- Runway: **75 × 18 m**, centre `(-19.0, -31.5)`, longitudinal X bounds `-56.5…18.5 m`; five instanced 15 m real 3D concrete slabs, 0.22 m slab depth, slab collision overlaps 0.04 m at joints, and four shallow recessed expansion-joint strips across the slab joins.
- Taxiway: separate 18.4 m wide segmented slabs, apron start `(28, -20)`, straight to `(28, -22.5)`, then a 12 m-radius 90-degree curve to `(16, -34.5)`. Individual colliders overlap slightly at segment ends.
- Apron: separate 18 × 14 m slab centred `(28, -20)`, currently one verified aircraft stand. The stand is dormant until the user later approves aircraft integration.
- PSP: eight interlocking 3.048 × 0.381 m nominal plates in a small patch on the apron. PSP adds no new ground region/collision.

The conservative sum used by the contract test is:

`65×42.46 + 17.5×14.8 + 75×18 + 18×14 + ((2.5 + 12×π/2 + 8)×18.4) = 5,160.9318 m²`.

This sum deliberately double-counts all overlaps and adds an 8 m taxi end-coverage allowance. It is below `6,452.435 m²` by `1,291.5032 m²`. The placement footprint is the union of these separate occupied component regions, not the rectangle enclosing their distant extents. The oversized `FOOTPRINT` constant is used only to frame the airfield build camera and clamp panning; it is not used as a single colliding pad, land-take area or preview slab. The preview draws every separate hangar, tower, runway, apron and taxi region, and placement tests each against the world.

## Placement safety and control

The existing build card enters the airport build view; the full component preview moves green/red with the candidate point. PAN moves the map, the 90-degree button rotates the layout where the entire composition still fits, and touch-release places only a valid/affordable site. The main gameplay camera continues to use the original ground-combat behavior outside this build context.

Placement checks every region against world bounds, the combat-spawn radius, river clearance and physics layers for walls, bunkers, rocks/stumps and water. The visible game-scene capture found a free valid site at `(140, 0, 20)` with 90-degree rotation; the broader location remains player-selected, not fixed to this capture point.

## Historical and asset notes

The separate tower uses a raised observation cab, perimeter glazing, framed doors/windows, visible operations equipment, exterior stair/landings, antenna/cabling and authored PBR maps. It is period-inspired based on 1942–44 USAAF tower references, including the [National Museum of the U.S. Air Force’s 1942 standard 8th Air Force tower reconstruction](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/195877/wwii-8th-air-force-control-tower/). It is not a direct reconstruction of that museum tower.

The existing PSP source contains an 87-hole LOD0 plate pattern; LOD1 and LOD2 reduce the openings/mesh silhouette for mobile rendering. The plate thickness is a documented visual asset approximation, not a claimed historical thickness. The pavement uses separate near/mid/far LODs and cheap collision boxes. The tower GLBs use textured hero LOD0 and lower-size flat-color LOD1/2 to avoid repeating all hero maps at each distance.

No new runway paint, numbers, taxi guides, berms, ground growth, decorative damage, oil or tire marks are present.

## Current test limits

Local Godot 4.7.2 checks validate asset import, collision endpoints, marker coordinates, placement guards, economy, selection/shop state, building lifecycle and protected HQ 2.2 animation/asset paths. The original Meshy P-47 is not available and its purchase is intentionally disabled. No aircraft movement/flight/landing, native iPhone test, FPS, 1%-low, frame-time or memory claim is made. The desktop screenshot pass uses OpenGL Compatibility because this Mac’s Vulkan compute-pipeline initialization fails; native iPhone rendering remains to be verified on the device.
