# M-47 Cinematic VFX 4.0

Een geïsoleerd Godot 4.7.2-project, gestapeld op de assetbranch van PR #238 en de VFX-branch van PR #239. Dit project raakt de root-scènes, bestaande bazooka, spelerbesturing en grafische instellingen niet.

## Bronnen

- `M47_Muurbreker_1.0_animated.glb` is een symlink naar de goedgekeurde asset in `docs/assets/m47-muurbreker-1.0/`.
- `soldaat_vq2.glb`, `jungle.glb` en de terrein-/bladtexturen wijzen naar bestaande repository-assets.
- `cinematic_concrete_breach.glb` en `blender/M47_Cinematic_Breach_4_0.blend` zijn nieuwe, afzonderlijke showcase-assets. De originele M-47-GLB wordt nooit door het Blender-script geopend of gewijzigd.

## Reproduceren

```bash
blender -b -noaudio -t 4 --python tests/m47_cinematic_vfx/blender/build_cinematic_assets.py
python tests/m47_cinematic_vfx/blender/pack_flipbooks.py
python tests/m47_cinematic_vfx/blender/make_light_cards.py
DISPLAY=:99 GODOT_BIN=/pad/naar/Godot_v4.7.2-stable_linux.x86_64 bash tests/m47_cinematic_vfx/run_showcase.sh
python tests/m47_cinematic_vfx/inspect_assets.py
python tests/m47_cinematic_vfx/make_captures.py
```

Voor alleen een nieuwe wand-/puinexport kan `-- --wall-only` achter de Blender-opdracht. Dat vervangt de flipbookatlassen niet. De test-scène gebruikt dezelfde camera als VFX 2.1: positie `(-0.4, 5.6, 7.2)`, doel `(2.0, 1.28, 0.25)`, FOV `47°`.

`screenshots/m47_cinematic_vfx_4_0.mp4` is de onbewerkte Godot-video. `screenshots/cinematic_*.png` zijn onbewerkte enginebeelden; `detail_*.png` zijn uitsneden daarvan. Zie `TESTRAPPORT.md` voor metingen en resterende verschillen met het referentiebeeld.
