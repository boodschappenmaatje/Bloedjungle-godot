# Airfield HQ 2.3 — implementation status

This is a partial production candidate on `feature/airfield-hq-2-0`, intended to update Draft PR #164. It is not final acceptance.

## Approved 2.2 source protection

Before edits, SHA-256 hashes were recorded for 105 files in `assets/airfield_hq_v22/` in [approved_2_2_sha256_before.txt](approved_2_2_sha256_before.txt). The 2.2 asset folder, source, runtime GLBs, textures, and showcase scene were not edited. The new building instantiates `scenes/airfield_hq_22_showcase.tscn` as a child; no edits are made to that scene or its hangar.

## Implemented in this candidate

- Adds a `Vliegveld` card to the current Build Mode list, with a hand-drawn 1940s fighter silhouette and centralized 2,800 point/build-credit cost.
- Selecting the card switches the existing build camera to an isolated, fixed construction plot centered at `(1000, 0, 0)`. This avoids overlap with the 80 m combat base and its city, river, walls, and spawn area. The preview shows the full 840 × 1,140 m bounding footprint; only the reserved site and its 0° alignment are accepted. The camera returns to the prior view on exit.
- Placing the complex uses `Game.pay_build()`, existing damage/repair/sale paths, one-per-base enforcement, and the existing build selection panel. The existing Airfield HQ 2.2 scene is nested without editing the approved assets.
- Adds separate runtime concrete geometry for 900 m of 38 m-wide runway slabs, a taxiway following the local taxi Curve3D, and a 112 × 98 m apron. Shared MultiMeshes keep renderer submissions low; the runway is split into six 150 m culling batches and every pavement segment gets a simple collision box. Existing neutral concrete PBR maps are reused; no new painted markings or decorative wear were added.
- Adds a centralized aircraft catalog and a P-47 purchase action at 1,800 points. Purchase stays disabled while the real model is missing, with an explicit status; the code will not charge or instantiate a surrogate.
- Adds a one-aircraft capacity because the current source contains one validated parking marker. Adds simple runway reservation helpers for future flight-controller integration.
- Selling the airfield clears its aircraft nodes and runway reservation.
- Adds `tests/airfield_hq_23_contract_test.gd` for the build price, reserved-site placement, one-per-base constraint, missing-aircraft guard, build-credit-first payment, and runway reservation behavior.

## Not implemented / blocked

- The original Meshy Pro Republic P-47 GLB/FBX was not found in the repository. The exact current purchase path is `assets/p47_thunderbolt.glb`; it is absent. No P-47 animation, aircraft flight controller, taxi/takeoff/landing demonstration, or aircraft purchase can be claimed complete.
- The 2.2 tower has not yet been rebuilt to the requested less-angular historical design. The hangar remains intact.
- The concrete paving is runtime-generated Godot geometry; separate Blender source/GLB library files and a PSP module library have not yet been produced. The runtime 2.2 visual core remains present under the new slabs.
- No requested 2.3 Blender/Godot screenshots, USDZ previews, 2.2-versus-2.3 comparison renders, or native iPhone measurements have been produced. This machine has no `godot`/`godot4` executable on PATH, so the new Godot test cannot be run locally. No FPS, 1%-low, frametime, drawcall, memory, or physical iPhone result is claimed.
- Flight controls, state-machine transitions, persistent aircraft operations, flight camera, robust route occupancy checks, and two-aircraft taxi separation remain future work.

## Configuration

- `AirfieldHQ23.BUILD_COST`: 2,800.
- `AirfieldHQ23.P47_COST`: 1,800.
- `AirfieldHQ23.AIRCRAFT_CAPACITY`: 1, conservatively limited by the single validated parking marker.
- `AirfieldHQ23.ANCHOR`: reserved site origin `(1000, 0, 0)`.
- `AirfieldHQ23.FOOTPRINT`: `(840, 18, 1140)` metres, keeping the existing 900 m runway footprint.

## Verification

- **PASS:** local `git diff --check` and SHA-256 comparison of the protected `assets/airfield_hq_v22/` inventory.
- **NOT RUN:** Godot 4.7.2 import and automated contract test; no Godot executable is installed in this local environment.
- **NOT RUN:** native iPhone visual/performance tests, Blender exports for 2.3, and USDZ preview validation.
