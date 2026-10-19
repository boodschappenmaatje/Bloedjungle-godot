# Tank (Blender-bron)

`assets/tank.glb` wordt gemaakt door `maak_tank.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_tank.py uit/      # maakt tank.glb, tank.blend en tank_camo.png
    python3 render.py uit/tank.blend $PWD/preview.png 9,10,7 45 --draai

`tank.blend` kun je ook gewoon in Blender openen en met de hand aanpassen of andere textures geven.
Daarna exporteren als glTF (.glb) naar `assets/tank.glb`.

Onderdelen: `Tank` > `Toren` (koepel, draait om de hoogte-as) > `Loop` (kanon, kantelt) > `Monding` (punt voor flits en kogels).
Voorkant is -Z in Godot. Ongeveer 3.300 driehoeken, 1 meter = 1 eenheid.
