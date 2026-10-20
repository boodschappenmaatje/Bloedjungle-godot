# Wachttoren (Blender-bron)

`assets/wachttoren.glb` komt uit `maak_wachttoren.py` (`pip install bpy`):

    python3 maak_wachttoren.py uit/
    python3 render.py uit/wachttoren.blend $PWD/p.png 12,-11,7 38

Platform op 5,3 m, klimladder aan de +X zijde, dakdelen heten Toren_dak en Toren_dakrib (de game verbergt ze als je op het platform staat). Klimlogica staat in scripts/player.gd.
