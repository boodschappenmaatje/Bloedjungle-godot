# Airfield HQ 2.3 — partial production candidate

Branch: `feature/airfield-hq-2-0`

Review target: existing Draft PR #164

Status: **partial; not accepted as complete**

## Latest size and placement instruction

The latest instruction replaces the 900 m runway and reserved-site assumptions. The complete placement footprint is now a conservative rectangle of **113.25 × 55.4 m = 6,274.05 m²**. Project wall geometry in `Data.COMPOUND` and `BaseProps._wall()` gives an outer base ground rectangle of **56.65 × 56.95 m = 3,226.2175 m²**. The hard limit is twice that area: **6,452.435 m²**. The candidate footprint is under the cap by **178.385 m²**.

See [compact_layout_audit.md](compact_layout_audit.md) for source dimensions, layout coordinates, and clearances. The card still uses the normal build menu. Selecting it moves the existing build camera into the airfield overview; the player can pan, rotate the full-footprint preview, and tap an eligible map location. The ordinary gameplay camera is unchanged outside build mode. World bounds, river, spawn zone, and physics obstacles are checked before placement.

The shortened runway is **30 m × 38 m**, represented by two instanced 15 m concrete slabs. The original approved hangar and tower meshes remain unscaled and unedited. Pavement and aircraft markers are realigned around their existing transforms. The 30 m runway and the 10 m/s, 5 m/s² takeoff profile are game-only arcade assumptions, not historical P-47 performance data.

## Protected 2.2 assets

Before edits, SHA-256 hashes were recorded for 105 files in `assets/airfield_hq_v22/` in [approved_2_2_sha256_before.txt](approved_2_2_sha256_before.txt). The protected folder and `scenes/airfield_hq_22_showcase.tscn` have no edits in this candidate. The placed build reuses that approved scene, hides its old showcase terrain/pavements, disables the old runway/apron/taxiway collision layers, and adds separate 2.3 pavement modules. A Godot regression test is now included in CI to exercise the approved hangar/tower meshes, door, tower door, windsock, and placed compact core.

## Implemented in this candidate

- Adds a `Vliegveld` build card to the existing Build Mode, with the fighter silhouette and centralized 2,800-point/build-credit price.
- Allows free map placement, full-footprint preview, rotation, panning, one-per-base enforcement, and rejects world-edge, spawn-zone, river, and physics-obstacle overlap.
- Uses the existing `Game.pay_build()` flow, building selection/status, repair/rebuild, turn, sale, and cleanup pathways.
- Reuses the approved 2.2 hangar, interior, tower, doors, service props, and wind sock without editing their source assets or changing their authored scale/design.
- Builds separate instanced concrete runway slabs, a curved 18.4 m taxiway with segmented collision, and a dedicated 18 × 14 m apron/parking stand. The pavement has near/mid/far render ranges; far slabs use lightweight flat meshes. Runway slab collisions overlap at the expansion joint to avoid a wheel drop.
- Adds an editable Blender PSP library in `source_assets/airfield_hq_v23/psp/` and a Godot-imported GLB with three LOD meshes. Eight 10 ft × 15 in plates form one small temporary surfacing patch at the back of the existing apron; it uses one MultiMesh batch per LOD and does not expand the footprint. Historical dimensions and the 87-hole pattern are sourced from the U.S. Army Center of Military History; the thin sheet thickness is a documented visual approximation.
- Adds local-to-complex P-47 markers and a 12.5 m taxi curve radius. The current runway has an 18 m marked takeoff roll; the configured arcade profile calculates a 10 m ground roll, leaving 8 m in this demo setup.
- Adds an aircraft catalog and asset-gated purchase path at 1,800 points. A missing model prevents charge/registration; the current slot capacity is conservatively one.
- Adds runway reservation helpers, airfield sale cleanup, compact-area contract assertions, and the 2.2 asset/animation import regression test to iOS CI.

## Not implemented or blocked

