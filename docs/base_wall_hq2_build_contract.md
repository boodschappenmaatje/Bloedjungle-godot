# Bloedjungle Base Wall HQ 2.0 — implementation and release contract

Read `docs/base_wall_hq2_source_transfer.md` FIRST. That document gives the ORIGINAL uploaded Meshy GLB, a working Google Drive file link, exact byte length and SHA-256. Use the original source, not a substitute. No need for a user re-upload or new Meshy credits.

## Scope and constraints
- Repo: `boodschappenmaatje/Bloedjungle-godot`.
- Existing branch: `feature/base-wall-hq-2-0-meshy`. Continue on this branch; never start a conflicting branch without reason.
- Existing base perimeter: `Data.COMPOUND=28`, i.e. square 56 x 56 metres with north and south gate openings `Data.GATE_GAP=3.4`, four corner watchtowers.
- Replace **all old visible own-base perimeter wall** with the supplied approved WWII US field-fortification Meshy modular wall. Do not change enemy-base walls.
- Target segment: 3.5 metres length, 3.0 metres height, 0.4 metres depth; actual source GLB dimensions must be normalized and validated, without distorting proportions. Source is ~226k triangles, too heavy to repeat unoptimized on mobile.
- Keep existing base layout, two gates, sliding gate animations and repair/damage systems, towers, HQ bunker, AI routes, supply trucks and player.
- Maintain the look of the supplied Meshy model, with authentic weathered wood, posts, earth and sandbag details; no generic replacement design.

## Geometry and visual quality
1. Use Blender inspect -> remesh/retopo/decimate -> normal bake -> shared PBR atlas -> LOD0/1/2. Indicative segment targets: 6k–10k / 1.5k–3k / 300–800 triangles; validate mobile FPS and justify deviations.
2. Keep original source asset outside OTA-exported game runtime and avoid committing 15.5MB unoptimized source to exported assets. Reuse optimized GLB resources, material and texture imports; avoid independently duplicating per segment.
3. Generate seamless horizontal/vertical placements from perimeter geometry. Use an accurate snapping strategy with special short filler, inside/outside corner and gate-end modules.
4. No cracks, Z-fighting, floating modules, duplicated corner posts, seams between colliders or different visible levels of wall height. Continue on same existing north/south portals. Blend the wall bases into dirt with subtle earth berm or material transition.
5. Retain subtle WWII military detailing. New variants must derive from the approved visual style and not require additional Meshy credits.
6. Follow existing Godot renderer and performance settings; use shared materials, reasonable shadow distance and LOD. Compare draw calls, triangles, FPS/1%-low/memory against current build; do not promise 60 FPS without measurement.

## Collision and combat
1. Use economical static collision bodies on `Kit.LAYER_WALL` covering the visible 3m wall with closed seams/corners, no high-poly concave collision per module.
2. Prevent player, enemies, friendlies and vehicles from walking/climbing/glitching through closed walls. Preserve traffic and pathfinding through OPEN gates.
3. Both players and enemy ground troops must not shoot straight THROUGH or OVER the new 3m fortification from either side. Pay special attention to `Bullet.fire(..., over_wall=true)` which currently removes `MASK_WALL`. Fix it for full-height perimeter walls without breaking deliberate low-cover mechanics elsewhere.
4. Validate all hitscan/projectile paths, including rocket/automatic weapon, muzzle height, raycasting and damage attribution. AI should not shoot targets through blocked lines of sight. Closed gate blocks; animated/open gate permits passage.
5. Explosion splash: add wall occlusion/cover verification so nearby explosives cannot apply unrestricted damage through a solid wall; keep separately specified artillery/airstrike exceptions grounded in the existing game behavior.
6. Higher walls must not ruin the Dead Nation camera or aiming controls. Camera occlusion tricks must NOT disable physical or gameplay wall collision.

## Existing code to audit
`scripts/base_props.gd`, `scripts/data.gd`, `scripts/gates.gd`, `scripts/kit.gd`, `scripts/bullet.gd`, `scripts/enemy.gd`, `scripts/player.gd`, `scripts/route.gd`, `scripts/level.gd` and grenade/explosion/vehicle/AI test paths. The old `BaseProps._wall` includes concrete boxes/posts, and `BaseProps._gates` provides gate posts and overhead signage. Preserve needed functional portions while eliminating old visible walls.

## Required validation
- Exact segment dimensions, outline continuity, both portals, corner/gate seams, no surviving old wall mesh.
- Physics from inside/outside: actor cannot cross or jump; vehicles can cross only open gates.
- Combat: bullets/rays/rocket/grenade/explosion through/over wall blocked per rule; open gate shots possible; old low-cover gameplay still works elsewhere.
- AI movement around base; door opening/closing, repairs and damage, truck deliveries, watchtowers, bunker.
- Original GLB checksum confirmed, imported optimized resources present in OTA, no missing materials/texture.
- iOS/desktop visual screenshots: overhead, three-quarter, both gates, all corners, in-game battle.
- Performance before/after and no severe Godot import/resource errors. Verify Godot 4.7.2 compatibility.
- Run existing tests plus new base-wall-specific automated regressions. Ensure iOS CI and OTA preview; no test bypasses.

## Completion
Develop on existing feature branch, commit code/assets/tests, open PR, fix CI until all required checks pass. Only then merge PR to main (no force push) and wait for successful main OTA safety net and published `updates` release manifest with matching commit and actual patch assets. Report exact PR/head/main/OTA commit, checks, screenshots, measurements and remaining limitations. No IPA reinstall or user save-data deletion.

If Codex Cloud session was interrupted, the documentation in this branch is the authoritative persisted specification. Resume from it rather than demanding the user upload the Meshy GLB in-chat again.
