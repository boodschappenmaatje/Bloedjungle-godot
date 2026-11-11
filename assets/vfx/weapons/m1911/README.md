# M1911 original VFX source concepts — Bloedjungle

**Status: DRAFT. No Godot/Xogot run in the producing environment.**

This branch contains **10 original SVG source textures** and a small isolated visual preview scene. No game-play scripts, damage, audio, global rendering defaults, scenes/main.tscn or HUD files were changed.

### Included
- 3 muzzle flash variants.
- Thin gold-white tracer source.
- Metallic impact sparks.
- Dust for dirt and concrete, plus smoke.
- Zombie hit splatter.
- Warm light halo.

### Test on Xogot
Open `res://scenes/vfx/weapons/m1911/m1911_vector_preview.tscn` and run it. Tap **M1911 SCHOT** and **ANDER DOEL**. This only previews sprites: it is **not** an M1911 weapon integration, damage simulation, physical capture or a validated frame-rate benchmark.

Godot can import SVG as rasterized textures; actual importer and renderer behavior must be checked in Xogot. For lower import risk and efficient mobile use, a separate ZIP of 12 rasterized PNG textures plus example Godot scene was also generated in the ChatGPT conversation. It is not part of this GitHub PR: upload that ZIP to Codex/Work for the subsequent integration if needed.

### Existing integration
Reuse draft PR #50 (`feature/arcade-shooting-vfx-prototype`) for the working M1911 lab. Connect these authored texture concepts to its `ArcadeVfxProfile` and the real `Fx` and `Bullet` nodes. Keep real ballistics, damage, animations, save files and Sfx unchanged.

### Validation boundary
- SVG source files created in GitHub: yes.
- Godot native preview scene/script created: yes; execution not validated.
- Godot renderer capture: no (local Godot binary unavailable).
- iPhone/Xogot performance: no.
- Official Game Development Studio CLI build/validation receipt: no (`game-dev` CLI missing).
- Merge to main: prohibited without review.

### License and provenance
Original vector designs authored solely for Bloedjungle, based on broad arcade military visual principles. No ripped images, audio, paid API calls or third-party licensed textures. The project owner can modify and use these sources in Bloedjungle.
