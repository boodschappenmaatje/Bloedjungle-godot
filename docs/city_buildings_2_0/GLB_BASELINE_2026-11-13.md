# Meshy GLB actual geometric inspection — 2026-11-13

Source: Google Drive file ID `1Mw0iNGLezRnIUiVFmCDAX8dBGaSyWfa2`, file `Meshy_AI_Photorealistic_1940s__1113185619_texture.glb`. Inspection performed using Python `trimesh`; **not** Blender/Godot validation.

| Property | Observed |
|---|---|
| Number of scene geometries | 1 |
| Triangles | 48,646 |
| Vertices (loaded mesh) | 100,315 |
| Watertight | **False** |
| Mesh bounds min | (-0.94504, -0.95169, -0.82187) |
| Mesh bounds max | (0.94375, 0.94874, 0.84142) |
| Mesh extents | (1.88879, 1.90044, 1.66329) |
| Visual type | textured mesh |

**Important:** The approximate 1.9×1.9×1.66 coordinate extents are **not a believable real-world two-storey-building size**; do not treat the GLB's encoded unit or bounds as verified metres. Choose orientation and scale against the in-game character and door dimensions after inspecting original world/city asset conventions.

### Implications
- One combined geometry, no separate roof or floors. Do not imply that removing roof is trivial.
- Mesh is not watertight, so blindly applying booleans and creating a hollow shell risks damage.
- Build a clean structural shell and stairs, reproject/bake exterior appearance or carefully segment facade where feasible.
- Preserve raw original and create derived assets only, keeping provenance. Audit texture maps, normals and materials before final export.

### Still required
Actual Blender processing, geometry separation, roof/floor/collider creation, Godot scene import, renders, 3D viewer, gameplay and iPhone tests. **None of these have passed yet.**
