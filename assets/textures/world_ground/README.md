# World ground — five photographic PBR layers

Rebuild with `python3 tools/build_world_ground.py` from the repository root.
Original photographs and maps remain under `assets/textures/terrain/`. They are
licensed CC0 by the original asset manifest. No download, AI image, paid provider
or upscaling is performed by this build.

The existing files are stored at 1024×1024. Some existing Poly Haven inputs were
already resampled from 512px before this task; these are **not new native 1K
sources**. Exact source limits, current byte hashes, prior manifest hashes and
original URLs are recorded in `provenance.json`. Prior manifest hashes do not
all match the current repository bytes; the originals were left untouched.

- `*_albedo.jpg`: restrained tint and lower photo microcontrast, sampled as sRGB.
- `*_normal_roughness.png`: **linear data**; RGB is the existing OpenGL normal,
  alpha is true source roughness remapped to a layer-specific dry/damp range.
- Keep alpha during Godot import. Normal-only compression would destroy the
  roughness channel. The committed import files use RGBA VRAM compression,
  mipmaps and desktop/mobile formats. No geometry or height is inferred.

The existing ground shader combines dry earth, gravel shoulders, damp mud, grass
and litter with the existing compound/gate/forest trail layout. Wetness follows
the existing weather menu. River, trench and helipad cut-outs are unchanged.
