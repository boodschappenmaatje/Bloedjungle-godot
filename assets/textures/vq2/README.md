# VQ2 photographic PBR textures

Seven native 1024×1024 sets, derived locally from the existing CC0 photographs
in `assets/textures/buildings`. No provider jobs, new downloads, purchased
art or enlarged low resolution images were used.

`python3 tools/vq2_textures.py` recreates every image. The transformation
retains photographed wood fibres, pores, cloth weave and metal relief, with
directional rain marks, controlled joint oxidation and worn paint masks.
`provenance.json` records the exact input/output SHA-256 digests; original
creator, URL and CC0 evidence remain in `assets/licenses/downloaded_assets.json`
and `docs/ASSET_SOURCES.md`. The derived texture images are CC0-1.0.

Each set has sRGB `albedo.jpg`, OpenGL tangent-space `normal.jpg` (linear), and
linear `orm.png` (R=1, G=roughness, B=metallic). Coated timber, canvas and concrete
are nonmetallic; exposed steel and roof sheet use appropriate metallic values.

The standalone GLBs embed the maps for portable browser use. Godot's scoped
`vq2_import.gd` remaps only `VQ2_*` materials to these shared files, preventing
separate texture copies for each building. The checked import settings enable
mipmaps and desktop/mobile VRAM compression without changing project settings.
