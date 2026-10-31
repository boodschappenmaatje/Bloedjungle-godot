# Bloedjungle Airfield HQ 2.0

This is an isolated replacement candidate for the existing Airfield. The V4
source and its original iPhone USDZ remain intact under
`bron/airfield_hq/fallback_v4/`. This work is on `feature/airfield-hq-2-0`; it
does not replace the gameplay scene or publish an OTA update.

## Files

- `high_quality/Bloedjungle_Airfield_HQ_Source.blend` — editable 1:1 metre
  source, 1,572 mesh objects, construction details, source actions, authored
  2K PBR images and a studio render setup.
- `game_optimized/Bloedjungle_Airfield_HQ_Game_Optimized.blend` — merged,
  triangulated runtime source with a budgeted hero hangar and separate animated
  doors.
- `game_optimized/Bloedjungle_Airfield_HQ_LOD1.blend` — separately authored
  mobile distance variant.
- `runtime/Bloedjungle_Airfield_HQ_Game_Optimized.glb` — Godot-ready LOD0.
- `runtime/Bloedjungle_Airfield_HQ_LOD1.glb` — Godot-ready mobile LOD1.
- `textures/` — tileable, authored PBR maps; the main hangar and concrete
  materials each have 2048×2048 Base Color, tangent Normal and packed ORM
  (ambient occlusion, roughness, metallic) images.
- `scenes/airfield_hq_showcase.tscn` — isolated Godot preview with
  gameplay collision proxies and distance-based LOD switching.

## Construction and look

The hero is a 44 m span by 38 m deep steel gable hangar with a reinforced
concrete base and floor, built-up portal frames and roof trusses, purlins,
continuous profiled roof sheets, ribbed wall and gable cladding, paired sliding
door panels with USAAF star-and-bar stencils, rollers, rails, braces, rivets,
service vents, louvres, glazing, gutters, downpipes and workshop lighting. A
period-identification board sits above the main doors. Door clips are named
`Open_Left_Door` and `Open_Right_Door`; the grouped red runway/tower markers
blink in `Blink_Red_Markers`. The Godot showcase exposes
`open_door(&"left"|&"right")` and `close_door(...)`.

The rest of the field is modular: a 760 m concrete runway, runway apron,
taxiway, dressed expansion joints, faded threshold and centerline markings,
control tower with glazed cab, analog control console, an external stair, wind
indicator, warm low-intensity incandescent markers, tower warning beacons,
fuel drums, crates, a service trolley, ladders, wheel chocks, sandbag positions
and perimeter details. The materials use authored tileable maps with multi-scale
surface variation, oxidation, scratches, pitting and roughness breakup. These
are procedural PBR maps made for this project rather than photographic scans;
no third-party mesh or image license is required.

Historical reference guided the austere 1940s US Army Air Forces treatment:
[FM 1-26, Defense of Airdromes (1944)](https://cgsc.contentdm.oclc.org/digital/collection/p4013coll9/id/703/)
and [FM 44-6, Employment of Antiaircraft Artillery Searchlights (1945)](https://patcosta.com/wp-content/uploads/2024/07/FM-44-6-Employment-of-AntiAircraft-Artillery-Searchlights-March-1945.pdf).
The design avoids modern LED runway systems and post-war USAF markings.

## Budget and checks

Exact current values are recorded in `high_quality/source_metrics.json`,
`game_optimized/production_metrics.json` and `game_optimized/lod1_metrics.json`.
The LOD0 hero hangar has 46,946 triangles, within the requested 35k–70k range.
The complete environment has 104,522 triangles in LOD0 and 54,184 in LOD1;
LOD1 is selected after 480 m in the Godot showcase. Each GLB has 13 mesh
objects, 15 unique materials and 42 material surfaces. Both embed the 2K maps
and carry left door, right door and red-marker animation clips.

The iPhone review package is in iCloud Drive at
`Bloedjungle Previews/Airfield HQ/2.0/Bloedjungle_Airfield_HQ_iPhone.usdz`.
Its USDZ package passed Apple's `usdchecker --arkit` and contains all 15
texture images. It includes the two door actions; the red-marker morph clip is
available in the GLB but isn't reported by Blender's USD export. Actual iPhone
Quick Look playback and device frame rate aren't claimed; check those on the
device before approval. Blender renders are under `previews/airfield_hq/v2/`.

Godot 4.7.2 imported the LOD0 and LOD1 GLBs. The import check passed with 13
LOD0 meshes, 42 material surfaces, 104,522 triangles, all UVs and materials,
three animation clips and six collision shapes. The test exercises the left
door animation. A pre-existing audio-loader warning elsewhere in the project
is unrelated to this isolated showcase.

The Airfield was not merged into the main gameplay scene. The Draft PR is the
visual review gate; do not merge or publish an OTA update before approval. The
isolated showcase includes named hangar/apron aircraft spawn markers for a
future points-shop integration; no shop, aircraft ownership or flight code is
added to existing gameplay as part of this visual replacement.
