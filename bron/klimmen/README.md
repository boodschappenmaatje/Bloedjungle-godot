# Klim-animatie (Blender-bron)

`assets/klimmen.glb` komt uit `maak_klimmen.py` (`pip install bpy`): het skelet van `assets/soldaat.glb` met alleen de loop-animatie "klimmen" (20 frames, 30 fps: links-rechts op een ladder).

    python3 maak_klimmen.py uit/
    python3 render.py uit/klimmen.blend uit/

`scripts/soldier_model.gd` haalt de animatie uit dit bestand en hangt hem aan elk mannetje. De speler speelt hem af in `player.gd` (`_climb_step`).
