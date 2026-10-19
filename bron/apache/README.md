# AH-64 Apache (Blender-bron)

`assets/apache.glb` wordt gemaakt door `maak_apache.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_apache.py uit/      # maakt apache.glb, apache.blend en apache_olijf.png
    python3 render.py uit/apache.blend $PWD/preview.png 9,16,4.5 38

`apache.blend` kun je ook in Blender openen en met de hand aanpassen of realistische textures geven.

Onderdelen: `Apache` > `RompMesh`, `Rotor` (hoofdrotor, draait om de hoogte-as), `Staartrotor` (draait om de X-as).
Voorkant is -Z in Godot. Ongeveer 4.200 driehoeken, 1 meter = 1 eenheid, rotor 14,6 m doorsnee.
Staat nog niet in het spel.
