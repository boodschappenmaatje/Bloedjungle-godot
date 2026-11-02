# Kazerne HQ 2.0 — Meshy source / production gate (2026-11-02)

**Status: INCOMPLETE — no game asset installed, no merge, no OTA.**

This report documents an actual inspection of the supplied Meshy archive, not a conceptual model.
The source export is a ZIP-named FBX with embedded source FBX and four 2048×2048 PNG maps.
Geometric source: **2,285,660 triangles**, 1,142,570 source vertices, single material,
UV mapping present. Original model is a 1943–45 US Army field barracks.

## Source processing, performed outside repository
- Original source preserved. High-resolution PBR source GLB exported at **6.4 m width × 4.8 m depth × 3.5 m height**, door oriented +Z for Godot.
- High GLB: **66,433,012 bytes**, with embedded 2K base color, normal, packed metallic-roughness textures, real original geometry.
- Initial mobile tests: automatic 79,999-triangle QEM candidate and UV-aware 81,604-triangle candidate. Both displayed unacceptable roof holes or wall/UV artifacts. **REJECT**; not suitable for integration.
- High GLB plus reproducibility report is available as a direct ChatGPT conversation artifact, not checked into GitHub. The branch intentionally does **not** reference missing runtime assets.

## Next action / explicit quality gate
1. Use the user-supplied source FBX (or high-source GLB) and the Blender candidate export script alongside actual Blender 4.5.15 on the iMac or a configured CI runner.
2. Retopologize correctly, preserve roof and facade, re-bake tangent-space normal/AO **from the full source** to the reduced mesh. Validate 2K albedo, 2K normal, packed 2K ORM. Inspect texture seams.
3. Supply genuine .blend, LOD0 at 60–80k (40k minimum only if quality remains intact), LOD1 ~20–30k, distant LOD after review, and a touch-friendly comparison preview.
4. After final asset passes visual comparison, update scripts/buildings.gd in a **single change**: DEFS size, collision/footprint, door_of spawn offset, door clear checks; preserve build/recruit/rally/repair/damage and level logic.
5. Run Godot import and gameplay regressions on the feature branch, then native iPhone performance after explicit merge/OTA approval.

## Verification
| Check | Status |
|---|---|
| Source FBX / 2K PBR maps inspected | PASS |
| GLB high source dimensions + UV + packed maps | PASS |
| Reduced 80K candidate visual acceptance | **FAIL** (holes/texture artefacts) |
| Approved mobile LOD0/LOD1 assets | NOT READY |
| Blender .blend high-to-low bake | NOT RUN (Blender not available in the current environment) |
| Godot 4.7.2 import and gameplay | NOT RUN (Godot not available in current environment) |
| iPhone native FPS | NOT RUN |
| Merge / OTA | NOT DONE |

**Do not replace `assets/kazerne.glb` or change gameplay yet.**