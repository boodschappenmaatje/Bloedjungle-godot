# Photogrammetry asset provenance

The cinematic uses three Poly Haven CC0 models. Their source `.blend` files are linked as external Blender libraries so the main scene stays portable without duplicating high-poly mesh data. Keep this directory and its `textures/` folder beside the cinematic scene; the relative library links in the `.blend` depend on them.

| Asset | Source page | License | Source file SHA-256 |
|---|---|---|---|
| Island Tree 01, 1K, LOD1 collection | <https://polyhaven.com/a/island_tree_01> | CC0 | `127d2b17778e0dd28508195e9095fe6e78cbcb6c6adb02faf3034506e29c9cd3` |
| Island Tree 02, 1K, LOD1 collection | <https://polyhaven.com/a/island_tree_02> | CC0 | `424746755d270ad50c020c0fe08fe9f0927e655e1ae26d66964d3a3360dd0cd9` |
| Fern 02, 1K | <https://polyhaven.com/a/fern_02> | CC0 | `1bfb6e12d805cc97035c8cbd051187ca6db650e3157fd8884afcf66a6c4e78eb` |

The 24 image maps in `textures/` are the corresponding source albedo, alpha, normal and roughness files. Asset names are retained. Poly Haven's CC0 terms are described at <https://polyhaven.com/license>.

The scene also uses approved Bloedjungle project assets for the M-47, commando, grass, wet soil, concrete, rebar and jungle ground debris. Their source files remain in their existing repository locations.
