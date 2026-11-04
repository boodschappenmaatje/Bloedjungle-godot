# Base Wall HQ 2.0

## Source and optimized asset

The source is the original Meshy GLB from the Google Drive transfer in `docs/base_wall_hq2_source_transfer.md`. Its verified SHA-256 is `19df1f487dc1b98f4890354340b9e4dc93aad2baa21ec900ea1fe4f46d4e9d0e` (15,535,848 bytes). The source is kept in ignored `source_assets/base_wall_hq2/`; it is not included in the game export. `bron/base_wall_hq2/build_wall.py` refuses a source with any other size or digest.

Inspection measured the source mesh at approximately 1.904 × 0.318 × 1.018 m, with 226,646 triangles, one material, and embedded PBR images. The actual supplied mesh is a weathered concrete-and-post barrier with US Army markings; it does not have the all-wood appearance described in the transfer prompt. The optimized wall keeps the source's proportions and markings, trims its central mesh to a 1.8 m high core, and adds three rows of shared jute sandbags to meet the 3 m target without stretching the source vertically to three times its measured height. The thickness correction is 1.26×; length and core-height corrections are close (1.84× and 1.77×).

The runtime resource is `assets/base_wall_hq2.glb`: exact bounds 3.5 × 0.4 × 3.0 m, 10,635,096 bytes, SHA-256 `18eca7972f512f885482cb22b7aa50e142a55ce0300a677f475e37b7e5540a26`, two shared PBR materials, 2K-or-smaller maps, and three LODs. Godot imports the embedded images as Basis Universal textures into its scene resource, keeping the runtime asset self-contained without loose texture files:

| LOD | Triangles per segment | Distance band |
| --- | ---: | ---: |
| 0 | 8,380 | 0–28 m |
| 1 | 2,960 | 28–58 m |
| 2 | 758 | 58 m and beyond |

The source tangent normal map is retained. Decimation reduces the original 226,646-triangle mesh; low-poly jute bags and their normal map are shared across segments. The editable Blender scene and machine-readable build report live under `bron/base_wall_hq2/uit/`. Rebuild from the verified local source with:

```sh
blender --background --threads 4 --python bron/base_wall_hq2/build_wall.py -- \
  source_assets/base_wall_hq2/Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb
```

## Perimeter and gameplay

`BaseProps._wall()` places 60 shared-mesh instances in six straight spans around the unchanged 56 × 56 m perimeter. A single shared six-instance earth berm grounds the wall while leaving both existing 6.8 m gate approaches clear. Each span has one continuous 3 m box collider; the two gates retain their animated low steel leaves and gain matching upper leaves and full-height collision while closed. Opening the gate disables its collision as before. The four existing watchtowers, bunker, base route, roads, buildings, vehicles, and gate positions are retained.

The camera fades only the wall span between the camera and player. This visual fade does not change the collision body or its combat layer. `Bullet.fire(..., over_wall=true)` continues to bypass low `LAYER_WALL` cover but retains `LAYER_FORTIFICATION` for this base wall. Ground-level direct fire also checks its projected low-height path, so aiming at an elevated target cannot arc ordinary bullets over the 3 m wall; elevated tower weapons retain their existing line-of-sight behavior. Ground-projectile, melee-adjacent blast, grenade, mine, tank-shell, and other ground explosion damage checks use fortification line of sight. Artillery intentionally retains its existing overhead wall-bypass rule. Aircraft napalm/airstrike rules remain aerial exceptions; aircraft crash damage is a ground blast and checks fortification line of sight.

## Validation evidence

`tests/base_wall_hq2_test.gd` checks imported bounds, LOD triangle/material/texture budgets, segment count, portals, continuous collision at straight seams and a corner, player capsule movement, high-wall projectile masks, wall-origin shots, grenade/rocket paths, closed and open gate collision, blast occlusion, camera fade, and the artillery exception. `tests/routes_test.gd` checks that existing attack routes still spawn and advance. The iOS workflow runs the wall regression before the existing bunker, soldier, weapon, and export checks. The OTA pull-request workflow exercises the existing light/heavy patch and old-updater bridge safety simulations.

The JPEGs in `screenshots/` are Blender preview compositions using the optimized GLB and the existing gate/watchtower models; they are not captures from a running Godot or iPhone build. The preview uses a simplified field floor and bunker footprint. `00_before_primitive_wall.jpg` reconstructs the previous `BaseProps._wall()` primitive dimensions and is labeled for visual comparison. These are review compositions, not runtime screenshot claims.

The perimeter contains 60 segments: at most 502,800 / 177,600 / 45,480 wall triangles if every segment were simultaneously at LOD0 / LOD1 / LOD2, plus 120 triangles for the shared berm shoulders and four corner caps. The six span MultiMeshes use two materials each; one active LOD per span contributes up to 12 wall surface submissions, with two additional berm surface submissions. These counts exclude shadow/depth passes and gates/towers. Six simple box colliders replace per-segment high-poly physics. No physical iPhone run was available in this workspace; FPS, 1%-low, GPU draw calls, and device memory are therefore unmeasured, and no 60-FPS guarantee is made. CI's iOS build validates compilation/export, not device performance or an OTA upgrade on a physical phone.
