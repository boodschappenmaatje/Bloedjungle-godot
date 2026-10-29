# Weapon Upgrade 2.0 — build and test report

Build output was produced through the existing local Bloedjungle 3D Production Pipeline 1.0 using Blender 4.5.15 LTS. Godot 4.7.2 imported the final GLB. The local `game-dev` CLI is not installed, so its adapter, sealed-capture and canonical-package receipts are unavailable. The repository's documented local Blender/Godot route was available and authorized for the asset build and game tests; direct outputs and test results are recorded below.

## Assets

- Six weapon roots retained: M1911, Thompson, Garand, Trench, MG42 and Bazooka. `Huls` and `Raket` remain available.
- Existing animated node names and 60 Hz clips remain. The Bazooka has no fabricated animation clip.
- Editable high-quality source and separate game `.blend` are in `bron/wapens/uit/`; reproducible generator and render helper are in `bron/wapens/`.
- `assets/wapens.glb`: 11,087,484 bytes, 27,848 triangles including Huls/Raket, 48 nodes, 35 meshes, 9 materials and 27 embedded images. All 35 mesh primitives have UVs and normals. All 9 materials reference base color, metallic-roughness and normal maps. The six weapon roots total 27,068 triangles.
- Original per-material maps are generated at 512×512 by the source script. No third-party model or texture was introduced.
- `assets/vq2_baseline/wapens.glb` preserves the old asset for V1/V2 comparison and rollback.
- Six static iOS Quick Look packages were exported from the HQ `.blend` and ZIP/CRC-checked: `bron/wapens/uit/ios_preview/{M1911,Thompson,Garand,Trench,MG42,Bazooka}.usdz` (30,941,814 bytes total). Quick Look on an iPhone was not run; these omit the GLB's interactive clips.

## Verification

| Check | Result |
| --- | --- |
| Blender background build, HQ source, game source and GLB export | PASS |
| Godot 4.7.2 headless import of final GLB | PASS |
| `tests/wapen_clips_test.gd --fixed-fps 60` | PASS — all five mechanical parts move the expected distance and reset; M1911 empty-slide hold/reset passes |
| `tests/combat_visuals_test.gd --fixed-fps 60` | PASS — six damage/ammo values, recoil profiles, sound mappings, burst bloom, projectile/FX limits, muzzle/casing positions, hand reach, and Garand last-shot ping |
| `tests/loadout_test.gd` | PASS — existing five-slot loadout, ownership and upgrade persistence |
| `tests/auto_raken_test.gd --fixed-fps 60` | PASS — 672 hit cases; all six weapons hit both auto and bus targets |
| `tests/weapon_test_zone_test.tscn` | PASS — real Main/player/camera, six selections, three target types, auto and bus |
| `tools/blender-vq2-viewer/test-wapens.mjs` | PASS — six clips, measured motion, empty M1911 slide, no Bazooka dummy clip, and orbit in Chromium software WebGL |
| Six USDZ archive integrity checks | PASS — all six exports open as ZIP/USDZ archives with valid entries |
| Local `game-dev` adapter/capture/package receipt workflow | NOT RUN — required local CLI is absent |
| Physical iPhone 18 Pro Max / Xogot FPS and touch testing | NOT RUN |
| USDZ / Quick Look on an iPhone | NOT RUN |

The general pipeline `validate_glb.py` reports FAIL only for its blanket requirement that every material reference occlusion and emission textures (0/9 each). These weapon materials are not emissive and no AO bake was specified; the other GLB checks pass. The validator result is preserved at `docs/vq2/results/wapens-glb-validation.json` rather than being relabelled as a pass.

Godot's headless renderer warns that SSAO is unavailable in its headless backend; tests still pass. The game test processes also report existing resource-leak warnings during shutdown. Neither warning was treated as a test pass/fail signal.

## Review captures

The six Blender draft renders and same-canvas/same-camera V1/V2 viewer comparison are in `docs/vq2/renders/`. The 3D viewer shows isolated V1/V2 weapons with matching camera and real clips. In-hand pose is reviewed in the real Godot Weapon Test Zone rather than overlaid in that browser viewer. Human visual approval and physical iPhone review remain pending; this work stays in Draft PR #141.
