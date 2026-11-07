# Jungle Depth Foliage

Three approved visual-only species add distinct silhouettes at the game camera:
`rosette` (broad, ribbed ground leaves), `arch_fern` (arched pinnate fronds),
and `red_bloom` (small oxide-red flower spikes). The source is authored in metres
in Blender Z-up. The exported GLB contains one node for each species/LOD. It is
batched through the existing jungle detail cells and receives no collision.

## Rebuild

From the repository root:

```sh
python3 bron/jungle_foliage_depth/build_pbr_atlas.py
blender --background --factory-startup --python bron/jungle_foliage_depth/make_assets.py
blender --background --factory-startup \
  --python bron/jungle_foliage_depth/export_usdz_previews.py -- \
  --source bron/jungle_foliage_depth/jungle_foliage_depth.blend \
  --output-dir previews/usdz/jungle_depth_foliage
```

The generator writes the editable `.blend`, `assets/jungle_depth_foliage.glb`,
the shared 1024×1024 base-color/OpenGL-normal/roughness set and a triangle manifest.
It does not change original sources. Four atlas quadrants use the project's native
leaf (512²), fern (512×256), and palm (512×256) maps; flower color derives from the
existing leaf source with a restrained red/bronze pigment. The fern and palm maps
are centered in their 512px atlas cells without enlargement. Roughness is authored
from source luminance/edge detail; it is not a measured source map. All PBR maps
are embedded in the GLB and remain available as source files.

## Runtime and budget

LOD0 triangles: broad rosette 648, arched fern 864, red bloom 1,108.
LOD1 and LOD2 reduce the same silhouettes: rosette 56/10, fern 392/200,
bloom 366/102. Godot merges the imported LOD node
arrays into one `ArrayMesh` with native LOD index sets, then uses the existing
cell-batched `MultiMesh`, clearances and distance culling. No extra plant shadow
casters, draw-per-instance objects, or collision shapes are used.

These figures are mesh counts, not mobile frame-rate claims. The iPhone test plan
and actual game-camera capture decide visual and performance acceptance.

## iPhone Quick Look copies

The three LOD0 USDZ review files are in
`previews/usdz/jungle_depth_foliage/v1/`. Blender 4.5.3 exports and re-imports
each package with one visible mesh and its PBR textures; the zip contains one USD
layer and base-color, normal and roughness images. The Linux environment has no
Apple `xcrun usdchecker --arkit` or Quick Look, so Apple validation and physical
iPhone preview remain untested. See the per-file JSON receipts beside each USDZ.
