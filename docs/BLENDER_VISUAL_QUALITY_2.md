# BLOEDJUNGLE — Visual Quality 2.0 / Blender production gate

Status: **implemented on the feature branch; physical iPhone/Xogot visual approval pending**. Results and reproduction instructions are in [vq2/README.md](vq2/README.md). This specification applies to the three selected model upgrades in `boodschappenmaatje/Bloedjungle-godot`. Never merge this branch without explicit user approval after an iPhone Xogot review.

## Goal

Upgrade existing **kazerne**, **wachttoren**, and **legerjeep** (not replacements with different gameplay) to a cohesive, visibly more realistic military jungle aesthetic inspired by Command & Conquer: Generals, viewed through Bloedjungle's actual 3D top-down camera. Build/export using Blender in automated/headless mode when possible. No paid cloud workstation required. Preserve source assets and all current gameplay.

Compare to **the actual pre-upgrade versions** using identical camera, scale and lighting. Improving a close-up Blender render while the top-down Godot result is unchanged is not a pass.

## Existing sources and integration constraints

| Model | Source | Runtime asset | Immutable contract / important detail |
| --- | --- | --- | --- |
| Kazerne | `bron/kazerne/maak_kazerne.py` | `assets/kazerne.glb` | Building orientation (+Z entrance in Godot), `scripts/buildings.gd`, footprint and placement |
| Wachttoren | `bron/wachttoren/maak_wachttoren.py` | `assets/wachttoren.glb` | 5.3 m platform, climb logic in `scripts/player.gd`, ladder on +X, `Toren_dak` and `Toren_dakrib` names hidden during platform occupancy |
| Legerjeep (static showcase) | `bron/legerjeep/maak_jeep.py`, `bron/legerjeep/jeep.blend` | `assets/legerjeep.glb` | `scenes/legerjeep.tscn` StaticBody3D + collision; originally ~75,628 triangles with one mesh and 15 material surfaces; DO NOT confuse with playable jeep |
| Playable jeep (viewer animation reference; modify only if necessary) | `bron/jeep/maak_jeep.py` | `assets/jeep.glb` | `scenes/jeep.tscn`, `scripts/jeep.gd` rely on exact hierarchy + MG/driver controls; existing clips Stationair, Rijden, Achteruit, Bocht, Remmen, Vuren, Rondkijken |

Check current remote main and open PRs before modifying paths. Do not copy old preview images as proof of improvements.

## Visual standard VQ2 — mandatory

1. **Plausible geometry:** clear silhouette at game-camera distance, accurate proportions, roof silhouettes and believable construction; bevel important edges and use correct face/weighted normals. Avoid the toy/block appearance of box-only primitives.
2. **PBR surface identity:** meaningful albedo + normal + roughness; metallic only where appropriate; non-repeating UVs or good triplanar/trim layout. Use actual source detail (1K baseline; 2K only for hero/close material where source genuinely warrants it). Never enlarge a 256px map and claim true 2K quality.
3. **Contextual aging:** grime in seams and near ground, rain streaks on walls, chipped paint only on edges, controlled rust on uncoated metal, worn wood fibers, mud accumulation at wheels. Avoid random uniform noise or excessive post-apocalyptic distress.
4. **Top-down first:** concentrate geometry/detail on roofs, cockpit/hood, visible facade edges and tower platform; test at the real gameplay FOV/height, not only studio-close-up.
5. **Coherent palette:** olive drab, desaturated green, earth brown, weathered concrete, galvanized steel, rubber, beige canvas. Match existing jungle and game lighting.
6. **Performance:** maintain iPhone/Xogot usability; propose budgets with reports on triangles/meshes/materials/texture VRAM/draw calls rather than blindly raising counts. For static ~75k-triangle legerjeep, reduce redundant hidden/round geometry while *improving* silhouette and material detail; create useful LOD variants if justified.
7. **Source preservation:** check in editable `.blend` when feasible, deterministic headless `.py` generator, final `.glb`, texture licenses/provenance. No fake or untracked purchased assets.