- The configured original Meshy source path `assets/p47_thunderbolt.glb` is absent. The repository and accessible local file-name search did not find a P-47/Thunderbolt GLB/FBX. No P-47 has been purchased or instantiated; no surrogate is used.
- Without the original aircraft, its Blender mechanical rig/animations, live propeller/wheels/landing gear, aircraft state machine, taxi/takeoff/flight/landing controller, player flight controls, route occupancy, and a complete use cycle remain incomplete. The markers/profile are not evidence that the flight cycle works.
- No separate Blender source for the Godot concrete runway/taxi modules, Godot placement/build/shop screenshots, 2.2-versus-2.3 comparison set, or USDZ previews have been produced. The PSP library has a Blender preview image; this is not a substitute for those full-scene captures.
- The local `game-dev` packaging/inspection CLI is not installed. The PSP asset was authored with Blender 4.5.15, imported by Godot 4.7.2, and covered by a runtime regression assertion; no canonical game-dev package receipt is claimed.
- Godot 4.7.2 local headless import and the two targeted Airfield tests now pass. Godot was run from a temporary `/tmp` download, not installed into the repository or system `PATH`.
- No native iPhone test or device performance measurement was performed. No FPS, 1%-low, frametime, drawcall, or memory result is claimed.

## Configuration

- `AirfieldHQ23.BUILD_COST`: 2,800 points/build credit.
- `AirfieldHQ23.P47_COST`: 1,800 points.
- `AirfieldHQ23.AIRCRAFT_CAPACITY`: 1 aircraft.
- `AirfieldHQ23.FOOTPRINT`: 113.25 × 55.4 m ground rectangle.
- `AirfieldHQ23.MAX_GROUND_AREA`: exactly 2× the measured outer base ground area.
- `AirfieldHQ23.MAX_RUNWAY_LENGTH`: 30 m.
- `AirfieldHQ23.RUNWAY_START_X`, `RUNWAY_CENTER_Z`, `APRON_CENTER`, and `TAXI_ARC_CENTER` / `TAXI_ARC_RADIUS`: compact layout in building-local metres.
- `AirfieldPavementModules.LOD0_END_M`, `LOD1_END_M`, and `LOD2_END_M`: 140 m, 700 m, and 2,500 m distance bands.
- `AirfieldPavementModules.PSP_PLATE_COUNT`: 8 plates in the compact apron patch; `PSP_PATCH_CENTER` is local to the 18 × 14 m apron.
- `AirfieldFlightIntegration.DEMO_ACCELERATION_MPS2` and `DEMO_LIFTOFF_SPEED_MPS`: arcade demonstration parameters only.

## Verification state

- **PASS, local:** protected 2.2 SHA-256 inventory matches; Godot 4.7.2 project import and startup complete without script/parser errors.
- **PASS, local:** `airfield_hq_22_import_test_scene.tscn` verifies 2.2 animations, meshes/materials/collisions, preserved hangar/tower visibility in the placed core, separate runway/apron modules, pavement LODs, and marker alignment.
- **PASS, local:** the same 2.2 regression scene verifies PSP LOD0/1/2 import and eight instances in the apron patch. Blender generated `source_assets/airfield_hq_v23/psp/PSP_plate_library.blend` and `assets/airfield_hq_v23/psp/PSP_plate_library.glb`; the rendered preview is `assets/airfield_hq_v23/psp/PSP_plate_library_preview.png`.
- **PASS, local:** `airfield_hq_23_contract_test_scene.tscn` verifies build-menu entry, area cap, free/blocked/rotated placement, spawn/river/world rejection, build-credit-first payment, missing-model no-charge, one-airfield limit, and runway reservation.
- **PENDING:** GitHub iOS CI after the current commit; fresh imports report existing 2.2 GLB external-resource UIDs as unavailable and use their embedded texture paths, while the import/animation tests still pass.
- **PASS, local:** `git diff --check` and all 105 protected 2.2 source-file hashes match.
- **NOT RUN:** native iPhone tests, flight demonstrations, Blender/Godot visual captures, USDZ validation, and device performance measurements.

The work remains partial until the missing original P-47 source and the remaining flight, visual, and device-verification work are available.
