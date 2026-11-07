# B-depth PBR jungle understory

This source replaces the earlier procedural leaf silhouettes with three approved
CC0 Poly Haven plants: `fern_02`, `anthurium_botany_01`, and `shrub_04`. The first
two retain three distinct scanned/modelled variants. `shrub_04` combines three
photographed branches into each compact clump variant. Its project names remain
`arch_fern`, `rosette`, and `red_bloom` so the existing gameplay scatter and
clearance code can keep its contracts.

## Provenance and rebuild

The official Poly Haven source package, asset pages, authors, CC0 license URL,
download URLs, source MD5 values, and pinned SHA-256 digests are recorded in
`polyhaven_source/download_manifest.json`. Recheck every source byte and update
that receipt with:

```sh
python3 bron/jungle_foliage_depth/record_polyhaven_sources.py
```

Runtime maps are derived from the official 2K diffuse, alpha, OpenGL normal, and
ARM maps. Transparent RGB and leaf-surface data are edge-dilated before
downsampling; tangent normals are filtered and renormalized. Each 1K runtime
roughness texture stores linear roughness in red and ambient occlusion in green,
so the shader reuses one sample for both channels. The mobile PBR sets are
1024×1024, mipmapped, alpha-cutout textures in
`assets/textures/foliage/polyhaven/`. Their hashes and channel handling are in
that directory's `manifest.json`.

Rebuild the maps and geometry in this order:

```sh
python3 bron/jungle_foliage_depth/prepare_polyhaven_textures.py
blender --background --factory-startup --python bron/jungle_foliage_depth/make_assets.py
```

The editable `jungle_foliage_depth.blend` holds the source silhouettes and the
three PBR materials. `assets/jungle_depth_foliage.glb` contains 27 render-only
meshes, with one mesh per source variant and LOD. It deliberately leaves
materials to the shared Godot shader so no duplicate texture copies are packed
into the runtime GLB.

## Mobile budget and behavior

The largest LOD0 models are 2,844 triangles for anthurium, 2,384 for fern, and
2,242 for the shrub clump. Their LOD1/LOD2 variants reduce to 1,105/315,
1,429/476, and 846/369 triangles at most, respectively. Godot joins each
species/variant's three levels into one `ArrayMesh` surface with native LOD
switches at 20 m and 48 m; existing cell-batched MultiMeshes and 76 m distance
culling remain in use. Detail casts no shadows and adds no collision shapes.

The existing plant-count caps and placements are unchanged by this model pass.
Only the shape variety and material quality change. The species remain low
enough to keep troops and firing lanes legible; source dimensions are normalized
to a 0.53–0.64 m plant height before the existing per-instance scale variation.

All textures and models are CC0 from Poly Haven. The source authors and exact
asset links are in the provenance receipt. No external or generated concept
images are used as implementation evidence; visual approval is based on the
real Godot main-camera capture in `docs/visual_upgrade_b_1_0/captures/`.
