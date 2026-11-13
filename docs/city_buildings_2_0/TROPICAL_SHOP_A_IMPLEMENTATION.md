# City Buildings 2.0 — Tropical WWII Shop A

Status: implementation in progress; **do not merge or publish OTA**.

## Approved design
- Tropical 1940s colonial two-storey shop, weathered plaster, blue-green shutters, tiled roof and awning.
- Both storeys playable in third-person: accessible shop and storage downstairs, rooms upstairs, walkable stairs, balcony access.
- Overhead construction camera must display intact roof and footprint/placement feedback.
- Source asset (private Drive): https://drive.google.com/file/d/1Mw0iNGLezRnIUiVFmCDAX8dBGaSyWfa2/view
- Supplied GLB: `Meshy_AI_Photorealistic_1940s__1113185619_texture.glb`; reported inspected: 48,646 triangles, one mesh, one material; do not assume it has an empty interior or separate roof.
- Initial envelope target approximately 12 × 9 m; measure actual mesh bounds before deciding uniform scale. This is not an approved exact measurement.

## Implementation (Codex/Blender/Godot)
1. Read `AGENTS.md`, `docs/ASSET_QUALITY_STANDARD.md`, `docs/vq2/README.md` and `docs/GENERALS_PLAN.md`. Inspect actual city-generation/building scene & placement code before touching it.
2. Import actual Drive GLB to Blender; save unmodified source externally and record mesh bounds, triangles, texture resolution, topology/manifold diagnostics and photos/renders (front/back/side/top).
3. Do **not** simply carve a closed, thin decimated shell by automatic booleans. Evaluate roof topology, windows, doors and facade. If cutting damages source mesh, preserve surface appearance through baked materials and rebuild a clean, hollow structural shell with precise openings. Separate roof, awning, balcony, storey floor, exterior and interior walls; align decorative facade pieces to shell. Ensure no blocked openings.
4. Create a reusable modular Blender generator/source and optimized GLB with collision-friendly floors/walls/stair. Build TWO navigable storeys. Make interior props as separate reusable instances (store, storage, upper living room/bedroom); no expensive interior behind permanently opaque walls.
5. Create independent Godot 4.7.2 showcase scene; explicit roof visibility and camera occlusion when the player is indoors; overhead construction mode shows full roof, valid placement footprint and avoids interaction obstruction. Do not alter current player controls or default camera until third-person integration is separately approved.
6. Tests: import/headless load, character-scale door and stair traversal, collision/nav tests, camera transitions, rooftop/balcony visibility, screenshots/renders both modes, no change in current city scene, measured triangles/draw calls/frame time. Target LOD0 ~50k exterior; LOD1 ~15k, LOD2 ~3k as hypotheses subject to real device profiling. Preserve PBR and quality standard.
7. Model viewer: add before/after and freely rotating 3D preview to `tools/blender-vq2-viewer/`. Produce .blend, GLB, screenshots; .usdz Quick Look preview if tooling supports it. Record limitations accurately.
8. CI and iOS unsigned export only on featurebranch. Native 60 FPS performance remains unverified until device test. NO merge / NO OTA without explicit approval.

## Acceptance checklist
- [ ] Blender source and actual modified GLB created (not just concept)
- [ ] Model visually faithful to Meshy source from all sides
- [ ] Both storeys, doors, staircase, balcony physically traversable
- [ ] Roof independently toggleable; third-person camera avoids clipping
- [ ] Build-mode footprint and full roof visible; no regression to current buildings
- [ ] Godot 4.7.2 scene imports and tests pass; capture evidence committed
- [ ] 3D viewer and performance report provided
- [ ] Draft PR remains unmerged and OTA unpublished

Do not claim any checkbox is complete without real output/test proof.