### Individual improvement targets

- **Kazerne:** weathered wood boards with legible fiber, roof/corrugation and proper thickness/ridges, convincing door/window frames, sill/foundation and localized staining. Retain scale, entry, collision and gameplay.
- **Wachttoren:** realistic timber/metal braces, fastening details, plank thickness and weathering, credible metal roof with drainage and rain marks, believable sandbags/railings, readable climbing ladder. Preserve scripted node names and 5.3 m walkable platform, visibility behavior.
- **Legerjeep:** recognizable military open off-road design, believable body stamping, bonnet/grille/windshield frame, tire tread and sidewalls, seat canvas, dashboard, spare wheel, shovel and jerrycan. Use carefully shaped primary forms, bevels and good shading before adding small bits. Preserve StaticBody3D placement and collision. This static model has **no current animation requirement**.
- **Playable jeep:** the separate existing `jeep.glb` **has animations**. For an animation demonstration, display that existing jeep too; only rebuild it if its hierarchy/animations remain fully intact, validated against `scripts/jeep.gd`.

## Required deliverable: interactive 3D viewer (iPhone friendly)

Build **one shared 3D viewer**, not only PNG stills, with selector:
- Kazerne V1 / V2, Wachttoren V1 / V2, Legerjeep V1 / V2 and animated Playable Jeep (existing and/or improved).
- Touch orbit 360°, pinch zoom, reset view, fullscreen if browser supports it, and top-down camera preset approximating Bloedjungle gameplay.
- Show **real materials loaded from final GLB**, not stand-in meshes.
- Display true GLB animation list, clip selector, Play/Pause, restart, and where possible a time scrubber. When no actual clips exist, display **'Geen animaties in dit model'**; do not invent clips.
- Verify animated playable jeep's exported clips in the viewer; it must visibly move (e.g., wheels steering/rolling, MG recoil) instead of just listing names.
- Robust iPhone Safari fallback and explanatory errors for missing GLB, WebGL or external CDN. The viewer should be a static HTML/JS site with reproducible local instructions; deploy a publicly accessible preview only if authorized and available.
- **ChatGPT 3D-viewer constraint:** Provide real GLB artifacts and an interactive preview link suitable to open from ChatGPT. If native inline 3D rendering is unavailable, explicitly state this and do not claim a viewer runs directly *inside* ChatGPT; offer the live mobile viewer link instead.
- Also include a Godot asset-showcase test scene demonstrating the three upgraded models with interactive existing functionality.

## Evidence and acceptance

For each of three assets supply:
1. Original and upgraded renders at exactly the same framing, environment, and exposure; include isometric/3-quarter and actual in-game camera.
2. New `.glb`, Blender source `.blend` and generator `.py` with instructions to recreate.
3. Mesh triangle/material/texture usage before+after, source resolution, import report, approximate iPhone performance impact.
4. Automated Godot import and relevant regression tests: building placement, tower climbing and roof visibility, legerjeep scene loading, plus existing jeep animations. No global camera or renderer settings changes.
5. Viewer URL or launch instructions; verified animation clip playback for animated models.
6. Human user review in Xogot still required. Don't mark it visually approved until user approves.

## Workflow and branch control

- Work on `feature/blender-visual-quality-v2-three-models`, created from the current main at task kickoff. Rebase/refresh carefully rather than overwrite subsequent work.
- Do not modify or close unrelated PRs (including PR #6 and M1911 VFX).
- Never merge to `main` or enable auto-merge.
- Produce a Draft PR, and include an honest checklist with pass/fail/untested labels. No placeholder screenshots, no fabricated performance measurements.
- If Blender/Godot unavailable in Codex environment: first try reproducible free GitHub Actions CPU pipeline. If blocked, commit the actual scripts and integration work possible, report the exact blocker. Do not claim finished models without real assets.
