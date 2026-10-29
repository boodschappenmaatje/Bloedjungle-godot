# Napalm-vlam (Blender-vuursimulatie)

`maak_vlam.py` simuleert vuur met Mantaflow (Blender 4.3), laadt de VDB-cache als volume en rendert 64 beelden (8x8 atlas, 256 px, alpha).
Gebruik: `blender --background --python bron/napalm/maak_vlam.py -- <uitmap> [--snel]` (hoge kwaliteit ca. 9 min op 4 cores). Plak de f###.png-beelden tot `assets/napalm_vlam_atlas.png` (8 kolommen, rij 0 boven).
In het spel: `shaders/napalm_vlam_sim.gdshader` + `Fx.napalm_flame_sim` (gebruikt door `NapalmAanval`). Zonder atlas valt het terug op de shader-vlam.
Gemeten: iPhone/Xogot-prestaties NIET. Twee atlassen: staand (napalm_vlam_atlas.png) en laag/breed (`--laag`, napalm_vlam_laag_atlas.png). Rook en plas uit Blender volgen na goedkeuring.
