# Visual Upgrade B 1.0
Spec: user's approved Terrain + Foliage Depth Pass; attached target has C label.
Base: b808fe1, feature/visual-upgrade-b-1-0. No merge/OTA.

1. Capture baseline from main.tscn, existing Camera script, High/day/clear/fake tree shadows, 60% render scale, fixed seed. Record reproducible static and 80-enemy combat timings and camera metadata. User screenshot lacks world coordinates/save; exact reconstruction cannot be claimed.
2. Reuse terrain PBR maps (no downloads). Pack existing normal+roughness into shared RGB+A maps for grass, jungle floor, earth, mud and moss; retain source maps. Blend at physical scale; organic path shoulders, longitudinal wear, restrained wet patches. Preserve all ground holes and collision mesh.
3. Reuse existing fern/bush geometry, Blender grass variants and LODs. Add clustered low understory and debris (existing rock/leaf/wood shapes) around natural anchors, path shoulders, riverbanks and foundations. Register removable vegetation with existing building clearance; no new collision or tree displacement. Bound counts, batch by cell, respect quality switches and distance culling.
4. Improve root contact in foliage shader and reduce flat yellow haze with existing sun/sky/fog only. Preserve time/weather/quality/shadow controls and all gameplay files.
5. Render real before/after, inspect and iterate; test route openness, render-only clearance, material contracts, existing regressions, iOS resource pack export. Document all test failures and unsupported hardware tests. Draft PR only; visual/mobile acceptance remains pending where reference or measurement cannot be achieved.

Review focus: base and gate clearance; bridge/ford corridors; building clearing (no plants through new walls); Mobile shader sampler/alias budget; quality/governor switches.
